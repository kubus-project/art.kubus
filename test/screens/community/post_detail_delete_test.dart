import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

Map<String, dynamic> _post() => <String, dynamic>{
      'id': 'post-1',
      'authorId': 'user-1',
      'authorName': 'Ana Umetnica',
      'content': 'A mural on the riverside wall.',
      'createdAt': '2026-10-01T12:00:00.000Z',
    };

class _SilentChat extends ChatProvider {
  @override
  Future<void> initialize({String? initialWallet}) async {}
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

  testWidgets('deleting from the detail screen drops the post from the feeds',
      (tester) async {
    final deleted = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      final path = request.url.path;
      http.Response json(Object body) => http.Response(
            jsonEncode(body),
            200,
            headers: const {'content-type': 'application/json'},
          );
      if (request.method == 'DELETE') {
        deleted.add(path);
        return json(<String, dynamic>{'success': true});
      }
      if (path == '/api/community/art-feed') {
        return json(<String, dynamic>{
          'success': true,
          'data': <dynamic>[_post()],
        });
      }
      if (path == '/api/community/posts/post-1') {
        return json(<String, dynamic>{'success': true, 'data': _post()});
      }
      if (path.endsWith('/comments')) {
        return json(<String, dynamic>{'success': true, 'data': <dynamic>[]});
      }
      return http.Response('{}', 404);
    }));
    final collab = CollabProvider();
    final chat = _SilentChat();
    final prior = FlutterError.onError;
    try {
      await pumpProductSurface(
        tester,
        child: const PostDetailScreen(
          postId: 'post-1',
          initialAction: PostDetailInitialAction.delete,
        ),
        size: const Size(390, 844),
        extraProviders: <SingleChildWidget>[
          ChangeNotifierProvider<CollabProvider>.value(value: collab),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        settle: const Duration(milliseconds: 500),
      );
      FlutterError.onError = prior;

      final hub = Provider.of<CommunityHubProvider>(
        tester.element(find.byType(PostDetailScreen)),
        listen: false,
      );
      await tester
          .runAsync(() => hub.loadArtFeed(latitude: 46.05, longitude: 14.5));
      expect(hub.artFeedPosts.map((p) => p.id), contains('post-1'));

      await tester.pump(const Duration(milliseconds: 500));
      final confirm = find.descendant(
        of: find.byType(KubusAlertDialog),
        matching: find.byType(TextButton),
      );
      expect(confirm, findsNWidgets(2));
      await tester.tap(confirm.last);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(deleted, <String>['/api/community/posts/post-1']);
      expect(hub.artFeedPosts, isEmpty);
      expect(find.byType(KubusAlertDialog), findsNothing);
    } finally {
      FlutterError.onError = prior;
      collab.stopInvitePolling();
      chat.dispose();
      SocketService().disconnect();
    }
  });
}
