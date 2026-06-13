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

  /// Cluster icon id.
  ///
  /// [categorySignature] encodes the dominant marker categories contained in
  /// the cluster (e.g. `artwork-streetArt-event`) so that mixed clusters with
  /// a different category composition get their own cached combined badge.
  static String cluster({
    required String categorySignature,
    required String label,
    required bool isDark,
  }) {
    final sig = categorySignature.isEmpty ? 'mixed' : categorySignature;
    return 'cl_${sig}_${label}_${isDark ? 'd' : 'l'}';
  }
}
