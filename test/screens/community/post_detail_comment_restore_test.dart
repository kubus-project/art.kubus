import 'dart:convert';

import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/widgets/auth/pending_action_continuation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

/// A signed-in visitor's post: the post, its comments and the comment write.
class _Backend {
  int commentRequests = 0;
  final List<String> commentBodies = <String>[];

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: const {'content-type': 'application/json'},
      );

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/community/posts/post-1') {
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'post-1',
          'authorId': 'user-1',
          'authorName': 'Ana Umetnica',
          'content': 'A mural on the riverside wall.',
          'createdAt': '2026-10-01T12:00:00.000Z',
          'likeCount': 3,
          'commentCount': 0,
          'isLiked': false,
        },
      });
    }
    if (request.method == 'GET' &&
        path == '/api/community/posts/post-1/comments') {
      return _json(<String, dynamic>{'success': true, 'data': <dynamic>[]});
    }
    if (request.method == 'GET' &&
        path == '/api/community/interactions/state') {
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'posts': <String, dynamic>{}},
      });
    }
    if (request.method == 'POST' &&
        path == '/api/community/posts/post-1/comments') {
      commentRequests += 1;
      commentBodies.add(request.body);
      return _json(<String, dynamic>{
        'success': true,
        'comment': <String, dynamic>{
          'id': 'comment-$commentRequests',
          'postId': 'post-1',
          'content': 'Lovely wall',
          'authorId': 'user-1',
          'authorName': 'Ana Umetnica',
          'createdAt': '2026-10-01T12:05:00.000Z',
        },
      }, 201);
    }
    if (request.method == 'POST' && path == '/api/analytics/app') {
      return _json(<String, dynamic>{'success': true});
    }
    return http.Response('{}', 404);
  }
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('test-token');
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(http.Client());
  });

  testWidgets(
      'a restored comment draft is sent by one tap on Send after the continuation',
      (tester) async {
    final backend = _Backend();
    BackendApiService().setHttpClient(MockClient(backend.handle));
    final hub = CommunityHubProvider();
    hub.rememberCommentDraftForAuth('post-1', 'Lovely wall');
    final pending = PendingActionProvider();
    final collab = CollabProvider();
    final chat = _SilentChat();
    final prior = FlutterError.onError;
    try {
      await pumpProductSurface(
        tester,
        child: PendingActionContinuationHost(
          child: PostDetailScreen(postId: 'post-1'),
        ),
        size: const Size(390, 844),
        extraProviders: <SingleChildWidget>[
          ChangeNotifierProvider<CommunityHubProvider>.value(value: hub),
          ChangeNotifierProvider<PendingActionProvider>.value(value: pending),
          ChangeNotifierProvider<CollabProvider>.value(value: collab),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        settle: const Duration(milliseconds: 500),
      );
      FlutterError.onError = prior;
      await _drain(tester);

      // The comment the guest wrote before sign-in is back in the composer.
      expect(find.text('Lovely wall'), findsOneWidget);

      // Sign-in restores the comment action; the visitor continues from the
      // confirmation sheet.
      await tester.runAsync(() async {
        await pending.capture(PendingActionIntent.create(
          actionType: PendingActionType.comment,
          targetType: PendingActionTargetType.post,
          targetId: 'post-1',
          returnRoute: '/p/post-1',
          sourceScreen: 'post_detail',
        )!);
        await pending.restore();
      });
      // The host builds on the next frame and waits out its settle delay on the
      // test clock; advance past it, then let the sheet settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Write your comment?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      // The composer is the feedback here: no toast sits over Send.
      expect(find.byType(SnackBar), findsNothing);

      // One tap on Send sends the comment.
      await tester.tap(find.byIcon(Icons.send_rounded));
      await _drain(tester);

      expect(backend.commentRequests, 1, reason: backend.commentBodies.join());
    } finally {
      FlutterError.onError = prior;
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });
}
