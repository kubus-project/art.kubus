import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

class _RecordingLayersController implements MapLayersController {
  final List<Map<String, dynamic>> sourcePayloads = <Map<String, dynamic>>[];
  int sourceWriteAttempts = 0;
  bool failNextSourceWrite = false;
  Completer<void>? sourceWriteGate;

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
  }) async {}

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
  }) async {}

  @override
  Future<void> addImage(String name, Uint8List bytes) async {}

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> data,
  ) async {
    sourceWriteAttempts += 1;
    final gate = sourceWriteGate;
    if (gate != null) await gate.future;
    if (failNextSourceWrite) {
      failNextSourceWrite = false;
      throw StateError('simulated source write failure');
    }
    sourcePayloads.add(data);
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {}

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

const _ids = MapLayersIds(
  markerSourceId: 'kubus_markers',
  markerLayerId: 'kubus_marker_layer',
  markerHitboxLayerId: 'kubus_marker_hitbox_layer',
  markerHitboxImageId: 'kubus_hitbox_square_transparent',
  markerDotLayerId: 'kubus_marker_dot_layer',
  markerPulseLayerId: 'kubus_marker_pulse_layer',
  cubeSourceId: 'kubus_marker_cubes',
  cubeLayerId: 'kubus_marker_cubes_layer',
  cubeIconLayerId: 'kubus_marker_cubes_icon_layer',
  locationSourceId: 'kubus_user_location',
  locationLayerId: 'kubus_user_location_layer',
);

Future<MapLayersManager> _initializedManager(
  _RecordingLayersController controller,
) async {
  final manager = MapLayersManager(
    controller: controller,
    ids: _ids,
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
  return manager;
}

Map<String, dynamic> _markerCollection({
  double entryScale = 1,
  bool spiderfied = false,
  double longitude = 14.505751,
}) {
  return <String, dynamic>{
    'type': 'FeatureCollection',
    'features': <dynamic>[
      <String, dynamic>{
        'type': 'Feature',
        'id': 'marker-a',
        'properties': <String, dynamic>{
          'id': 'marker-a',
          'entryScale': entryScale,
          'spiderfied': spiderfied,
        },
        'geometry': <String, dynamic>{
          'type': 'Point',
          'coordinates': <double>[longitude, 46.056946],
        },
      },
    ],
  };
}

void main() {
  test('identical and concurrent marker payloads write once', () async {
    final controller = _RecordingLayersController();
    final manager = await _initializedManager(controller);
    final payload = _markerCollection();

    final results = await Future.wait(<Future<bool>>[
      manager.upsertMarkerData(payload),
      manager.upsertMarkerData(payload),
    ]);

    expect(results, <bool>[true, false]);
    expect(controller.sourcePayloads, hasLength(1));
    expect(manager.stats.sourceUpdateCalls, 1);
    expect(manager.stats.sourceUpdateSkips, 1);
  });

  test(
    'a slow source write retains only the latest queued marker frame',
    () async {
      final controller = _RecordingLayersController();
      final manager = await _initializedManager(controller);
      final gate = Completer<void>();
      controller.sourceWriteGate = gate;

      final first = manager.upsertMarkerData(
        _markerCollection(entryScale: 0.2),
      );
      await Future<void>.delayed(Duration.zero);
      final stale = manager.upsertMarkerData(
        _markerCollection(entryScale: 0.5),
      );
      final latest = manager.upsertMarkerData(_markerCollection(entryScale: 1));

      controller.sourceWriteGate = null;
      gate.complete();
      expect(await Future.wait(<Future<bool>>[first, stale, latest]), <bool>[
        true,
        false,
        true,
      ]);
      expect(controller.sourcePayloads, hasLength(2));
      expect(
        controller
            .sourcePayloads
            .last['features'][0]['properties']['entryScale'],
        1,
      );
    },
  );

  test('canonical fingerprint ignores map key order', () async {
    final controller = _RecordingLayersController();
    final manager = await _initializedManager(controller);
    final original = _markerCollection();
    final reordered = <String, dynamic>{
      'features': original['features'],
      'type': 'FeatureCollection',
    };

    expect(await manager.upsertMarkerData(original), isTrue);
    expect(await manager.upsertMarkerData(reordered), isFalse);
    expect(controller.sourcePayloads, hasLength(1));
  });

  test('entry and spiderfy state changes each produce one write', () async {
    final controller = _RecordingLayersController();
    final manager = await _initializedManager(controller);

    expect(await manager.upsertMarkerData(_markerCollection()), isTrue);
    expect(
      await manager.upsertMarkerData(_markerCollection(entryScale: 0.8)),
      isTrue,
    );
    expect(
      await manager.upsertMarkerData(
        _markerCollection(spiderfied: true, longitude: 14.506),
      ),
      isTrue,
    );
    expect(controller.sourcePayloads, hasLength(3));
  });

  test('new style lifecycle writes an unchanged payload again', () async {
    final controller = _RecordingLayersController();
    final manager = await _initializedManager(controller);
    final payload = _markerCollection();

    expect(await manager.upsertMarkerData(payload), isTrue);
    expect(await manager.upsertMarkerData(payload), isFalse);
    manager.onNewStyle(styleEpoch: 2);
    await manager.ensureInitialized(styleEpoch: 2);
    expect(await manager.upsertMarkerData(payload), isTrue);
    expect(controller.sourcePayloads, hasLength(2));
  });

  test('failed writes do not suppress an identical retry', () async {
    final controller = _RecordingLayersController();
    final manager = await _initializedManager(controller);
    final payload = _markerCollection();
    controller.failNextSourceWrite = true;

    expect(await manager.upsertMarkerData(payload), isFalse);
    expect(await manager.upsertMarkerData(payload), isTrue);
    expect(controller.sourceWriteAttempts, 2);
    expect(controller.sourcePayloads, hasLength(1));
    expect(manager.stats.sourceUpdateSkips, 0);
  });
}
