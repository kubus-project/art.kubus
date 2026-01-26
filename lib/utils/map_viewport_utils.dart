import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

/// Utilities for viewport-based marker loading on FlutterMap.
///
/// Travel Mode fetches markers using a bounds query. To keep panning smooth,
/// we expand the visible bounds by a padding factor and only refetch when the
/// viewport escapes the previously loaded region (or when zoom crosses
/// density buckets).
class MapViewportUtils {
  /// Groups zoom levels into coarse buckets so we only refresh marker density
  /// at meaningful thresholds.
  ///
  /// Buckets are intentionally sparse to avoid rebuild churn while zooming.
  static int zoomBucket(double zoom) {
    if (zoom.isNaN || zoom.isInfinite) return 0;
    if (zoom < 6) return 5;
    if (zoom < 8) return 7;
    if (zoom < 10) return 9;
    if (zoom < 12) return 11;
    if (zoom < 14) return 13;
    if (zoom < 16) return 15;
    if (zoom < 18) return 17;
    return 19;
  }

  /// How much extra viewport padding to include when querying bounds.
  ///
  /// Higher zoom => smaller geographic area => we can pad more aggressively.
  static double paddingFractionForZoomBucket(int bucket) {
    if (bucket <= 9) return 0.14;
    if (bucket <= 13) return 0.18;
    if (bucket <= 15) return 0.22;
    return 0.26;
  }

  /// Marker fetch limit per zoom bucket.
  ///
  /// Travel Mode can cover large areas quickly; this keeps payload sizes bounded
  /// while still returning enough density for clustering and exploration.
  static int markerLimitForZoomBucket(int bucket) {
    if (bucket <= 7) return 300;
    if (bucket <= 9) return 500;
    if (bucket <= 11) return 800;
    if (bucket <= 13) return 1200;
    if (bucket <= 15) return 1700;
    if (bucket <= 17) return 2200;
    return 2600;
  }

  /// Returns `true` if Travel Mode should refetch based on bounds coverage and
  /// zoom bucket changes.
  static bool shouldRefetchTravelMode({
    required LatLngBounds visibleBounds,
    required LatLngBounds? loadedBounds,
    required int zoomBucket,
    required int? loadedZoomBucket,
    required bool hasMarkers,
  }) {
    if (!hasMarkers) return true;
    if (loadedBounds == null) return true;
    if (loadedZoomBucket == null) return true;
    if (loadedZoomBucket != zoomBucket) return true;
    return !containsBounds(loadedBounds, visibleBounds);
  }

  /// Expand [bounds] by a fraction of its width/height.
  ///
  /// For dateline-crossing bounds, this returns the input bounds unmodified to
  /// stay conservative.
  static LatLngBounds expandBounds(LatLngBounds bounds, double paddingFraction) {
    final clamped = paddingFraction.clamp(0.0, 0.6).toDouble();
    if (clamped <= 0) return bounds;

    final crossesDateline = bounds.west > bounds.east;
    if (crossesDateline) return bounds;

    final latSpan = (bounds.north - bounds.south).abs();
    final lngSpan = (bounds.east - bounds.west).abs();

    final latPad = math.max(0.0001, latSpan * clamped);
    final lngPad = math.max(0.0001, lngSpan * clamped);

    final south = (bounds.south - latPad).clamp(-90.0, 90.0);
    final north = (bounds.north + latPad).clamp(-90.0, 90.0);
    final west = (bounds.west - lngPad).clamp(-180.0, 180.0);
    final east = (bounds.east + lngPad).clamp(-180.0, 180.0);

    return LatLngBounds(
      LatLng(south, west),
      LatLng(north, east),
    );
  }

  /// Returns `true` if [outer] fully contains [inner] (all four corners).
  static bool containsBounds(LatLngBounds outer, LatLngBounds inner) {
    return containsPoint(outer, LatLng(inner.south, inner.west)) &&
        containsPoint(outer, LatLng(inner.south, inner.east)) &&
        containsPoint(outer, LatLng(inner.north, inner.west)) &&
        containsPoint(outer, LatLng(inner.north, inner.east));
  }

  /// Returns `true` if [bounds] contains [point], including dateline crossing.
  static bool containsPoint(LatLngBounds bounds, LatLng point) {
    final south = bounds.south;
    final north = bounds.north;
    final west = bounds.west;
    final east = bounds.east;

    if (point.latitude < south || point.latitude > north) return false;

    // Dateline-crossing support: when west > east, the bounds wrap around.
    if (west <= east) {
      return point.longitude >= west && point.longitude <= east;
    }
    return point.longitude >= west || point.longitude <= east;
  }
}
