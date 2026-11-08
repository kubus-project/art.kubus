import 'dart:convert';
import 'dart:ui' show Size;

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

/// A wallet is optional. The owner's own profile of an account that has no
/// wallet identity must not tell them to connect one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const legacyPrompt = 'Connect wallet to see profile';

  for (final (name, surface, size) in <(String, ProfileSurface, Size)>[
    ('mobile', ProfileSurface.mobileOwner, const Size(390, 2400)),
    ('desktop', ProfileSurface.desktopOwner, const Size(1440, 1600)),
  ]) {
    testWidgets('$name owner profile without a wallet shows no connect prompt',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: surface,
        user: ProfileFixtures.user(isArtist: true),
        size: size,
      );
      expect(find.text(legacyPrompt), findsNothing);
    });
  }

  group('the Artworks count of a walletless owner is the account total', () {
    const profileId = '8c03b35a-a4d6-4c08-95fc-503c879fbc45';
    // More than one page of the showcase (6): the count must not be the
    // page-capped length of the loaded list.
    const serverTotal = 37;

    tearDown(() {
      BackendApiService().setHttpClient(createPlatformHttpClient());
    });

    for (final (name, surface, size) in <(String, ProfileSurface, Size)>[
      ('mobile', ProfileSurface.mobileOwner, const Size(390, 2400)),
      ('desktop', ProfileSurface.desktopOwner, const Size(1440, 1600)),
    ]) {
      testWidgets('$name shows the server total, not the loaded page',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final requests = <http.Request>[];
        BackendApiService().setHttpClient(MockClient((request) async {
          requests.add(request);
          final isArtworks =
              request.url.path == '/api/profiles/$profileId/artworks';
          final authored =
              request.url.queryParameters['relationship'] == 'authored';
          return http.Response(
            jsonEncode(<String, Object?>{
              'data': isArtworks && authored
                  ? [
                      for (var i = 0; i < 6; i++)
                        <String, Object?>{'id': 'a$i', 'title': 'Work $i'},
                    ]
                  : <Object?>[],
              'relationship': request.url.queryParameters['relationship'],
              'pagination': <String, Object?>{
                'total': isArtworks && authored ? serverTotal : 0,
                'limit': 6,
                'offset': 0,
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }));

        await pumpProfileSurface(
          tester,
          surface: surface,
          user: ProfileFixtures.user(id: profileId, isArtist: true),
          size: size,
          ownerWalletless: true,
        );
        // Let the artist-data load (mocked HTTP) finish.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        expect(
          requests.any((r) =>
              r.url.path == '/api/profiles/$profileId/artworks' &&
              r.url.queryParameters['relationship'] == 'authored'),
          isTrue,
          reason: 'the artist data is loaded by profile id, not by wallet',
        );
        expect(find.text('$serverTotal'), findsWidgets);
        expect(find.text('6'), findsNothing);
      });
    }
  });
}
