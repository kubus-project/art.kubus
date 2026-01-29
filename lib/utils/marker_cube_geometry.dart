import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import 'maplibre_style_utils.dart';
import '../widgets/art_marker_cube.dart';

class MarkerCubeGeometry {
  MarkerCubeGeometry._();

  static const double _minZoom = 3.0;
  static const double _midZoom = 15.0;
  static const double _maxZoom = 24.0;
  static const double _minScale = 0.5;
  static const double _midScale = 1.0;
  static const double _maxScale = 1.5;
  static const double _metersPerDegreeLat = 111320.0;

  static double markerScaleForZoom(double zoom) {
    if (zoom <= _minZoom) return _minScale;
    if (zoom <= _midZoom) {
      return _lerp(_minScale, _midScale, (zoom - _minZoom) / (_midZoom - _minZoom));
    }
    if (zoom <= _maxZoom) {
      return _lerp(_midScale, _maxScale, (zoom - _midZoom) / (_maxZoom - _midZoom));
    }
    return _maxScale;
  }

  static double markerPixelSize(double zoom) {
    return CubeMarkerTokens.staticSizeAtZoom15 * markerScaleForZoom(zoom);
  }

  static double metersPerPixel(double zoom, double latitude) {
    const double earthRadiusMeters = 6378137.0;
    const double tileSize = 512.0;
    final latRad = latitude * (math.pi / 180.0);
    final scale = math.pow(2.0, zoom).toDouble();
    return (2 * math.pi * earthRadiusMeters * math.cos(latRad)) /
        (tileSize * scale);
  }

  static Map<String, dynamic> cubeFeatureForMarker({
    required ArtMarker marker,
    required String colorHex,
    required double zoom,
  }) {
    final sizePixels = markerPixelSize(zoom);
    final mpp = metersPerPixel(zoom, marker.position.latitude);
    final sizeMeters = sizePixels * mpp;
    final coords = _squarePolygon(marker.position, sizeMeters);

    return <String, dynamic>{
      'type': 'Feature',
      'id': marker.id,
      'properties': <String, dynamic>{
        'id': marker.id,
        'markerId': marker.id,
        'kind': 'cube',
        'height': sizeMeters,
        'color': colorHex,
      },
      'geometry': <String, dynamic>{
        'type': 'Polygon',
        'coordinates': coords,
      },
    };
  }

  static String toHex(Color color) => MapLibreStyleUtils.hexRgb(color);

  static List<List<List<double>>> _squarePolygon(
    LatLng center,
    double sizeMeters,
  ) {
    final half = sizeMeters / 2.0;
    final latRad = center.latitude * (math.pi / 180.0);
    final metersPerDegreeLon = _metersPerDegreeLat * math.cos(latRad).abs().clamp(0.1, 1.0);

    final deltaLat = half / _metersPerDegreeLat;
    final deltaLng = half / metersPerDegreeLon;

    final north = center.latitude + deltaLat;
    final south = center.latitude - deltaLat;
    final east = center.longitude + deltaLng;
    final west = center.longitude - deltaLng;

    return <List<List<double>>>[
      <List<double>>[
        <double>[west, north],
        <double>[east, north],
        <double>[east, south],
        <double>[west, south],
        <double>[west, north],
      ],
    ];
  }

  static double _lerp(double a, double b, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return a + (b - a) * clamped;
  }
}
