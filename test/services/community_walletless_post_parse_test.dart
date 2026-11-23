import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accountId = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsInVzZXJfaWQiOiI2ZjFjMWQyZS0zYTRiLTRjNWQtOGU5Zi0wYTFiMmMzZDRlNWYifQ.'
    'signature';

/// A post by an account that has no wallet: the DTO carries a null wallet and
/// the account id under author.userId.
Map<String, Object?> _walletlessPostPayload({required String id}) {
  return <String, Object?>{
    'id': id,
    'content': 'Posted without a wallet',
    'createdAt': '2026-11-15T10:00:00.000Z',
    'walletAddress': null,
    'userId': _accountId,
    'author': <String, Object?>{
      'userId': _accountId,
      'walletAddress': null,
      'displayName': 'Walletless Author',
      'username': 'walletless_author',
      'avatarUrl': null,
      'roles': <String, bool>{'artist': false, 'institution': false},
    },
    'stats': <String, int>{
      'likes': 0,
      'comments': 0,
      'shares': 0,
      'views': 0,
    },
    'isLiked': false,
    'isBookmarked': false,
  };
}

http.Response _jsonResponse(Map<String, Object?> payload) {
  return http.Response(
    jsonEncode(payload),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test(
      'a post with a null wallet parses under its author account and stays in the list',
      () async {
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path != '/api/community/posts') {
        return http.Response('Unexpected request', 500);
      }
      return _jsonResponse(<String, Object?>{
        'data': <Object?>[
          _walletlessPostPayload(id: '11111111-1111-4111-8111-111111111111'),
        ],
      });
    }));

    final posts = await BackendApiService().getCommunityPosts(
      page: 1,
      limit: 24,
      surface: 'discover',
      sort: 'recent',
    );

    expect(posts, hasLength(1),
        reason: 'a walletless post is not filtered out');
    final post = posts.single;
    expect(post.id, '11111111-1111-4111-8111-111111111111');
    expect(post.content, 'Posted without a wallet');
    expect(post.authorId, _accountId);
    expect(post.authorIdentityData.userId, _accountId);
    expect(post.authorName, 'Walletless Author');
    expect(post.authorUsername, 'walletless_author');
  });
}
