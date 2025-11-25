import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class GridUtils {
  static const double tileSize = 256.0;

  /// Snaps a LatLng to the center of the nearest isometric grid cell at the given grid level.
  /// The grid is defined such that at integer zoom level L, the grid lines are spaced by 256 pixels.
  static LatLng snapToGrid(LatLng position, double gridLevel) {
    const Crs crs = Epsg3857();
    
    // Project to world pixel coordinates at the given grid level
    // At zoom = gridLevel, the grid spacing is exactly 256 pixels.
    final math.Point<double> point = crs.latLngToPoint(position, gridLevel);
    
    const double spacing = tileSize;

    // Isometric coordinates
    // u = x + y
    // v = x - y
    double u = point.x + point.y;
    double v = point.x - point.y;

    // Snap to nearest diamond center
    // Grid lines are at k * spacing.
    // Diamond centers are at (k + 0.5) * spacing.
    double snapU = (u / spacing).floorToDouble() * spacing + (spacing / 2);
    double snapV = (v / spacing).floorToDouble() * spacing + (spacing / 2);

    // Convert back to x, y
    // x = (u + v) / 2
    // y = (u - v) / 2
    double x = (snapU + snapV) / 2;
    double y = (snapU - snapV) / 2;

    return crs.pointToLatLng(math.Point(x, y), gridLevel);
  }
}
