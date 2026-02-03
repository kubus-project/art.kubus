import 'dart:math' as math;

/// Shared heuristics to dedupe MapLibre `onFeatureTapped` vs `onMapClick`.
///
/// On Flutter web (MapLibre GL JS), a marker tap can produce both:
/// - `MapLibreMapController.onFeatureTapped` (for interactive style layers), and
/// - `MapLibreMap.onMapClick` (background click).
///
/// If we treat the click as a background tap, overlays can be immediately
/// dismissed, which looks like "the UI disappears".
class MapTapGating {
  const MapTapGating._();

  static bool shouldIgnoreMapClickAfterFeatureTap({
    required DateTime? lastFeatureTapAt,
    required math.Point<double>? lastFeatureTapPoint,
    required math.Point<double> clickPoint,
    Duration maxAge = const Duration(milliseconds: 260),
    double tolerancePx = 28.0,
  }) {
    if (lastFeatureTapAt == null || lastFeatureTapPoint == null) return false;

    final age = DateTime.now().difference(lastFeatureTapAt);
    if (age.isNegative || age > maxAge) return false;

    final dx = (clickPoint.x - lastFeatureTapPoint.x).abs();
    final dy = (clickPoint.y - lastFeatureTapPoint.y).abs();
    return dx <= tolerancePx && dy <= tolerancePx;
  }
}
