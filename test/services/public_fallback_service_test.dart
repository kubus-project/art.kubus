import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _HealthState {
  bothDown,
  standbyWritable,
  hintedStandbyWritable,
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PublicFallbackService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = PublicFallbackService();
    await service.resetForTesting();
  });

  test(
    'refreshBackendMode enters IPFS fallback after three dual failures and recovers after two standby successes',
    () async {
      var healthState = _HealthState.bothDown;

      service.bindHttpClient(
        MockClient((request) async {
          if (request.url.path != '/health/writable') {
            return http.Response('Not Found', 404);
          }

          switch (healthState) {
            case _HealthState.bothDown:
              throw Exception('offline');
            case _HealthState.standbyWritable:
              if (request.url.host == 'bapi.kubus.site') {
                return http.Response(
                  jsonEncode(<String, dynamic>{
                    'writable': true,
                    'databaseRole': 'primary',
                  }),
                  200,
                );
              }
              throw Exception('offline');
            case _HealthState.hintedStandbyWritable:
              if (request.url.host == 'bapi.kubus.site') {
                return http.Response(
                  jsonEncode(<String, dynamic>{
                    'writable': true,
                    'databaseRole': 'primary',
                    'switchRecommended': true,
                    'preferredWriteBaseUrl': AppConfig.standbyApiUrl,
                  }),
                  200,
                );
              }
              throw Exception('offline');
          }
        }),
      );

      await service.refreshBackendMode();
      await service.refreshBackendMode();
      expect(service.mode, AppRuntimeMode.live);

      await service.refreshBackendMode();
      expect(service.mode, AppRuntimeMode.ipfsFallback);
      expect(service.consecutiveDualFailures, 3);

      healthState = _HealthState.standbyWritable;

      await service.refreshBackendMode();
      expect(service.mode, AppRuntimeMode.ipfsFallback);
      expect(service.consecutiveRecoverySuccesses, 1);

      await service.refreshBackendMode();
      expect(service.mode, AppRuntimeMode.standby);
    },
  );

  test(
    'switch hint exits IPFS fallback immediately when standby becomes writable',
    () async {
      var healthState = _HealthState.bothDown;

      service.bindHttpClient(
        MockClient((request) async {
          if (request.url.path != '/health/writable') {
            return http.Response('Not Found', 404);
          }

          switch (healthState) {
            case _HealthState.bothDown:
              throw Exception('offline');
            case _HealthState.standbyWritable:
              if (request.url.host == 'bapi.kubus.site') {
                return http.Response(
                  jsonEncode(<String, dynamic>{
                    'writable': true,
                    'databaseRole': 'primary',
                  }),
                  200,
                );
              }
              throw Exception('offline');
            case _HealthState.hintedStandbyWritable:
              if (request.url.host == 'bapi.kubus.site') {
                return http.Response(
                  jsonEncode(<String, dynamic>{
                    'writable': true,
                    'databaseRole': 'primary',
                    'switchRecommended': true,
                    'preferredWriteBaseUrl': AppConfig.standbyApiUrl,
                  }),
                  200,
                );
              }
              throw Exception('offline');
          }
        }),
      );

      await service.refreshBackendMode();
      await service.refreshBackendMode();
      await service.refreshBackendMode();
      expect(service.mode, AppRuntimeMode.ipfsFallback);

      healthState = _HealthState.hintedStandbyWritable;
      await service.refreshBackendMode();

      expect(service.mode, AppRuntimeMode.standby);
      expect(service.consecutiveRecoverySuccesses, 0);
    },
  );

  test(
      'standby read success does not promote mode when standby is not writable',
      () async {
    service.bindHttpClient(
      MockClient((request) async {
        if (request.url.path != '/health/writable') {
          return http.Response('Not Found', 404);
        }

        if (request.url.host == Uri.parse(AppConfig.standbyApiUrl).host) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'writable': false,
              'databaseRole': 'standby',
            }),
            503,
          );
        }

        throw Exception('offline');
      }),
    );

    await service.refreshBackendMode();
    service.recordBackendSuccess(baseUrl: AppConfig.standbyApiUrl);

    expect(service.standbyStatus?.writable, isFalse);
    expect(service.mode, AppRuntimeMode.live);
  });

  test(
      'loadRegistry and loadDatasetArray cache DNSLink registry data for offline reuse',
      () async {
    const artworksCid =
        'bafybeigdyrzt5bq2dp2i5m2h3x2p6g7c6f3s4n5m6p7q8r9s0t1u2v3w4';
    const placeholderCid =
        'bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku';
    final requestPaths = <String>[];
    final registryJson = jsonEncode(<String, dynamic>{
      'version': '2026-03-28',
      'generatedAt': '2026-03-28T12:00:00Z',
      'datasets': <String, dynamic>{
        'artworks': <String, dynamic>{
          'cid': artworksCid,
          'generatedAt': '2026-03-28T12:00:00Z',
        },
        for (final key in PublicFallbackService.requiredDatasetKeys
            .where((entry) => entry != 'artworks'))
          key: <String, dynamic>{
            'cid': placeholderCid,
            'generatedAt': '2026-03-28T12:00:00Z',
          },
      },
    });
    final artworksJson = jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{'id': 'art-1', 'title': 'Snapshot Artwork'},
    ]);

    service.bindHttpClient(
      MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path
            .contains('/ipns/public.kubus.site/public-index.json')) {
          return http.Response(registryJson, 200);
        }
        if (request.url.path.contains('/ipfs/$artworksCid')) {
          return http.Response(artworksJson, 200);
        }
        return http.Response('Not Found', 404);
      }),
    );

    final registry = await service.loadRegistry(forceRefresh: true);
    final artworks = await service.loadDatasetArray(
      'artworks',
      forceRefresh: true,
    );

    expect(registry, isNotNull);
    expect(registry!.datasets['artworks']?.cid, artworksCid);
    expect(artworks, hasLength(1));
    expect(artworks.first['id'], 'art-1');
    expect(
      requestPaths,
      contains(contains('/ipns/public.kubus.site/public-index.json')),
    );
    expect(requestPaths, contains(contains('/ipfs/$artworksCid')));

    await service.resetForTesting();
    service.bindHttpClient(
      MockClient((_) async => throw Exception('offline')),
    );

    final cachedRegistry = await service.loadRegistry();
    final cachedArtworks = await service.loadDatasetArray('artworks');

    expect(cachedRegistry, isNotNull);
    expect(cachedRegistry!.datasets['artworks']?.cid, artworksCid);
    expect(cachedArtworks, hasLength(1));
    expect(cachedArtworks.first['title'], 'Snapshot Artwork');
  });

  test('snapshot reads withhold markers and cached exhibition marker links',
      () async {
    const markerCid =
        'bafybeigdyrzt5bq2dp2i5m2h3x2p6g7c6f3s4n5m6p7q8r9s0t1u2v3w4';
    const exhibitionCid =
        'bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku';
    const placeholderCid =
        'bafybeibwzif3usj2hej4gkd5xwhkq6xrj2a6o3ilol4w6a7fdj3lvz2xsi';
    final registryJson = jsonEncode(<String, dynamic>{
      'version': '2026-10-23',
      'generatedAt': '2026-10-23T00:00:00Z',
      'datasets': <String, dynamic>{
        for (final key in PublicFallbackService.requiredDatasetKeys)
          key: <String, dynamic>{
            'cid': key == 'markers'
                ? markerCid
                : key == 'exhibitions'
                    ? exhibitionCid
                    : placeholderCid,
            'generatedAt': '2026-10-23T00:00:00Z',
          },
      },
    });

    service.bindHttpClient(
      MockClient((request) async {
        if (request.url.path
            .contains('/ipns/public.kubus.site/public-index.json')) {
          return http.Response(registryJson, 200);
        }
        if (request.url.path.contains('/ipfs/$exhibitionCid')) {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'exhibition-1',
                'title': 'Snapshot Exhibition',
                'markerIds': <String>['marker-public'],
                'marker_ids': <String>['marker-legacy'],
              },
            ]),
            200,
          );
        }
        if (request.url.path.contains('/ipfs/$markerCid')) {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{'id': 'marker-public'},
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      }),
    );

    final initialExhibitions = await service.loadDatasetArray(
      'exhibitions',
      forceRefresh: true,
    );
    expect(initialExhibitions, hasLength(1));
    expect(initialExhibitions.single['title'], 'Snapshot Exhibition');
    expect(initialExhibitions.single.containsKey('markerIds'), isFalse);
    expect(initialExhibitions.single.containsKey('marker_ids'), isFalse);

    await service.resetForTesting();
    for (var i = 0; i < AppConfig.backendOutageFailureThreshold; i++) {
      service.recordDualBackendFailure();
    }
    expect(service.mode, AppRuntimeMode.ipfsFallback);
    service.bindHttpClient(
      MockClient((_) async => throw Exception('offline')),
    );

    final cachedExhibitions = await service.loadDatasetArray('exhibitions');
    final cachedMarkers = await service.loadDatasetArray('markers');
    expect(cachedExhibitions, hasLength(1));
    expect(cachedExhibitions.single['title'], 'Snapshot Exhibition');
    expect(cachedExhibitions.single.containsKey('markerIds'), isFalse);
    expect(cachedExhibitions.single.containsKey('marker_ids'), isFalse);
    expect(cachedMarkers, isEmpty);
  });

  test(
    'refreshBackendMode reduces standby probe frequency in deep prolonged IPFS fallback outages',
    () async {
      var primaryChecks = 0;
      var standbyChecks = 0;

      service.bindHttpClient(
        MockClient((request) async {
          if (request.url.path != '/health/writable') {
            return http.Response('Not Found', 404);
          }

          if (request.url.host == Uri.parse(AppConfig.baseApiUrl).host) {
            primaryChecks += 1;
          }
          if (request.url.host == Uri.parse(AppConfig.standbyApiUrl).host) {
            standbyChecks += 1;
          }

          throw Exception('offline');
        }),
      );

      for (var i = 0; i < 9; i++) {
        await service.refreshBackendMode();
      }

      expect(service.mode, AppRuntimeMode.ipfsFallback);
      expect(service.consecutiveDualFailures, 9);
      expect(primaryChecks, 9);
      expect(standbyChecks, 9);

      await service.refreshBackendMode();

      expect(primaryChecks, 10);
      expect(standbyChecks, 9);
    },
  );
}
