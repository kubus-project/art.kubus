import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

/// A walletless author without the artist role opens "My profile". The
/// authored works and public collection are public content, so the owner sees
/// them as visitors do. The artist-only parts (events, artist header) stay off.
const String _profileId = '8c03b35a-a4d6-4c08-95fc-503c879fbc45';

const List<Map<String, Object?>> _authoredWorks = <Map<String, Object?>>[
  <String, Object?>{'id': 'authored-lala', 'title': 'Lala Pilot Work'},
  <String, Object?>{'id': 'authored-nez', 'title': 'Nezaboravak Pilot Work'},
];

http.Response _json(Object? payload) {
  return http.Response(
    jsonEncode(payload),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

MockClient _ownerClient({
  required List<Uri> requests,
  bool withWorks = true,
  bool withCollection = true,
}) {
  return MockClient((request) async {
    requests.add(request.url);
    final path = request.url.path;
    if (path == '/api/profiles/$_profileId/artworks') {
      final relationship = request.url.queryParameters['relationship'];
      final items = relationship == 'authored' && withWorks
          ? _authoredWorks
          : const <Map<String, Object?>>[];
      return _json(<String, Object?>{
        'data': items,
        'relationship': relationship,
        'pagination': <String, Object?>{
          'total': items.length,
          'limit': 6,
          'offset': 0,
        },
      });
    }
    if (path == '/api/collections') {
      return _json(<String, Object?>{
        'data': withCollection
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'collection-hof',
                  'name': 'Head of Flowers',
                  'artworkCount': 2,
                },
              ]
            : <Map<String, Object?>>[],
      });
    }
    if (path == '/api/events') {
      return _json(<String, Object?>{'data': <Object?>[]});
    }
    return http.Response('Not found', 404);
  });
}

Future<void> _pumpOwner(
  WidgetTester tester, {
  required ProfileSurface surface,
  required Size size,
  required List<Uri> requests,
  bool withWorks = true,
  bool withCollection = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  BackendApiService().setHttpClient(_ownerClient(
    requests: requests,
    withWorks: withWorks,
    withCollection: withCollection,
  ));

  await pumpProfileSurface(
    tester,
    surface: surface,
    user: ProfileFixtures.user(id: _profileId, isArtist: false),
    size: size,
    ownerWalletless: true,
  );
  // Let the owner's showcase load (mocked HTTP) finish.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(
      tester.element(find.byType(ProfileIdentityBlock).first),
    )!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  testWidgets(
      'mobile own profile without the artist role shows its authored works '
      'and collection, with no artist header or events', (tester) async {
    final requests = <Uri>[];
    await _pumpOwner(
      tester,
      surface: ProfileSurface.mobileOwner,
      size: const Size(390, 2400),
      requests: requests,
    );
    final l10n = _l10n(tester);

    expect(find.text('Lala Pilot Work'), findsWidgets);
    expect(find.text('Head of Flowers'), findsWidgets);
    expect(find.text(l10n.userProfileArtistHighlightsTitle), findsNothing);
    expect(find.text(l10n.userProfileEventsTitle), findsNothing);
    expect(
      requests.where((uri) => uri.path == '/api/events'),
      isEmpty,
      reason: 'events are a creator surface',
    );
  });

  testWidgets(
      'desktop own profile without the artist role shows its authored works '
      'and collection, with no artist events', (tester) async {
    final requests = <Uri>[];
    await _pumpOwner(
      tester,
      surface: ProfileSurface.desktopOwner,
      size: const Size(1440, 2400),
      requests: requests,
    );
    final l10n = _l10n(tester);

    expect(find.text('Lala Pilot Work'), findsWidgets);
    expect(find.text('Head of Flowers'), findsWidgets);
    expect(find.text(l10n.desktopProfileEventsTitle), findsNothing);
    expect(
      requests.where((uri) => uri.path == '/api/events'),
      isEmpty,
      reason: 'events are a creator surface',
    );
  });

  testWidgets(
      'mobile own profile without the artist role shows only the collection '
      'when it has no works', (tester) async {
    await _pumpOwner(
      tester,
      surface: ProfileSurface.mobileOwner,
      size: const Size(390, 2400),
      requests: <Uri>[],
      withWorks: false,
    );
    final l10n = _l10n(tester);

    expect(find.text('Head of Flowers'), findsWidgets);
    expect(
      find.text(l10n.profileShowcaseEmptyTitle(
        l10n.userProfileArtworksTitle,
      )),
      findsNothing,
      reason: 'an empty Artworks band is not rendered for a non-artist',
    );
  });

  testWidgets(
      'desktop own profile without the artist role shows only the collection '
      'when it has no works', (tester) async {
    await _pumpOwner(
      tester,
      surface: ProfileSurface.desktopOwner,
      size: const Size(1440, 2400),
      requests: <Uri>[],
      withWorks: false,
    );
    final l10n = _l10n(tester);

    expect(find.text('Head of Flowers'), findsWidgets);
    expect(find.text(l10n.artistGalleryEmptyTitle), findsNothing,
        reason: 'an empty Portfolio band is not rendered for a non-artist');
    expect(find.text(l10n.desktopProfilePortfolioTitle), findsNothing);
  });
}
