/// Shared icon ID generation for MapLibre `addImage(...)` marker assets.
class MapMarkerIconIds {
  const MapMarkerIconIds._();

  static String markerBase({
    required String typeName,
    required String tierName,
    required bool isDark,
    bool promoted = false,
  }) {
    return 'mk_${typeName}_${tierName}_${isDark ? 'd' : 'l'}_${promoted ? 'pro' : 'std'}';
  }

  static String markerSelected({
    required String typeName,
    required String tierName,
    required bool isDark,
    bool promoted = false,
  }) {
    return 'mk_${typeName}_${tierName}_sel_${isDark ? 'd' : 'l'}_${promoted ? 'pro' : 'std'}';
  }

  /// Visual renderer version for combined cluster badges.
  ///
  /// Bumping this invalidates every cached cluster icon id so MapLibre cannot
  /// reuse a stale image (e.g. the old generic count circle) after the cluster
  /// renderer changes. Bump whenever [renderClusterPng]'s visual output changes.
  static const String clusterRendererVersion = 'v2';

  /// Cluster icon id.
  ///
  /// [categorySignature] encodes the dominant marker categories contained in
  /// the cluster (e.g. `artwork-streetArt-event`) so that mixed clusters with
  /// a different category composition get their own cached combined badge.
  ///
  /// The [clusterRendererVersion] prefix guarantees that when the cluster
  /// renderer changes shape (e.g. from generic circles to category-shaped
  /// badges with glyphs) the previously generated images are not reused.
  static String cluster({
    required String categorySignature,
    required String label,
    required bool isDark,
  }) {
    final sig = categorySignature.isEmpty ? 'mixed' : categorySignature;
    return 'cl_${clusterRendererVersion}_${sig}_${label}_${isDark ? 'd' : 'l'}';
  }
}
