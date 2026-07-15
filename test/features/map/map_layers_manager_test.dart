import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:art_kubus/features/map/map_layers_manager.dart';

class _FakeMapLayersController implements MapLayersController {
  final List<String> calls = <String>[];
  final Map<String, Map<String, dynamic>> initialSourceData =
      <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> updatedSourceData =
      <String, Map<String, dynamic>>{};
  final Map<String, dynamic> lineFilters = <String, dynamic>{};

  void _record(String call) => calls.add(call);

  @override
  Future<List<dynamic>> getLayerIds() async {
    _record('getLayerIds');
    return const <dynamic>[];
  }

  @override
  Future<void> removeLayer(String id) async {
    _record('removeLayer:$id');
  }

  @override
  Future<void> removeSource(String id) async {
    _record('removeSource:$id');
  }

  @override
  Future<void> addGeoJsonSource(
    String id,
    Map<String, dynamic> data, {
    String? promoteId,
  }) async {
    _record('addGeoJsonSource:$id:${promoteId ?? ''}');
    initialSourceData[id] = data;
  }

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    ml.FillExtrusionLayerProperties properties,
  ) async {
    _record('addFillExtrusionLayer:$sourceId:$layerId');
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    ml.SymbolLayerProperties properties,
  ) async {
    _record('addSymbolLayer:$sourceId:$layerId');
  }

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    ml.CircleLayerProperties properties,
  ) async {
    _record('addCircleLayer:$sourceId:$layerId');
  }

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    ml.LineLayerProperties properties, {
    dynamic filter,
  }) async {
    _record('addLineLayer:$sourceId:$layerId');
    lineFilters[layerId] = filter;
  }

  @override
  Future<void> addImage(String name, Uint8List bytes) async {
    _record('addImage:$name:${bytes.length}');
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> data,
  ) async {
    _record('setGeoJsonSource:$sourceId');
    updatedSourceData[sourceId] = data;
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    _record('setLayerVisibility:$layerId:$visible');
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    ml.LayerProperties properties,
  ) async {
    _record('setLayerProperties:$layerId');
  }

  @override
  Future<void> setPaintProperty(
    String layerId,
    String name,
    Object value,
  ) async {
    _record('setPaintProperty:$layerId:$name');
  }

  @override
  Future<void> setLayoutProperty(
    String layerId,
    String name,
    Object value,
  ) async {
    _record('setLayoutProperty:$layerId:$name');
  }
}

void main() {
  group('MapLayersManager', () {
    test('ensureInitialized is idempotent per style epoch', () async {
      final controller = _FakeMapLayersController();
      const ids = MapLayersIds(
        markerSourceId: 'kubus_markers',
        markerLayerId: 'kubus_marker_layer',
        markerHitboxLayerId: 'kubus_marker_hitbox_layer',
        markerHitboxImageId: 'kubus_hitbox_square_transparent',
        markerDotLayerId: 'kubus_marker_dot_layer',
        markerPulseLayerId: 'kubus_marker_pulse_layer',
        cubeLayerId: 'kubus_marker_cubes_layer',
        cubeIconLayerId: 'kubus_marker_cubes_icon_layer',
        locationSourceId: 'kubus_user_location',
        locationLayerId: 'kubus_user_location_layer',
      );

      final manager = MapLayersManager(
        controller: controller,
        ids: ids,
        debugTracing: false,
      );
      manager.onNewStyle(styleEpoch: 1);
      manager.updateThemeSpec(
        const MapLayersThemeSpec(
          locationFill: Colors.blue,
          locationStroke: Colors.white,
        ),
      );

      await manager.ensureInitialized(styleEpoch: 1);
      final firstCallCount = controller.calls.length;
      expect(firstCallCount, greaterThan(0));
      expect(manager.hasSource(ids.markerSourceId), isTrue);
      expect(manager.hasLayer(ids.markerLayerId), isTrue);
      expect(manager.hasLayer(ids.cubeLayerId), isTrue);
      expect(
        controller.calls,
        contains(
          'addSymbolLayer:${ids.markerSourceId}:${ids.cubeLayerId}',
        ),
      );

      await manager.ensureInitialized(styleEpoch: 1);
      expect(controller.calls.length, equals(firstCallCount));

      // New epoch should allow a new init attempt.
      manager.onNewStyle(styleEpoch: 2);
      expect(manager.hasLayer(ids.markerLayerId), isFalse);
      await manager.ensureInitialized(styleEpoch: 2);
      expect(controller.calls.length, greaterThan(firstCallCount));
    });

    test('safe setters are no-ops for unknown layers', () async {
      final controller = _FakeMapLayersController();
      const ids = MapLayersIds(
        markerSourceId: 'kubus_markers',
        markerLayerId: 'kubus_marker_layer',
        markerHitboxLayerId: 'kubus_marker_hitbox_layer',
        markerHitboxImageId: 'kubus_hitbox_square_transparent',
        markerDotLayerId: 'kubus_marker_dot_layer',
        markerPulseLayerId: 'kubus_marker_pulse_layer',
        cubeLayerId: 'kubus_marker_cubes_layer',
        cubeIconLayerId: 'kubus_marker_cubes_icon_layer',
        locationSourceId: 'kubus_user_location',
        locationLayerId: 'kubus_user_location_layer',
      );

      final manager = MapLayersManager(
        controller: controller,
        ids: ids,
        debugTracing: false,
      );

      await manager.safeSetLayerVisibility('missing_layer', true);
      await manager.safeSetLayerProperties(
        'missing_layer',
        ml.CircleLayerProperties(circleRadius: 6),
      );
      await manager.safeSetPaintProperty('missing_layer', 'circle-radius', 6);
      await manager.safeSetLayoutProperty(
        'missing_layer',
        'visibility',
        'none',
      );

      expect(controller.calls, isEmpty);
    });

    test(
      'installs route layers below markers and walking glyph over user dot',
      () async {
        final controller = _FakeMapLayersController();
        const ids = MapLayersIds(
          markerSourceId: 'kubus_markers',
          markerLayerId: 'kubus_marker_layer',
          markerHitboxLayerId: 'kubus_marker_hitbox_layer',
          markerHitboxImageId: 'kubus_hitbox_square_transparent',
          markerDotLayerId: 'kubus_marker_dot_layer',
          markerPulseLayerId: 'kubus_marker_pulse_layer',
          cubeLayerId: 'kubus_marker_cubes_layer',
          cubeIconLayerId: 'kubus_marker_cubes_icon_layer',
          locationSourceId: 'kubus_user_location',
          locationLayerId: 'kubus_user_location_layer',
        );
        final manager = MapLayersManager(
          controller: controller,
          ids: ids,
          debugTracing: false,
        );
        manager.onNewStyle(styleEpoch: 1);
        manager.updateThemeSpec(
          const MapLayersThemeSpec(
            locationFill: Colors.blue,
            locationStroke: Colors.white,
          ),
        );

        await manager.ensureInitialized(styleEpoch: 1);

        expect(manager.hasSource(ids.walkingRouteSourceId), isTrue);
        expect(manager.hasLayer(ids.walkingRouteCasingLayerId), isTrue);
        expect(manager.hasLayer(ids.walkingRouteLayerId), isTrue);
        expect(manager.hasLayer(ids.walkingRouteConnectorLayerId), isTrue);
        expect(manager.hasLayer(ids.walkingLocationSymbolLayerId), isTrue);
        expect(
          controller.calls.indexOf(
            'addLineLayer:${ids.walkingRouteSourceId}:${ids.walkingRouteLayerId}',
          ),
          lessThan(
            controller.calls.indexOf(
              'addSymbolLayer:${ids.markerSourceId}:${ids.markerLayerId}',
            ),
          ),
        );
        expect(
          controller.calls.indexOf(
            'addCircleLayer:${ids.locationSourceId}:${ids.locationLayerId}',
          ),
          lessThan(
            controller.calls.indexOf(
              'addSymbolLayer:${ids.locationSourceId}:${ids.walkingLocationSymbolLayerId}',
            ),
          ),
        );
        expect(controller.lineFilters[ids.walkingRouteLayerId], const <Object>[
          '==',
          <Object>['get', 'kind'],
          'route',
        ]);
        expect(
          controller.lineFilters[ids.walkingRouteConnectorLayerId],
          const <Object>[
            '==',
            <Object>['get', 'kind'],
            'connector',
          ],
        );
      },
    );

    test('retains route data and visibility across style epochs', () async {
      final controller = _FakeMapLayersController();
      const ids = MapLayersIds(
        markerSourceId: 'kubus_markers',
        markerLayerId: 'kubus_marker_layer',
        markerHitboxLayerId: 'kubus_marker_hitbox_layer',
        markerHitboxImageId: 'kubus_hitbox_square_transparent',
        markerDotLayerId: 'kubus_marker_dot_layer',
        markerPulseLayerId: 'kubus_marker_pulse_layer',
        cubeLayerId: 'kubus_marker_cubes_layer',
        cubeIconLayerId: 'kubus_marker_cubes_icon_layer',
        locationSourceId: 'kubus_user_location',
        locationLayerId: 'kubus_user_location_layer',
      );
      final route = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[
          <String, dynamic>{
            'type': 'Feature',
            'properties': <String, dynamic>{'kind': 'route'},
            'geometry': <String, dynamic>{
              'type': 'LineString',
              'coordinates': <dynamic>[
                <double>[14.50, 46.05],
                <double>[14.51, 46.06],
              ],
            },
          },
        ],
      };
      final manager = MapLayersManager(
        controller: controller,
        ids: ids,
        debugTracing: false,
      );
      manager.updateThemeSpec(
        const MapLayersThemeSpec(
          locationFill: Colors.blue,
          locationStroke: Colors.white,
        ),
      );
      await manager.upsertWalkingRouteData(route);
      await manager.setWalkingNavigationVisibility(true);
      manager.onNewStyle(styleEpoch: 1);
      await manager.ensureInitialized(styleEpoch: 1);

      expect(controller.initialSourceData[ids.walkingRouteSourceId], route);
      expect(
        controller.calls,
        contains('setLayerVisibility:${ids.walkingLocationSymbolLayerId}:true'),
      );

      manager.onNewStyle(styleEpoch: 2);
      await manager.ensureInitialized(styleEpoch: 2);

      expect(controller.initialSourceData[ids.walkingRouteSourceId], route);
      final glyphVisibleCalls = controller.calls
          .where(
            (call) =>
                call ==
                'setLayerVisibility:${ids.walkingLocationSymbolLayerId}:true',
          )
          .length;
      expect(glyphVisibleCalls, 2);

      final updatedRoute = Map<String, dynamic>.from(route)
        ..['features'] = <dynamic>[];
      await manager.upsertWalkingRouteData(updatedRoute);
      expect(
        controller.updatedSourceData[ids.walkingRouteSourceId],
        updatedRoute,
      );
    });
  });
}
