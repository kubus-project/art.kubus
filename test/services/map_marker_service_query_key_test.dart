import 'package:art_kubus/services/map_marker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:art_kubus/utils/geo_bounds.dart';

void main() {
  group('MapMarkerService.buildBoundsQueryKey', () {
    test('includes zoom bucket, limit, filters, and quantized coords', () {
      final bounds = GeoBounds.fromCorners(
        const LatLng(12.123456, 34.123456),
        const LatLng(12.987654, 34.987654),
      );

      final key11 = MapMarkerService.buildBoundsQueryKey(
        bounds: bounds,
        limit: 500,
        zoomBucket: 11,
      );

      expect(key11, contains('b|'));
      expect(key11, contains('zb=11'));
      expect(key11, contains('lim=500'));
      expect(key11, contains('f=-'));
      expect(key11, contains('s=12.12'));
      expect(key11, contains('n=12.99'));
      expect(key11, contains('w=34.12'));
      expect(key11, contains('e=34.99'));

      final key13 = MapMarkerService.buildBoundsQueryKey(
        bounds: bounds,
        limit: 500,
        zoomBucket: 13,
        filtersKey: 'layer=art',
      );
      expect(key13, contains('zb=13'));
      expect(key13, contains('f=layer=art'));
      expect(key13, contains('s=12.123'));
      expect(key13, contains('n=12.988'));
      expect(key13, contains('w=34.123'));
      expect(key13, contains('e=34.988'));
    });

    test('marks dateline-crossing bounds', () {
      final bounds = GeoBounds.fromCorners(
        const LatLng(-10, 170),
        const LatLng(10, -170),
      );

      final key = MapMarkerService.buildBoundsQueryKey(
        bounds: bounds,
        limit: 100,
        zoomBucket: 13,
      );
      expect(key, contains('xdl=1'));
    });
  });

  group('MapMarkerService.buildRadiusQueryKey', () {
    test('quantizes coords based on zoom bucket', () {
      final center = const LatLng(12.123456, 34.123456);

      final key9 = MapMarkerService.buildRadiusQueryKey(
        center: center,
        radiusKm: 5.0,
        limit: 100,
        zoomBucket: 9,
      );
      expect(key9, contains('zb=9'));
      expect(key9, contains('lat=12.1'));
      expect(key9, contains('lng=34.1'));
      expect(key9, contains('rad=5.00'));

      final key15 = MapMarkerService.buildRadiusQueryKey(
        center: center,
        radiusKm: 5.0,
        limit: 100,
        zoomBucket: 15,
      );
      expect(key15, contains('zb=15'));
      expect(key15, contains('lat=12.123'));
      expect(key15, contains('lng=34.123'));
    });

    test('includes filters key to avoid stale cache collisions', () {
      final center = const LatLng(46.056946, 14.505751);

      final keyA = MapMarkerService.buildRadiusQueryKey(
        center: center,
        radiusKm: 5.0,
        limit: 100,
        zoomBucket: 13,
        filtersKey: 'filter=nearby|query=city',
      );
      final keyB = MapMarkerService.buildRadiusQueryKey(
        center: center,
        radiusKm: 5.0,
        limit: 100,
        zoomBucket: 13,
        filtersKey: 'filter=all|query=city',
      );

      expect(keyA, contains('f=filter=nearby|query=city'));
      expect(keyB, contains('f=filter=all|query=city'));
      expect(keyA, isNot(equals(keyB)));
    });
  });
}
