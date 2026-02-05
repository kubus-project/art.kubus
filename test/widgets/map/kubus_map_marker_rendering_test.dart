import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_rendering.dart';

ArtMarker _marker(String id, LatLng pos) {
  return ArtMarker(
    id: id,
    name: 'm$id',
    description: '',
    position: pos,
    type: ArtMarkerType.artwork,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
  );
}

void main() {
  test('kubusClusterMarkersByGridLevel groups markers and computes centroid', () {
    final a = _marker('a', const LatLng(52.0, 13.0));
    final b = _marker('b', const LatLng(52.0, 13.0));
    final c = _marker('c', const LatLng(48.0, 2.0));

    final buckets = kubusClusterMarkersByGridLevel([a, b, c], 20);

    expect(buckets.length, 2);

    final two = buckets.firstWhere((b) => b.markers.length == 2);
    expect(two.centroid.latitude, 52.0);
    expect(two.centroid.longitude, 13.0);

    final one = buckets.firstWhere((b) => b.markers.length == 1);
    expect(one.markers.single.id, 'c');
  });

  test('kubusClusterMarkersByGridLevel can sort largest clusters first', () {
    final a = _marker('a', const LatLng(52.0, 13.0));
    final b = _marker('b', const LatLng(52.0, 13.0));
    final c = _marker('c', const LatLng(52.0, 13.0));
    final d = _marker('d', const LatLng(48.0, 2.0));

    final buckets = kubusClusterMarkersByGridLevel(
      [a, b, c, d],
      20,
      sortBySizeDesc: true,
    );

    expect(buckets.first.markers.length, 3);
    expect(buckets.last.markers.length, 1);
  });
}
