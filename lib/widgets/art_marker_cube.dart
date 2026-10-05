import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'map_marker_style_config.dart';

import 'package:flutter/material.dart';

import '../models/art_marker.dart';
import '../utils/app_color_utils.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import '../utils/map_marker_icon_ids.dart';
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
      case ArtMarkerType.exhibition:
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
    required this.icon,
  });

  final ArtMapMarkerShape shape;
  final Color color;
  final int count;

  /// Glyph for this category, drawn inside the cluster pip / single-category
  /// badge so a cluster communicates not just the shape + colour but the
  /// category icon used by individual markers of that type.
  final IconData icon;
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
    return isDark
        ? MarkerCubePalette.glyphDarkMode
        : MarkerCubePalette.glyphLightMode;
  }

  /// How large a glyph's em box is, as a fraction of the badge body's edge,
  /// tuned to each silhouette's own usable face.
  ///
  /// A Material glyph fills about 80% of its em box, so these land the visible
  /// glyph at roughly 55-70% of the face. They differ because the shapes do:
  /// a diamond and a pill have far less room than a rounded square or a
  /// hexagon, and a capsule is limited by its narrow width.
  @visibleForTesting
  static double glyphScaleFor(ArtMapMarkerShape shape) {
    switch (shape) {
      case ArtMapMarkerShape.roundedSquare:
        return 0.68;
      case ArtMapMarkerShape.diamond:
        return 0.54;
      case ArtMapMarkerShape.arch:
        return 0.62;
      case ArtMapMarkerShape.pill:
        return 0.50;
      case ArtMapMarkerShape.hexagon:
        return 0.64;
      case ArtMapMarkerShape.portalHex:
        return 0.64;
      case ArtMapMarkerShape.capsule:
        return 0.54;
      case ArtMapMarkerShape.circle:
        return 0.66;
    }
  }

  /// Optical vertical nudge for a glyph inside [shape]: the arch's rounded top
  /// leaves its visual mass low, so its glyph sits a little lower.
  static double _glyphNudgeY(ArtMapMarkerShape shape, double bodySize) {
    return shape == ArtMapMarkerShape.arch ? bodySize * 0.04 : 0.0;
  }

  /// The subject colour with its HSL lightness moved by [delta].
  static Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + delta).clamp(0.0, 1.0).toDouble())
        .toColor();
  }

  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance() + 0.05;
    final lb = b.computeLuminance() + 0.05;
    return la > lb ? la / lb : lb / la;
  }

  /// The glyph's tonal pair for a body of [field] colour: a tint of the
  /// category colour pushed toward white (light theme) or black (dark theme),
  /// lighter-to-deeper along the same diagonal as the body field.
  ///
  /// The theme polarity is the existing preference (white glyphs on the light
  /// map, black on the dark one). It is the starting point, not a rule: where a
  /// category colour cannot reach legible contrast that way (a pale yellow
  /// under a white glyph) the opposite polarity is used instead.
  @visibleForTesting
  static ({Color from, Color to}) glyphTintFor(
    Color field, {
    required bool isDark,
  }) {
    const double minContrast = 3.2;
    // The marker palette's own extremes, so no colour is declared here.
    const white = MarkerCubePalette.glyphLightMode;
    const black = MarkerCubePalette.glyphDarkMode;
    final preferred = isDark ? black : white;
    final opposite = isDark ? white : black;

    double reachable(Color target) =>
        _contrastRatio(Color.lerp(field, target, 0.96)!, field);

    final target = reachable(preferred) >= minContrast ||
            reachable(preferred) >= reachable(opposite)
        ? preferred
        : opposite;

    // Weakest acceptable tint: the further end of the pair.
    var t = 0.70;
    while (t < 0.96 &&
        _contrastRatio(Color.lerp(field, target, t)!, field) < minContrast) {
      t += 0.03;
    }
    return (
      // Never all the way to the extreme: a tint that reaches pure white or
      // black is just the plain ink this exists to replace.
      from: Color.lerp(field, target, math.min(0.97, t + 0.12))!,
      to: Color.lerp(field, target, t)!,
    );
  }

  /// The face glyph's tonal pair for a body of [field] colour, independent of
  /// the map theme: a light tint of the category colour (the light falls from
  /// the upper left, as on a stat card), or a deep shade of it where the
  /// category colour is too pale to carry a light glyph. Never plain black or
  /// white: the glyph is made of the category colour.
  @visibleForTesting
  static ({Color from, Color to}) faceGlyphTintFor(Color field) {
    const double minContrast = 3.0;
    const light = MarkerCubePalette.glyphLightMode;
    const dark = MarkerCubePalette.glyphDarkMode;
    double reach(Color target) =>
        _contrastRatio(Color.lerp(field, target, 0.9)!, field);
    final target = reach(light) >= minContrast ? light : dark;
    var t = 0.62;
    while (t < 0.92 &&
        _contrastRatio(Color.lerp(field, target, t)!, field) < minContrast) {
      t += 0.03;
    }
    return (
      from: Color.lerp(field, target, math.min(0.94, t + 0.14))!,
      to: Color.lerp(field, target, t)!,
    );
  }

  /// The PRODUCT v5 marker face: a [KubusStatCard] compressed into the
  /// category's cartographic silhouette.
  ///
  /// Inside [bodyPath]:
  /// * the category colour as a directional tonal field (light upper left,
  ///   deep lower right), with an atmospheric wash where the light falls;
  /// * the category glyph oversized and cropped off the trailing corner. At
  ///   map scale this ghost glyph *is* the category signal; there is no small
  ///   icon floating dead centre;
  /// * an accent rim: a light active edge on the lit side fading into a deep
  ///   edge on the shaded side.
  /// [selected] strengthens the field, the wash and the rim. [glyphOpacity]
  /// lets a cluster quieten the glyph under its count.
  static void _paintExpressiveFace({
    required Canvas canvas,
    required Path bodyPath,
    required Color color,
    required IconData? glyph,
    required ArtMapMarkerShape shape,
    bool selected = false,
    double glyphOpacity = 0.62,
    double glyphScale = 1.12,
    Offset glyphShift = const Offset(0.20, 0.17),
  }) {
    final bounds = bodyPath.getBounds();
    final lift = selected ? 0.13 : 0.10;
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          <Color>[_shiftLightness(color, lift), _shiftLightness(color, -0.15)],
        ),
    );

    canvas.save();
    canvas.clipPath(bodyPath);

    // Atmospheric wash where the light falls (the stat card's field, inverted:
    // the whole body is already the category colour).
    final washCenter = Offset(
      bounds.left + bounds.width * 0.24,
      bounds.top + bounds.height * 0.20,
    );
    canvas.drawCircle(
      washCenter,
      bounds.longestSide * 0.78,
      Paint()
        ..shader = ui.Gradient.radial(
          washCenter,
          bounds.longestSide * 0.78,
          <Color>[
            MarkerCubePalette.glyphLightMode
                .withValues(alpha: selected ? 0.30 : 0.20),
            MarkerCubePalette.glyphLightMode.withValues(alpha: 0),
          ],
        ),
    );

    // Oversized ghost glyph, cropped off the trailing (lower-right) corner.
    if (glyph != null && glyph.codePoint != 0) {
      final tint = faceGlyphTintFor(color);
      final size = math.min(bounds.width, bounds.height) *
          _ghostGlyphFactor(shape) *
          glyphScale;
      final center = bounds.center +
          Offset(bounds.width * glyphShift.dx, bounds.height * glyphShift.dy) +
          Offset(0, _glyphNudgeY(shape, bounds.height));
      _paintTonalGlyph(
        canvas: canvas,
        center: center,
        glyph: glyph,
        size: size,
        from: tint.from.withValues(alpha: glyphOpacity),
        to: tint.to.withValues(alpha: glyphOpacity * 0.82),
      );
    }
    canvas.restore();

    // Accent rim: lit edge upper left, deep edge lower right.
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.0 : 1.4
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          <Color>[
            Color.lerp(color, MarkerCubePalette.glyphLightMode,
                    selected ? 0.75 : 0.55)!
                .withValues(alpha: selected ? 0.95 : 0.80),
            _shiftLightness(color, -0.24).withValues(alpha: 0.75),
          ],
        ),
    );
  }

  /// Ghost glyph size as a fraction of the silhouette's shorter side. Larger
  /// than the face (so it crops), tuned per shape so the visible part keeps
  /// the glyph's recognisable mass.
  static double _ghostGlyphFactor(ArtMapMarkerShape shape) {
    switch (shape) {
      case ArtMapMarkerShape.roundedSquare:
      case ArtMapMarkerShape.circle:
        return 0.98;
      case ArtMapMarkerShape.hexagon:
      case ArtMapMarkerShape.portalHex:
        return 0.92;
      case ArtMapMarkerShape.arch:
        return 0.94;
      case ArtMapMarkerShape.diamond:
        return 0.80;
      case ArtMapMarkerShape.pill:
        return 1.02;
      case ArtMapMarkerShape.capsule:
        return 0.96;
    }
  }

  /// A count that stays legible on [field]: light ink where it clears
  /// contrast, otherwise a deep shade of the field itself.
  static Color _countInkFor(Color field) {
    const light = MarkerCubePalette.glyphLightMode;
    if (_contrastRatio(light, field) >= 3.0) return light;
    return _shiftLightness(field, -0.62);
  }

  /// Paints [glyph] centred at [center] with a tonal gradient instead of a
  /// flat ink: the same diagonal as the body field, so the glyph reads as part
  /// of the face rather than a sticker on it.
  static void _paintTonalGlyph({
    required Canvas canvas,
    required Offset center,
    required IconData glyph,
    required double size,
    required Color from,
    required Color to,
  }) {
    if (glyph.codePoint == 0) return;
    TextPainter build(Paint? foreground) => TextPainter(
          text: TextSpan(
            text: String.fromCharCode(glyph.codePoint),
            style: TextStyle(
              fontSize: size,
              fontFamily: glyph.fontFamily ?? 'MaterialIcons',
              fontFamilyFallback: const <String>[
                'MaterialIcons',
                'Material Symbols Outlined',
              ],
              package: glyph.fontPackage,
              foreground: foreground,
              color: foreground == null ? from : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

    final measure = build(null)..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: measure.width,
      height: measure.height,
    );
    final painter = build(
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          <Color>[from, to],
        ),
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
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

  /// Renders the canonical badge with an artwork [cover] inside its geometry.
  ///
  /// The silhouette (shape), category-colour rim, signal ring and promotion
  /// star are exactly the mid-level marker's; only the face changes from glyph
  /// to photograph, clipped to the shape inset by [coverRimWidth]. Covers are
  /// per marker and per URL, so the result is not cached here: the map's cover
  /// registry owns the bounded set of live cover images.
  static Future<Uint8List> renderCoverMarkerPng({
    required ui.Image cover,
    required Color baseColor,
    required ArtMarkerSignal tier,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required bool isDark,
    ArtMapMarkerShape shape = ArtMapMarkerShape.roundedSquare,
    bool forceGlow = false,
    bool showPromotionStar = false,
    double pixelRatio = 2.0,
  }) {
    final style = CubeMarkerStyle.fromScheme(
      scheme: scheme,
      isDark: isDark,
      baseColor: baseColor,
    );
    final showGlow = forceGlow ||
        tier == ArtMarkerSignal.featured ||
        tier == ArtMarkerSignal.legendary;
    return _renderFloatingBadgePng(
      baseColor: baseColor,
      icon: const IconData(0),
      shape: shape,
      tier: tier,
      style: style,
      roles: roles,
      showGlow: showGlow,
      forceGlow: forceGlow,
      showPromotionStar: showPromotionStar,
      isDark: isDark,
      pixelRatio: pixelRatio,
      cover: cover,
    );
  }

  /// Width of the category-colour rim kept around a cover so photography never
  /// erases the marker's identity.
  static const double coverRimWidth = 2.5;

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
        _addPolygon(path, center, half * 1.12,
            sides: 6, rotation: -math.pi / 2);
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
    ui.Image? cover,
  }) async {
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

        // Body: the expressive face (field, wash, cropped ghost glyph, rim).
        // A cover replaces the glyph; the rim and field stay around it.
        final bodyPath = _buildBadgePath(shape, center, bodySize);
        _paintExpressiveFace(
          canvas: canvas,
          bodyPath: bodyPath,
          color: baseColor,
          glyph: cover == null ? icon : null,
          shape: shape,
          selected: forceGlow,
        );

        if (cover != null) {
          // Artwork cover inside the canonical geometry: clipped to the shape
          // inset by the rim, scaled to fill (centre crop).
          final inner = _buildBadgePath(
            shape,
            center,
            bodySize - (coverRimWidth * 2),
          );
          final target = inner.getBounds();
          // Centre crop to the target's own aspect: pill, arch, capsule and
          // hexagon badges are not square, and a square crop drawn into them
          // would stretch the cover.
          final coverWidth = cover.width.toDouble();
          final coverHeight = cover.height.toDouble();
          final targetAspect =
              target.height > 0 ? target.width / target.height : 1.0;
          final coverAspect = coverHeight > 0 ? coverWidth / coverHeight : 1.0;
          final source = Rect.fromCenter(
            center: Offset(coverWidth / 2, coverHeight / 2),
            width: coverAspect > targetAspect
                ? coverHeight * targetAspect
                : coverWidth,
            height: coverAspect > targetAspect
                ? coverHeight
                : coverWidth / targetAspect,
          );
          canvas.save();
          canvas.clipPath(inner);
          canvas.drawImageRect(
            cover,
            source,
            target,
            Paint()..filterQuality = FilterQuality.medium,
          );
          canvas.restore();
        }

        if (cover != null) {
          // The category rim stays visible around the photograph.
          canvas.drawPath(
            bodyPath,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = forceGlow ? 2.0 : 1.4
              ..color = Color.lerp(baseColor, MarkerCubePalette.glyphLightMode,
                      forceGlow ? 0.55 : 0.25)!
                  .withValues(alpha: 0.9),
          );
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
      Paint()..color = MarkerCubePalette.starHaloInk,
    );
    canvas.drawPath(
      path,
      Paint()..color = MarkerCubePalette.starFill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = MarkerCubePalette.starStroke,
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

    // Carry every resolved category (shape + colour + glyph) through to the
    // renderer so the badge always communicates category identity:
    // - 2+ categories => a combined ring of category-shaped pips with glyphs;
    // - exactly 1 category => that category's shape/colour/glyph plus count
    //   (no generic circle);
    // - 0 categories => last-resort generic fallback only.
    //
    // The cache key folds in each category's shape/colour/glyph and the visual
    // renderer version so a composition or renderer change never reuses a stale
    // (e.g. old generic-circle) cluster image.
    final categoryKey = <String>[
      MapMarkerIconIds.clusterRendererVersion,
      for (final c in categories)
        '${c.shape.index}:${c.color.toARGB32()}:${c.icon.codePoint}',
    ].join('|');

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
          categories: categories,
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
    final isSingleCategory = categories.length == 1;

    // Clusters reuse the floating-badge language of single markers, but never a
    // generic circle when category data is available:
    // - mixed clusters get a ring of category-shaped pips (with glyphs);
    // - single-category clusters take that category's shape/colour/glyph;
    // - only a category-less cluster (data error) falls back to a plain circle.
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

        if (isSingleCategory) {
          _paintSingleCategoryClusterBadge(
            canvas: canvas,
            center: center,
            bodySize: bodySize,
            label: label,
            labelStyle: labelStyle,
            iconForeground: iconForeground,
            style: style,
            showGlow: showGlow,
            isDark: isDark,
            category: categories.first,
          );
          return;
        }

        // Last-resort fallback (no category data): generic circle + count.
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

  /// Paints a single-category cluster: the category's shape + colour (matching
  /// individual markers of that type) with a small category glyph in the upper
  /// body and the count centred below it, so the cluster still reads as that
  /// category rather than a generic circle.
  static void _paintSingleCategoryClusterBadge({
    required Canvas canvas,
    required Offset center,
    required double bodySize,
    required String label,
    required TextStyle labelStyle,
    required Color iconForeground,
    required CubeMarkerStyle style,
    required bool showGlow,
    required bool isDark,
    required ClusterCategoryBadge category,
  }) {
    final shape = category.shape;
    final color = category.color;

    final shadowPath =
        _buildBadgePath(shape, center + const Offset(0, 3.5), bodySize);
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = style.shadowColor.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    if (showGlow) {
      final glowPath = _buildBadgePath(shape, center, bodySize + 12);
      canvas.drawPath(
        glowPath,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    // The same face as a single marker of this category, with the ghost
    // glyph quietened so the count leads: identity from shape, field and
    // count, not from icon detail.
    final bodyPath = _buildBadgePath(shape, center, bodySize);
    _paintExpressiveFace(
      canvas: canvas,
      bodyPath: bodyPath,
      color: color,
      glyph: category.icon,
      shape: shape,
      glyphOpacity: 0.40,
      glyphScale: 1.1,
      glyphShift: const Offset(0.26, 0.24),
    );

    final countStyle = labelStyle.copyWith(
      fontSize: (labelStyle.fontSize ?? 14.0) * 1.18,
      fontWeight: FontWeight.w800,
      color: _countInkFor(color),
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: countStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    // Upper left, where the light falls and the ghost glyph is not.
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - bodySize * 0.10 - labelPainter.width / 2,
        center.dy - bodySize * 0.09 - labelPainter.height / 2,
      ),
    );
  }

  /// Paints a mixed cluster: the dominant category's silhouette and face carry
  /// the badge and its count; each secondary category is a small plain
  /// silhouette in its own colour tucked behind the dominant body's trailing
  /// edge. At far scale identity comes from shape, field and count; the
  /// secondary cue is geometry and colour only, never a tiny icon.
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
    final dominant = categories.first;
    final secondary = categories.skip(1).take(3).toList();
    // Secondary categories fan out behind the trailing edge, upper right to
    // lower right, so they read as "and also" rather than as equals.
    const angles = <double>[-0.55, 0.05, 0.65];
    Offset pipOffset(int i, double radius) =>
        Offset(math.cos(angles[i]) * radius, math.sin(angles[i]) * radius);

    // Fit the composition to the canvas from the real silhouettes (a diamond
    // is wider than its nominal size): body plus pips, centred horizontally
    // with a 2 px margin and scaled down only when they cannot fit.
    const double baseMainSize = 36.0;
    const double basePipSize = 17.0;
    var bounds =
        _buildBadgePath(dominant.shape, Offset.zero, baseMainSize).getBounds();
    for (var i = 0; i < secondary.length; i++) {
      bounds = bounds.expandToInclude(_buildBadgePath(
        secondary[i].shape,
        pipOffset(i, baseMainSize * 0.6),
        basePipSize,
      ).getBounds());
    }
    final fit = math.min(1.0, (badgePngWidth - 4) / bounds.width);
    final mainSize = baseMainSize * fit;
    final pipSize = basePipSize * fit;
    final pipRadius = mainSize * 0.6;
    final mainCenter =
        Offset(center.dx - bounds.center.dx * fit, center.dy + 1);

    // Soft drop shadow grounding the whole badge.
    canvas.drawPath(
      _buildBadgePath(
          dominant.shape, mainCenter + const Offset(0, 3.5), mainSize + 6),
      Paint()
        ..color = style.shadowColor.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    if (showGlow) {
      canvas.drawPath(
        _buildBadgePath(dominant.shape, mainCenter, mainSize + 10),
        Paint()
          ..color = dominant.color.withValues(alpha: 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    for (var i = 0; i < secondary.length; i++) {
      final category = secondary[i];
      final pipCenter = mainCenter + pipOffset(i, pipRadius);
      final pipPath = _buildBadgePath(category.shape, pipCenter, pipSize);
      canvas.drawPath(
        pipPath,
        Paint()
          ..shader = ui.Gradient.linear(
            pipPath.getBounds().topLeft,
            pipPath.getBounds().bottomRight,
            <Color>[
              _shiftLightness(category.color, 0.08),
              _shiftLightness(category.color, -0.14),
            ],
          ),
      );
      canvas.drawPath(
        pipPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color =
              _shiftLightness(category.color, -0.26).withValues(alpha: 0.85),
      );
    }

    final mainPath = _buildBadgePath(dominant.shape, mainCenter, mainSize);
    _paintExpressiveFace(
      canvas: canvas,
      bodyPath: mainPath,
      color: dominant.color,
      glyph: dominant.icon,
      shape: dominant.shape,
      glyphOpacity: 0.36,
      glyphScale: 1.1,
      glyphShift: const Offset(0.26, 0.24),
    );

    final countStyle = labelStyle.copyWith(
      fontSize: (labelStyle.fontSize ?? 14.0) * 1.02,
      fontWeight: FontWeight.w800,
      color: _countInkFor(dominant.color),
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: countStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(
        mainCenter.dx - mainSize * 0.06 - labelPainter.width / 2,
        mainCenter.dy - mainSize * 0.05 - labelPainter.height / 2,
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
        ..color = MarkerCubePalette.clear
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
