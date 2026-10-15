import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// A nearby row can ask for its marker before the marker is loaded. The card
/// opens when a marker list that holds it arrives, or the wait expires.
void main() {
  late KubusMapController controller;

  ArtMarker marker(String id) => ArtMarker(
        id: id,
        name: 'Marker $id',
        description: 'd',
        position: const LatLng(46.05, 14.5),
        type: ArtMarkerType.streetArt,
        artworkId: 'artwork-$id',
        createdAt: DateTime(2026, 10, 2),
        createdBy: 'wallet-1',
      );

  ArtMarker? byId(List<ArtMarker> markers, String id) {
    for (final m in markers) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    controller = KubusMapController(
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
    );
  });

  test('a loaded marker is selected at once', () {
    controller.setMarkers([marker('a')]);
    controller.selectMarkerWhenLoaded((m) => byId(m, 'a'));
    expect(controller.selectedMarkerId, 'a');
  });

  test('an unloaded marker is selected when a list holding it arrives',
      () async {
    controller.selectMarkerWhenLoaded((m) => byId(m, 'a'));
    expect(controller.selectedMarkerId, isNull);

    controller.setMarkers([marker('b')]);
    await settle();
    expect(controller.selectedMarkerId, isNull);

    controller.setMarkers([marker('b'), marker('a')]);
    await settle();
    expect(controller.selectedMarkerId, 'a');
  });

  test('an expired wait selects nothing', () async {
    controller.selectMarkerWhenLoaded(
      (m) => byId(m, 'a'),
      timeout: Duration.zero,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));

    controller.setMarkers([marker('a')]);
    await settle();
    expect(controller.selectedMarkerId, isNull);
  });

  test('a newer request replaces the waiting one', () async {
    controller.selectMarkerWhenLoaded((m) => byId(m, 'a'));
    controller.selectMarkerWhenLoaded((m) => byId(m, 'b'));

    controller.setMarkers([marker('a'), marker('b')]);
    await settle();
    expect(controller.selectedMarkerId, 'b');
  });
}
