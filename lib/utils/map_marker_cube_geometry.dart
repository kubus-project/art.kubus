import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class MapMarkerCubeGeometry {
  MapMarkerCubeGeometry._();

  static const double _earthRadiusMeters = 6378137.0;
  static const double _metersPerDegreeLat = 111320.0;
  static const int _tileSize = 512;

  /// Matches the map marker icon scale expression used in MapLibre layers.
  static double iconScaleForZoom(double zoom) {
    if (zoom.isNaN || zoom.isInfinite) return 1.0;
    if (zoom <= 3) return 0.5;
    if (zoom >= 24) return 1.5;
    if (zoom <= 15) {
      return _lerp(0.5, 1.0, (zoom - 3) / 12);
    }
    return _lerp(1.0, 1.5, (zoom - 15) / 9);
  }

  static double cubeSizePixels({required double zoom, required double baseSizePx}) {
    return baseSizePx * iconScaleForZoom(zoom);
  }

  static double metersPerPixel({required double latitude, required double zoom}) {
    final latRad = latitude * (math.pi / 180.0);
    final scale = math.pow(2, zoom).toDouble();
    final metersPerTile = 2 * math.pi * _earthRadiusMeters * math.cos(latRad);
    final raw = metersPerTile / (_tileSize * scale);
    return raw.isFinite && raw > 0 ? raw : 0.0;
  }

  static double cubeSizeMeters({
    required LatLng center,
    required double zoom,
    required double baseSizePx,
  }) {
    final sizePx = cubeSizePixels(zoom: zoom, baseSizePx: baseSizePx);
    final mpp = metersPerPixel(latitude: center.latitude, zoom: zoom);
    return sizePx * mpp;
  }

  static List<List<double>> squarePolygon({
    required LatLng center,
    required double sizeMeters,
  }) {
    final half = sizeMeters * 0.5;
    final latRad = center.latitude * (math.pi / 180.0);
    final cosLat = math.cos(latRad).abs().clamp(0.00001, 1.0);

    final dLat = half / _metersPerDegreeLat;
    final dLng = half / (_metersPerDegreeLat * cosLat);

    final north = (center.latitude + dLat).clamp(-90.0, 90.0);
    final south = (center.latitude - dLat).clamp(-90.0, 90.0);
    final east = (center.longitude + dLng).clamp(-180.0, 180.0);
    final west = (center.longitude - dLng).clamp(-180.0, 180.0);

    return <List<double>>[
      <double>[west, north],
      <double>[east, north],
      <double>[east, south],
      <double>[west, south],
      <double>[west, north],
    ];
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
