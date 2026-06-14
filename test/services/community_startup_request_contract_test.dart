import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

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

  test('initial mobile community load fetches only active feed payload',
      () async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/community/posts') {
        expect(request.url.queryParameters['surface'], 'following');
        return _jsonResponse(<String, Object?>{
          'data': <Object?>[
            _postPayload(
              id: '11111111-1111-4111-8111-111111111111',
              isLiked: true,
              isBookmarked: true,
            ),
          ],
        });
      }
      return http.Response('Unexpected startup request', 500);
    }));

    final posts = await BackendApiService().getCommunityPosts(
      page: 1,
      limit: 24,
      followingOnly: true,
      surface: 'following',
      sort: 'hybrid',
    );

    expect(posts, hasLength(1));
    expect(posts.single.isLiked, isTrue);
    expect(posts.single.isBookmarked, isTrue);
    expect(requests, <String>['/api/community/posts']);
    _expectNoBannedStartupRequests(requests);
  });

  test('inactive feed fetch happens only when tab switch requests it', () async {
    final surfaces = <String?>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path != '/api/community/posts') {
        return http.Response('Unexpected startup request', 500);
      }
      surfaces.add(request.url.queryParameters['surface']);
      return _jsonResponse(<String, Object?>{
        'data': <Object?>[
          _postPayload(id: '22222222-2222-4222-8222-222222222222'),
        ],
      });
    }));

    await BackendApiService().getCommunityPosts(
      page: 1,
      limit: 24,
      followingOnly: true,
      surface: 'following',
      sort: 'hybrid',
    );

    expect(surfaces, <String?>['following']);

    await BackendApiService().getCommunityPosts(
      page: 1,
      limit: 24,
      followingOnly: false,
      surface: 'discover',
      sort: 'hybrid',
    );

    expect(surfaces, <String?>['following', 'discover']);
  });

  test('initial desktop community load fetches only active feed payload',
      () async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/community/posts') {
        expect(request.url.queryParameters['surface'], 'discover');
        return _jsonResponse(<String, Object?>{
          'data': <Object?>[
            _postPayload(
              id: '33333333-3333-4333-8333-333333333333',
              isLiked: true,
              isBookmarked: true,
            ),
          ],
        });
      }
      return http.Response('Unexpected startup request', 500);
    }));

    final posts = await BackendApiService().getCommunityPosts(
      page: 1,
      limit: 24,
      followingOnly: false,
      surface: 'discover',
      sort: 'hybrid',
    );

    expect(posts.single.isLiked, isTrue);
    expect(posts.single.isBookmarked, isTrue);
    expect(requests, <String>['/api/community/posts']);
    _expectNoBannedStartupRequests(requests);
  });

  test('art feed payload carries authoritative like and bookmark state',
      () async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/community/art-feed') {
        return _jsonResponse(<String, Object?>{
          'data': <Object?>[
            _postPayload(
              id: '44444444-4444-4444-8444-444444444444',
              isLiked: true,
              isBookmarked: true,
            ),
          ],
        });
      }
      return http.Response('Unexpected startup request', 500);
    }));

    final posts = await BackendApiService().getCommunityArtFeed(
      latitude: 46.05,
      longitude: 14.5,
      radiusKm: 3,
      limit: 24,
      page: 1,
    );

    expect(posts.single.isLiked, isTrue);
    expect(posts.single.isBookmarked, isTrue);
    expect(requests, <String>['/api/community/art-feed']);
    _expectNoBannedStartupRequests(requests);
  });
}

Map<String, Object?> _postPayload({
  required String id,
  bool isLiked = false,
  bool isBookmarked = false,
}) {
  return <String, Object?>{
    'id': id,
    'content': 'Feed payload post',
    'createdAt': '2026-06-14T12:00:00.000Z',
    'author': <String, Object?>{
      'userId': '55555555-5555-4555-8555-555555555555',
      'walletAddress': 'WalletAuthor111111111111111111111111',
      'displayName': 'Feed Author',
      'username': 'feed_author',
      'avatarUrl': null,
      'roles': <String, bool>{'artist': false, 'institution': false},
    },
    'stats': <String, int>{
      'likes': 7,
      'comments': 3,
      'shares': 1,
      'views': 11,
    },
    'isLiked': isLiked,
    'isBookmarked': isBookmarked,
  };
}

http.Response _jsonResponse(Map<String, Object?> payload) {
  return http.Response(
    jsonEncode(payload),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

void _expectNoBannedStartupRequests(List<String> requests) {
  const banned = <String>[
    '/api/community/interactions/state',
    '/api/groups',
    '/api/public/home-rails',
    '/api/search',
    '/api/search/trending',
  ];

  for (final path in requests) {
    expect(
      banned.any(path.startsWith),
      isFalse,
      reason: 'Unexpected startup fan-out request: $path',
    );
    expect(path.contains('/comments'), isFalse);
    expect(path.contains('/likes'), isFalse);
    expect(path.contains('/profiles/'), isFalse);
    expect(path.contains('/achievements/'), isFalse);
  }
}
