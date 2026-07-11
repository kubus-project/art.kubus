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

  // ---------------------------------------------------------------------------
  // Stable screen-space badge sizing
  // ---------------------------------------------------------------------------
  // The floating badge keeps a constant size across normal browsing zooms so it
  // no longer continuously grows/shrinks while zooming. A single gentle step
  // keeps badges from dominating the canvas at very far zoom-out; from
  // [stableNearZoom] upward the size is locked.
  static const double stableFarZoom = 7.0;
  static const double stableNearZoom = 11.0;
  static const double stableFarScale = 0.82;
  static const double stableBaseScale = 1.0;

  // ---------------------------------------------------------------------------
  // Coordinate dot (precise geospatial point)
  // ---------------------------------------------------------------------------
  static const double dotRadiusPx = 4.5;
  static const double dotStrokeWidthPx = 1.5;
  static const double clusterDotRadiusPx = 5.5;

  // ---------------------------------------------------------------------------
  // Pulse ring (soft expanding ring emanating from the dot)
  // ---------------------------------------------------------------------------
  static const Duration pulsePeriod = Duration(milliseconds: 2600);
  static const double pulseMinRadiusPx = 5.0;
  static const double pulseMaxRadiusPx = 19.0;
  static const double pulseMaxOpacity = 0.30;

  static double pulseRadiusForPhase(double phase) {
    final t = phase.clamp(0.0, 1.0).toDouble();
    return pulseMinRadiusPx + (pulseMaxRadiusPx - pulseMinRadiusPx) * t;
  }

  static double pulseOpacityForPhase(double phase) {
    final t = phase.clamp(0.0, 1.0).toDouble();
    // Fade out as the ring expands; ease so it lingers softly near the dot.
    return pulseMaxOpacity * (1.0 - t) * (1.0 - t);
  }

  // ---------------------------------------------------------------------------
  // Floating badge bob (replaces the old cube spin)
  // ---------------------------------------------------------------------------
  // The badge hovers above the dot (its float gap is baked into the PNG, so the
  // symbol is anchored at its bottom). This adds a subtle vertical bob in screen
  // pixels. icon-offset is multiplied by icon-size, and badge size is stable, so
  // the bob stays constant across normal zooms.
  static const Duration badgeBobPeriod = Duration(milliseconds: 2600);
  static const double badgeBobAmplitudePx = 2.5;

  /// icon-offset for the floating badge given the current bob offset in pixels.
  /// Negative Y lifts the badge further from the dot (screen up).
  static List<Object> badgeBobOffset(double bobPx) => <Object>[0.0, bobPx];

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

  /// Stable screen-space icon size expression.
  ///
  /// Unlike the previous aggressive `minScale..maxScale` interpolation across
  /// the whole zoom range, this keeps markers at a constant size during normal
  /// browsing zooms ([stableNearZoom] and closer) and only applies a single
  /// gentle step-down when zoomed far out. This is what stops markers from
  /// continuously growing/shrinking while zooming.
  ///
  /// [multiplier] (used for interaction/entry animations) is encoded inside the
  /// stop outputs so the top-level expression input stays `['zoom']`, which
  /// MapLibre GL JS requires.
  static List<Object> iconSizeExpression({
    double constantScale = 1.0,
    Object? multiplier,
  }) {
    Object scaled(double base) {
      final value = base * constantScale;
      if (multiplier == null) return value;
      return <Object>['*', value, multiplier];
    }

    return <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['zoom'],
      stableFarZoom,
      scaled(stableFarScale),
      stableNearZoom,
      scaled(stableBaseScale),
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

    // Prefer the theme-appropriate foreground when it has acceptable contrast.
    // This keeps marker icons feeling consistent when the app toggles between
    // light/dark themes (e.g. dark mode favors white glyphs).
    const minPreferredContrast = 2.4;
    if (brightness == Brightness.dark) {
      if (whiteScore >= minPreferredContrast) return white;
      return black;
    }
    if (blackScore >= minPreferredContrast) return black;
    return white;
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

/// Fixed canvas-paint colors for the marker cube renderer
/// (`art_marker_cube.dart`). Marker art is intentionally theme-fixed; keep
/// the values here so widgets carry no raw color literals.
class MarkerCubePalette {
  MarkerCubePalette._();

  /// Marker glyphs invert from the usual scheme by design:
  /// dark mode paints black glyphs, light mode paints white glyphs.
  static const Color glyphDarkMode = Color(0xFF000000);
  static const Color glyphLightMode = Color(0xFFFFFFFF);

  /// Featured-star badge: dark ink halo, gold fill, amber stroke.
  static const Color starHaloInk = Color(0xCC111827);
  static const Color starFill = Color(0xFFFFD54F);
  static const Color starStroke = Color(0xFFF59E0B);

  /// Fully transparent clear color for canvas initialisation.
  static const Color clear = Color(0x00000000);
}
