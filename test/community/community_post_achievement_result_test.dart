import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('createCommunityPost parses backend achievement result', () async {
    BackendApiService().setAuthTokenForTesting('token');
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/community/posts')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'post_1',
                'authorId': 'wallet_1',
                'walletAddress': 'wallet_1',
                'authorName': 'Creator',
                'content': 'My first post',
                'createdAt': '2026-05-25T00:00:00.000Z',
                'category': 'post',
                'stats': {
                  'likes': 0,
                  'comments': 0,
                  'shares': 0,
                  'views': 0,
                },
              },
              'achievements': {
                'progress': [
                  {
                    'achievementCode': 'first_post',
                    'currentProgress': 1,
                    'requiredCount': 1,
                    'isCompleted': true,
                  }
                ],
                'unlocked': [
                  {
                    'code': 'first_post',
                    'title': 'First Post',
                    'description': 'Created your first community post',
                    'category': 'community',
                    'rarity': 'common',
                    'kub8Reward': 5,
                    'rewardCurrency': 'KUB8',
                  }
                ],
                'totalKub8Earned': 5,
              },
            }),
            201,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final post = await BackendApiService().createCommunityPost(
      content: 'My first post',
    );

    expect(post.achievementResult, isNotNull);
    expect(post.achievementResult!.unlocked.single.code, 'first_post');
    expect(post.achievementResult!.totalKub8Earned, 5);
  });
}
