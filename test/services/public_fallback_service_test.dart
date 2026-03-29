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
}
