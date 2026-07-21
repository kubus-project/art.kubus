import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/features/map/navigation/walking_navigation_map_coordinator.dart';
import 'package:art_kubus/features/map/navigation/walking_navigation_models.dart';
import 'package:art_kubus/providers/walking_navigation_provider.dart';
import 'package:art_kubus/services/walking_directions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

/// Stage-level coverage for the walking-route render pipeline: GeoJSON
/// production (stage 6), source writes (stage 8), and cached synchronization
/// state (stages 7-10).
void main() {
  const ids = MapLayersIds(
    markerSourceId: 'markers',
    markerLayerId: 'marker_layer',
    markerHitboxLayerId: 'marker_hitbox_layer',
    markerHitboxImageId: 'marker_hitbox_image',
    markerDotLayerId: 'marker_dot_layer',
    markerPulseLayerId: 'marker_pulse_layer',
    cubeLayerId: 'cube_layer',
    cubeIconLayerId: 'cube_icon_layer',
    locationSourceId: 'location',
    locationLayerId: 'location_layer',
  );

  group('WalkingRoute.toGeoJson', () {
    test('emits a primary route line when the graph segment is a single node',
        () {
      const route = WalkingRoute(
        points: <LatLng>[
          LatLng(46.0500, 14.5000),
          LatLng(46.0505, 14.5010),
          LatLng(46.0510, 14.5020),
        ],
        steps: <WalkingRouteStep>[],
        distanceMeters: 140,
        durationSeconds: 110,
        graphStartIndex: 1,
        graphEndIndex: 1,
      );

      final features = route.toGeoJson()['features'] as List<dynamic>;
      final kinds = features
          .map((feature) =>
              (feature as Map<String, dynamic>)['properties']['kind'] as String)
          .toList();

      expect(
        kinds,
        contains('route'),
        reason: 'a nominally successful route must never render as connectors '
            'only; the route layer filter would match nothing',
      );
    });

    test('drops degenerate geometry instead of emitting invalid coordinates',
        () {
      const route = WalkingRoute(
        points: <LatLng>[LatLng(46.05, 14.5), LatLng(46.05, 14.5)],
        steps: <WalkingRouteStep>[],
        distanceMeters: 0,
        durationSeconds: 0,
      );

      final features = route.toGeoJson()['features'] as List<dynamic>;
      expect(features, isEmpty);
    });

    test('produces no features for a single-point route', () {
      const route = WalkingRoute(
        points: <LatLng>[LatLng(46.05, 14.5)],
        steps: <WalkingRouteStep>[],
        distanceMeters: 0,
        durationSeconds: 0,
      );

      expect(route.toGeoJson()['features'], isEmpty);
    });

    test('produces no features for an empty route without throwing', () {
      const route = WalkingRoute(
        points: <LatLng>[],
        steps: <WalkingRouteStep>[],
        distanceMeters: 0,
        durationSeconds: 0,
      );

      expect(route.toGeoJson()['features'], isEmpty);
    });
  });

  group('MapLayersManager walking route mutations', () {
    test('reports styleNotReady before any style installed layers', () async {
      final controller = _FakeMapLayersController();
      final manager = MapLayersManager(
        controller: controller,
        ids: ids,
        debugTracing: false,
      );

      final result = await manager.upsertWalkingRouteData(_featureCollection());

      expect(result.isSuccess, isFalse);
      expect(result.status, WalkingRouteMutationStatus.styleNotReady);
    });

    test('reports sourceMissing when route-layer installation failed',
        () async {
      final controller = _FakeMapLayersController()
        ..failWalkingRouteInstall = true;
      final manager = await _initializedManager(controller, ids);

      final result = await manager.upsertWalkingRouteData(_featureCollection());

      expect(result.status, WalkingRouteMutationStatus.sourceMissing);
    });

    test('keeps the rest of the style usable when route install fails',
        () async {
      final controller = _FakeMapLayersController()
        ..failWalkingRouteInstall = true;
      final manager = await _initializedManager(controller, ids);

      expect(
        manager.initializedStyleEpoch,
        1,
        reason: 'a walking-route failure must not abort marker/location layers',
      );
      expect(manager.hasLayer(ids.markerLayerId), isTrue);
    });

    test('reports staleStyleEpoch when the style swapped mid-write', () async {
      final controller = _FakeMapLayersController();
      final manager = await _initializedManager(controller, ids);

      final result = await manager.upsertWalkingRouteData(
        _featureCollection(),
        expectedStyleEpoch: 99,
      );

      expect(result.status, WalkingRouteMutationStatus.staleStyleEpoch);
    });

    test('reports a typed failure when the controller rejects the write',
        () async {
      final controller = _FakeMapLayersController()
        ..failSetGeoJsonSource = true;
      final manager = await _initializedManager(controller, ids);

      final result = await manager.upsertWalkingRouteData(_featureCollection());

      expect(result.isSuccess, isFalse);
      expect(result.status, WalkingRouteMutationStatus.platformError);
    });

    test('reports success after a real write', () async {
      final controller = _FakeMapLayersController();
      final manager = await _initializedManager(controller, ids);

      final result = await manager.upsertWalkingRouteData(_featureCollection());

      expect(result.isSuccess, isTrue);
      expect(
        controller.updatedSourceData[ids.walkingRouteSourceId],
        isNotNull,
      );
    });

    test('visibility reports failure when a required layer is missing',
        () async {
      final controller = _FakeMapLayersController()
        ..failWalkingRouteInstall = true;
      final manager = await _initializedManager(controller, ids);

      final result = await manager.setWalkingNavigationVisibility(true);

      expect(result.isSuccess, isFalse);
      expect(result.status, WalkingRouteMutationStatus.layerMissing);
    });

    test('installs the documented kind filters on all three route layers',
        () async {
      final controller = _FakeMapLayersController();
      await _initializedManager(controller, ids);

      expect(
        controller.lineFilters[ids.walkingRouteLayerId],
        <Object>[
          '==',
          <Object>['get', 'kind'],
          'route',
        ],
      );
      expect(
        controller.lineFilters[ids.walkingRouteCasingLayerId],
        <Object>[
          '==',
          <Object>['get', 'kind'],
          'route',
        ],
      );
      expect(
        controller.lineFilters[ids.walkingRouteConnectorLayerId],
        <Object>[
          '==',
          <Object>['get', 'kind'],
          'connector',
        ],
      );
    });
  });

  group('WalkingNavigationMapCoordinator', () {
    test('retries the route write after the first write fails', () async {
      final controller = _FakeMapLayersController()
        ..failSetGeoJsonSource = true;
      final manager = await _initializedManager(controller, ids);
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => true,
        shouldFollow: () => false,
        followCamera: (_) async {},
        fitRouteBounds: (_) async {},
      );
      final navigation = await _activeNavigation();

      await coordinator.sync(navigation);
      expect(controller.setGeoJsonSourceCalls, 1);

      controller.failSetGeoJsonSource = false;
      await coordinator.sync(navigation);

      expect(
        controller.setGeoJsonSourceCalls,
        2,
        reason:
            'an identical route object must be retried after a failed write',
      );
      expect(
        controller.updatedSourceData[ids.walkingRouteSourceId],
        isNotNull,
      );
    });

    test('retries visibility after a failed visibility write', () async {
      final controller = _FakeMapLayersController()
        ..failSetLayerVisibility = true;
      final manager = await _initializedManager(controller, ids);
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => true,
        shouldFollow: () => false,
        followCamera: (_) async {},
        fitRouteBounds: (_) async {},
      );
      final navigation = await _activeNavigation();

      await coordinator.sync(navigation);
      controller.failSetLayerVisibility = false;
      controller.visibilityWrites.clear();
      await coordinator.sync(navigation);

      expect(
        controller.visibilityWrites[ids.walkingRouteLayerId],
        isTrue,
        reason: 'visibility must not be cached before it was applied',
      );
    });

    test('restores route geometry after a style reload', () async {
      final controller = _FakeMapLayersController();
      final manager = await _initializedManager(controller, ids);
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => true,
        shouldFollow: () => false,
        followCamera: (_) async {},
        fitRouteBounds: (_) async {},
      );
      final navigation = await _activeNavigation();

      await coordinator.sync(navigation);
      expect(controller.setGeoJsonSourceCalls, 1);

      manager.onNewStyle(styleEpoch: 2);
      await manager.ensureInitialized(styleEpoch: 2);
      await coordinator.sync(navigation);

      expect(
        controller.setGeoJsonSourceCalls,
        2,
        reason: 'a new style epoch must re-write the retained route',
      );
      final features = (controller.updatedSourceData[ids.walkingRouteSourceId]
          as Map<String, dynamic>)['features'] as List<dynamic>;
      expect(features, isNotEmpty);
    });

    test('fits the route into view before entering follow mode', () async {
      final controller = _FakeMapLayersController();
      final manager = await _initializedManager(controller, ids);
      final events = <String>[];
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => true,
        shouldFollow: () => true,
        followCamera: (_) async => events.add('follow'),
        fitRouteBounds: (_) async => events.add('fit'),
      );
      final navigation = await _activeNavigation();

      await coordinator.sync(navigation);

      expect(events, <String>['fit']);
      expect(coordinator.isRouteOverviewActive, isTrue);
    });

    test('resume hands the camera back to follow mode', () async {
      final controller = _FakeMapLayersController();
      final manager = await _initializedManager(controller, ids);
      final events = <String>[];
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => true,
        shouldFollow: () => true,
        followCamera: (_) async => events.add('follow'),
        fitRouteBounds: (_) async => events.add('fit'),
      );
      final navigation = await _activeNavigation();

      await coordinator.sync(navigation);
      coordinator.resumeFollow();
      await coordinator.sync(navigation);

      expect(events, <String>['fit', 'follow']);
    });

    test('does not fit again for the same route', () async {
      final controller = _FakeMapLayersController();
      final manager = await _initializedManager(controller, ids);
      var fits = 0;
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => true,
        shouldFollow: () => false,
        followCamera: (_) async {},
        fitRouteBounds: (_) async => fits += 1,
      );
      final navigation = await _activeNavigation();

      await coordinator.sync(navigation);
      await coordinator.sync(navigation);
      await coordinator.sync(navigation);

      expect(fits, 1);
    });

    test('never writes an empty feature collection for a live route', () async {
      final controller = _FakeMapLayersController();
      final manager = await _initializedManager(controller, ids);
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => true,
        shouldFollow: () => false,
        followCamera: (_) async {},
        fitRouteBounds: (_) async {},
      );
      final session = await _activeSession(
        routes: <WalkingRoute>[
          // Graph start and end collapse onto the same node.
          const WalkingRoute(
            points: <LatLng>[
              LatLng(46.0500, 14.5000),
              LatLng(46.0505, 14.5010),
              LatLng(46.0510, 14.5020),
            ],
            steps: <WalkingRouteStep>[],
            distanceMeters: 140,
            durationSeconds: 110,
            graphStartIndex: 1,
            graphEndIndex: 1,
          ),
        ],
      );

      await coordinator.sync(session.provider);

      final written = (controller.updatedSourceData[ids.walkingRouteSourceId]
          as Map<String, dynamic>)['features'] as List<dynamic>;
      expect(written, isNotEmpty);
      expect(
        written.map(
          (feature) =>
              (feature as Map<String, dynamic>)['properties']['kind'] as String,
        ),
        contains('route'),
      );
    });

    test('renders once the style becomes ready after a deferred sync',
        () async {
      final controller = _FakeMapLayersController();
      final manager = await _initializedManager(controller, ids);
      var styleReady = false;
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => styleReady,
        shouldFollow: () => false,
        followCamera: (_) async {},
        fitRouteBounds: (_) async {},
      );
      addTearDown(coordinator.dispose);
      final navigation = await _activeNavigation();

      // The route exists but the style is still loading, and no further
      // provider notification will arrive.
      await coordinator.sync(navigation);
      expect(controller.setGeoJsonSourceCalls, 0);

      styleReady = true;
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        controller.setGeoJsonSourceCalls,
        greaterThan(0),
        reason: 'the coordinator must retry once the map becomes usable',
      );
      expect(coordinator.isRouteVisuallyReady, isTrue);
    });

    test('a superseded route write never replaces a newer route', () async {
      final controller = _FakeMapLayersController()
        ..holdSetGeoJsonSource = true;
      final manager = await _initializedManager(controller, ids);
      final coordinator = WalkingNavigationMapCoordinator(
        layersManager: () => manager,
        isStyleReady: () => true,
        shouldFollow: () => false,
        followCamera: (_) async {},
        fitRouteBounds: (_) async {},
      );

      final session = await _activeSession(
        routes: <WalkingRoute>[
          _route(
            const <LatLng>[
              LatLng(46.0500, 14.5000),
              LatLng(46.0505, 14.5010),
              LatLng(46.0510, 14.5020),
            ],
          ),
          _route(
            const <LatLng>[
              LatLng(46.0600, 14.5100),
              LatLng(46.0610, 14.5120),
              LatLng(46.0620, 14.5140),
            ],
          ),
        ],
      );
      final navigation = session.provider;
      final first = coordinator.sync(navigation);

      // A production reroute replaces the route object mid-write.
      await navigation.retry(lease: session.lease);
      final second = coordinator.sync(navigation);

      controller.releaseHeldWrites();
      await first;
      await second;

      final written = (controller.updatedSourceData[ids.walkingRouteSourceId]
          as Map<String, dynamic>)['features'] as List<dynamic>;
      final coordinates = ((written.first as Map<String, dynamic>)['geometry']
          as Map<String, dynamic>)['coordinates'] as List<dynamic>;
      expect(
        (coordinates.first as List<dynamic>).last,
        closeTo(46.0600, 0.00001),
        reason: 'the latest route revision must win',
      );
    });
  });
}

Future<MapLayersManager> _initializedManager(
  _FakeMapLayersController controller,
  MapLayersIds ids,
) async {
  final manager = MapLayersManager(
    controller: controller,
    ids: ids,
    debugTracing: false,
  )..updateThemeSpec(
      const MapLayersThemeSpec(
        locationFill: Color(0xFF2196F3),
        locationStroke: Color(0xFFFFFFFF),
      ),
    );
  await manager.ensureInitialized(styleEpoch: 1);
  controller.updatedSourceData.clear();
  controller.setGeoJsonSourceCalls = 0;
  controller.visibilityWrites.clear();
  return manager;
}

Future<WalkingNavigationProvider> _activeNavigation() async =>
    (await _activeSession(
      routes: <WalkingRoute>[
        _route(
          const <LatLng>[
            LatLng(46.0500, 14.5000),
            LatLng(46.0505, 14.5010),
            LatLng(46.0510, 14.5020),
          ],
        ),
      ],
    ))
        .provider;

Future<_NavigationSession> _activeSession({
  required List<WalkingRoute> routes,
}) async {
  final provider = WalkingNavigationProvider(
    directionsApi: _SequenceDirectionsApi(routes),
  );
  final lease = provider.start(
    const WalkingNavigationIntent(
      destinationId: 'artwork-1',
      destinationLabel: 'Artwork',
      destination: LatLng(46.0510, 14.5020),
    ),
  );
  await provider.updatePosition(const LatLng(46.05, 14.5), lease: lease);
  return _NavigationSession(provider, lease);
}

class _NavigationSession {
  _NavigationSession(this.provider, this.lease);

  final WalkingNavigationProvider provider;
  final WalkingNavigationSessionLease? lease;
}

WalkingRoute _route(List<LatLng> points) => WalkingRoute(
      points: points,
      steps: const <WalkingRouteStep>[],
      distanceMeters: 200,
      durationSeconds: 150,
    );

Map<String, dynamic> _featureCollection() => <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'Feature',
          'id': 'walking-route',
          'properties': <String, dynamic>{'kind': 'route'},
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': <List<double>>[
              <double>[14.5, 46.05],
              <double>[14.501, 46.0505],
            ],
          },
        },
      ],
    };

class _SequenceDirectionsApi implements WalkingDirectionsApi {
  _SequenceDirectionsApi(this.results);

  final List<WalkingRoute> results;
  int requests = 0;

  @override
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final result = results[requests.clamp(0, results.length - 1)];
    requests += 1;
    return result;
  }

  @override
  void dispose() {}
}

class _FakeMapLayersController implements MapLayersController {
  final Map<String, Map<String, dynamic>> updatedSourceData =
      <String, Map<String, dynamic>>{};
  final Map<String, bool> visibilityWrites = <String, bool>{};
  final List<Completer<void>> _heldWrites = <Completer<void>>[];

  bool failSetGeoJsonSource = false;
  bool failSetLayerVisibility = false;
  bool holdSetGeoJsonSource = false;
  bool failWalkingRouteInstall = false;
  int setGeoJsonSourceCalls = 0;
  final Set<String> installedLayerIds = <String>{};

  void releaseHeldWrites() {
    holdSetGeoJsonSource = false;
    for (final completer in _heldWrites) {
      if (!completer.isCompleted) completer.complete();
    }
    _heldWrites.clear();
  }

  @override
  Future<List<dynamic>> getLayerIds() async => const <dynamic>[];

  @override
  Future<void> removeLayer(String id) async {}

  @override
  Future<void> removeSource(String id) async {}

  @override
  Future<void> addGeoJsonSource(
    String id,
    Map<String, dynamic> data, {
    String? promoteId,
  }) async {
    if (failWalkingRouteInstall && id.contains('walking_route')) {
      throw StateError('style is mutating');
    }
  }

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    ml.FillExtrusionLayerProperties properties,
  ) async {}

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    ml.SymbolLayerProperties properties,
  ) async {}

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    ml.CircleLayerProperties properties,
  ) async {}

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    ml.LineLayerProperties properties, {
    dynamic filter,
  }) async {
    lineFilters[layerId] = filter;
    installedLayerIds.add(layerId);
  }

  final Map<String, dynamic> lineFilters = <String, dynamic>{};

  @override
  Future<void> addImage(String name, Uint8List bytes) async {}

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> data,
  ) async {
    setGeoJsonSourceCalls += 1;
    if (holdSetGeoJsonSource) {
      final completer = Completer<void>();
      _heldWrites.add(completer);
      await completer.future;
    }
    if (failSetGeoJsonSource) {
      throw StateError('style not ready');
    }
    updatedSourceData[sourceId] = data;
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    if (failSetLayerVisibility) {
      throw StateError('layer not ready');
    }
    visibilityWrites[layerId] = visible;
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    ml.LayerProperties properties,
  ) async {}

  @override
  Future<void> setPaintProperty(
    String layerId,
    String name,
    Object value,
  ) async {}

  @override
  Future<void> setLayoutProperty(
    String layerId,
    String name,
    Object value,
  ) async {}
}
