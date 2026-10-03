import 'dart:math' as math;

import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

/// Wave 5B: the selected marker is a map invariant, not a UI state. These
/// tests pin the controller side of it (the screens' viewport-refresh side is
/// covered by markersPreservedAcrossViewportRefresh).
void main() {
  late KubusMapController controller;
  late List<KubusMarkerSelectionState> selectionChanges;
  late int styleUpdates;

  ArtMarker marker(
    String id,
    double lat, {
    double lng = 14.5,
    ArtMarkerType type = ArtMarkerType.artwork,
  }) =>
      ArtMarker(
        id: id,
        name: 'Marker $id',
        description: 'd',
        position: LatLng(lat, lng),
        type: type,
        artworkId: 'artwork-$id',
        createdAt: DateTime(2026, 10, 3),
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
        dismissSelectionOnUserGesture: false,
        onSelectionChanged: (state) => selectionChanges.add(state),
        onRequestMarkerLayerStyleUpdate: () => styleUpdates += 1,
      );

  setUp(() {
    selectionChanges = <KubusMarkerSelectionState>[];
    styleUpdates = 0;
    controller = build();
  });

  tearDown(() => controller.dispose());

  test('a marker refresh that still contains the selection keeps it', () {
    controller.setMarkers(<ArtMarker>[marker('a', 46.05), marker('b', 46.06)]);
    controller.selectMarker(marker('a', 46.05));
    expect(controller.selectedMarkerId, 'a');

    // A viewport refresh delivers new instances of the same records.
    controller.setMarkers(<ArtMarker>[
      marker('a', 46.05),
      marker('b', 46.06),
      marker('c', 46.07),
    ]);

    expect(controller.selectedMarkerId, 'a');
    expect(controller.selectedMarkerData?.id, 'a');
  });

  test('a refresh that drops the selected record clears the selection', () {
    controller.setMarkers(<ArtMarker>[marker('a', 46.05), marker('b', 46.06)]);
    controller.selectMarker(marker('a', 46.05));

    controller.setMarkers(<ArtMarker>[marker('b', 46.06)]);

    // The screens carry the selected marker across bounds refreshes, so this
    // only happens when the record really no longer exists.
    expect(controller.selectedMarkerId, isNull);
  });

  test('hiding the selected marker\'s layer does not hide the selection', () {
    controller.setMarkers(<ArtMarker>[
      marker('a', 46.05, type: ArtMarkerType.event),
      marker('b', 46.06),
    ]);
    controller.selectMarker(marker('a', 46.05, type: ArtMarkerType.event));

    controller.setMarkerTypeVisibility(<ArtMarkerType, bool>{
      ArtMarkerType.event: false,
    });

    final rendered =
        controller.buildRenderedMarkers().map((m) => m.marker.id).toList();
    expect(rendered, contains('a'),
        reason: 'the selected marker stays rendered');
    expect(rendered, contains('b'));
    expect(controller.selectedMarkerId, 'a');
  });

  test('a hidden layer still hides every marker that is not selected', () {
    controller.setMarkers(<ArtMarker>[
      marker('a', 46.05, type: ArtMarkerType.event),
      marker('b', 46.06, type: ArtMarkerType.event),
      marker('c', 46.07),
    ]);
    controller.selectMarker(marker('a', 46.05, type: ArtMarkerType.event));
    controller.setMarkerTypeVisibility(<ArtMarkerType, bool>{
      ArtMarkerType.event: false,
    });

    final rendered =
        controller.buildRenderedMarkers().map((m) => m.marker.id).toSet();
    expect(rendered, <String>{'a', 'c'});
  });

  test('once the selection is dismissed its hidden layer hides it again', () {
    controller.setMarkers(<ArtMarker>[
      marker('a', 46.05, type: ArtMarkerType.event),
      marker('c', 46.07),
    ]);
    controller.selectMarker(marker('a', 46.05, type: ArtMarkerType.event));
    controller.setMarkerTypeVisibility(<ArtMarkerType, bool>{
      ArtMarkerType.event: false,
    });
    controller.dismissSelection();

    expect(
      controller.buildRenderedMarkers().map((m) => m.marker.id),
      <String>['c'],
    );
  });

  test('selecting asks for a restyle so the badge opacity pins the selection',
      () {
    controller.setMarkers(<ArtMarker>[marker('a', 46.05)]);
    final before = styleUpdates;

    controller.selectMarker(marker('a', 46.05));

    expect(styleUpdates, greaterThan(before));
    expect(selectionChanges.last.selectedMarkerId, 'a');
  });

  test(
      'same-coordinate records stay a reachable stack with the selection '
      'first', () {
    final a = marker('a', 46.05);
    final b = marker('b', 46.05);
    final c = marker('c', 46.05);
    controller.setMarkers(<ArtMarker>[a, b, c, marker('far', 47)]);

    controller.selectMarker(b);

    final state = controller.selectionState;
    expect(state.stackedMarkers.map((m) => m.id), <String>['b', 'a', 'c']);
    expect(state.selectedMarkerId, 'b');
  });

  test('visibleMarkerIds is empty until a viewport pass has run', () {
    controller.setMarkers(<ArtMarker>[marker('a', 46.05)]);
    expect(controller.visibleMarkerIds, isEmpty);
  });

  test('a programmatic camera move flag is owned by the controller', () {
    expect(controller.programmaticCameraMove, isFalse);
    controller.setProgrammaticCameraMove(true);
    expect(controller.programmaticCameraMove, isTrue);
    controller.setProgrammaticCameraMove(false);
    expect(controller.programmaticCameraMove, isFalse);
  });

  test('a background web tap dismisses the selection (explicit user act)',
      () async {
    controller.setMarkers(<ArtMarker>[marker('a', 46.05)]);
    controller.selectMarker(marker('a', 46.05));

    await controller.handleMapClick(const math.Point<double>(10, 10),
        isWeb: true);

    expect(controller.selectedMarkerId, isNull);
  });

  group('visible bounds on a far-out globe', () {
    ml.LatLngBounds bounds(double s, double w, double n, double e) =>
        ml.LatLngBounds(
          southwest: ml.LatLng(s, w),
          northeast: ml.LatLng(n, e),
        );

    test('a zero-width span means the whole world is in view', () {
      // Measured from the web globe at zoom 0.8 / 1.5.
      expect(
        KubusMapController.isDegenerateVisibleBounds(
          bounds(-34.6, -180.0, 90.0, -180.0),
        ),
        isTrue,
      );
    });

    test('ordinary and dateline-wrapping viewports are not degenerate', () {
      expect(
        KubusMapController.isDegenerateVisibleBounds(
          bounds(45.0, 13.0, 47.0, 16.0),
        ),
        isFalse,
      );
      // Flat world view at zoom 0.8 wraps the dateline (west > east).
      expect(
        KubusMapController.isDegenerateVisibleBounds(
          bounds(-71.1, 172.6, 85.1, -143.6),
        ),
        isFalse,
      );
    });
  });

  test('marking a style reload makes the controller not-initialised', () {
    controller.markStyleReloading();
    expect(controller.styleInitialized, isFalse);
  });
}
