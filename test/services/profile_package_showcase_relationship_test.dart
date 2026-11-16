import 'dart:convert';

import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object? payload) {
  return http.Response(
    jsonEncode(payload),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

/// Fake backend for the showcase load. `/artworks` is matched before any
/// generic profile path so the scoped requests are answered explicitly.
MockClient _showcaseClient({
  required bool honourScope,
  List<Uri>? requests,
  List<String> collectionIds = const <String>[],
}) {
  return MockClient((request) async {
    requests?.add(request.url);
    final path = request.url.path;
    if (path == '/api/artworks' &&
        request.url.queryParameters['authorProfileId'] != null) {
      final authorProfileId =
          request.url.queryParameters['authorProfileId']!.toLowerCase();
      return _json(<String, Object?>{
        'source': 'postgresql',
        'appliedFilters': <String, Object?>{
          'authorProfileId': authorProfileId,
        },
        'data': <Map<String, Object?>>[
          for (final id in const <String>[
            'credited-work-1',
            'credited-work-2',
            'credited-work-3',
            'credited-work-4',
            'credited-work-5',
            'credited-work-6',
          ])
            <String, Object?>{
              'id': id,
              'walletAddress': 'uploader-wallet',
              'title': id,
              'artist': 'turrdl',
              'description': '',
              'latitude': 46.05,
              'longitude': 14.5,
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
        ],
      });
    }
    if (path.endsWith('/artworks')) {
      if (!honourScope) {
        // Older backend: ignores `relationship`, no echo, same mixed list.
        return _json(<String, Object?>{
          'data': <Map<String, Object?>>[
            <String, Object?>{'id': 'legacy-1'},
            <String, Object?>{'id': 'legacy-2'},
          ],
          'pagination': <String, Object?>{'total': 2},
        });
      }
      final relationship = request.url.queryParameters['relationship'];
      if (relationship == 'authored') {
        return _json(<String, Object?>{
          'data': <Map<String, Object?>>[
            <String, Object?>{'id': 'authored-1'},
            <String, Object?>{'id': 'authored-2'},
          ],
          'relationship': 'authored',
          'pagination': <String, Object?>{'total': 9},
        });
      }
      if (relationship == 'documented') {
        return _json(<String, Object?>{
          'data': <Map<String, Object?>>[
            <String, Object?>{'id': 'documented-1'},
          ],
          'relationship': 'documented',
          'pagination': <String, Object?>{'total': 4},
        });
      }
      return http.Response('Unexpected scope', 400);
    }
    if (path.contains('/api/collections')) {
      return _json(<String, Object?>{
        'data': <Map<String, Object?>>[
          for (final id in collectionIds) <String, Object?>{'id': id},
        ],
      });
    }
    if (path.contains('/api/events')) {
      return _json(<String, Object?>{'data': <Object?>[]});
    }
    return http.Response('Not found', 404);
  });
}

const User _artist = User(
  id: 'profile_showcase_wallet',
  name: 'Showcase Artist',
  username: 'showcase',
  bio: 'Showcase fixture.',
  followersCount: 0,
  followingCount: 0,
  postsCount: 0,
  isFollowing: false,
  isVerified: false,
  joinedDate: 'Joined recently',
  isArtist: true,
);

const User _walletlessAuthor = User(
  id: '40000000-0000-4000-8000-000000000010',
  userId: '40000000-0000-4000-8000-000000000010',
  profileId: '10000000-0000-4000-8000-000000000010',
  walletAddress: null,
  name: 'Walletless Author',
  username: 'walletless-author',
  bio: '',
  followersCount: 0,
  followingCount: 0,
  postsCount: 0,
  isFollowing: false,
  isVerified: false,
  joinedDate: 'Joined recently',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProfilePackageService.clearMemoryCacheForTesting();
    await UserService.clearCache();
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() async {
    ProfilePackageService.clearMemoryCacheForTesting();
    await UserService.clearCache();
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('new backend keeps authored and documented artworks separate', () async {
    BackendApiService().setHttpClient(_showcaseClient(honourScope: true));

    final extended =
        await ProfilePackageService.loadPublicProfileExtendedPackage(
      _artist.id,
      forceRefresh: true,
      includePosts: false,
      includeShowcase: true,
      user: _artist,
    );

    expect(extended, isNotNull);
    expect(
      extended!.artistArtworks.map((item) => item['id']),
      <Object?>['authored-1', 'authored-2'],
    );
    expect(
      extended.documentedArtworks.map((item) => item['id']),
      <Object?>['documented-1'],
    );
    expect(extended.authoredArtworksTotal, 9);
    expect(extended.documentedArtworksTotal, 4);
  });

  test('old backend exposes the legacy list once and no documented scope',
      () async {
    const wallet = 'profile_showcase_legacy_wallet';
    BackendApiService().setHttpClient(_showcaseClient(honourScope: false));

    final extended =
        await ProfilePackageService.loadPublicProfileExtendedPackage(
      wallet,
      forceRefresh: true,
      includePosts: false,
      includeShowcase: true,
      user: const User(
        id: wallet,
        name: 'Legacy Artist',
        username: 'legacy',
        bio: 'Legacy fixture.',
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        isFollowing: false,
        isVerified: false,
        joinedDate: 'Joined recently',
        isArtist: true,
      ),
    );

    expect(extended, isNotNull);
    expect(
      extended!.artistArtworks.map((item) => item['id']),
      <Object?>['legacy-1', 'legacy-2'],
    );
    expect(extended.documentedArtworks, isEmpty);
    expect(extended.authoredArtworksTotal, isNull);
    expect(extended.documentedArtworksTotal, isNull);
  });

  test(
      'walletless non-creator still loads public authored work and collections, '
      'without requesting events', () async {
    final requests = <Uri>[];
    BackendApiService().setHttpClient(
      _showcaseClient(
        honourScope: true,
        requests: requests,
        collectionIds: const <String>['collection-1'],
      ),
    );

    final extended =
        await ProfilePackageService.loadPublicProfileExtendedPackage(
      _walletlessAuthor.id,
      forceRefresh: true,
      includePosts: false,
      includeShowcase: true,
      user: _walletlessAuthor,
    );

    expect(extended, isNotNull);
    expect(
      extended!.artistArtworks.map((item) => item['id']),
      <Object?>[
        'credited-work-1',
        'credited-work-2',
        'credited-work-3',
        'credited-work-4',
        'credited-work-5',
        'credited-work-6',
      ],
    );
    expect(
      extended.artistArtworks.map((item) => item['artist']),
      everyElement('turrdl'),
    );
    expect(
      extended.artistCollections.map((item) => item['id']),
      <Object?>['collection-1'],
    );
    expect(extended.artistEvents, isEmpty);
    expect(
      requests.where((uri) => uri.path.endsWith('/api/events')),
      isEmpty,
    );
  });

  test('an artist profile still loads its events', () async {
    final requests = <Uri>[];
    BackendApiService().setHttpClient(
      _showcaseClient(honourScope: true, requests: requests),
    );

    await ProfilePackageService.loadPublicProfileExtendedPackage(
      _artist.id,
      forceRefresh: true,
      includePosts: false,
      includeShowcase: true,
      user: _artist,
    );

    expect(
      requests.where((uri) => uri.path.endsWith('/api/events')),
      isNotEmpty,
    );
  });

  test('walletless profile uses profileId filter, not account id or uploader',
      () async {
    const profileId = '10000000-0000-4000-8000-000000000010';
    const accountId = '40000000-0000-4000-8000-000000000010';
    final requests = <http.Request>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/artworks') {
        return _json(<String, Object?>{
          'source': 'postgresql',
          'appliedFilters': <String, Object?>{'authorProfileId': profileId},
          'data': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'foreign-uploaded-work',
              'walletAddress': 'uploader-wallet',
              'title': 'Imported by another account',
              'artist': 'Recorded artist',
              'description': '',
              'latitude': 46.05,
              'longitude': 14.5,
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        });
      }
      return http.Response('Not found', 404);
    }));
    final profile = User(
      id: profileId,
      userId: accountId,
      profileId: profileId,
      walletAddress: null,
      name: 'Walletless Author',
      username: 'walletless-author',
      bio: '',
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      isFollowing: false,
      isVerified: false,
      isArtist: true,
      joinedDate: 'Joined recently',
    );

    final sections = await ProfilePackageService.loadProfileArtworkSections(
      profileId,
      limit: 6,
      user: profile,
    );

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/artworks');
    expect(requests.single.url.queryParameters['authorProfileId'], profileId);
    expect(requests.single.url.queryParameters['mine'], isNull);
    expect(sections.authored.single['id'], 'foreign-uploaded-work');
    expect(sections.authoredTotal, 1);
    expect(sections.documented, isEmpty);
  });

  test('walletless profile refuses a generic list without appliedFilters echo',
      () async {
    const profileId = '10000000-0000-4000-8000-000000000011';
    final requests = <http.Request>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request);
      return _json(<String, Object?>{
        'data': <Map<String, Object?>>[
          <String, Object?>{'id': 'unfiltered'}
        ],
      });
    }));
    final profile = User(
      id: profileId,
      profileId: profileId,
      name: 'Walletless Author',
      username: 'author',
      bio: '',
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      isFollowing: false,
      isVerified: false,
      joinedDate: 'Joined recently',
    );

    await expectLater(
      ProfilePackageService.loadProfileArtworkSections(
        profileId,
        user: profile,
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(requests, hasLength(1));
    expect(requests.single.url.queryParameters['authorProfileId'], profileId);
  });
}
