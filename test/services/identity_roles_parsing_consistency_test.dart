import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  test('community post roles come only from stated flags, never from role/type',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('token');
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/community/posts/post_inferred')) {
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'id': 'post_inferred',
              'authorId': 'user_1',
              'authorName': 'Visitor',
              'content': 'Hello',
              'createdAt': '2024-01-01T00:00:00.000Z',
              'author': <String, dynamic>{
                'id': 'user_1',
                'username': 'visitor',
                'displayName': 'Visitor',
                'type': 'gallery_visitor',
                'role': 'creator',
              },
            },
          });
        }
        return _json(<String, dynamic>{}, 404);
      }),
    );

    final post = await api.getCommunityPostById('post_inferred');
    expect(post.authorIsArtist, isFalse);
    expect(post.authorIsInstitution, isFalse);
  });

  test('community post author roles use OR semantics across stated sources',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('token');
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/community/posts/post_or')) {
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'id': 'post_or',
              'authorId': 'user_2',
              'authorName': 'Artist',
              'content': 'Hello',
              'createdAt': '2024-01-01T00:00:00.000Z',
              'author': <String, dynamic>{
                'id': 'user_2',
                'username': 'artist',
                'displayName': 'Artist',
                'roles': <String, dynamic>{'artist': false},
                'isArtist': true,
              },
            },
          });
        }
        return _json(<String, dynamic>{}, 404);
      }),
    );

    final post = await api.getCommunityPostById('post_or');
    expect(post.authorIsArtist, isTrue);
    expect(post.authorIsInstitution, isFalse);
  });

  test('profile cache mapping accepts string booleans without throwing',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final wallet = 'WalletStringBool1234567890abcdefghijklmnop';
    final api = BackendApiService();
    api.setAuthTokenForTesting('token');
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path.contains('/api/profiles/')) {
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'walletAddress': wallet,
              'username': 'stringbool',
              'displayName': 'String Bool',
              'isVerified': 'true',
              'isArtist': 'yes',
              'isInstitution': '0',
            },
          });
        }
        return _json(<String, dynamic>{}, 404);
      }),
    );

    await UserService.clearCache();
    final user = await UserService.getUserById(
      wallet,
      forceRefresh: true,
      includeAchievements: false,
    );
    expect(user, isNotNull);
    expect(user!.isVerified, isTrue);
    expect(user.isArtist, isTrue);
    expect(user.isInstitution, isFalse);
  });
}
