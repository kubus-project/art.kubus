import 'package:art_kubus/utils/geo_bounds.dart';
import 'package:art_kubus/utils/map_viewport_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GeoBounds.fromVisibleCorners', () {
    test('keeps an ordinary visible region as it is', () {
      final bounds = GeoBounds.fromVisibleCorners(
        const LatLng(45.9, 14.3),
        const LatLng(46.2, 14.8),
      );
      expect(bounds.south, 45.9);
      expect(bounds.west, 14.3);
      expect(bounds.north, 46.2);
      expect(bounds.east, 14.8);
    });

    test('a globe zoomed far out (west == east) is the whole world', () {
      final bounds = GeoBounds.fromVisibleCorners(
        const LatLng(-60, -180),
        const LatLng(60, -180),
      );
      expect(bounds, GeoBounds.world);
    });

    test('a zero-height span is the whole world', () {
      final bounds = GeoBounds.fromVisibleCorners(
        const LatLng(10, -50),
        const LatLng(10, 50),
      );
      expect(bounds, GeoBounds.world);
    });

    test('non-finite corners are the whole world', () {
      expect(
        GeoBounds.fromVisibleCorners(
          const LatLng(double.nan, 0),
          const LatLng(10, 10),
        ),
        GeoBounds.world,
      );
    });

    test('a dateline crossing is a real rectangle and is kept', () {
      final bounds = GeoBounds.fromVisibleCorners(
        const LatLng(-10, 170),
        const LatLng(10, -170),
      );
      expect(bounds.crossesDateline, isTrue);
      expect(bounds.west, 170);
      expect(bounds.east, -170);
    });

    test('the world still holds markers after the viewport padding', () {
      // The fetch path pads the visible bounds; the world must stay the world
      // (not a padded sliver), so a zoom-out never narrows the marker query.
      final padded = MapViewportUtils.expandBounds(GeoBounds.world, 0.14);
      expect(MapViewportUtils.containsBounds(padded, GeoBounds.world), isTrue);
      expect(
        MapViewportUtils.containsPoint(padded, const LatLng(46.05, 14.5)),
        isTrue,
      );
    });
  });
}
