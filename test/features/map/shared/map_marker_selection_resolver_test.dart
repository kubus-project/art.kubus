import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/nearby/nearby_art_controller.dart';
import 'package:art_kubus/features/map/shared/map_marker_selection_resolver.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker({
  required String id,
  String? artworkId,
  required double lat,
  required double lng,
  String name = 'Marker',
}) {
  return ArtMarker(
    id: id,
    name: name,
    description: '',
    position: LatLng(lat, lng),
    artworkId: artworkId,
    type: ArtMarkerType.artwork,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
  );
}

Artwork _artwork({
  String? arMarkerId,
  double lat = 46.0569,
  double lng = 14.5058,
}) {
  return Artwork(
    id: 'art-1',
    title: 'Main Artwork',
    artist: 'Artist',
    description: 'Description',
    position: LatLng(lat, lng),
    rewards: 0,
    createdAt: DateTime(2024, 1, 1),
    category: 'Painting',
    arMarkerId: arMarkerId,
  );
}

class _FakeNearbyMapDelegate implements NearbyArtMapDelegate {
  @override
  KubusMapCameraState get camera => const KubusMapCameraState(
        center: LatLng(46.0569, 14.5058),
        zoom: 14,
        bearing: 0,
        pitch: 0,
      );

  @override
  Future<void> animateTo(
    LatLng target, {
    double? zoom,
    double? rotation,
    double? tilt,
    Duration duration = const Duration(milliseconds: 360),
    double? compositionYOffsetPx,
  }) async {}

  @override
  void selectMarker(
    ArtMarker marker, {
    List<ArtMarker>? stackedMarkers,
    int? stackIndex,
  }) {}
}

void main() {
  group('resolveBestMarkerCandidate', () {
    test('prefers exact marker id over nearer artwork-linked markers', () {
      final resolved = resolveBestMarkerCandidate(
        <ArtMarker>[
          _marker(
            id: 'marker-near',
            artworkId: 'art-1',
            lat: 46.0569,
            lng: 14.5058,
            name: 'Near Marker',
          ),
          _marker(
            id: 'marker-selected',
            artworkId: 'art-1',
            lat: 46.0700,
            lng: 14.5200,
            name: 'Far Marker',
          ),
        ],
        exactMarkerId: 'marker-selected',
        artworkId: 'art-1',
        preferredPosition: const LatLng(46.0569, 14.5058),
      );

      expect(resolved?.id, 'marker-selected');
    });

    test('chooses the nearest artwork-linked marker for multi-spatial artwork',
        () {
      final resolved = resolveBestMarkerCandidate(
        <ArtMarker>[
          _marker(
            id: 'marker-far',
            artworkId: 'art-1',
            lat: 46.0800,
            lng: 14.5400,
          ),
          _marker(
            id: 'marker-near',
            artworkId: 'art-1',
            lat: 46.0568,
            lng: 14.5057,
          ),
        ],
        artworkId: 'art-1',
        preferredPosition: const LatLng(46.0569, 14.5058),
      );

      expect(resolved?.id, 'marker-near');
    });

    test('prefers exact label match when multiple candidates share artwork id',
        () {
      final resolved = resolveBestMarkerCandidate(
        <ArtMarker>[
          _marker(
            id: 'marker-a',
            artworkId: 'art-1',
            lat: 46.0569,
            lng: 14.5058,
            name: 'North Gate',
          ),
          _marker(
            id: 'marker-b',
            artworkId: 'art-1',
            lat: 46.0600,
            lng: 14.5100,
            name: 'South Gate',
          ),
        ],
        artworkId: 'art-1',
        preferredLabel: 'South Gate',
      );

      expect(resolved?.id, 'marker-b');
    });
  });

  group('NearbyArtController.findMarkerForArtwork', () {
    final controller = NearbyArtController(map: _FakeNearbyMapDelegate());

    test('honors explicit arMarkerId before proximity ranking', () {
      final resolved = controller.findMarkerForArtwork(
        _artwork(arMarkerId: 'marker-b'),
        <ArtMarker>[
          _marker(
            id: 'marker-a',
            artworkId: 'art-1',
            lat: 46.0569,
            lng: 14.5058,
          ),
          _marker(
            id: 'marker-b',
            artworkId: 'art-1',
            lat: 46.0900,
            lng: 14.5500,
          ),
        ],
      );

      expect(resolved?.id, 'marker-b');
    });

    test('chooses the nearest linked marker when artwork has multiple markers',
        () {
      final resolved = controller.findMarkerForArtwork(
        _artwork(),
        <ArtMarker>[
          _marker(
            id: 'marker-far',
            artworkId: 'art-1',
            lat: 46.0900,
            lng: 14.5500,
          ),
          _marker(
            id: 'marker-near',
            artworkId: 'art-1',
            lat: 46.05691,
            lng: 14.50581,
          ),
        ],
      );

      expect(resolved?.id, 'marker-near');
    });
  });
}
