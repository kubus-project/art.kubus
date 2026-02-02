import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import 'maplibre_style_utils.dart';
import '../widgets/map_marker_style_config.dart';

class MarkerCubeGeometry {
  MarkerCubeGeometry._();

  static const double _metersPerDegreeLat = 111320.0;

  static double markerScaleForZoom(double zoom) {
    return MapMarkerStyleConfig.scaleForZoom(zoom);
  }

  static double markerPixelSize(double zoom) {
    return MapMarkerStyleConfig.markerBodySizeAtZoom15 * markerScaleForZoom(zoom);
  }

  static double metersPerPixel(double zoom, double latitude) {
    const double earthRadiusMeters = 6378137.0;
    const double tileSize = 512.0;
    final latRad = latitude * (math.pi / 180.0);
    final scale = math.pow(2.0, zoom).toDouble();
    return (2 * math.pi * earthRadiusMeters * math.cos(latRad)) /
        (tileSize * scale);
  }

  static double cubeBaseSizeMeters({
    required double zoom,
    required double latitude,
  }) {
    final sizePixels = markerPixelSize(zoom);
    final mpp = metersPerPixel(zoom, latitude);
    return sizePixels * mpp;
  }

  static Map<String, dynamic> cubeFeatureForMarker({
    required ArtMarker marker,
    required String colorHex,
    required double zoom,
  }) {
    final sizeMeters = cubeBaseSizeMeters(
      zoom: zoom,
      latitude: marker.position.latitude,
    );
    return cubeFeatureForMarkerWithMeters(
      marker: marker,
      colorHex: colorHex,
      sizeMeters: sizeMeters,
      heightMeters: sizeMeters,
      kind: 'cube',
    );
  }

  static Map<String, dynamic> cubeFeatureForMarkerWithMeters({
    required ArtMarker marker,
    required String colorHex,
    required double sizeMeters,
    required double heightMeters,
    required String kind,
  }) {
    final coords = _squarePolygon(marker.position, sizeMeters);

    return <String, dynamic>{
      'type': 'Feature',
      'id': marker.id,
      'properties': <String, dynamic>{
        'id': marker.id,
        'markerId': marker.id,
        'kind': kind,
        'height': heightMeters,
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

}
