import 'dart:math' as math;

/// Chooses from explicit server-provided image variants. It never constructs
/// derivative URLs: old records may have only [fallbackUrl], and external or
/// IPFS URLs need not have a corresponding derivative at all.
class ImageVariantSelector {
  const ImageVariantSelector._();

  /// [variants] entries have `url`, `width`, and `height` fields. The target
  /// is the longest rendered logical edge multiplied by device pixel ratio.
  /// Invalid entries are ignored. If no variant is large enough, the largest
  /// available variant is used; if none is usable, [fallbackUrl] is returned.
  static String? select({
    required Iterable<dynamic>? variants,
    required String? fallbackUrl,
    required double logicalWidth,
    required double logicalHeight,
    required double devicePixelRatio,
  }) {
    final fallback = _url(fallbackUrl);
    if (!logicalWidth.isFinite ||
        !logicalHeight.isFinite ||
        !devicePixelRatio.isFinite ||
        logicalWidth < 0 ||
        logicalHeight < 0 ||
        devicePixelRatio <= 0) {
      return fallback;
    }
    final logicalEdge = math.max(logicalWidth, logicalHeight);
    if (logicalEdge <= 0) return fallback;
    final target = logicalEdge * devicePixelRatio;
    if (!target.isFinite) return fallback;

    String? atLeastUrl;
    int? atLeastEdge;
    String? largestUrl;
    int largestEdge = 0;
    for (final item in variants ?? const []) {
      if (item is! Map) continue;
      final url = _url(item['url']);
      final width = _dimension(item['width']);
      final height = _dimension(item['height']);
      if (url == null || width == null || height == null) continue;
      final edge = math.max(width, height);
      if (edge > largestEdge) {
        largestEdge = edge;
        largestUrl = url;
      }
      if (edge >= target && (atLeastEdge == null || edge < atLeastEdge)) {
        atLeastEdge = edge;
        atLeastUrl = url;
      }
    }
    return atLeastUrl ?? largestUrl ?? fallback;
  }

  static String? _url(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _dimension(Object? value) {
    if (value is! num ||
        !value.isFinite ||
        value <= 0 ||
        value != value.roundToDouble()) {
      return null;
    }
    return value.toInt();
  }
}
