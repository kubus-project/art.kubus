import 'dart:convert';
import 'dart:ui' show Size;

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

http.Response _json(Object? payload) {
  return http.Response(
    jsonEncode(payload),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

/// Fake `/artworks` endpoint. Honouring backends echo `relationship` and return
/// only the requested scope; older backends ignore it and return the mixed list.
MockClient _artworksClient({
  required List<String> authoredIds,
  required List<String> documentedIds,
  bool honourScope = true,
}) {
  return MockClient((request) async {
    if (!request.url.path.endsWith('/artworks')) {
      return http.Response('Not found', 404);
    }
    if (!honourScope) {
      final mixed = <String>[...authoredIds, ...documentedIds];
      return _json(<String, Object?>{
        'data': <Map<String, Object?>>[
          for (final id in mixed) <String, Object?>{'id': id},
        ],
        'pagination': <String, Object?>{'total': mixed.length},
      });
    }
    final relationship = request.url.queryParameters['relationship'];
    final ids = switch (relationship) {
      'authored' => authoredIds,
      'documented' => documentedIds,
      _ => null,
    };
    if (ids == null) {
      return http.Response('Unexpected scope', 400);
    }
    return _json(<String, Object?>{
      'data': <Map<String, Object?>>[
        for (final id in ids) <String, Object?>{'id': id},
      ],
      'relationship': relationship,
      'pagination': <String, Object?>{'total': ids.length},
    });
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProfilePackageService.clearMemoryCacheForTesting();
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() async {
    ProfilePackageService.clearMemoryCacheForTesting();
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('authored and documented sections never share items', () async {
    BackendApiService().setHttpClient(
      _artworksClient(
        authoredIds: const <String>['authored-1', 'authored-2'],
        documentedIds: const <String>['documented-1'],
      ),
    );

    final sections = await ProfilePackageService.loadProfileArtworkSections(
      'profile_showcase_wallet',
    );

    expect(
      sections.authored.map((item) => item['id']),
      <Object?>['authored-1', 'authored-2'],
    );
    expect(
      sections.documented.map((item) => item['id']),
      <Object?>['documented-1'],
    );
    final authoredIds = sections.authored.map((item) => item['id']).toSet();
    final documentedIds = sections.documented.map((item) => item['id']).toSet();
    expect(authoredIds.intersection(documentedIds), isEmpty);
    expect(sections.authoredTotal, 2);
    expect(sections.documentedTotal, 1);
  });

  test('documented section stays empty when the profile documented nothing',
      () async {
    BackendApiService().setHttpClient(
      _artworksClient(
        authoredIds: const <String>['authored-1'],
        documentedIds: const <String>[],
      ),
    );

    final sections = await ProfilePackageService.loadProfileArtworkSections(
      'profile_showcase_wallet',
    );

    expect(
        sections.authored.map((item) => item['id']), <Object?>['authored-1']);
    expect(sections.documented, isEmpty);
    expect(sections.documentedTotal, 0);
  });

  test('older backend keeps the legacy list as authored only', () async {
    BackendApiService().setHttpClient(
      _artworksClient(
        authoredIds: const <String>['legacy-1'],
        documentedIds: const <String>['legacy-2'],
        honourScope: false,
      ),
    );

    final sections = await ProfilePackageService.loadProfileArtworkSections(
      'profile_showcase_wallet',
    );

    expect(
      sections.authored.map((item) => item['id']),
      <Object?>['legacy-1', 'legacy-2'],
    );
    expect(sections.documented, isEmpty);
    expect(sections.authoredTotal, isNull);
    expect(sections.documentedTotal, isNull);
  });

  test('missing author filter echo marks public showcase unavailable',
      () async {
    const profileId = '10000000-0000-4000-8000-000000000021';
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == '/api/artworks') {
        return _json(<String, Object?>{'data': <Object?>[]});
      }
      return _json(<String, Object?>{'data': <Object?>[]});
    }));

    final package =
        await ProfilePackageService.loadPublicProfileExtendedPackage(
      profileId,
      forceRefresh: true,
      includePosts: false,
      user: ProfileFixtures.user(id: profileId, isArtist: true)
          .copyWith(profileId: profileId),
    );

    expect(package, isNotNull);
    expect(package!.authoredArtworksUnavailable, isTrue);
    expect(package.artistArtworks, isEmpty);
  });

  for (final (name, surface, size) in <(String, ProfileSurface, Size)>[
    ('mobile', ProfileSurface.mobilePublic, const Size(390, 2400)),
    ('desktop', ProfileSurface.desktopPublic, const Size(1440, 1600)),
  ]) {
    for (final isOwner in <bool>[false, true]) {
      testWidgets(
          '$name ${isOwner ? 'own' : 'foreign'} showcase reports unsupported author filter',
          (tester) async {
        const profileId = '10000000-0000-4000-8000-000000000022';
        final user = ProfileFixtures.user(id: profileId, isArtist: true)
            .copyWith(profileId: profileId);
        await pumpProfileSurface(
          tester,
          surface: surface,
          user: user,
          size: size,
          viewerIsSubject: isOwner,
          ownerWalletless: isOwner,
          authoredArtworksUnavailable: true,
        );

        expect(find.text('Not available'), findsWidgets);
        expect(find.text('Retry'), findsWidgets);
      });
    }
  }
}
