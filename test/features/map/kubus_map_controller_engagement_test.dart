import 'dart:math' as math;

import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/features/map/telemetry/map_engagement_tracker.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// `map_engaged` ownership: the controller owns every *user* marker tap, so the
/// web feature-tap path (whose follow-up `onMapClick` is suppressed) and the
/// native hit-test path feed one bounded tracker, and nothing programmatic does.
void main() {
  late List<String> engaged;
  late MapEngagementTracker tracker;
  late int rawInteractions;
  late KubusMapController controller;

  ArtMarker marker(String id, double lat) => ArtMarker(
        id: id,
        name: 'Marker $id',
        description: 'd',
        position: LatLng(lat, 14.5),
        type: ArtMarkerType.streetArt,
        artworkId: 'artwork-$id',
        createdAt: DateTime(2026, 10, 2),
        createdBy: 'wallet-1',
      );

  KubusMapController build() => KubusMapController(
        ids: const KubusMapControllerIds(
          layers: MapLayersIds(
            markerSourceId: 'markers',
            markerLayerId: 'marker-layer',
            markerHitboxLayerId: 'marker-hitbox',
            markerHitboxImageId: 'marker-hitbox-image',
            markerDotLayerId: 'marker-dot',
            markerPulseLayerId: 'marker-pulse',
            cubeLayerId: 'cube-layer',
            cubeIconLayerId: 'cube-icon-layer',
            locationSourceId: 'location',
            locationLayerId: 'location-layer',
          ),
        ),
        debugTracing: false,
        tapConfig: const KubusMapTapConfig(),
        distance: const Distance(),
        onUserMarkerInteraction: () {
          rawInteractions += 1;
          tracker.markerOpened();
        },
      );

  setUp(() {
    engaged = <String>[];
    rawInteractions = 0;
    tracker = MapEngagementTracker(onEngaged: engaged.add);
    controller = build();
    controller.setMarkers(<ArtMarker>[marker('a', 46.05), marker('b', 46.06)]);
  });

  tearDown(() => controller.dispose());

  const point = math.Point<double>(120, 220);
  const coords = <String, double>{'lat': 46.05, 'lng': 14.5};

  test('a web feature tap on a marker emits map_engaged once', () {
    controller.debugHandleMapFeatureTapped(point, coords, 'a');

    expect(controller.selectedMarkerId, 'a');
    expect(engaged, <String>['marker_open']);
  });

  test('the suppressed map click that follows does not emit a duplicate',
      () async {
    controller.debugHandleMapFeatureTapped(point, coords, 'a');
    expect(rawInteractions, 1);

    // Same gesture: MapLibre delivers onMapClick right after the feature tap
    // and MapTapGating swallows it.
    await controller.handleMapClick(const math.Point<double>(124, 224),
        isWeb: true);

    expect(rawInteractions, 1);
    expect(engaged, <String>['marker_open']);
    expect(controller.selectedMarkerId, 'a',
        reason: 'the suppressed click must not dismiss the opened marker');
  });

  test('a second marker tap in the same session does not emit again', () {
    controller.debugHandleMapFeatureTapped(point, coords, 'a');
    controller.debugHandleMapFeatureTapped(
      point,
      const <String, double>{'lat': 46.06, 'lng': 14.5},
      'b',
    );

    expect(controller.selectedMarkerId, 'b');
    expect(engaged, <String>['marker_open'], reason: 'tracker is once-only');
  });

  test('a cluster tap is a deliberate interaction too', () {
    controller.debugHandleMapFeatureTapped(
      point,
      coords,
      '${const KubusMapTapConfig().clusterIdPrefix}cluster-1',
    );

    expect(engaged, <String>['marker_open']);
  });

  test('programmatic selection never emits', () {
    controller.selectMarker(marker('a', 46.05));

    expect(controller.selectedMarkerId, 'a');
    expect(rawInteractions, 0);
    expect(engaged, isEmpty);
  });

  test('an unusable feature tap is not an interaction', () {
    controller.debugHandleMapFeatureTapped(null, coords, 'a');
    controller.debugHandleMapFeatureTapped(point, null, 'a');
    controller.debugHandleMapFeatureTapped(point, coords, '');

    expect(rawInteractions, 0);
  });

  test('a web background click is not a marker interaction', () async {
    await controller.handleMapClick(point, isWeb: true);

    expect(rawInteractions, 0);
    expect(engaged, isEmpty);
  });
}
