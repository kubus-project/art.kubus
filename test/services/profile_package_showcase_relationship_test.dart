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

/// A walletless author without artist privileges: the profile is addressed by
/// its UUID and carries authored works, like the pilot profile does.
const User _walkerProfile = User(
  id: '8c03b35a-a4d6-4c08-95fc-503c879fbc45',
  name: 'Walker Author',
  username: 'walker_author',
  bio: 'Showcase fixture without an artist role.',
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
      'a profile that is neither artist nor institution still shows its '
      'authored works and public collections, and asks for no events',
      () async {
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
      _walkerProfile.id,
      forceRefresh: true,
      includePosts: false,
      includeShowcase: true,
      user: _walkerProfile,
    );

    expect(extended, isNotNull);
    expect(
      extended!.artistArtworks.map((item) => item['id']),
      <Object?>['authored-1', 'authored-2'],
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
}
