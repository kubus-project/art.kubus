import 'package:art_kubus/utils/map_viewport_utils.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('MapViewportUtils.zoomBucket', () {
    test('buckets at expected thresholds', () {
      expect(MapViewportUtils.zoomBucket(0), 5);
      expect(MapViewportUtils.zoomBucket(5.9), 5);
      expect(MapViewportUtils.zoomBucket(6.0), 7);
      expect(MapViewportUtils.zoomBucket(7.99), 7);
      expect(MapViewportUtils.zoomBucket(8.0), 9);
      expect(MapViewportUtils.zoomBucket(9.99), 9);
      expect(MapViewportUtils.zoomBucket(10.0), 11);
      expect(MapViewportUtils.zoomBucket(11.99), 11);
      expect(MapViewportUtils.zoomBucket(12.0), 13);
      expect(MapViewportUtils.zoomBucket(13.99), 13);
      expect(MapViewportUtils.zoomBucket(14.0), 15);
      expect(MapViewportUtils.zoomBucket(15.99), 15);
      expect(MapViewportUtils.zoomBucket(16.0), 17);
      expect(MapViewportUtils.zoomBucket(17.99), 17);
      expect(MapViewportUtils.zoomBucket(18.0), 19);
    });
  });

  group('MapViewportUtils.expandBounds', () {
    test('expands non-dateline bounds by fraction', () {
      final bounds = LatLngBounds(
        const LatLng(0, 0),
        const LatLng(1, 1),
      );

      final expanded = MapViewportUtils.expandBounds(bounds, 0.2);
      expect(expanded.south, closeTo(-0.2, 1e-9));
      expect(expanded.north, closeTo(1.2, 1e-9));
      expect(expanded.west, closeTo(-0.2, 1e-9));
      expect(expanded.east, closeTo(1.2, 1e-9));
    });

    test('does not expand dateline-crossing bounds', () {
      final bounds = LatLngBounds(
        const LatLng(-10, 170),
        const LatLng(10, -170),
      );

      final expanded = MapViewportUtils.expandBounds(bounds, 0.2);
      expect(expanded.south, bounds.south);
      expect(expanded.north, bounds.north);
      expect(expanded.west, bounds.west);
      expect(expanded.east, bounds.east);
    });
  });

  group('MapViewportUtils.containsPoint', () {
    test('supports dateline crossing', () {
      final bounds = LatLngBounds(
        const LatLng(-10, 170),
        const LatLng(10, -170),
      );

      expect(MapViewportUtils.containsPoint(bounds, const LatLng(0, 175)), isTrue);
      expect(MapViewportUtils.containsPoint(bounds, const LatLng(0, -175)), isTrue);
      expect(MapViewportUtils.containsPoint(bounds, const LatLng(0, 0)), isFalse);
      expect(MapViewportUtils.containsPoint(bounds, const LatLng(20, 175)), isFalse);
    });
  });

  group('MapViewportUtils.shouldRefetchTravelMode', () {
    test('refetches when missing state', () {
      final visible = LatLngBounds(const LatLng(0, 0), const LatLng(1, 1));
      expect(
        MapViewportUtils.shouldRefetchTravelMode(
          visibleBounds: visible,
          loadedBounds: null,
          zoomBucket: 13,
          loadedZoomBucket: 13,
          hasMarkers: true,
        ),
        isTrue,
      );
      expect(
        MapViewportUtils.shouldRefetchTravelMode(
          visibleBounds: visible,
          loadedBounds: visible,
          zoomBucket: 13,
          loadedZoomBucket: null,
          hasMarkers: true,
        ),
        isTrue,
      );
      expect(
        MapViewportUtils.shouldRefetchTravelMode(
          visibleBounds: visible,
          loadedBounds: visible,
          zoomBucket: 13,
          loadedZoomBucket: 13,
          hasMarkers: false,
        ),
        isTrue,
      );
    });

    test('refetches on zoom bucket change', () {
      final visible = LatLngBounds(const LatLng(0, 0), const LatLng(1, 1));
      expect(
        MapViewportUtils.shouldRefetchTravelMode(
          visibleBounds: visible,
          loadedBounds: visible,
          zoomBucket: 15,
          loadedZoomBucket: 13,
          hasMarkers: true,
        ),
        isTrue,
      );
    });

    test('refetches when viewport escapes loaded bounds', () {
      final loaded = LatLngBounds(const LatLng(0, 0), const LatLng(1, 1));
      final visible = LatLngBounds(const LatLng(2, 2), const LatLng(3, 3));
      expect(
        MapViewportUtils.shouldRefetchTravelMode(
          visibleBounds: visible,
          loadedBounds: loaded,
          zoomBucket: 13,
          loadedZoomBucket: 13,
          hasMarkers: true,
        ),
        isTrue,
      );
    });

    test('does not refetch when viewport is contained in loaded bounds', () {
      final visible = LatLngBounds(const LatLng(0, 0), const LatLng(1, 1));
      final loaded = MapViewportUtils.expandBounds(visible, 0.2);
      expect(
        MapViewportUtils.shouldRefetchTravelMode(
          visibleBounds: visible,
          loadedBounds: loaded,
          zoomBucket: 13,
          loadedZoomBucket: 13,
          hasMarkers: true,
        ),
        isFalse,
      );
    });
  });

  group('MapViewportUtils.markerLimitForZoomBucket', () {
    test('is monotonic for standard buckets', () {
      final buckets = <int>[5, 7, 9, 11, 13, 15, 17, 19];
      final limits = buckets.map(MapViewportUtils.markerLimitForZoomBucket).toList();

      expect(limits, everyElement(greaterThan(0)));
      for (var i = 1; i < limits.length; i++) {
        expect(limits[i], greaterThanOrEqualTo(limits[i - 1]));
      }
    });
  });
}
