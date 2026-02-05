import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:art_kubus/features/map/map_layers_manager.dart';

class _FakeMapLayersController implements MapLayersController {
  final List<String> calls = <String>[];

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
  Future<void> addImage(String name, Uint8List bytes) async {
    _record('addImage:$name:${bytes.length}');
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> data) async {
    _record('setGeoJsonSource:$sourceId');
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    _record('setLayerVisibility:$layerId:$visible');
  }

  @override
  Future<void> setLayerProperties(String layerId, ml.LayerProperties properties) async {
    _record('setLayerProperties:$layerId');
  }

  @override
  Future<void> setPaintProperty(String layerId, String name, Object value) async {
    _record('setPaintProperty:$layerId:$name');
  }

  @override
  Future<void> setLayoutProperty(String layerId, String name, Object value) async {
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
        cubeSourceId: 'kubus_marker_cubes',
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
        cubeSourceId: 'kubus_marker_cubes',
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
      await manager.safeSetLayoutProperty('missing_layer', 'visibility', 'none');

      expect(controller.calls, isEmpty);
    });
  });
}
