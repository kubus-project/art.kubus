import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
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
  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
    AccountIdentity.resetForTesting();
  });

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

  for (final (name, surface, size) in <(String, ProfileSurface, Size)>[
    ('mobile', ProfileSurface.mobileOwner, const Size(390, 2400)),
    ('desktop', ProfileSurface.desktopOwner, const Size(1440, 1600)),
  ]) {
    testWidgets('$name wallet-linked owner keeps legacy authored lookup',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final requests = <http.Request>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        requests.add(request);
        final isAuthored = request.url.path ==
                '/api/profiles/${ProfileFixtures.wallet}/artworks' &&
            request.url.queryParameters['relationship'] == 'authored';
        return _jsonResponse(<String, Object?>{
          'data': isAuthored
              ? [_artworkJson('Wallet linked artwork')]
              : <Object?>[],
          'relationship': request.url.queryParameters['relationship'],
          'pagination': <String, Object?>{
            'total': isAuthored ? 1 : 0,
            'limit': 6,
            'offset': 0,
          },
        });
      }));

      await pumpProfileSurface(
        tester,
        surface: surface,
        user: ProfileFixtures.user(isArtist: true),
        size: size,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(
        requests.any((request) =>
            request.url.path ==
                '/api/profiles/${ProfileFixtures.wallet}/artworks' &&
            request.url.queryParameters['relationship'] == 'authored'),
        isTrue,
      );
      expect(
        requests.any((request) =>
            request.url.path == '/api/artworks' &&
            request.url.queryParameters['authorProfileId'] != null),
        isFalse,
      );
      expect(find.text('Wallet linked artwork'), findsWidgets);
    });
  }

  group('the Artworks count of a walletless owner is the account total', () {
    const profileId = '8c03b35a-a4d6-4c08-95fc-503c879fbc45';
    // More than one page of the showcase (6): the count must not be the
    // page-capped length of the loaded list.
    const serverTotal = 37;

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
          final isArtworks = request.url.path == '/api/artworks' &&
              request.url.queryParameters['authorProfileId'] == profileId;
          return http.Response(
            jsonEncode(<String, Object?>{
              'appliedFilters': <String, Object?>{
                'authorProfileId': profileId,
              },
              'data': isArtworks
                  ? [
                      for (var i = 0; i < serverTotal; i++)
                        _artworkJson('Work $i'),
                    ]
                  : <Object?>[],
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
              r.url.path == '/api/artworks' &&
              r.url.queryParameters['authorProfileId'] == profileId),
          isTrue,
          reason: 'the artist data is loaded by profile id, not by wallet',
        );
        expect(find.text('$serverTotal'), findsWidgets);
        expect(find.text('6'), findsNothing);
      });
    }
  });

  group('non-artist walletless owner author-filter failures', () {
    const profileId = '10000000-0000-4000-8000-000000000004';
    for (final (name, surface, size) in <(String, ProfileSurface, Size)>[
      ('mobile', ProfileSurface.mobileOwner, const Size(390, 2400)),
      ('desktop', ProfileSurface.desktopOwner, const Size(1440, 1600)),
    ]) {
      for (final withCollection in <bool>[false, true]) {
        testWidgets(
            '$name exposes author retry with ${withCollection ? 'a collection' : 'empty scopes'}',
            (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final requests = <http.Request>[];
          BackendApiService()
              .setHttpClient(legacyProfileClient((request) async {
            requests.add(request);
            if (request.url.path == '/api/artworks' &&
                request.url.queryParameters['authorProfileId'] == profileId) {
              return http.Response('author filter unavailable', 503);
            }
            if (request.url.path == '/api/collections') {
              return _jsonResponse(<String, Object?>{
                'data': withCollection
                    ? <Map<String, Object?>>[
                        <String, Object?>{
                          'id': 'collection-preserves-retry',
                          'title': 'Collection beside retry',
                        },
                      ]
                    : <Object?>[],
              });
            }
            return _jsonResponse(<String, Object?>{'data': <Object?>[]});
          }));

          await pumpProfileSurface(
            tester,
            surface: surface,
            user: ProfileFixtures.user(id: profileId),
            ownerWalletless: true,
            size: size,
          );
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }

          expect(
            requests.any((request) =>
                request.url.path == '/api/artworks' &&
                request.url.queryParameters['authorProfileId'] == profileId),
            isTrue,
          );
          expect(find.text('Not available'), findsWidgets);
          expect(find.text('Retry'), findsWidgets);
          if (withCollection) {
            expect(find.text('Collection beside retry'), findsWidgets);
          }
        });
      }
    }
  });

  group('owner showcase identity changes', () {
    const profileA = '10000000-0000-4000-8000-000000000001';
    const profileB = '10000000-0000-4000-8000-000000000002';
    const accountA = '40000000-0000-4000-8000-000000000001';
    const accountB = '40000000-0000-4000-8000-000000000002';

    for (final (name, surface, size) in <(String, ProfileSurface, Size)>[
      ('mobile', ProfileSurface.mobileOwner, const Size(390, 2400)),
      ('desktop', ProfileSurface.desktopOwner, const Size(1440, 1600)),
    ]) {
      testWidgets('$name owner shows unavailable when author filter is ignored',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final requests = <http.Request>[];
        var supportsAuthorFilter = false;
        var failCollections = false;
        var collectionFailures = 0;
        const profileId = '10000000-0000-4000-8000-000000000003';
        BackendApiService().setHttpClient(legacyProfileClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/collections') {
            if (failCollections) {
              collectionFailures++;
              return http.Response('collection unavailable', 503);
            }
            return _jsonResponse(<String, Object?>{
              'data': [
                <String, Object?>{
                  'id': 'collection-after-author-error',
                  'title': 'Collections still load',
                },
              ],
            });
          }
          if (request.url.path == '/api/events') {
            return _jsonResponse(<String, Object?>{
              'data': [
                <String, Object?>{
                  'id': 'event-after-author-error',
                  'title': 'Events still load',
                  'createdBy': profileId,
                },
              ],
            });
          }
          if (request.url.path == '/api/artworks' &&
              request.url.queryParameters['authorProfileId'] == profileId) {
            return supportsAuthorFilter
                ? _jsonResponse(<String, Object?>{
                    'appliedFilters': <String, Object?>{
                      'authorProfileId': profileId,
                    },
                    'data': [_artworkJson('Recovered artwork')],
                  })
                : _jsonResponse(<String, Object?>{'data': <Object?>[]});
          }
          return _jsonResponse(<String, Object?>{'data': <Object?>[]});
        }));

        await pumpProfileSurface(
          tester,
          surface: surface,
          user: ProfileFixtures.user(id: profileId, isArtist: true),
          ownerWalletless: true,
          size: size,
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }

        expect(
          requests.any((request) =>
              request.url.path == '/api/artworks' &&
              request.url.queryParameters['authorProfileId'] == profileId),
          isTrue,
        );
        expect(find.text('Not available'), findsWidgets);
        expect(find.text('Retry'), findsWidgets);
        expect(find.text('Collections still load'), findsWidgets);
        expect(find.text('Events still load'), findsWidgets);

        if (surface == ProfileSurface.desktopOwner) {
          supportsAuthorFilter = true;
          failCollections = true;
          await tester.tap(find.text('Retry').last);
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }

          expect(find.text('Recovered artwork'), findsWidgets);
          expect(find.text('Not available'), findsNothing);
          expect(find.text('1'), findsWidgets);
          expect(collectionFailures, greaterThan(0));
        }
      });

      testWidgets('$name discards delayed A showcase after switching to B',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final aResponse = Completer<http.Response>();
        final bResponse = Completer<http.Response>();
        final authorRequests = <String>[];
        final profileProvider = ProfileProvider();
        AccountIdentity.setAccountKey(accountA);
        BackendApiService().setHttpClient(legacyProfileClient((request) async {
          if (request.url.path == '/api/artworks' &&
              request.url.queryParameters['authorProfileId'] != null) {
            final author = request.url.queryParameters['authorProfileId']!;
            authorRequests.add(author);
            return author == profileA ? aResponse.future : bResponse.future;
          }
          if (request.url.path == '/api/collections') {
            final owner = request.url.queryParameters.values.firstWhere(
                (value) => value == profileA || value == profileB,
                orElse: () => 'none');
            return _jsonResponse(<String, Object?>{
              'data': [
                <String, Object?>{
                  'id': 'collection-$owner',
                  'title': 'Collection $owner',
                },
              ],
            });
          }
          if (request.url.path == '/api/events') {
            return _jsonResponse(<String, Object?>{
              'data': [
                <String, Object?>{
                  'id': 'event-b',
                  'title': 'Event B',
                  'createdBy': profileB,
                },
              ],
            });
          }
          return _jsonResponse(<String, Object?>{'data': <Object?>[]});
        }));

        await pumpProfileSurface(
          tester,
          surface: surface,
          user: ProfileFixtures.user(id: profileA, isArtist: true)
              .copyWith(userId: accountA),
          ownerWalletless: true,
          injectedProfileProvider: profileProvider,
          size: size,
        );
        expect(AccountIdentity.accountKey, accountA);
        expect(profileProvider.currentUser?.userId, accountA);
        expect(aResponse.isCompleted, isFalse);
        expect(authorRequests.where((id) => id == profileA), hasLength(1));

        // Match production order: the session is B before B's profile has
        // hydrated, so the screen must stay cleared and must not request A.
        AccountIdentity.setAccountKey(accountB);
        AccountIdentity.notifyListenersChanged();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(authorRequests.where((id) => id == profileA), hasLength(1));
        expect(authorRequests.where((id) => id == profileB), isEmpty);

        profileProvider.setCurrentUser(_owner(profileB, accountB));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(authorRequests.where((id) => id == profileB), hasLength(1));

        aResponse.complete(_jsonResponse(<String, Object?>{
          'appliedFilters': <String, Object?>{'authorProfileId': profileA},
          'data': [_artworkJson('A stale artwork')],
        }));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('A stale artwork'), findsNothing);

        bResponse.complete(_jsonResponse(<String, Object?>{
          'appliedFilters': <String, Object?>{'authorProfileId': profileB},
          'data': [_artworkJson('B artwork')],
        }));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.text('B artwork'), findsWidgets);
        expect(find.text('A stale artwork'), findsNothing);
        expect(find.text('Collection $profileB'), findsWidgets);
        expect(find.text('Event B'), findsWidgets);
      });

      testWidgets('$name ignores delayed A showcase error after switching to B',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final aResponse = Completer<http.Response>();
        final bResponse = Completer<http.Response>();
        final authorRequests = <String>[];
        final profileProvider = ProfileProvider();
        AccountIdentity.setAccountKey(accountA);
        BackendApiService().setHttpClient(legacyProfileClient((request) async {
          if (request.url.path == '/api/artworks' &&
              request.url.queryParameters['authorProfileId'] != null) {
            final author = request.url.queryParameters['authorProfileId']!;
            authorRequests.add(author);
            return author == profileA ? aResponse.future : bResponse.future;
          }
          return _jsonResponse(<String, Object?>{'data': <Object?>[]});
        }));

        await pumpProfileSurface(
          tester,
          surface: surface,
          user: ProfileFixtures.user(id: profileA, isArtist: true)
              .copyWith(userId: accountA),
          ownerWalletless: true,
          injectedProfileProvider: profileProvider,
          size: size,
        );
        expect(authorRequests.where((id) => id == profileA), hasLength(1));

        AccountIdentity.setAccountKey(accountB);
        AccountIdentity.notifyListenersChanged();
        await tester.pump();
        expect(authorRequests.where((id) => id == profileA), hasLength(1));
        expect(authorRequests.where((id) => id == profileB), isEmpty);

        profileProvider.setCurrentUser(_owner(profileB, accountB));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(authorRequests.where((id) => id == profileB), hasLength(1));

        aResponse.completeError(StateError('A request failed late'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Not available'), findsNothing);
        expect(authorRequests.where((id) => id == profileB), hasLength(1));

        bResponse.complete(_jsonResponse(<String, Object?>{
          'appliedFilters': <String, Object?>{'authorProfileId': profileB},
          'data': [_artworkJson('B after A error')],
        }));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('B after A error'), findsWidgets);
        expect(find.text('Not available'), findsNothing);
      });
    }
  });
}

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
      jsonEncode(body),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

Map<String, Object?> _artworkJson(String title) => <String, Object?>{
      'id': title.toLowerCase().replaceAll(' ', '-'),
      'title': title,
      'artist': 'Profile artist',
      'description': 'Widget test artwork',
      'latitude': 46.05,
      'longitude': 14.50,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'public': true,
    };

UserProfile _owner(String profileId, String accountId) => UserProfile(
      id: profileId,
      userId: accountId,
      walletAddress: '',
      username: 'artist',
      displayName: 'Profile Artist',
      bio: '',
      avatar: '',
      isArtist: true,
      createdAt: ProfileFixtures.fetchedAt,
      updatedAt: ProfileFixtures.fetchedAt,
    );
