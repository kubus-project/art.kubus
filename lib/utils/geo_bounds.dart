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
