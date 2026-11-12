import 'dart:math' as math;

/// Chooses from explicit server-provided image variants. It never constructs
/// derivative URLs: old records may have only [fallbackUrl], and external or
/// IPFS URLs need not have a corresponding derivative at all.
class ImageVariantSelector {
  const ImageVariantSelector._();

  static bool isRevocableDerivative(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return RegExp(
            r'^/api/upload/derivatives/[a-f0-9]{64}/(thumbnail|card|detail)$')
        .hasMatch(uri.path);
  }

  /// Select only variants explicitly bound to [sourceUrl]. A duplicate source
  /// record is ambiguous and falls back; gallery position is never an identity.
  static String? selectForSource({
    required Iterable<dynamic>? records,
    required String sourceUrl,
    required String? fallbackUrl,
    required double logicalWidth,
    required double logicalHeight,
    required double devicePixelRatio,
    int? maxVariantEdge,
  }) {
    final source = sourceUrl.trim();
    if (source.isEmpty) return _url(fallbackUrl);
    Map? match;
    for (final record in records ?? const []) {
      if (record is! Map || _url(record['sourceUrl']) != source) continue;
      if (match != null) return _url(fallbackUrl);
      match = record;
    }
    final raw = match?['variants'];
    if (raw is! Iterable) return _url(fallbackUrl);
    final variants = maxVariantEdge == null
        ? raw
        : raw.where((item) {
            if (item is! Map) return false;
            final width = _dimension(item['width']);
            final height = _dimension(item['height']);
            return width != null &&
                height != null &&
                math.max(width, height) <= maxVariantEdge;
          });
    return select(
      variants: variants,
      fallbackUrl: fallbackUrl,
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// Only explicit, bounded neighbor variants may be prefetched. Never fetch
  /// the current image twice or prefetch an unbounded legacy original.
  static List<String> galleryNeighborPreviews({
    required List<String> sources,
    required int index,
    required Iterable<dynamic>? records,
    required double logicalWidth,
    required double logicalHeight,
    required double devicePixelRatio,
  }) {
    final results = <String>{};
    for (final neighbor in [index - 1, index + 1]) {
      if (neighbor < 0 || neighbor >= sources.length) continue;
      final source = sources[neighbor].trim();
      final selected = selectForSource(
        records: records,
        sourceUrl: source,
        fallbackUrl: null,
        logicalWidth: logicalWidth,
        logicalHeight: logicalHeight,
        devicePixelRatio: devicePixelRatio,
        maxVariantEdge: 1280,
      );
      final displayed = selectForSource(
        records: records,
        sourceUrl: source,
        fallbackUrl: null,
        logicalWidth: logicalWidth,
        logicalHeight: logicalHeight,
        devicePixelRatio: devicePixelRatio,
      );
      if (selected != null && selected != source && selected == displayed) {
        results.add(selected);
      }
    }
    return results.toList(growable: false);
  }

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
