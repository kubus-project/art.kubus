import 'dart:collection';
import 'dart:math' as math;
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

/// Body silhouette of a floating map marker badge.
///
/// Different marker types get a slightly different badge shape (not only a
/// different color) so they stay distinguishable at a glance, Pokémon-Go-stop
/// style but cleaner / more premium.
enum ArtMapMarkerShape {
  roundedSquare,
  diamond,
  arch,
  pill,
  hexagon,
  capsule,
  portalHex,
  circle;

  static ArtMapMarkerShape forType(ArtMarkerType type) {
    switch (type) {
      case ArtMarkerType.artwork:
        return ArtMapMarkerShape.roundedSquare;
      case ArtMarkerType.streetArt:
        return ArtMapMarkerShape.diamond;
      case ArtMarkerType.institution:
        return ArtMapMarkerShape.arch;
      case ArtMarkerType.event:
        return ArtMapMarkerShape.pill;
      case ArtMarkerType.residency:
        return ArtMapMarkerShape.hexagon;
      case ArtMarkerType.drop:
        return ArtMapMarkerShape.capsule;
      case ArtMarkerType.experience:
        return ArtMapMarkerShape.portalHex;
      case ArtMarkerType.other:
        return ArtMapMarkerShape.circle;
    }
  }
}

/// One category contained in a cluster, described by the silhouette + colour
/// used for that marker type. Used to render a combined cluster badge whose
/// pips communicate which categories (artwork, street art, events, …) are
/// bundled inside the cluster.
@immutable
class ClusterCategoryBadge {
  const ClusterCategoryBadge({
    required this.shape,
    required this.color,
    required this.count,
  });

  final ArtMapMarkerShape shape;
  final Color color;
  final int count;
}

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
class _MarkerPngCacheKey {
  const _MarkerPngCacheKey({
    required this.baseColorValue,
    required this.shapeIndex,
    required this.iconCodePoint,
    required this.iconFamily,
    required this.iconPackage,
    required this.tierIndex,
    required this.isDark,
    required this.forceGlow,
    required this.showPromotionStar,
    required this.shadowColorValue,
    required this.highlightColorValue,
    required this.legendaryRingValue,
    required this.pixelRatioKey,
  });

  final int baseColorValue;
  final int shapeIndex;
  final int iconCodePoint;
  final String iconFamily;
  final String iconPackage;
  final int tierIndex;
  final bool isDark;
  final bool forceGlow;
  final bool showPromotionStar;
  final int shadowColorValue;
  final int highlightColorValue;
  final int legendaryRingValue;
  final int pixelRatioKey;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _MarkerPngCacheKey &&
            other.baseColorValue == baseColorValue &&
            other.shapeIndex == shapeIndex &&
            other.iconCodePoint == iconCodePoint &&
            other.iconFamily == iconFamily &&
            other.iconPackage == iconPackage &&
            other.tierIndex == tierIndex &&
            other.isDark == isDark &&
            other.forceGlow == forceGlow &&
            other.showPromotionStar == showPromotionStar &&
            other.shadowColorValue == shadowColorValue &&
            other.highlightColorValue == highlightColorValue &&
            other.legendaryRingValue == legendaryRingValue &&
            other.pixelRatioKey == pixelRatioKey);
  }

  @override
  int get hashCode => Object.hash(
        baseColorValue,
        shapeIndex,
        iconCodePoint,
        iconFamily,
        iconPackage,
        tierIndex,
        isDark,
        forceGlow,
        showPromotionStar,
        shadowColorValue,
        highlightColorValue,
        legendaryRingValue,
        pixelRatioKey,
      );
}

@immutable
class _ClusterPngCacheKey {
  const _ClusterPngCacheKey({
    required this.baseColorValue,
    required this.label,
    required this.isDark,
    required this.shadowColorValue,
    required this.pixelRatioKey,
    required this.labelStyleKey,
    required this.categoryKey,
  });

  final int baseColorValue;
  final String label;
  final bool isDark;
  final int shadowColorValue;
  final int pixelRatioKey;
  final int labelStyleKey;

  /// Encodes the combined-badge composition (per-category shape + colour) so
  /// mixed clusters with different category sets cache distinct icons.
  final String categoryKey;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _ClusterPngCacheKey &&
            other.baseColorValue == baseColorValue &&
            other.label == label &&
            other.isDark == isDark &&
            other.shadowColorValue == shadowColorValue &&
            other.pixelRatioKey == pixelRatioKey &&
            other.labelStyleKey == labelStyleKey &&
            other.categoryKey == categoryKey);
  }

  @override
  int get hashCode => Object.hash(
        baseColorValue,
        label,
        isDark,
        shadowColorValue,
        pixelRatioKey,
        labelStyleKey,
        categoryKey,
      );
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
/// map) while preserving the exact kubus cube styling.
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

  // ---------------------------------------------------------------------------
  // Floating badge geometry
  // ---------------------------------------------------------------------------
  // The badge PNG is taller than it is wide: the shaped body lives in the upper
  // region and the bottom is intentionally empty. The symbol layer anchors this
  // image at its bottom, so the badge appears to hover above its coordinate dot
  // with a clean gap — no per-zoom geometry, no fake 3D cube.
  static const double badgePngWidth = 56.0;
  static const double badgePngHeight = 72.0;
  static const double badgeBodySize = 44.0;
  static const double badgeBottomGap = 18.0;

  /// Vertical center of the badge body inside the PNG canvas.
  static const double badgeBodyCenterY =
      badgePngHeight - badgeBottomGap - (badgeBodySize / 2.0);

  static const int _maxMarkerCacheEntries = 320;
  static const int _maxClusterCacheEntries = 180;

  static final LinkedHashMap<_MarkerPngCacheKey, Future<Uint8List>>
      _markerPngCache = LinkedHashMap<_MarkerPngCacheKey, Future<Uint8List>>();
  static final LinkedHashMap<_ClusterPngCacheKey, Future<Uint8List>>
      _clusterPngCache =
      LinkedHashMap<_ClusterPngCacheKey, Future<Uint8List>>();

  static Future<Uint8List> _cachedFuture<K>({
    required LinkedHashMap<K, Future<Uint8List>> cache,
    required K key,
    required int maxEntries,
    required Future<Uint8List> Function() render,
  }) {
    final existing = cache.remove(key);
    if (existing != null) {
      cache[key] = existing;
      return existing;
    }

    final created = render();
    cache[key] = created;
    if (cache.length > maxEntries) {
      cache.remove(cache.keys.first);
    }
    return created;
  }

  static int _pixelRatioKey(double pixelRatio) {
    final pr =
        pixelRatio.isFinite ? pixelRatio.clamp(1.0, 4.0).toDouble() : 2.0;
    return (pr * 100).round();
  }

  static Color _iconForegroundForTheme({required bool isDark}) {
    // User preference: marker glyphs should invert from the typical scheme:
    // dark mode uses black glyphs, light mode uses white glyphs.
    return isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  /// Renders a marker as a flat top-down square (top face + shadow).
  static Future<Uint8List> renderMarkerPng({
    required Color baseColor,
    required IconData icon,
    required ArtMarkerSignal tier,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    ArtMapMarkerShape shape = ArtMapMarkerShape.roundedSquare,
    bool forceGlow = false,
    bool showPromotionStar = false,
    double pixelRatio = 2.0,
  }) async {
    final style = CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );

    final key = _MarkerPngCacheKey(
      baseColorValue: baseColor.toARGB32(),
      shapeIndex: shape.index,
      iconCodePoint: icon.codePoint,
      iconFamily: icon.fontFamily ?? 'MaterialIcons',
      iconPackage: icon.fontPackage ?? '',
      tierIndex: tier.index,
      isDark: isDark,
      forceGlow: forceGlow,
      showPromotionStar: showPromotionStar,
      shadowColorValue: scheme.shadow.toARGB32(),
      highlightColorValue: style.highlightColor.toARGB32(),
      legendaryRingValue: roles.achievementGold.toARGB32(),
      pixelRatioKey: _pixelRatioKey(pixelRatio),
    );

    return _cachedFuture<_MarkerPngCacheKey>(
      cache: _markerPngCache,
      key: key,
      maxEntries: _maxMarkerCacheEntries,
      render: () async {
        final showGlow = forceGlow ||
            tier == ArtMarkerSignal.featured ||
            tier == ArtMarkerSignal.legendary;

        return _renderFloatingBadgePng(
          baseColor: baseColor,
          icon: icon,
          shape: shape,
          tier: tier,
          style: style,
          roles: roles,
          showGlow: showGlow,
          forceGlow: forceGlow,
          showPromotionStar: showPromotionStar,
          isDark: isDark,
          pixelRatio: pixelRatio,
        );
      },
    );
  }

  /// Builds the body silhouette path for a badge [shape], centered on [center]
  /// with nominal extent [size].
  static Path _buildBadgePath(
    ArtMapMarkerShape shape,
    Offset center,
    double size,
  ) {
    final path = Path();
    final half = size / 2.0;

    switch (shape) {
      case ArtMapMarkerShape.roundedSquare:
        final r = math.min(KubusRadius.md, size * 0.30);
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: size, height: size),
            Radius.circular(r),
          ),
        );
        break;
      case ArtMapMarkerShape.diamond:
        final d = half * 1.18;
        path
          ..moveTo(center.dx, center.dy - d)
          ..lineTo(center.dx + d, center.dy)
          ..lineTo(center.dx, center.dy + d)
          ..lineTo(center.dx - d, center.dy)
          ..close();
        break;
      case ArtMapMarkerShape.arch:
        // Portal / arch: semicircular top, straight sides, slightly rounded base.
        final w = size * 0.86;
        final h = size * 1.0;
        final left = center.dx - w / 2;
        final right = center.dx + w / 2;
        final top = center.dy - h / 2;
        final bottom = center.dy + h / 2;
        final baseR = w * 0.18;
        path
          ..moveTo(left, bottom - baseR)
          ..lineTo(left, top + w / 2)
          ..arcToPoint(
            Offset(right, top + w / 2),
            radius: Radius.circular(w / 2),
            clockwise: true,
          )
          ..lineTo(right, bottom - baseR)
          ..arcToPoint(
            Offset(right - baseR, bottom),
            radius: Radius.circular(baseR),
            clockwise: true,
          )
          ..lineTo(left + baseR, bottom)
          ..arcToPoint(
            Offset(left, bottom - baseR),
            radius: Radius.circular(baseR),
            clockwise: true,
          )
          ..close();
        break;
      case ArtMapMarkerShape.pill:
        // Horizontal ticket / stadium.
        final w = size * 1.08;
        final h = size * 0.66;
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: w, height: h),
            Radius.circular(h / 2),
          ),
        );
        break;
      case ArtMapMarkerShape.hexagon:
        _addPolygon(path, center, half * 1.12, sides: 6, rotation: -math.pi / 2);
        break;
      case ArtMapMarkerShape.portalHex:
        // Flat-top hexagon (distinct orientation from the residency hexagon).
        _addPolygon(path, center, half * 1.12, sides: 6, rotation: 0);
        break;
      case ArtMapMarkerShape.capsule:
        // Vertical capsule (drop-like).
        final w = size * 0.66;
        final h = size * 1.04;
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: w, height: h),
            Radius.circular(w / 2),
          ),
        );
        break;
      case ArtMapMarkerShape.circle:
        path.addOval(Rect.fromCircle(center: center, radius: half * 1.06));
        break;
    }
    return path;
  }

  static void _addPolygon(
    Path path,
    Offset center,
    double radius, {
    required int sides,
    required double rotation,
  }) {
    for (var i = 0; i < sides; i++) {
      final angle = rotation + (2 * math.pi / sides) * i;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
  }

  /// Renders the floating badge (shaped body + glyph + shadow) into a tall PNG.
  ///
  /// The body lives in the upper region of the canvas with an intentional bottom
  /// gap, so the symbol layer (anchored at the icon's bottom) makes the badge
  /// hover above its coordinate dot.
  static Future<Uint8List> _renderFloatingBadgePng({
    required Color baseColor,
    required IconData icon,
    required ArtMapMarkerShape shape,
    required ArtMarkerSignal tier,
    required CubeMarkerStyle style,
    required KubusColorRoles roles,
    required bool showGlow,
    required bool forceGlow,
    required bool showPromotionStar,
    required bool isDark,
    double pixelRatio = 2.0,
  }) async {
    final iconForeground = _iconForegroundForTheme(isDark: isDark);

    return _renderPng(
      width: badgePngWidth,
      height: badgePngHeight,
      pixelRatio: pixelRatio,
      paint: (canvas, logicalSize) {
        final center = Offset(logicalSize.width / 2, badgeBodyCenterY);
        const bodySize = badgeBodySize;

        // Soft drop shadow beneath the floating body.
        final shadowPath = _buildBadgePath(
          shape,
          center + const Offset(0, 3.5),
          bodySize,
        );
        canvas.drawPath(
          shadowPath,
          Paint()
            ..color = style.shadowColor.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );

        // Optional colored glow for featured/legendary/selected badges.
        if (showGlow) {
          final glowPath = _buildBadgePath(shape, center, bodySize + 12);
          canvas.drawPath(
            glowPath,
            Paint()
              ..color = baseColor.withValues(alpha: forceGlow ? 0.42 : 0.30)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
          );
        }

        // Body fill (solid subject color).
        final bodyPath = _buildBadgePath(shape, center, bodySize);
        canvas.drawPath(bodyPath, Paint()..color = baseColor);

        // Subtle outline for crispness on both light and dark maps.
        canvas.drawPath(
          bodyPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25
            ..color = iconForeground.withValues(alpha: isDark ? 0.18 : 0.12),
        );

        // Centered icon glyph (no inner background box).
        if (icon.codePoint != 0) {
          final fontFamily = icon.fontFamily ?? 'MaterialIcons';
          final glyphPainter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontSize: bodySize * 0.5,
                fontFamily: fontFamily,
                fontFamilyFallback: const <String>[
                  'MaterialIcons',
                  'Material Symbols Outlined',
                ],
                package: icon.fontPackage,
                color: iconForeground,
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

        // Signal ring follows the body silhouette.
        if (tier != ArtMarkerSignal.subtle) {
          _paintSignalRing(
            canvas,
            shape: shape,
            center: center,
            size: bodySize + 5,
            tier: tier,
            baseColor: baseColor,
            roles: roles,
          );
        }

        if (showPromotionStar) {
          _paintPromotionStar(canvas, center, bodySize);
        }
      },
    );
  }

  static void _paintPromotionStar(
      Canvas canvas, Offset center, double squareSize) {
    final starCenter = Offset(
      center.dx + (squareSize * 0.31),
      center.dy - (squareSize * 0.31),
    );
    final outerRadius = squareSize * 0.16;
    final innerRadius = outerRadius * 0.52;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (-math.pi / 2) + (math.pi / 5) * i;
      final radius = i.isEven ? outerRadius : innerRadius;
      final point = Offset(
        starCenter.dx + math.cos(angle) * radius,
        starCenter.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawCircle(
      starCenter,
      outerRadius + 2.5,
      Paint()..color = const Color(0xCC111827),
    );
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFFFD54F),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFF59E0B),
    );
  }

  /// Paints a signal ring that follows the badge body silhouette.
  static void _paintSignalRing(
    Canvas canvas, {
    required ArtMapMarkerShape shape,
    required Offset center,
    required double size,
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

    final ringPath = _buildBadgePath(shape, center, size);

    canvas.drawPath(
      ringPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = glowColor.withValues(alpha: opacity),
    );
    canvas.drawPath(
      ringPath,
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
    TextStyle? labelStyleOverride,
    List<ClusterCategoryBadge> categories = const <ClusterCategoryBadge>[],
  }) async {
    final style = CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );
    final showGlow = count >= 10;
    final label = count > 99 ? '99+' : '$count';
    final iconForeground = _iconForegroundForTheme(isDark: isDark);

    // Only render the combined-category ring when the cluster actually mixes
    // more than one category; single-category clusters keep the clean badge.
    final combinedCategories = categories.length > 1
        ? categories
        : const <ClusterCategoryBadge>[];
    final categoryKey = combinedCategories
        .map((c) => '${c.shape.index}:${c.color.toARGB32()}')
        .join('|');

    final key = _ClusterPngCacheKey(
      baseColorValue: baseColor.toARGB32(),
      label: label,
      isDark: isDark,
      shadowColorValue: scheme.shadow.toARGB32(),
      pixelRatioKey: _pixelRatioKey(pixelRatio),
      labelStyleKey: _clusterLabelStyleKey(labelStyleOverride),
      categoryKey: categoryKey,
    );

    return _cachedFuture<_ClusterPngCacheKey>(
      cache: _clusterPngCache,
      key: key,
      maxEntries: _maxClusterCacheEntries,
      render: () async {
        final palette =
            _CubePalette.fromBase(baseColor, edgeColor: style.edgeColor);
        final labelStyle = (labelStyleOverride ?? KubusTextStyles.badgeCount)
            .copyWith(color: iconForeground);

        return _renderFlatClusterPng(
          label: label,
          labelStyle: labelStyle,
          iconForeground: iconForeground,
          baseColor: baseColor,
          palette: palette,
          style: style,
          showGlow: showGlow,
          categories: combinedCategories,
          isDark: isDark,
          pixelRatio: pixelRatio,
        );
      },
    );
  }

  static int _clusterLabelStyleKey(TextStyle? style) {
    if (style == null) return 0;
    return Object.hash(
      style.fontFamily,
      Object.hashAll(style.fontFamilyFallback ?? const <String>[]),
      style.fontSize,
      style.fontWeight?.value,
      style.fontStyle?.index,
      style.letterSpacing,
      style.height,
    );
  }

  static Future<Uint8List> _renderFlatClusterPng({
    required String label,
    required TextStyle labelStyle,
    required Color iconForeground,
    required Color baseColor,
    required _CubePalette palette,
    required CubeMarkerStyle style,
    required bool showGlow,
    required bool isDark,
    List<ClusterCategoryBadge> categories = const <ClusterCategoryBadge>[],
    double pixelRatio = 2.0,
  }) async {
    final isCombined = categories.length > 1;

    // Clusters use the same floating-badge language as single markers (a circle
    // body that reads as an aggregate node), so the map never mixes a separate
    // cube style with the new marker system.
    return _renderPng(
      width: badgePngWidth,
      height: badgePngHeight,
      pixelRatio: pixelRatio,
      paint: (canvas, logicalSize) {
        final center = Offset(logicalSize.width / 2, badgeBodyCenterY);
        const bodySize = badgeBodySize;

        if (isCombined) {
          _paintCombinedClusterBadge(
            canvas: canvas,
            center: center,
            label: label,
            labelStyle: labelStyle,
            iconForeground: iconForeground,
            baseColor: baseColor,
            style: style,
            showGlow: showGlow,
            isDark: isDark,
            categories: categories,
          );
          return;
        }

        final shadowPath = _buildBadgePath(
          ArtMapMarkerShape.circle,
          center + const Offset(0, 3.5),
          bodySize,
        );
        canvas.drawPath(
          shadowPath,
          Paint()
            ..color = style.shadowColor.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );

        if (showGlow) {
          final glowPath =
              _buildBadgePath(ArtMapMarkerShape.circle, center, bodySize + 12);
          canvas.drawPath(
            glowPath,
            Paint()
              ..color = baseColor.withValues(alpha: 0.28)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
          );
        }

        final bodyPath =
            _buildBadgePath(ArtMapMarkerShape.circle, center, bodySize);
        canvas.drawPath(bodyPath, Paint()..color = baseColor);

        canvas.drawPath(
          bodyPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = iconForeground.withValues(alpha: 0.16),
        );

        // Draw cluster count label directly on the subject-colored body.
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

  /// Paints a combined cluster badge: a ring of small category-shaped pips
  /// (one per dominant category, in that category's colour) around a central
  /// count circle. This makes a mixed cluster visually communicate the variety
  /// of categories it holds while keeping the count readable.
  static void _paintCombinedClusterBadge({
    required Canvas canvas,
    required Offset center,
    required String label,
    required TextStyle labelStyle,
    required Color iconForeground,
    required Color baseColor,
    required CubeMarkerStyle style,
    required bool showGlow,
    required bool isDark,
    required List<ClusterCategoryBadge> categories,
  }) {
    const double centralRadius = 14.5;
    const double ringRadius = 19.0;
    final int pipCount = categories.length;
    final double pipSize = pipCount <= 3 ? 16.0 : 14.0;

    // Soft drop shadow grounding the whole badge.
    canvas.drawCircle(
      center + const Offset(0, 3.5),
      ringRadius + pipSize / 2,
      Paint()
        ..color = style.shadowColor.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    if (showGlow) {
      canvas.drawCircle(
        center,
        ringRadius + pipSize / 2 + 4,
        Paint()
          ..color = baseColor.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    // Category pips evenly distributed around the ring, starting at the top.
    final pipOutline = iconForeground.withValues(alpha: isDark ? 0.32 : 0.85);
    for (var i = 0; i < pipCount; i++) {
      final angle = -math.pi / 2 + (2 * math.pi / pipCount) * i;
      final pipCenter = Offset(
        center.dx + math.cos(angle) * ringRadius,
        center.dy + math.sin(angle) * ringRadius,
      );
      final category = categories[i];

      // Tiny shadow so adjacent pips stay separated on busy map tiles.
      final pipShadow =
          _buildBadgePath(category.shape, pipCenter + const Offset(0, 1.0), pipSize);
      canvas.drawPath(
        pipShadow,
        Paint()
          ..color = style.shadowColor.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      final pipPath = _buildBadgePath(category.shape, pipCenter, pipSize);
      canvas.drawPath(pipPath, Paint()..color = category.color);
      canvas.drawPath(
        pipPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = pipOutline,
      );
    }

    // Central count circle drawn on top so the number is always legible.
    canvas.drawCircle(center, centralRadius, Paint()..color = baseColor);
    canvas.drawCircle(
      center,
      centralRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = iconForeground.withValues(alpha: isDark ? 0.22 : 0.85),
    );

    final scaledLabelStyle = labelStyle.copyWith(
      fontSize: (labelStyle.fontSize ?? 14.0) * 0.82,
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: scaledLabelStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy - labelPainter.height / 2,
      ),
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
