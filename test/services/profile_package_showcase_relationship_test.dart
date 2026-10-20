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
MockClient _showcaseClient({required bool honourScope}) {
  return MockClient((request) async {
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
      return _json(<String, Object?>{'data': <Object?>[]});
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
}
