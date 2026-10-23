import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/map_data_controller.dart';
import 'package:art_kubus/services/map_marker_service.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:art_kubus/utils/geo_bounds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const markerId = 'synthetic-public-marker-1';
  const artworkId = 'synthetic-artwork-1';

  Map<String, Object?> markerJson() => <String, Object?>{
        'id': markerId,
        'name': 'Synthetic public marker',
        'description': 'Local cache fixture',
        'latitude': 46.0569,
        'longitude': 14.5058,
        'markerType': 'artwork',
        'artworkId': artworkId,
        'createdAt': '2026-10-23T00:00:00.000Z',
        'createdBy': 'synthetic-test',
        'isPublic': true,
        'isActive': true,
      };

  http.Response markerListResponse() => http.Response(
        jsonEncode(<String, Object?>{
          'success': true,
          'data': <Map<String, Object?>>[markerJson()],
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );

  http.Response singleMarkerResponse() => http.Response(
        jsonEncode(<String, Object?>{'success': true, 'data': markerJson()}),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );

  void enterIpfsFallback() {
    final fallback = PublicFallbackService();
    for (var i = 0; i < AppConfig.backendOutageFailureThreshold; i++) {
      fallback.recordDualBackendFailure(notify: false);
    }
    expect(fallback.isIpfsFallbackMode, isTrue);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PublicFallbackService().resetForTesting();
    BackendApiService().setAuthTokenForTesting(null);
    MapDataController().clearMarkerByIdCache();
  });

  tearDown(() async {
    MapDataController().clearMarkerByIdCache();
    BackendApiService().setHttpClient(http.Client());
    await PublicFallbackService().resetForTesting();
  });

  test(
    'radius and bounds caches do not expose markers in IPFS fallback',
    () async {
      final requests = <Uri>[];
      BackendApiService().setHttpClient(
        MockClient((request) async {
          requests.add(request.url);
          return markerListResponse();
        }),
      );
      final service = MapMarkerService.createForTest();
      const center = LatLng(46.0569, 14.5058);
      const bounds = GeoBounds(
        south: 46.0,
        west: 14.4,
        north: 46.1,
        east: 14.6,
      );

      expect(
        await service.loadMarkers(center: center, radiusKm: 5),
        hasLength(1),
      );
      expect(
        await service.loadMarkersInBounds(center: center, bounds: bounds),
        hasLength(1),
      );
      expect(requests, hasLength(2));
      expect(service.cachedMarkers, hasLength(1));

      enterIpfsFallback();

      expect(await service.loadMarkers(center: center, radiusKm: 5), isEmpty);
      expect(
        await service.loadMarkersInBounds(center: center, bounds: bounds),
        isEmpty,
      );
      expect(service.cachedMarkers, isEmpty);
      expect(requests, hasLength(2));
      expect(service.debugStats.cacheHits, 0);
    },
  );

  test(
    'single and by-artwork TTL caches are withheld in IPFS fallback',
    () async {
      final requests = <Uri>[];
      BackendApiService().setHttpClient(
        MockClient((request) async {
          requests.add(request.url);
          if (request.url.path.endsWith('/$markerId')) {
            return singleMarkerResponse();
          }
          return markerListResponse();
        }),
      );
      final controller = MapDataController();

      expect(await controller.getArtMarkerById(markerId), isNotNull);
      expect(await controller.getArtMarkersByArtwork(artworkId), hasLength(1));
      expect(requests, hasLength(2));

      enterIpfsFallback();

      expect(await controller.getArtMarkerById(markerId), isNull);
      expect(await controller.getArtMarkersByArtwork(artworkId), isEmpty);
      expect(requests, hasLength(2));
      expect(controller.debugStats.markerByIdCacheHits, 0);
      expect(controller.debugStats.markersByArtworkCacheHits, 0);
    },
  );

  test('socket and local marker upserts are withheld in IPFS fallback',
      () async {
    BackendApiService().setHttpClient(
      MockClient((_) async => markerListResponse()),
    );
    final service = MapMarkerService.createForTest();
    const center = LatLng(46.0569, 14.5058);
    await service.loadMarkers(center: center, radiusKm: 5);

    final emitted = <ArtMarker>[];
    final subscription = service.onMarkerCreated.listen(emitted.add);
    Map<String, dynamic> socketMarker(String id) => <String, dynamic>{
          'id': id,
          'name': 'Synthetic socket marker',
          'latitude': center.latitude,
          'longitude': center.longitude,
          'markerType': 'artwork',
          'createdAt': '2026-10-23T00:00:00.000Z',
          'createdBy': 'synthetic-test',
          'isPublic': true,
          'isActive': true,
        };

    service.debugHandleSocketMarker(socketMarker('synthetic-live-socket'));
    await Future<void>.delayed(Duration.zero);
    expect(
        emitted.map((marker) => marker.id), <String>['synthetic-live-socket']);

    enterIpfsFallback();
    service.debugHandleSocketMarker(socketMarker('synthetic-fallback-socket'));
    service.notifyMarkerUpserted(
      ArtMarker.fromMap(socketMarker('synthetic-fallback-local')),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
        emitted.map((marker) => marker.id), <String>['synthetic-live-socket']);
    expect(service.cachedMarkers, isEmpty);

    await PublicFallbackService().resetForTesting();
    expect(
      service.cachedMarkers.map((marker) => marker.id),
      isNot(contains('synthetic-fallback-socket')),
    );
    expect(
      service.cachedMarkers.map((marker) => marker.id),
      isNot(contains('synthetic-fallback-local')),
    );
    await subscription.cancel();
  });
}
