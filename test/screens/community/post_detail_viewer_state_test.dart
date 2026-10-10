import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/widgets/community/community_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

/// A signed-in viewer opens a post by its route. As in the browser run, the
/// post read is anonymous (isLiked false) and the viewer's own like arrives
/// from the interaction state, authenticated.
class _Backend {
  _Backend({required this.likedForViewer});

  final bool likedForViewer;

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: const {'content-type': 'application/json'},
      );

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    final authed = (request.headers['authorization'] ?? '').isNotEmpty;
    if (request.method == 'GET' && path == '/api/community/posts/post-1') {
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'post-1',
          'authorId': 'user-1',
          'authorName': 'Ana Umetnica',
          'content': 'A mural on the riverside wall.',
          'createdAt': '2026-10-01T12:00:00.000Z',
          'likeCount': 4,
          // The anonymous read never carries the viewer's like.
          'isLiked': authed && likedForViewer,
        },
      });
    }
    if (request.method == 'GET' &&
        path == '/api/community/interactions/state') {
      // The viewer's state lands after the post is already on screen (browser order).
      await Future<void>.delayed(const Duration(seconds: 2));
      return _json(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'posts': <String, dynamic>{
            'post-1': <String, dynamic>{
              'isLiked': likedForViewer,
              'likeCount': 4,
            },
          },
        },
      });
    }
    if (request.method == 'GET' && path.endsWith('/comments')) {
      return _json(<String, dynamic>{'success': true, 'data': <dynamic>[]});
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

  testWidgets('a reopened post shows the viewer’s own like as filled',
      (tester) async {
    BackendApiService()
        .setHttpClient(MockClient(_Backend(likedForViewer: true).handle));
    final collab = CollabProvider();
    final chat = _SilentChat();
    final prior = FlutterError.onError;
    try {
      await pumpProductSurface(
        tester,
        child: PostDetailScreen(postId: 'post-1'),
        size: const Size(390, 844),
        extraProviders: <SingleChildWidget>[
          ChangeNotifierProvider<CollabProvider>.value(value: collab),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        settle: const Duration(milliseconds: 500),
      );
      FlutterError.onError = prior;
      // The viewer's state lands on real time, after the page has built, and no
      // further frame is forced by anything else: the card must repaint itself.
      await _drain(tester);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();

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
    } finally {
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });
}
