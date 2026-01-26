import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Utilities for working with the isometric grid used to align map overlays and
/// AR attachments. Grid spacing is defined in WebMercator pixels where one tile
/// is 256px.
class GridUtils {
  static const double tileSize = 256.0;
  static const double _targetScreenSpacing = 96.0;
  static const double _minScreenSpacing = 24.0;
  static const double _maxScreenSpacing = 420.0;
  static const int _maxGridLevel = 22;

  /// Snap a LatLng to the center of the nearest grid cell using the grid level
  /// resolved for the current camera zoom.
  static LatLng snapToVisibleGrid(LatLng position, double cameraZoom) {
    return gridCellForZoom(position, cameraZoom).center;
  }

  /// Snap to a specific grid level (maintains backward compatibility for code
  /// that expects an explicit level).
  static LatLng snapToGrid(LatLng position, double gridLevel) {
    return gridCellForLevel(position, gridLevel.round()).center;
  }

  /// Returns the grid cell aligned to the visible grid for a given camera zoom.
  static GridCell gridCellForZoom(LatLng position, double cameraZoom) {
    final int gridLevel = resolvePrimaryGridLevel(cameraZoom);
    return gridCellForLevel(position, gridLevel);
  }

  /// Returns the grid cell for a specific grid level (integer zoom).
  static GridCell gridCellForLevel(LatLng position, int gridLevel) {
    final math.Point<double> point = _latLngToWorldPixel(position, gridLevel);

    const double spacing = tileSize;
    final double u = point.x + point.y;
    final double v = point.x - point.y;

    final int uIndex = (u / spacing).floor();
    final int vIndex = (v / spacing).floor();

    final double snapU = (uIndex + 0.5) * spacing;
    final double snapV = (vIndex + 0.5) * spacing;

    final double x = (snapU + snapV) / 2;
    final double y = (snapU - snapV) / 2;

    final LatLng center = _worldPixelToLatLng(math.Point(x, y), gridLevel);
    return GridCell(
      gridLevel: gridLevel,
      uIndex: uIndex,
      vIndex: vIndex,
      spacing: spacing,
      center: center,
    );
  }

  /// Resolve the primary grid level based on the current zoom so that the grid
  /// spacing stays readable on screen.
  static int resolvePrimaryGridLevel(double cameraZoom,
      {double targetScreenSpacing = _targetScreenSpacing}) {
    if (cameraZoom.isNaN || cameraZoom.isInfinite) return 0;

    final double candidateLevel =
        cameraZoom - math.log(targetScreenSpacing / tileSize) / math.ln2;
    final int rounded = candidateLevel.round();
    return rounded.clamp(0, _maxGridLevel);
  }

  /// Determines which grid levels to render at the given zoom. The primary
  /// level aligns to the current camera zoom; a secondary level adds a lighter
  /// coarse grid for orientation.
  static List<GridLevel> resolveGridLevels(double cameraZoom) {
    final List<GridLevel> levels = [];
    final int primaryLevel = resolvePrimaryGridLevel(cameraZoom);
    final double primarySpacing =
        screenSpacingForLevel(cameraZoom, primaryLevel);

    if (_isSpacingInRange(primarySpacing)) {
      levels.add(GridLevel(
        zoomLevel: primaryLevel,
        intensity: 1.0,
        screenSpacing: primarySpacing,
      ));
    }

    final int secondaryLevel = primaryLevel - 2;
    final double secondarySpacing =
        screenSpacingForLevel(cameraZoom, secondaryLevel);
    if (_isSpacingInRange(secondarySpacing)) {
      levels.add(GridLevel(
        zoomLevel: secondaryLevel,
        intensity: 0.35,
        screenSpacing: secondarySpacing,
      ));
    }

    return levels;
  }

  /// Pixel spacing of the grid at the current camera zoom.
  static double screenSpacingForLevel(
    double cameraZoom,
    int gridLevel, {
    double tileSizePx = tileSize,
  }) {
    return tileSizePx * math.pow(2.0, cameraZoom - gridLevel);
  }

  /// Tile-space spacing for the given tile zoom.
  static double tileSpacingForLevel(
    int gridLevel,
    int tileZ, {
    required double tileSize,
  }) {
    return tileSize * math.pow(2.0, tileZ - gridLevel);
  }

  static GridPhase phaseForTile(
    int tileX,
    int tileY, {
    required double tileSize,
    required double spacing,
  }) {
    final double phaseX = -tileX * tileSize;
    final double phaseY = -tileY * tileSize;

    return GridPhase(
      sumPhase: _positiveMod(phaseX + phaseY, spacing),
      diffPhase: _positiveMod(phaseX - phaseY, spacing),
    );
  }

  static bool _isSpacingInRange(double spacing) =>
      spacing >= _minScreenSpacing && spacing <= _maxScreenSpacing;

  static double _positiveMod(double value, double modulus) {
    final double result = value % modulus;
    return result < 0 ? result + modulus : result;
  }

  static double _worldSize(int zoomLevel) =>
      tileSize * math.pow(2.0, zoomLevel).toDouble();

  static double _clampLatitude(double lat) => lat.clamp(-85.05112878, 85.05112878).toDouble();

  static math.Point<double> _latLngToWorldPixel(LatLng latLng, int zoomLevel) {
    final double lat = _clampLatitude(latLng.latitude);
    final double lng = latLng.longitude.clamp(-180.0, 180.0).toDouble();

    final double x = (lng + 180.0) / 360.0;
    final double sinLat = math.sin(lat * math.pi / 180.0);
    final double y = 0.5 - (math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi));

    final double size = _worldSize(zoomLevel);
    return math.Point<double>(x * size, y * size);
  }

  static LatLng _worldPixelToLatLng(math.Point<double> point, int zoomLevel) {
    final double size = _worldSize(zoomLevel);
    final double x = (point.x / size) - 0.5;
    final double y = 0.5 - (point.y / size);

    final double lng = 360.0 * x;
    final double lat =
        90.0 - (360.0 * math.atan(math.exp(-y * 2.0 * math.pi)) / math.pi);

    return LatLng(_clampLatitude(lat), lng.clamp(-180.0, 180.0).toDouble());
  }
}

/// Represents the snapped grid cell the coordinate belongs to. Provides a
/// stable anchor key for attaching files/content to the grid.
class GridCell {
  final int gridLevel;
  final int uIndex;
  final int vIndex;
  final double spacing;
  final LatLng center;

  const GridCell({
    required this.gridLevel,
    required this.uIndex,
    required this.vIndex,
    required this.spacing,
    required this.center,
  });

  String get anchorKey => '$gridLevel:$uIndex:$vIndex';
}

class GridPhase {
  final double sumPhase;
  final double diffPhase;

  const GridPhase({required this.sumPhase, required this.diffPhase});
}

class GridLevel {
  final int zoomLevel;
  final double intensity;
  final double screenSpacing;

  const GridLevel({
    required this.zoomLevel,
    required this.intensity,
    required this.screenSpacing,
  });
}
