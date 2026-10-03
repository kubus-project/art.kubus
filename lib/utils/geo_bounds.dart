import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A lightweight geographic bounds representation used across the app.
///
/// This intentionally avoids tying the core marker fetching / viewport logic to
/// a specific map renderer (e.g. MapLibre).
@immutable
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// Constructs bounds from SW/NE corners.
  ///
  /// Note: For dateline-crossing bounds, west may be > east.
  factory GeoBounds.fromCorners(LatLng southWest, LatLng northEast) {
    final south = southWest.latitude;
    final west = southWest.longitude;
    final north = northEast.latitude;
    final east = northEast.longitude;
    return GeoBounds(
      south: south,
      west: west,
      north: north,
      east: east,
    );
  }

  /// Everything MapLibre can show, with the Web Mercator latitude limit.
  static const GeoBounds world = GeoBounds(
    south: -85.0,
    west: -180.0,
    north: 85.0,
    east: 180.0,
  );

  /// Constructs bounds from the corners of MapLibre's visible region.
  ///
  /// A globe zoomed far out has no rectangular viewport: MapLibre reports a
  /// zero-width (`west == east`) or zero-height span, or non-finite numbers.
  /// That means the whole world is in view, so it is returned as [world]
  /// instead of a sliver that a bounds query would turn into "no markers".
  /// A dateline crossing (`west > east`) is a real rectangle and is kept.
  factory GeoBounds.fromVisibleCorners(LatLng southWest, LatLng northEast) {
    final south = southWest.latitude;
    final west = southWest.longitude;
    final north = northEast.latitude;
    final east = northEast.longitude;
    final degenerate = !south.isFinite ||
        !west.isFinite ||
        !north.isFinite ||
        !east.isFinite ||
        (west - east).abs() < 1e-6 ||
        (north - south).abs() < 1e-6;
    return degenerate ? world : GeoBounds.fromCorners(southWest, northEast);
  }

  final double south;
  final double west;
  final double north;
  final double east;

  bool get crossesDateline => west > east;

  LatLng get southWest => LatLng(south, west);
  LatLng get northEast => LatLng(north, east);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is GeoBounds &&
            other.south == south &&
            other.west == west &&
            other.north == north &&
            other.east == east);
  }

  @override
  int get hashCode => Object.hash(south, west, north, east);

  @override
  String toString() => 'GeoBounds(s=$south, w=$west, n=$north, e=$east)';
}
