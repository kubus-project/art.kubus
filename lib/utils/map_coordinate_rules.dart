import 'package:latlong2/latlong.dart';

/// The one rule for whether a coordinate can be shown on a map or sent to a
/// navigation provider: finite, in range, and not the (0, 0) "no coordinate"
/// default that unlocated records are stored with.
///
/// Artwork, marker and destination surfaces all defer to this function, so
/// they cannot disagree about whether a place has a location.
bool isValidMapCoordinate(LatLng position) {
  final latitude = position.latitude;
  final longitude = position.longitude;
  if (!latitude.isFinite || !longitude.isFinite) return false;
  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;
  return !(latitude.abs() < 0.0001 && longitude.abs() < 0.0001);
}

/// The one serialization of a coordinate component for display text and for
/// URIs. Fixed precision keeps values out of exponent notation (a `double`
/// such as 1e-7 would otherwise print as `1e-7`).
String formatMapCoordinate(double value) => value.toStringAsFixed(6);
