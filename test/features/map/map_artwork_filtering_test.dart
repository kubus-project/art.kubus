import 'package:art_kubus/features/map/shared/map_artwork_filtering.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  Artwork artwork({
    required String id,
    required double lat,
    required double lng,
  }) {
    return Artwork(
      id: id,
      title: 'Artwork $id',
      artist: 'Artist $id',
      description: 'Description $id',
      position: LatLng(lat, lng),
      rewards: 0,
      createdAt: DateTime(2025, 1, 1),
    );
  }

  test('nearby filter returns empty when base position is missing', () {
    final items = <Artwork>[
      artwork(id: 'a1', lat: 46.0569, lng: 14.5058),
      artwork(id: 'a2', lat: 46.0610, lng: 14.5100),
    ];

    final filtered = MapArtworkFiltering.filter(
      artworks: items,
      markers: const <ArtMarker>[],
      markerLayerVisibility: const <ArtMarkerType, bool>{},
      query: '',
      filterKey: 'nearby',
      basePosition: null,
      radiusKm: 2.0,
      strictNearbyWithoutBase: true,
    );

    expect(filtered, isEmpty);
  });

  test('nearby filter honors radius when base position is provided', () {
    final items = <Artwork>[
      artwork(id: 'a1', lat: 46.0569, lng: 14.5058),
      artwork(id: 'a2', lat: 46.1569, lng: 14.6058),
    ];

    final filtered = MapArtworkFiltering.filter(
      artworks: items,
      markers: const <ArtMarker>[],
      markerLayerVisibility: const <ArtMarkerType, bool>{},
      query: '',
      filterKey: 'nearby',
      basePosition: const LatLng(46.0569, 14.5058),
      radiusKm: 1.0,
      strictNearbyWithoutBase: true,
    );

    expect(filtered.map((a) => a.id), <String>['a1']);
  });
}
