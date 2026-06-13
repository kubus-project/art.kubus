import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_rendering.dart';

ArtMarker _marker(
  String id,
  LatLng pos, {
  ArtMarkerType type = ArtMarkerType.artwork,
}) {
  return ArtMarker(
    id: id,
    name: 'm$id',
    description: '',
    position: pos,
    type: type,
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

  test('kubusClusterCategoryBreakdown orders categories dominant-first', () {
    final markers = <ArtMarker>[
      _marker('a1', const LatLng(52.0, 13.0), type: ArtMarkerType.artwork),
      _marker('a2', const LatLng(52.0, 13.0), type: ArtMarkerType.artwork),
      _marker('s1', const LatLng(52.0, 13.0), type: ArtMarkerType.streetArt),
      _marker('s2', const LatLng(52.0, 13.0), type: ArtMarkerType.streetArt),
      _marker('s3', const LatLng(52.0, 13.0), type: ArtMarkerType.streetArt),
      _marker('e1', const LatLng(52.0, 13.0), type: ArtMarkerType.event),
    ];

    final breakdown = kubusClusterCategoryBreakdown(markers);

    expect(breakdown.length, 3);
    // Dominant first: streetArt (3), artwork (2), event (1).
    expect(breakdown[0].type, ArtMarkerType.streetArt);
    expect(breakdown[0].count, 3);
    expect(breakdown[1].type, ArtMarkerType.artwork);
    expect(breakdown[1].count, 2);
    expect(breakdown[2].type, ArtMarkerType.event);
    expect(breakdown[2].count, 1);
  });

  test('kubusClusterCategorySignature is stable and composition-aware', () {
    final mixed = <ArtMarker>[
      _marker('a', const LatLng(1, 1), type: ArtMarkerType.artwork),
      _marker('b', const LatLng(1, 1), type: ArtMarkerType.event),
    ];
    final single = <ArtMarker>[
      _marker('c', const LatLng(1, 1), type: ArtMarkerType.artwork),
      _marker('d', const LatLng(1, 1), type: ArtMarkerType.artwork),
    ];

    final mixedSig =
        kubusClusterCategorySignature(kubusClusterCategoryBreakdown(mixed));
    final singleSig =
        kubusClusterCategorySignature(kubusClusterCategoryBreakdown(single));

    expect(mixedSig, isNot(equals(singleSig)));
    expect(singleSig, 'artwork');
    expect(mixedSig.split('-').length, 2);
  });

  test('kubusClusterCategorySignature caps at the max badge categories', () {
    final types = ArtMarkerType.values;
    final markers = <ArtMarker>[
      for (var i = 0; i < types.length; i++)
        _marker('m$i', const LatLng(1, 1), type: types[i]),
    ];

    final signature =
        kubusClusterCategorySignature(kubusClusterCategoryBreakdown(markers));

    expect(signature.split('-').length, kKubusClusterMaxBadgeCategories);
  });
}
