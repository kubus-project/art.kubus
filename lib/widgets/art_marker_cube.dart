import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/art_marker.dart';
import '../utils/app_color_utils.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'rotatable_cube_painter.dart';

// Re-export rotatable cube components for convenience.
export 'rotatable_cube_painter.dart'
    show
        RotatableCubeMarker,
        RotatableCubePainter,
        RotatableCubePalette,
        RotatableCubeStyle,
        RotatableCubeTokens,
        CubeFaceVisibility,
        CubeFace;

/// Design tokens for cube marker sizing.
///
/// For camera-relative 3D markers, use [RotatableCubeTokens] instead.
class CubeMarkerTokens {
  CubeMarkerTokens._();

  /// Base size for static isometric cube markers at zoom 15.
  /// This is the size used for pre-rendered PNG icons.
  static const double staticSizeAtZoom15 = 46.0;

  /// Base size for real-time rotatable cube markers at zoom 15.
  /// Reduced by ~12% from static markers for a cleaner overlay appearance.
  static const double rotatableSizeAtZoom15 =
      RotatableCubeTokens.baseSizeAtZoom15;

  /// Width of the pre-rendered marker PNG.
  static const double pngWidth = 56.0;

  /// Height of the pre-rendered marker PNG.
  static const double pngHeight = 72.0;

  /// Computes rotatable cube size for a given zoom level.
  static double sizeForZoom(double zoom) =>
      RotatableCubeTokens.sizeForZoom(zoom);
}

@immutable
class CubeMarkerStyle {
  static const double selectedScale = 1.08;
  static const double hoveredScale = 1.04;
  static const Duration animationDuration = Duration(milliseconds: 140);

  const CubeMarkerStyle({
    required this.shadowColor,
    required this.iconBackgroundColor,
    required this.iconShadowColor,
    required this.edgeColor,
    required this.highlightColor,
  });

  final Color shadowColor;
  final Color iconBackgroundColor;
  final Color iconShadowColor;
  final Color edgeColor;
  final Color highlightColor;

  factory CubeMarkerStyle.resolve(
    BuildContext context, {
    required Color baseColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );
  }

  factory CubeMarkerStyle.fromScheme({
    required ColorScheme scheme,
    required bool isDark,
    required Color baseColor,
  }) {
    final shadow = scheme.shadow;

    return CubeMarkerStyle(
      shadowColor: shadow,
      iconBackgroundColor:
          scheme.surface.withValues(alpha: isDark ? 0.92 : 0.96),
      iconShadowColor: shadow.withValues(alpha: 0.16),
      edgeColor: shadow.withValues(alpha: 0.35),
      highlightColor: AppColorUtils.shiftLightness(
        baseColor,
        isDark ? 0.28 : 0.20,
      ).withValues(alpha: 0.30),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CubeMarkerStyle &&
            other.shadowColor == shadowColor &&
            other.iconBackgroundColor == iconBackgroundColor &&
            other.iconShadowColor == iconShadowColor &&
            other.edgeColor == edgeColor &&
            other.highlightColor == highlightColor);
  }

  @override
  int get hashCode => Object.hash(
        shadowColor,
        iconBackgroundColor,
        iconShadowColor,
        edgeColor,
        highlightColor,
      );
}


class _CubePalette {
  const _CubePalette({
    required this.top,
    required this.topAccent,
    required this.left,
    required this.right,
    required this.frontLeft,
    required this.frontRight,
    required this.base,
    required this.edge,
  });

  final Color top;
  final Color topAccent;
  final Color left;
  final Color right;
  final Color frontLeft;
  final Color frontRight;
  final Color base;
  final Color edge;

  factory _CubePalette.fromBase(
    Color color, {
    required Color edgeColor,
  }) {
    final normalized = _normalizeBase(color);
    final hsl = HSLColor.fromColor(normalized);

    // Increase saturation slightly for more vibrant colors
    final vibrant =
        hsl.withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0)).toColor();

    return _CubePalette(
      // Top face is brightest (light comes from above)
      top: _lighten(vibrant, 0.22),
      topAccent: _saturate(_lighten(vibrant, 0.12), 0.1),
      // Left face catches some light
      left: _darken(vibrant, 0.08),
      // Right face is in shadow
      right: _darken(vibrant, 0.18),
      // Front faces are darker (angled away from light)
      frontLeft: _darken(vibrant, 0.22),
      frontRight: _darken(vibrant, 0.28),
      // Base shadow
      base: normalized.withValues(alpha: 0.4),
      // Edges for definition
      edge: edgeColor.withValues(alpha: 0.35),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _CubePalette &&
            other.top == top &&
            other.topAccent == topAccent &&
            other.left == left &&
            other.right == right &&
            other.frontLeft == frontLeft &&
            other.frontRight == frontRight &&
            other.base == base &&
            other.edge == edge);
  }

  @override
  int get hashCode => Object.hash(
        top,
        topAccent,
        left,
        right,
        frontLeft,
        frontRight,
        base,
        edge,
      );
}

Color _lighten(Color color, double amount) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

Color _darken(Color color, double amount) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

Color _saturate(Color color, double amount) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final double saturation = (hsl.saturation + amount).clamp(0.0, 1.0);
  return hsl.withSaturation(saturation).toColor();
}

Color _normalizeBase(Color color) {
  final hsl = HSLColor.fromColor(color);
  // Clamp lightness to ensure good contrast on both light and dark maps
  final lightness = hsl.lightness.clamp(0.28, 0.62);
  // Ensure minimum saturation for color visibility
  final saturation = hsl.saturation.clamp(0.35, 1.0);
  return hsl
      .withLightness(lightness.toDouble())
      .withSaturation(saturation.toDouble())
      .toColor();
}

/// Renders the cube marker visuals into PNG bytes for MapLibre symbol icons.
///
/// This keeps marker rendering native (no Flutter widget markers on top of the
/// map) while preserving the exact Kubus cube styling.
///
/// For real-time camera-relative markers, use [RotatableCubeMarker] instead.
class ArtMarkerCubeIconRenderer {
  /// @deprecated Use [CubeMarkerTokens.staticSizeAtZoom15] instead.
  static const double markerCubeSizeAtZoom15 =
      CubeMarkerTokens.staticSizeAtZoom15;

  /// @deprecated Use [CubeMarkerTokens.pngWidth] instead.
  static const double markerWidthAtZoom15 = CubeMarkerTokens.pngWidth;

  /// @deprecated Use [CubeMarkerTokens.pngHeight] instead.
  static const double markerHeightAtZoom15 = CubeMarkerTokens.pngHeight;

  /// Renders a marker as a flat top-down square (top face + shadow).
  static Future<Uint8List> renderMarkerPng({
    required Color baseColor,
    required IconData icon,
    required ArtMarkerSignal tier,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    bool forceGlow = false,
    double pixelRatio = 2.0,
  }) async {
    final style = CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );

    final showGlow = forceGlow ||
        tier == ArtMarkerSignal.featured ||
        tier == ArtMarkerSignal.legendary;

    return _renderFlatMarkerPng(
      baseColor: baseColor,
      icon: icon,
      tier: tier,
      style: style,
      roles: roles,
      showGlow: showGlow,
      forceGlow: forceGlow,
      isDark: isDark,
      pixelRatio: pixelRatio,
    );
  }

  /// Renders a flat (top-down) marker showing only the top face with shadow.
  /// Used when isometric view is disabled.
  static Future<Uint8List> _renderFlatMarkerPng({
    required Color baseColor,
    required IconData icon,
    required ArtMarkerSignal tier,
    required CubeMarkerStyle style,
    required KubusColorRoles roles,
    required bool showGlow,
    required bool forceGlow,
    required bool isDark,
    double pixelRatio = 2.0,
  }) async {
    // Flat marker is a square matching the previous isometric footprint.
    const double size = CubeMarkerTokens.pngWidth;
    const double height = CubeMarkerTokens.pngWidth;
    final palette =
        _CubePalette.fromBase(baseColor, edgeColor: style.edgeColor);

    return _renderPng(
      width: size,
      height: height,
      pixelRatio: pixelRatio,
      paint: (canvas, logicalSize) {
        final center = Offset(logicalSize.width / 2, logicalSize.height / 2);
        final squareSize = CubeMarkerTokens.staticSizeAtZoom15;
        final halfSize = squareSize / 2;

        // Draw shadow beneath the square
        canvas.drawRect(
          Rect.fromCenter(
            center: center + const Offset(0, 2),
            width: squareSize + 4,
            height: squareSize * 0.15,
          ),
          Paint()
            ..color = style.shadowColor.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        // Draw colored glow if needed
        if (showGlow) {
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: squareSize + 12,
              height: squareSize + 12,
            ),
            Paint()
              ..color = baseColor.withValues(alpha: forceGlow ? 0.45 : 0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
        }

        // Draw main square (top face color)
        final squareRect = Rect.fromCenter(
          center: center,
          width: squareSize,
          height: squareSize,
        );
        final gradient = ui.Gradient.linear(
          Offset(center.dx - halfSize, center.dy - halfSize),
          Offset(center.dx + halfSize, center.dy + halfSize),
          [palette.topAccent, palette.top],
        );
        canvas.drawRect(
          squareRect,
          Paint()..shader = gradient,
        );

        // Draw border around square
        canvas.drawRect(
          squareRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = palette.edge,
        );

        // Draw icon directly on the subject-colored marker body.
        // No background box - just the icon glyph.
        // Icon color is theme-based: white in dark mode, black in light mode.
        if (icon.codePoint != 0) {
          final fontFamily = icon.fontFamily ?? 'MaterialIcons';
          final iconColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
          final glyphPainter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontSize: squareSize * 0.5,
                fontFamily: fontFamily,
                fontFamilyFallback: const <String>[
                  'MaterialIcons',
                  'Material Symbols Outlined',
                ],
                package: icon.fontPackage,
                color: iconColor,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          glyphPainter.layout();
          final glyphOffset = Offset(
            center.dx - glyphPainter.width / 2,
            center.dy - glyphPainter.height / 2,
          );
          glyphPainter.paint(canvas, glyphOffset);
        }

        // Draw signal ring if applicable
        if (tier != ArtMarkerSignal.subtle) {
          _paintFlatSignalRing(
            canvas,
            center: center,
            squareSize: squareSize + 4,
            tier: tier,
            baseColor: baseColor,
            roles: roles,
          );
        }
      },
    );
  }

  /// Paints a signal ring for flat markers (square outline instead of circular)
  static void _paintFlatSignalRing(
    Canvas canvas, {
    required Offset center,
    required double squareSize,
    required ArtMarkerSignal tier,
    required Color baseColor,
    required KubusColorRoles roles,
  }) {
    Color glowColor;
    double opacity;
    double strokeWidth;
    double blur;

    switch (tier) {
      case ArtMarkerSignal.legendary:
        glowColor = roles.achievementGold;
        opacity = 0.7;
        strokeWidth = 2.5;
        blur = 6;
        break;
      case ArtMarkerSignal.featured:
        glowColor = baseColor;
        opacity = 0.55;
        strokeWidth = 1.5;
        blur = 4;
        break;
      case ArtMarkerSignal.active:
        glowColor = baseColor;
        opacity = 0.35;
        strokeWidth = 1.5;
        blur = 3;
        break;
      case ArtMarkerSignal.subtle:
        return;
    }

    final rect = Rect.fromCenter(
      center: center,
      width: squareSize,
      height: squareSize,
    );

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = glowColor.withValues(alpha: opacity),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = glowColor.withValues(alpha: opacity * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  static Future<Uint8List> renderClusterPng({
    required int count,
    required Color baseColor,
    required ColorScheme scheme,
    required bool isDark,
    double cubeSize = 54,
    double pixelRatio = 2.0,
  }) async {
    final style = CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );
    final showGlow = count >= 10;
    final label = count > 99 ? '99+' : '$count';
    final palette =
        _CubePalette.fromBase(baseColor, edgeColor: style.edgeColor);
    // Cluster label color is theme-based: white in dark mode, black in light mode.
    final labelColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final labelStyle = KubusTextStyles.badgeCount.copyWith(
      color: labelColor,
    );

    return _renderFlatClusterPng(
      label: label,
      labelStyle: labelStyle,
      baseColor: baseColor,
      palette: palette,
      style: style,
      showGlow: showGlow,
      pixelRatio: pixelRatio,
    );
  }

  static Future<Uint8List> _renderFlatClusterPng({
    required String label,
    required TextStyle labelStyle,
    required Color baseColor,
    required _CubePalette palette,
    required CubeMarkerStyle style,
    required bool showGlow,
    double pixelRatio = 2.0,
  }) async {
    const double size = CubeMarkerTokens.pngWidth;
    const double height = CubeMarkerTokens.pngWidth;

    return _renderPng(
      width: size,
      height: height,
      pixelRatio: pixelRatio,
      paint: (canvas, logicalSize) {
        final center = Offset(logicalSize.width / 2, logicalSize.height / 2);
        final squareSize = CubeMarkerTokens.staticSizeAtZoom15;
        final halfSize = squareSize / 2;

        // Draw shadow beneath the square
        canvas.drawRect(
          Rect.fromCenter(
            center: center + const Offset(0, 2),
            width: squareSize + 4,
            height: squareSize * 0.15,
          ),
          Paint()
            ..color = style.shadowColor.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        if (showGlow) {
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: squareSize + 12,
              height: squareSize + 12,
            ),
            Paint()
              ..color = baseColor.withValues(alpha: 0.32)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
        }

        final squareRect = Rect.fromCenter(
          center: center,
          width: squareSize,
          height: squareSize,
        );
        final gradient = ui.Gradient.linear(
          Offset(center.dx - halfSize, center.dy - halfSize),
          Offset(center.dx + halfSize, center.dy + halfSize),
          [palette.topAccent, palette.top],
        );
        canvas.drawRect(squareRect, Paint()..shader = gradient);

        canvas.drawRect(
          squareRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = palette.edge,
        );

        // Draw cluster count label directly on the subject-colored marker body.
        // No background box - just the label text.
        final labelPainter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        labelPainter.layout();
        final labelOffset = Offset(
          center.dx - labelPainter.width / 2,
          center.dy - labelPainter.height / 2,
        );
        labelPainter.paint(canvas, labelOffset);
      },
    );
  }

  static Future<Uint8List> _renderPng({
    required double width,
    required double height,
    required double pixelRatio,
    required void Function(Canvas canvas, Size logicalSize) paint,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final logicalSize = Size(width, height);

    final pr =
        pixelRatio.isFinite ? pixelRatio.clamp(1.0, 4.0).toDouble() : 2.0;
    canvas.scale(pr, pr);

    // Clear canvas to fully transparent to prevent black box artifacts.
    // Without this, uninitialized pixels may render as black on some platforms.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()
        ..color = const Color(0x00000000)
        ..blendMode = BlendMode.clear,
    );

    paint(canvas, logicalSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pr).round(),
      (height * pr).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      // Return a minimal 1x1 transparent PNG as fallback if rendering fails.
      return Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, // RGBA
        0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
        0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
        0xAE, 0x42, 0x60, 0x82,
      ]);
    }
    return bytes.buffer.asUint8List();
  }

}
