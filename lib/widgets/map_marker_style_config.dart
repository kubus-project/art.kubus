import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

enum MapMarkerInteractionState {
  idle,
  hovered,
  pressed,
  selected,
}

@immutable
class MapMarkerStyleConfig {
  const MapMarkerStyleConfig({
    required this.subjectColor,
    required this.brightness,
    required this.zoom,
    required this.interaction,
  });

  final Color subjectColor;
  final Brightness brightness;
  final double zoom;
  final MapMarkerInteractionState interaction;

  static const double minZoom = 3.0;
  static const double midZoom = 15.0;
  static const double maxZoom = 24.0;

  static const double minScale = 0.5;
  static const double midScale = 1.0;
  static const double maxScale = 1.5;

  static const double markerBodySizeAtZoom15 = 46.0;
  static const double markerPngCanvasSizeAtZoom15 = 56.0;

  static const Duration interactionDuration = Duration(milliseconds: 140);
  static const Duration selectionPopDuration = Duration(milliseconds: 180);

  static const Duration cubeIconSpinPeriod = Duration(seconds: 18);

  static const double hoverScaleFactor = 1.04;
  static const double pressedScaleFactor = 0.97;
  static const double selectedPopScaleFactor = 1.06;

  static double scaleForZoom(double zoom) {
    if (zoom <= minZoom) return minScale;
    if (zoom <= midZoom) {
      return _lerp(minScale, midScale, (zoom - minZoom) / (midZoom - minZoom));
    }
    if (zoom <= maxZoom) {
      return _lerp(midScale, maxScale, (zoom - midZoom) / (maxZoom - midZoom));
    }
    return maxScale;
  }

  static List<Object> iconSizeExpression({
    double constantScale = 1.0,
    Object? multiplier,
  }) {
    if (constantScale == 1.0 && multiplier == null) {
      return <Object>[
        'interpolate',
        <Object>['linear'],
        <Object>['zoom'],
        minZoom,
        minScale,
        midZoom,
        midScale,
        maxZoom,
        maxScale,
      ];
    }

    Object scaled(double base) {
      final value = base * constantScale;
      if (multiplier == null) return value;
      return <Object>['*', value, multiplier];
    }

    return <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['zoom'],
      minZoom,
      scaled(minScale),
      midZoom,
      scaled(midScale),
      maxZoom,
      scaled(maxScale),
    ];
  }

  double get markerScale => scaleForZoom(zoom);

  double get markerBodySizePx => markerBodySizeAtZoom15 * markerScale;

  double get markerCanvasSizePx => markerPngCanvasSizeAtZoom15 * markerScale;

  double get markerOverlayVerticalOffsetPx =>
      (markerBodySizePx / 2.0) + math.min(14.0, markerBodySizePx * 0.28);

  double get markerCornerRadiusPx =>
      math.min(KubusRadius.md, markerBodySizePx * 0.28);

  Color get iconForegroundColor => bestForegroundOn(subjectColor, brightness);

  Color get hoverOutlineColor {
    final isDark = brightness == Brightness.dark;
    final base = iconForegroundColor;
    return base.withValues(alpha: isDark ? 0.60 : 0.42);
  }

  Color get pressOutlineColor {
    final isDark = brightness == Brightness.dark;
    final base = iconForegroundColor;
    return base.withValues(alpha: isDark ? 0.70 : 0.50);
  }

  Color get selectionPulseColor => subjectColor.withValues(alpha: 0.90);

  double get hoverScale => hoverScaleFactor;

  double get pressedScale => pressedScaleFactor;

  double get selectedPopScale => selectedPopScaleFactor;

  /// Vertical offset (in "ems") for the floating icon symbol in 3D mode.
  ///
  /// This is multiplied by the icon size, so it scales with zoom automatically.
  static const Duration cubeIconBobPeriod = Duration(milliseconds: 2400);
  static const double cubeIconBobAmplitudeEm = 0.12;
  static const double cubeFloatingIconBaseOffsetYEm = -1.85;

  static const List<Object> cubeFloatingIconOffsetEm = <Object>[
    0.0,
    cubeFloatingIconBaseOffsetYEm,
  ];

  static List<Object> cubeFloatingIconOffsetEmWithBob(double bobOffsetEm) =>
      <Object>[0.0, cubeFloatingIconBaseOffsetYEm + bobOffsetEm];

  static double cubeSpinDegreesPerSecond() =>
      360.0 / (cubeIconSpinPeriod.inMilliseconds / 1000.0);

  static Color bestForegroundOn(Color background, Brightness brightness) {
    final white = const Color(0xFFFFFFFF);
    final black = const Color(0xFF000000);
    final whiteScore = _contrastRatio(background, white);
    final blackScore = _contrastRatio(background, black);
    if (whiteScore == blackScore) {
      return brightness == Brightness.dark ? white : black;
    }
    return whiteScore > blackScore ? white : black;
  }

  static double _lerp(double a, double b, double t) {
    final clamped = t.clamp(0.0, 1.0).toDouble();
    return a + (b - a) * clamped;
  }

  static double _contrastRatio(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _relativeLuminance(Color c) {
    double f(double channel) {
      final v = channel.clamp(0.0, 1.0).toDouble();
      return v <= 0.03928
          ? (v / 12.92)
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = f(c.r);
    final g = f(c.g);
    final b = f(c.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
}
