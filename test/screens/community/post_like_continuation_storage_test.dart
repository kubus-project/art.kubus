import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
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

/// The backend the browser run talked to: the post, its interaction state, the
/// like endpoint and analytics. [failAfterInsert] answers the like with a server
/// error after the like row is written, which is what the browser run showed.
class _Backend {
  _Backend({
    required this.likedOnServer,
    this.failAfterInsert = false,
    this.failWithoutInsert = false,
  });

  bool likedOnServer;
  final bool failAfterInsert;
  final bool failWithoutInsert;
  int serverLikeCount = 3;
  int likeRequests = 0;
  final List<String> requests = <String>[];
  // When set, a like is recorded on the server at once but answered only when
  // this completes: the rig's shape (the like lands in about a second, the
  // answer takes 20 to 40 s).
  Completer<void>? likeAnswer;

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: const {'content-type': 'application/json'},
      );

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    requests.add('${request.method} $path');
    if (request.method == 'GET' && path == '/api/community/posts/post-1') {
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'post-1',
          'authorId': 'user-1',
          'authorName': 'Ana Umetnica',
          'content': 'A mural on the riverside wall.',
          'createdAt': '2026-10-01T12:00:00.000Z',
          'likeCount': serverLikeCount,
          'isLiked': likedOnServer,
        },
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
      if (failWithoutInsert) {
        await likeAnswer?.future;
        return _json(
          <String, dynamic>{'success': false, 'error': 'Internal server error'},
          500,
        );
      }
      if (!likedOnServer) serverLikeCount += 1;
      likedOnServer = true;
      await likeAnswer?.future;
      if (failAfterInsert) {
        return _json(
          <String, dynamic>{'success': false, 'error': 'Internal server error'},
          500,
        );
      }
      return _json(<String, dynamic>{
        'success': true,
        'message': 'Post liked successfully',
        'likesCount': serverLikeCount,
        'isLiked': true,
      });
    }
    if (request.method == 'POST' && path == '/api/analytics/app') {
      return _json(<String, dynamic>{'success': true});
    }
    return http.Response('{}', 404);
  }
}

/// Sign-in destination of the gate. Finishing it is what the post-auth
/// coordinator does after a real sign-in: the session is authenticated and the
/// captured action is restored for confirmation.
class _FakeSignIn extends StatelessWidget {
  const _FakeSignIn();

  @override
  Widget build(BuildContext context) => Scaffold(
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

Widget _shell(Widget screen) => Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => settings.name == '/onboarding'
            ? const _FakeSignIn()
            : PendingActionContinuationHost(child: screen),
      ),
    );

class _SilentChat extends ChatProvider {
  @override
  Future<void> initialize({String? initialWallet}) async {}
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// One page load over the shared storage: a fresh provider and a fresh screen.
/// Storage is the only thing that carries over between loads, as in the
/// browser.
Future<void> _load(
  WidgetTester tester, {
  required _Backend backend,
  required PendingActionProvider pending,
  required CollabProvider collab,
  required ChatProvider chat,
}) async {
  BackendApiService().setHttpClient(MockClient(backend.handle));
  final prior = FlutterError.onError;
  await pumpProductSurface(
    tester,
    child: _shell(PostDetailScreen(postId: 'post-1')),
    size: const Size(390, 844),
    extraProviders: <SingleChildWidget>[
      ChangeNotifierProvider<PendingActionProvider>.value(value: pending),
      ChangeNotifierProvider<CollabProvider>.value(value: collab),
      ChangeNotifierProvider<ChatProvider>.value(value: chat),
    ],
    settle: const Duration(milliseconds: 500),
  );
  FlutterError.onError = prior;
  await _drain(tester);
}

/// Guest taps the heart, goes through the gate and the sign-in, and reaches the
/// confirmation sheet.
Future<void> _guestLikeToConfirmation(WidgetTester tester) async {
  await tester.tap(find.descendant(
    of: find.byType(CommunityPostCard),
    matching: find.byIcon(Icons.favorite_border),
  ));
  await tester.pumpAndSettle();
  expect(find.text('Like this post'), findsOneWidget);
  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finish sign-in'));
  await tester.pumpAndSettle();
  await tester.pump(PendingActionContinuationHost.settleDelay);
  await tester.pumpAndSettle();
  expect(find.text('Like this post?'), findsOneWidget);
}

Future<String?> _storedSlot() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(PendingActionService.storageKey);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(http.Client());
  });

  testWidgets('a confirmed like fills the heart, adds one, clears the slot',
      (tester) async {
    final backend = _Backend(likedOnServer: false);
    final collab = CollabProvider();
    final chat = _SilentChat();
    try {
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      await _guestLikeToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Like'));
      await _drain(tester);

      expect(backend.likeRequests, 1, reason: backend.requests.join('\n'));
      final card =
          tester.widget<CommunityPostCard>(find.byType(CommunityPostCard));
      expect(card.post.isLiked, isTrue);
      expect(card.post.likeCount, 4);
      expect(await _storedSlot(), isNull);
    } finally {
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });

  testWidgets('the like is recorded, then the route answers 500 (browser run)',
      (tester) async {
    final backend = _Backend(likedOnServer: false, failAfterInsert: true);
    final collab = CollabProvider();
    final chat = _SilentChat();
    try {
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      await _guestLikeToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Like'));
      await _drain(tester);

      final card =
          tester.widget<CommunityPostCard>(find.byType(CommunityPostCard));
      expect(card.post.isLiked, isTrue);
      expect(card.post.likeCount, 4);
      expect(backend.serverLikeCount, 4);
      expect(await _storedSlot(), isNull);

      // Reload: the consumed like is neither offered nor sent again.
      final sent = backend.likeRequests;
      await tester.pumpWidget(const SizedBox());
      SocketService().disconnect();
      await _drain(tester);
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      expect(find.text('Like this post?'), findsNothing);
      expect(backend.likeRequests, sent);
      final reloaded =
          tester.widget<CommunityPostCard>(find.byType(CommunityPostCard));
      expect(reloaded.post.isLiked, isTrue);
      expect(reloaded.post.likeCount, 4);
    } finally {
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });

  testWidgets(
      'a failed like clears the stored slot at once; reload replays none',
      (tester) async {
    final backend = _Backend(likedOnServer: false, failWithoutInsert: true);
    final collab = CollabProvider();
    final chat = _SilentChat();
    try {
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      await _guestLikeToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Like'));
      await _drain(tester);

      expect(backend.serverLikeCount, 3);
      final card =
          tester.widget<CommunityPostCard>(find.byType(CommunityPostCard));
      expect(card.post.isLiked, isFalse);
      expect(await _storedSlot(), isNull);

      final sent = backend.likeRequests;
      await tester.pumpWidget(const SizedBox());
      SocketService().disconnect();
      await _drain(tester);
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      expect(find.text('Like this post?'), findsNothing);
      expect(backend.likeRequests, sent);
    } finally {
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });

  testWidgets(
      'a failed like closes the confirmation and reports once, never re-prompts',
      (tester) async {
    final backend = _Backend(likedOnServer: false, failWithoutInsert: true);
    final collab = CollabProvider();
    final chat = _SilentChat();
    try {
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      await _guestLikeToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Like'));
      await _drain(tester);

      // The confirmation must not come back over the failure feedback: its
      // toast sits under the sheet, so a re-shown sheet hides the only message.
      expect(find.text('Like this post?'), findsNothing);
      final card =
          tester.widget<CommunityPostCard>(find.byType(CommunityPostCard));
      expect(card.post.isLiked, isFalse);
    } finally {
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });

  testWidgets(
      'a confirmed like shows liked at once, while the server answer is in flight',
      (tester) async {
    final backend = _Backend(likedOnServer: false)
      ..likeAnswer = Completer<void>();
    final collab = CollabProvider();
    final chat = _SilentChat();
    try {
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      await _guestLikeToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Like'));
      await _drain(tester);

      // The like is on the server and the answer is still out: the heart is
      // liked and the count is one more, not "not liked" until the answer.
      expect(backend.serverLikeCount, 4);
      expect(backend.likeRequests, 1);
      final shown =
          tester.widget<CommunityPostCard>(find.byType(CommunityPostCard)).post;
      expect(shown.isLiked, isTrue);
      expect(shown.likeCount, 4);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // A tap while the like is in flight does not take it back. Short pump:
      // the transport re-sends a write after 30 s, which would blur the count.
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump(const Duration(milliseconds: 100));
      expect(backend.likeRequests, 1);
      expect(shown.isLiked, isTrue);

      backend.likeAnswer!.complete();
      await _drain(tester);
      expect(shown.isLiked, isTrue);
      expect(shown.likeCount, 4);
      expect(backend.likeRequests, 1);
    } finally {
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });

  testWidgets(
      'a like that fails in flight returns the heart to the server state',
      (tester) async {
    final backend = _Backend(likedOnServer: false, failWithoutInsert: true)
      ..likeAnswer = Completer<void>();
    final collab = CollabProvider();
    final chat = _SilentChat();
    try {
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      await _guestLikeToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Like'));
      await _drain(tester);
      final shown =
          tester.widget<CommunityPostCard>(find.byType(CommunityPostCard)).post;
      expect(shown.isLiked, isTrue);

      backend.likeAnswer!.complete();
      await _drain(tester);
      expect(shown.isLiked, isFalse);
      expect(shown.likeCount, 3);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    } finally {
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });

  testWidgets(
      'cancelling the confirmation clears the slot; reload offers nothing',
      (tester) async {
    final backend = _Backend(likedOnServer: false);
    final collab = CollabProvider();
    final chat = _SilentChat();
    try {
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      await _guestLikeToConfirmation(tester);
      await tester.tap(find.text('Not now'));
      await _drain(tester);

      expect(backend.likeRequests, 0);
      expect(await _storedSlot(), isNull);

      await tester.pumpWidget(const SizedBox());
      SocketService().disconnect();
      await _drain(tester);
      await _load(
        tester,
        backend: backend,
        pending: PendingActionProvider(),
        collab: collab,
        chat: chat,
      );
      expect(find.text('Like this post?'), findsNothing);
      expect(backend.likeRequests, 0);
      final card =
          tester.widget<CommunityPostCard>(find.byType(CommunityPostCard));
      expect(card.post.isLiked, isFalse);
    } finally {
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });
}
