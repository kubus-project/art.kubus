import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/collections_provider.dart';
import 'package:art_kubus/providers/collectibles_provider.dart';
import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _walletA = 'WalletTest111111111111111111111111111111111111';

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

Map<String, Object?> _institutionPayload({required String id}) {
  return {
    'id': id,
    'name': 'Kubus Gallery',
    'description': 'Institution',
    'type': 'gallery',
    'address': 'Main Street',
    'latitude': 46.0511,
    'longitude': 14.5051,
    'contactEmail': 'hello@example.com',
    'website': 'https://example.com',
    'imageUrls': <String>[],
    'stats': {
      'totalVisitors': 0,
      'activeEvents': 1,
      'artworkViews': 0,
      'revenue': 0,
      'visitorGrowth': 0,
      'revenueGrowth': 0,
    },
    'isVerified': true,
    'createdAt': '2026-07-01T10:00:00.000Z',
  };
}

Map<String, Object?> _eventPayload({required String id}) {
  return {
    'id': id,
    'title': 'Backend Event',
    'description': 'From /api/events',
    'type': 'workshop',
    'category': 'digital',
    'institution_id': 'inst-1',
    'starts_at': '2026-08-01T18:00:00.000Z',
    'ends_at': '2026-08-01T20:00:00.000Z',
    'location_name': 'Studio 2',
    'lat': 46.0511,
    'lng': 14.5051,
    'created_at': '2026-07-01T10:00:00.000Z',
    'host_user_id': 'host-1',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AccountIdentity.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
    await AccountIdentity.notifyChanged();
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  group('exhibitions of the account that signed out', () {
    test(
        'the signed-in mine list, drafts included, is cleared when the '
        'account changes', () async {
      final api = BackendApiService();
      api.setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/exhibitions' &&
            request.url.queryParameters['mine'] == 'true') {
          return _jsonResponse(<String, Object?>{
            'data': <String, Object?>{
              'exhibitions': <Object?>[
                <String, Object?>{
                  'id': 'exhibition-draft',
                  'title': 'Unpublished Draft',
                  'status': 'draft',
                  'starts_at': '2026-08-01T18:00:00.000Z',
                },
              ],
            },
          });
        }
        return http.Response('Unexpected request ${request.url}', 500);
      }));
      final provider = ExhibitionsProvider(api: api);
      addTearDown(provider.dispose);

      await provider.loadExhibitions(refresh: true, mine: true);
      expect(provider.myExhibitions.map((e) => e.id),
          <String>['exhibition-draft']);

      await AccountIdentity.notifyChanged();

      expect(provider.myExhibitions, isEmpty);
      expect(provider.exhibitionById('exhibition-draft'), isNull);
    });

    test('a mine list still in flight when the account changes is discarded',
        () async {
      final api = BackendApiService();
      final gate = Completer<void>();
      api.setHttpClient(MockClient((request) async {
        await gate.future;
        return _jsonResponse(<String, Object?>{
          'data': <String, Object?>{
            'exhibitions': <Object?>[
              <String, Object?>{
                'id': 'exhibition-draft',
                'title': 'Unpublished Draft',
                'status': 'draft',
                'starts_at': '2026-08-01T18:00:00.000Z',
              },
            ],
          },
        });
      }));
      final provider = ExhibitionsProvider(api: api);
      addTearDown(provider.dispose);

      final load = provider.loadExhibitions(refresh: true, mine: true);
      await AccountIdentity.notifyChanged();
      gate.complete();
      await load;

      expect(provider.myExhibitions, isEmpty);
      expect(provider.exhibitionById('exhibition-draft'), isNull);
    });
  });

  group('events held in memory', () {
    test('the events cache is cleared when the account changes', () async {
      final api = BackendApiService();
      api.setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/events') {
          return _jsonResponse(<String, Object?>{
            'data': <String, Object?>{
              'events': <Object?>[_eventPayload(id: 'event-1')],
            },
          });
        }
        return http.Response('Unexpected request ${request.url}', 500);
      }));
      final provider = EventsProvider(api: api);
      addTearDown(provider.dispose);

      await provider.loadEvents(refresh: true);
      expect(provider.events.single.id, 'event-1');

      await AccountIdentity.notifyChanged();

      expect(provider.events, isEmpty);
      expect(provider.eventById('event-1'), isNull);
      expect(provider.initialized, isFalse);
    });
  });

  group('collections of the account that signed out', () {
    test('the collections list is cleared when the account changes', () async {
      final api = BackendApiService();
      api.setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/collections') {
          return _jsonResponse(<String, Object?>{
            'data': <Object?>[
              <String, Object?>{
                'id': 'collection-1',
                'title': 'My Collection',
                'wallet_address': _walletA,
              },
            ],
          });
        }
        return http.Response('Unexpected request ${request.url}', 500);
      }));
      final provider = CollectionsProvider(api: api);
      addTearDown(provider.dispose);

      await provider.loadCollections(refresh: true);
      expect(provider.collections.single.id, 'collection-1');

      await AccountIdentity.notifyChanged();

      expect(provider.collections, isEmpty);
      expect(provider.getCollectionById('collection-1'), isNull);
      expect(provider.listInitialized, isFalse);
    });
  });

  group('institutions and events held in memory', () {
    test(
        'institutions and events are cleared when the account changes, and '
        'the public list is requested again', () async {
      var eventRequests = 0;
      final reloadGate = Completer<void>();
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/institutions') {
          return _jsonResponse(<String, Object?>{
            'institutions': <Object?>[_institutionPayload(id: 'inst-1')],
          });
        }
        if (request.url.path == '/api/events') {
          eventRequests += 1;
          // The first request is the previous account's list. The reload waits
          // until the test has checked that nothing of that list is left.
          if (eventRequests == 2) await reloadGate.future;
          final id = eventRequests == 1 ? 'event-1' : 'event-2';
          return _jsonResponse(<String, Object?>{
            'data': <String, Object?>{
              'events': <Object?>[_eventPayload(id: id)],
            },
          });
        }
        return http.Response('Unexpected request ${request.url}', 500);
      }));
      final provider = InstitutionProvider();
      addTearDown(provider.dispose);

      await provider.initialize();
      expect(provider.events.single.id, 'event-1');

      await AccountIdentity.notifyChanged();
      expect(provider.events, isEmpty, reason: 'nothing of the old list left');

      reloadGate.complete();
      for (var i = 0; i < 400 && provider.events.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(provider.events.single.id, 'event-2');
    });
  });

  group('collectibles held in memory', () {
    test(
        'the wallet collectible index is fetched again after the account '
        'changes', () async {
      final requests = <String>[];
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/collectibles')) {
          requests.add(request.url.path);
          return _jsonResponse(<String, Object?>{
            'data': <String, Object?>{'collectibles': <Object?>[]},
          });
        }
        return http.Response('Unexpected request ${request.url}', 500);
      }));
      final provider = CollectiblesProvider();
      addTearDown(provider.dispose);

      await provider.refreshWalletCollectibleIndex(_walletA);
      await provider.refreshWalletCollectibleIndex(_walletA);
      expect(requests, hasLength(1), reason: 'cached within the session');

      await AccountIdentity.notifyChanged();
      await provider.refreshWalletCollectibleIndex(_walletA);
      expect(requests, hasLength(2), reason: 'refetched after the switch');
    });

    test(
        'an index read still in flight when the account changes is '
        'discarded', () async {
      final requests = <String>[];
      final gate = Completer<void>();
      var gated = true;
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/collectibles')) {
          requests.add(request.url.path);
          if (gated) {
            gated = false;
            await gate.future;
          }
          return _jsonResponse(<String, Object?>{
            'data': <String, Object?>{'collectibles': <Object?>[]},
          });
        }
        return http.Response('Unexpected request ${request.url}', 500);
      }));
      final provider = CollectiblesProvider();
      addTearDown(provider.dispose);

      final read = provider.refreshWalletCollectibleIndex(_walletA);
      await AccountIdentity.notifyChanged();
      gate.complete();
      await read;

      await provider.refreshWalletCollectibleIndex(_walletA);
      expect(requests, hasLength(2),
          reason: 'the discarded read was not kept as the index');
    });
  });

  group('achievement and task progress', () {
    test('progress is cleared when the account changes', () async {
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/achievements/me') {
          return _jsonResponse(<String, Object?>{
            'success': true,
            'definitions': <Object?>[
              <String, Object?>{
                'code': 'first_visit',
                'title': 'First visit',
                'description': 'Visit the map',
              },
            ],
            'progress': <Object?>[
              <String, Object?>{
                'achievementCode': 'first_visit',
                'currentProgress': 1,
                'isCompleted': false,
              },
            ],
            'unlocked': <Object?>[],
          });
        }
        return http.Response('Unexpected request ${request.url}', 500);
      }));
      final provider = TaskProvider();
      addTearDown(provider.dispose);
      await provider.refreshAchievementsForCurrentUser();
      provider.initializeProgress();
      expect(provider.achievementProgress, isNotEmpty);
      expect(provider.taskProgress, isNotEmpty);

      await AccountIdentity.notifyChanged();

      expect(provider.achievementProgress, isEmpty);
      expect(provider.taskProgress, isEmpty);
    });
  });
}
