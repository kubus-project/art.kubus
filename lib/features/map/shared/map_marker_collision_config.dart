/// Shared tuning constants for same-location marker behavior and marker
/// entrance animation. Centralized here so mobile and desktop stay in sync.
abstract final class MapMarkerCollisionConfig {
  /// Number of decimal places used to build a stable same-coordinate key.
  /// 6 decimals ~= 0.11m precision at the equator.
  static const int coordinateKeyDecimals = 6;

  /// Auto-expand same-location markers when zoom reaches this threshold.
  static const double spiderfyAutoExpandZoom = 17.0;

  /// Base spiderfy ring radius in screen pixels.
  static const double spiderfyBaseRadiusPx = 34.0;

  /// Additional radius per ring in screen pixels.
  static const double spiderfyRadiusStepPx = 24.0;

  /// Minimum desired marker separation in screen pixels.
  static const double spiderfyMinSeparationPx = 24.0;

  /// Minimum capacity for the first spiderfy ring.
  static const int spiderfyMinFirstRingCount = 6;

  /// Enable adaptive spiderfy spacing once stacked markers exceed this count.
  static const int spiderfyAdaptiveSpacingStartCount = 10;

  /// Additional spiderfy radius scale applied per marker above the threshold.
  static const double spiderfyRadiusScalePerExtraMarker = 0.015;

  /// Upper bound for additive radius scale boost (e.g. 0.65 => up to 1.65x).
  static const double spiderfyRadiusScaleMaxBoost = 0.65;

  /// Additional min-separation scale per marker above the threshold.
  static const double spiderfySeparationScalePerExtraMarker = 0.01;

  /// Upper bound for additive min-separation scale boost.
  static const double spiderfySeparationScaleMaxBoost = 0.35;

  /// Marker entrance animation starting scale.
  static const double entryStartScale = 0.78;

  /// Marker entrance animation duration in milliseconds.
  static const int entryDurationMs = 220;

  /// Additional stagger per marker for sequential pop-in.
  static const int entryStaggerMs = 36;

  /// Debounce for viewport visibility checks while moving/zooming.
  static const int viewportVisibilityDebounceMs = 120;

  /// Retry delay for first viewport visibility bootstrap on web.
  ///
  /// On first route entry, MapLibre can briefly report an empty visible region
  /// before layout settles. We retry a few times before falling back.
  static const int viewportInitRetryDelayMs = 140;

  /// Maximum retries for initial viewport visibility bootstrap.
  static const int viewportInitMaxRetries = 6;

  /// Debounce for nearby radius slider fetches.
  static const int nearbyRadiusDebounceMs = 400;
}
