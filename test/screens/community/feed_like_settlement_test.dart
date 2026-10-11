import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/screens/community/community_screen.dart';
import 'package:art_kubus/screens/desktop/community/desktop_community_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/pending_action_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/widgets/auth/pending_action_continuation.dart';
import 'package:art_kubus/widgets/community/community_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

/// The backend as the feed and the like action see it. A guest's feed never
/// shows a like, so the feed starts unliked; [likedOnServer] is what the
/// account already holds.
class _FakeBackend {
  // When set, a like is recorded at once and answered only when this completes
  // (the rig: the like lands in about a second, the answer takes 20 to 40 s).
  Completer<void>? likeAnswer;

  _FakeBackend({required this.likedOnServer, this.failAfterInsert = false});

  bool likedOnServer;

  /// The like route writes the like, then answers with a server error (the
  /// browser run's behaviour).
  final bool failAfterInsert;
  int serverLikeCount = 3;
  int likeRequests = 0;

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: const {'content-type': 'application/json'},
      );

  Map<String, dynamic> _postJson() => <String, dynamic>{
        'id': 'post-1',
        'authorId': 'user-1',
        'authorName': 'Ana Umetnica',
        'content': 'A mural on the riverside wall.',
        'createdAt': '2026-10-01T12:00:00.000Z',
        'likeCount': serverLikeCount,
        'isLiked': false,
      };

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/community/posts') {
      return _json(<String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[_postJson()],
      });
    }
    if (request.method == 'GET' &&
        path == '/api/community/interactions/state') {
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'posts': <String, dynamic>{
            'post-1': <String, dynamic>{
              'isLiked': likedOnServer,
              'likeCount': serverLikeCount,
            },
          },
        },
      });
    }
    if (request.method == 'POST' &&
        path == '/api/community/posts/post-1/like') {
      likeRequests += 1;
      // The like route is idempotent: a repeated like never counts twice.
      if (!likedOnServer) serverLikeCount += 1;
      likedOnServer = true;
      await likeAnswer?.future;
      if (failAfterInsert) {
        return _json(<String, dynamic>{
          'success': false,
          'error': 'Internal server error',
        }, 500);
      }
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'likesCount': serverLikeCount},
      });
    }
    return http.Response('{}', 404);
  }
}

/// Chat is not under test here. The feed starts chat when it loads, and a
/// signed-in chat opens a live socket that outlives the test. This keeps the
/// feed's chat start-up away from the network.
class _SilentChat extends ChatProvider {
  @override
  Future<void> initialize({String? initialWallet}) async {}
}

/// The account step a guest reaches from the gate. Finishing it authenticates
/// the session and restores the attempted action, as the post-auth coordinator
/// does after a real sign-in.
class _FakeSignIn extends StatelessWidget {
  const _FakeSignIn();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            BackendApiService().setAuthTokenForTesting('test-token');
            await context.read<PendingActionProvider>().restore();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Finish sign-in'),
        ),
      ),
    );
  }
}

/// The feed under test, inside a navigator that knows the sign-in route, with
/// the continuation host above it as in the app shell.
Widget _shell(Widget feed) => Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => settings.name == '/onboarding'
            ? const _FakeSignIn()
            : PendingActionContinuationHost(child: feed),
      ),
    );

Future<void> _pumpFeed(
  WidgetTester tester, {
  required Widget feed,
  required Size size,
  required PendingActionProvider pending,
  required CollabProvider collab,
  required ChatProvider chat,
}) async {
  final prior = FlutterError.onError;
  final extra = <SingleChildWidget>[
    ChangeNotifierProvider<PendingActionProvider>.value(value: pending),
    ChangeNotifierProvider<CollabProvider>.value(value: collab),
    ChangeNotifierProvider<ChatProvider>.value(value: chat),
  ];
  await pumpProductSurface(
    tester,
    child: _shell(feed),
    size: size,
    extraProviders: extra,
    settle: const Duration(milliseconds: 500),
  );
  FlutterError.onError = prior;
  // The feed loads over the fake client, which completes outside the fake
  // clock; give it real turns to land before reading the card.
  for (var i = 0; i < 5; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// Taps the like action on the one post card, then walks the guest through
/// the gate, the sign-in step and the confirmation.
Future<void> _likeAsGuestAndConfirm(WidgetTester tester) async {
  final heart = find.descendant(
    of: find.byType(CommunityPostCard),
    matching: find.byIcon(Icons.favorite_border),
  );
  expect(heart, findsOneWidget);

  await tester.tap(heart);
  await tester.pumpAndSettle();
  expect(find.text('Like this post'), findsOneWidget);

  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
  expect(find.text('Finish sign-in'), findsOneWidget);

  await tester.tap(find.text('Finish sign-in'));
  await tester.pumpAndSettle();
  await tester.pump(PendingActionContinuationHost.settleDelay);
  await tester.pumpAndSettle();
  expect(find.text('Like this post?'), findsOneWidget);

  await tester.tap(find.widgetWithText(FilledButton, 'Like'));
  for (var i = 0; i < 5; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  // Let the feed's short debounce timers run out before the test ends.
  await tester.pump(const Duration(seconds: 1));
}

/// Lets real and fake time run until the feed's background work has settled.
/// The feed opens a socket on start-up; in tests the handshake fails at once,
/// and that failure starts a close timer on the test clock. Real time is given
/// first so the failure lands, then the clock runs past every timer it starts.
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Pumps the feed and runs [body] against it. A signed-in session starts the
/// collab invite poll, a periodic timer that must be stopped before the body
/// ends or flutter_test reports it as still pending.
Future<void> _runFeed(
  WidgetTester tester, {
  required Widget feed,
  required Size size,
  required Future<void> Function(PendingActionProvider pending) body,
}) async {
  final pending = PendingActionProvider();
  final collab = CollabProvider();
  final chat = _SilentChat();
  try {
    await _pumpFeed(
      tester,
      feed: feed,
      size: size,
      pending: pending,
      collab: collab,
      chat: chat,
    );
    await body(pending);
    // Work the feed started (secure-storage reads, telemetry flushes, debounces)
    // finishes on real time, and its timers on the test clock. Drain both until
    // nothing is left, or flutter_test reports them as still pending.
    await _drain(tester);
    await tester.pumpWidget(const SizedBox());
    // A signed-in session opens the chat socket, a singleton that outlives the
    // test. Close it here, then let the close handshake's timers run out.
    SocketService().disconnect();
    await _drain(tester);
  } finally {
    // The feed starts the chat subscription monitor and the collab invite poll.
    // Both are periodic, so they are stopped here, before flutter_test checks.
    collab.stopInvitePolling();
    chat.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(http.Client());
  });

  void useBackend(bool likedOnServer, {bool failAfterInsert = false}) {
    backend = _FakeBackend(
      likedOnServer: likedOnServer,
      failAfterInsert: failAfterInsert,
    );
    BackendApiService().setHttpClient(MockClient(backend.handle));
  }

  group('mobile community feed', () {
    testWidgets(
        'a guest like confirmed after sign-in fills the heart and adds one',
        (tester) async {
      useBackend(false);
      await _runFeed(tester,
          feed: CommunityScreen(), size: const Size(390, 844), body: (_) async {
        await _likeAsGuestAndConfirm(tester);

        final card = tester.widget<CommunityPostCard>(
          find.byType(CommunityPostCard),
        );
        expect(card.post.isLiked, isTrue);
        expect(card.post.likeCount, 4);
        expect(backend.likeRequests, 1);
        expect(
          find.descendant(
            of: find.byType(CommunityPostCard),
            matching: find.byIcon(Icons.favorite),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets(
        'a like recorded before a 500 fills the heart once and clears the slot',
        (tester) async {
      useBackend(false, failAfterInsert: true);
      await _runFeed(
        tester,
        feed: CommunityScreen(),
        size: const Size(390, 844),
        body: (_) async {
          await _likeAsGuestAndConfirm(tester);

          final card = tester.widget<CommunityPostCard>(
            find.byType(CommunityPostCard),
          );
          expect(card.post.isLiked, isTrue);
          expect(card.post.likeCount, 4);
          expect(backend.serverLikeCount, 4);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString(PendingActionService.storageKey), isNull);
        },
      );
    });

    testWidgets('a post the account already likes stays liked, count unchanged',
        (tester) async {
      useBackend(true);
      await _runFeed(tester,
          feed: CommunityScreen(), size: const Size(390, 844), body: (_) async {
        await _likeAsGuestAndConfirm(tester);

        final card = tester.widget<CommunityPostCard>(
          find.byType(CommunityPostCard),
        );
        expect(card.post.isLiked, isTrue);
        expect(card.post.likeCount, 3);
        expect(backend.likeRequests, 0);
      });
    });

    testWidgets(
        'a signed-in visitor sees the heart filled for a post already liked',
        (tester) async {
      // The discover feed is read anonymously (isLiked false); the account's own
      // like comes from the interaction state and must reach the card.
      useBackend(true);
      BackendApiService().setAuthTokenForTesting('test-token');
      await _runFeed(tester,
          feed: CommunityScreen(), size: const Size(390, 844), body: (_) async {
        expect(
          find.descendant(
            of: find.byType(CommunityPostCard),
            matching: find.byIcon(Icons.favorite),
          ),
          findsOneWidget,
        );
        final card =
            tester.widget<CommunityPostCard>(find.byType(CommunityPostCard));
        expect(card.post.isLiked, isTrue);
      });
    });

    testWidgets(
        'a confirmed like shows liked on the card while its answer is in flight',
        (tester) async {
      useBackend(false);
      backend.likeAnswer = Completer<void>();
      await _runFeed(tester,
          feed: CommunityScreen(), size: const Size(390, 844), body: (_) async {
        await _likeAsGuestAndConfirm(tester);

        // Recorded on the server, answer still out: the card is liked now.
        expect(backend.likeRequests, 1);
        expect(backend.serverLikeCount, 4);
        final card = tester.widget<CommunityPostCard>(
          find.byType(CommunityPostCard),
        );
        expect(card.post.isLiked, isTrue);
        expect(card.post.likeCount, 4);
        expect(
          find.descendant(
            of: find.byType(CommunityPostCard),
            matching: find.byIcon(Icons.favorite),
          ),
          findsOneWidget,
        );

        // A tap on the liked card while in flight does not take the like back.
        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pump(const Duration(milliseconds: 100));
        expect(backend.likeRequests, 1);
        expect(card.post.isLiked, isTrue);

        backend.likeAnswer!.complete();
        await tester.pump(const Duration(milliseconds: 200));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(card.post.isLiked, isTrue);
        expect(card.post.likeCount, 4);
        expect(backend.likeRequests, 1);
      });
    });
  });

  group('desktop community feed', () {
    testWidgets(
        'a guest like confirmed after sign-in fills the heart and adds one',
        (tester) async {
      useBackend(false);
      await _runFeed(
        tester,
        feed: DesktopCommunityScreen(),
        size: const Size(1440, 900),
        body: (_) async {
          await _likeAsGuestAndConfirm(tester);

          final card = tester.widget<CommunityPostCard>(
            find.byType(CommunityPostCard),
          );
          expect(card.post.isLiked, isTrue);
          expect(card.post.likeCount, 4);
          expect(backend.likeRequests, 1);
        },
      );
    });

    testWidgets('a post the account already likes stays liked, count unchanged',
        (tester) async {
      useBackend(true);
      await _runFeed(
        tester,
        feed: DesktopCommunityScreen(),
        size: const Size(1440, 900),
        body: (_) async {
          await _likeAsGuestAndConfirm(tester);

          final card = tester.widget<CommunityPostCard>(
            find.byType(CommunityPostCard),
          );
          expect(card.post.isLiked, isTrue);
          expect(card.post.likeCount, 3);
          expect(backend.likeRequests, 0);
        },
      );
    });

    testWidgets(
        'a signed-in visitor sees the heart filled for a post already liked',
        (tester) async {
      useBackend(true);
      BackendApiService().setAuthTokenForTesting('test-token');
      await _runFeed(tester,
          feed: DesktopCommunityScreen(),
          size: const Size(1440, 900), body: (_) async {
        expect(
          find.descendant(
            of: find.byType(CommunityPostCard),
            matching: find.byIcon(Icons.favorite),
          ),
          findsOneWidget,
        );
      });
    });
  });
}
