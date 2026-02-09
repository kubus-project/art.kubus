import 'dart:math' as math;

import 'package:art_kubus/features/map/shared/map_marker_collision_config.dart';
import 'package:art_kubus/features/map/shared/map_marker_collision_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:art_kubus/models/art_marker.dart';

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

double _distance(Offset a, Offset b) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  group('mapMarkerCoordinateKey', () {
    test('rounds to configured decimals', () {
      final key = mapMarkerCoordinateKey(
        const LatLng(46.0569464, 14.5057514),
      );
      expect(key, equals('46.056946,14.505751'));
    });
  });

  group('groupMarkersByCoordinateKey', () {
    test('groups near-equal coordinates into the same bucket', () {
      final markers = <ArtMarker>[
        _marker('a', const LatLng(46.05694601, 14.50575101)),
        _marker('b', const LatLng(46.05694602, 14.50575102)),
        _marker('c', const LatLng(46.056947, 14.505752)),
      ];

      final grouped = groupMarkersByCoordinateKey(markers);
      expect(grouped.length, 2);
      expect(grouped.values.any((bucket) => bucket.length == 2), isTrue);
      expect(grouped.values.any((bucket) => bucket.length == 1), isTrue);
    });
  });

  group('buildSpiderfyOffsets', () {
    test('is deterministic and preserves count', () {
      final first = buildSpiderfyOffsets(9);
      final second = buildSpiderfyOffsets(9);
      expect(first, equals(second));
      expect(first.length, 9);
    });

    test('keeps minimum separation per layout config', () {
      const config = SpiderfyLayoutConfig(
        baseRadiusPx: 34,
        radiusStepPx: 24,
        minSeparationPx: 24,
      );
      final offsets = buildSpiderfyOffsets(20, config: config);

      var minDistance = double.infinity;
      for (var i = 0; i < offsets.length; i++) {
        for (var j = i + 1; j < offsets.length; j++) {
          minDistance = math.min(minDistance, _distance(offsets[i], offsets[j]));
        }
      }

      expect(
        minDistance,
        greaterThanOrEqualTo(
          MapMarkerCollisionConfig.spiderfyMinSeparationPx - 0.5,
        ),
      );
    });

    test('creates multiple rings for larger sets', () {
      final offsets = buildSpiderfyOffsets(24);
      final radii = offsets
          .map((o) => math.sqrt(o.dx * o.dx + o.dy * o.dy).round())
          .toSet();
      expect(radii.length, greaterThan(1));
    });
  });
}
