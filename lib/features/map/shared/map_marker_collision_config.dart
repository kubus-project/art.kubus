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

  /// Upper bound for animation-driven marker data syncs.
  static const int entrySyncThrottleMs = 96;

  static Object webHitboxIconSizeExpression() {
    return <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['zoom'],
      3,
      <Object>[
        'case',
        <Object>['==', <Object>['get', 'kind'], 'cluster'],
        44,
        28,
      ],
      12,
      <Object>[
        'case',
        <Object>['==', <Object>['get', 'kind'], 'cluster'],
        52,
        34,
      ],
      15,
      <Object>[
        'case',
        <Object>['==', <Object>['get', 'kind'], 'cluster'],
        62,
        40,
      ],
      24,
      <Object>[
        'case',
        <Object>['==', <Object>['get', 'kind'], 'cluster'],
        74,
        56,
      ],
    ];
  }

  static Object webHitboxRadiusExpression() {
    return <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['zoom'],
      3,
      <Object>[
        'case',
        <Object>['==', <Object>['get', 'kind'], 'cluster'],
        22,
        14,
      ],
      12,
      <Object>[
        'case',
        <Object>['==', <Object>['get', 'kind'], 'cluster'],
        26,
        17,
      ],
      15,
      <Object>[
        'case',
        <Object>['==', <Object>['get', 'kind'], 'cluster'],
        31,
        20,
      ],
      24,
      <Object>[
        'case',
        <Object>['==', <Object>['get', 'kind'], 'cluster'],
        37,
        28,
      ],
    ];
  }

  static double webFallbackPickRadiusForZoom(double zoom) {
    return _interpolateStops(
      zoom,
      const <double>[3, 12, 15, 24],
      const <double>[14, 17, 20, 28],
    );
  }

  static double _interpolateStops(
    double zoom,
    List<double> stops,
    List<double> values,
  ) {
    if (stops.isEmpty || values.isEmpty || stops.length != values.length) {
      return 0.0;
    }
    final clamped = zoom.clamp(stops.first, stops.last).toDouble();
    for (var i = 1; i < stops.length; i++) {
      final currentStop = stops[i];
      if (clamped > currentStop) continue;
      final previousStop = stops[i - 1];
      final previousValue = values[i - 1];
      final currentValue = values[i];
      final span = currentStop - previousStop;
      if (span <= 0) return currentValue;
      final t = (clamped - previousStop) / span;
      return previousValue + ((currentValue - previousValue) * t);
    }
    return values.last;
  }
}
