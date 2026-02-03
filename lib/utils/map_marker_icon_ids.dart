/// Shared icon ID generation for MapLibre `addImage(...)` marker assets.
class MapMarkerIconIds {
  const MapMarkerIconIds._();

  static String markerBase({
    required String typeName,
    required String tierName,
    required bool isDark,
  }) {
    return 'mk_${typeName}_${tierName}_${isDark ? 'd' : 'l'}';
  }

  static String markerSelected({
    required String typeName,
    required String tierName,
    required bool isDark,
  }) {
    return 'mk_${typeName}_${tierName}_sel_${isDark ? 'd' : 'l'}';
  }

  static String cluster({
    required String typeName,
    required String label,
    required bool isDark,
  }) {
    return 'cl_${typeName}_${label}_${isDark ? 'd' : 'l'}';
  }
}
