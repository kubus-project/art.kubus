import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// Optional texture painted inside a [KubusAtmosphere].
enum KubusAtmosphereTexture {
  /// Light only: diffuse colour fields and the edge light.
  none,

  /// The bundled Ljubljana street map, faded in from the trailing edge. Real
  /// geography, not decoration: use it where the surface introduces the map
  /// or a place (home discovery, public art context).
  cartographic,
}

/// PRODUCT v5 art-directed identity field.
///
/// The one place a screen may carry an atmosphere: a surface lit by a diffuse
/// field of its contextual colour from one corner and a quieter field of the
/// secondary colour from the opposite corner, closed by a hairline whose top
/// edge catches the accent. An oversized [glyph] can sit cropped in the
/// trailing corner as visual material. Content sits on the plain surface
/// colour underneath, so contrast is the ordinary surface contrast.
///
/// Use it for page identity and hero context (home discovery, profile cover
/// fallback, creator hub header, wallet balance, achievement summary,
/// governance intro). Never for list rows, settings groups, form fields or
/// cards inside cards: if every surface glows, none of them does.
class KubusAtmosphere extends StatelessWidget {
  const KubusAtmosphere({
    super.key,
    required this.accent,
    required this.child,
    this.secondary,
    this.glyph,
    this.glyphExtent,
    this.texture = KubusAtmosphereTexture.none,
    this.padding = const EdgeInsets.all(KubusSpacing.lg),
    this.borderRadius,
    this.framed = true,
    this.fieldAlignment = Alignment.topRight,
    this.glyphAlignment,
    this.base,
  });

  /// Contextual colour from [KubusColorRoles]; never a raw literal.
  final Color accent;
  final Widget child;

  /// Counter field; defaults to the family secondary (information blue).
  final Color? secondary;
  final IconData? glyph;

  /// Glyph size; defaults to 1.25x the surface's shorter side, clamped.
  final double? glyphExtent;
  final KubusAtmosphereTexture texture;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  /// Rounded, hairline-ruled surface. `false` paints a full-bleed field (a
  /// page band or a cover) with no rule and no radius.
  final bool framed;

  /// Where the accent field and the glyph live; the secondary field takes
  /// the opposite corner.
  final Alignment fieldAlignment;

  /// Corner for the glyph when it should not share the field's corner (for
  /// example to stay clear of a control). Defaults to [fieldAlignment].
  final Alignment? glyphAlignment;

  /// Fill under the fields; defaults to the surface. Covers use the raised
  /// surface so the band separates from the card body below it.
  final Color? base;

  /// Field strengths per theme. Dark grounds take more light before a
  /// colour field reads as a tint rather than a block.
  static double accentFieldAlpha(Brightness b) =>
      b == Brightness.dark ? 0.20 : 0.13;
  static double secondaryFieldAlpha(Brightness b) =>
      b == Brightness.dark ? 0.09 : 0.06;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final brightness = Theme.of(context).brightness;
    final radius = framed
        ? (borderRadius ?? BorderRadius.circular(KubusRadius.lg))
        : BorderRadius.zero;
    final counter = secondary ?? roles.secondary;
    final opposite = Alignment(-fieldAlignment.x, -fieldAlignment.y);

    return Container(
      key: const ValueKey<String>('kubus_atmosphere'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: base ?? roles.surface,
        borderRadius: radius,
        border: framed ? KubusBorders.hairline(context) : null,
      ),
      child: Stack(
        children: [
          if (texture == KubusAtmosphereTexture.cartographic)
            Positioned.fill(
              child: _CartographicTexture(
                brightness: brightness,
                fadeFrom: fieldAlignment,
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: fieldAlignment,
                    radius: 1.15,
                    colors: [
                      accent.withValues(alpha: accentFieldAlpha(brightness)),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: opposite,
                    radius: 0.9,
                    colors: [
                      counter.withValues(
                          alpha: secondaryFieldAlpha(brightness)),
                      counter.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (glyph != null)
            Positioned.fill(
              child: KubusGhostGlyph(
                icon: glyph!,
                color: accent,
                alignment: glyphAlignment ?? fieldAlignment,
                extent: glyphExtent,
              ),
            ),
          if (framed)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: KubusEdgeLight(color: accent, from: fieldAlignment),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A one-pixel edge that catches the contextual colour at one end and fades
/// out across the surface: the "edge light" of an art-directed surface.
class KubusEdgeLight extends StatelessWidget {
  const KubusEdgeLight({
    super.key,
    required this.color,
    this.from = Alignment.topRight,
    this.strength = 0.65,
  });

  final Color color;
  final Alignment from;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final fromRight = from.x >= 0;
    return IgnorePointer(
      child: SizedBox(
        height: KubusSizes.hairline,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: fromRight ? Alignment.centerRight : Alignment.centerLeft,
              end: fromRight ? Alignment.centerLeft : Alignment.centerRight,
              colors: [
                color.withValues(alpha: strength),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An oversized, cropped, low-opacity contextual glyph used as visual
/// material: it bleeds off the corner named by [alignment] so only part of
/// the symbol shows. Decorative by contract: no semantics, no hit testing.
///
/// Place it as a full-size layer of a clipped [Stack]
/// (`Positioned.fill(child: KubusGhostGlyph(...))`).
class KubusGhostGlyph extends StatelessWidget {
  const KubusGhostGlyph({
    super.key,
    required this.icon,
    required this.color,
    this.alignment = Alignment.bottomRight,
    this.extent,
    this.bleed = 0.28,
    this.opacity,
    this.scale = 1,
    this.shift = Offset.zero,
  });

  final IconData icon;
  final Color color;
  final Alignment alignment;

  /// Glyph size. Defaults to 1.25x the shorter side of the layer, clamped to
  /// 56-220 px so tiny tiles keep a recognisable shape and heroes do not
  /// turn into wallpaper.
  final double? extent;

  /// Fraction of the glyph pushed past the edge (cropped).
  final double bleed;

  /// Glyph opacity; defaults to [defaultOpacity] for the ambient theme.
  final double? opacity;

  /// Hover response hooks (applied as paint transforms, never layout).
  final double scale;
  final Offset shift;

  static double defaultOpacity(Brightness b) =>
      b == Brightness.dark ? 0.11 : 0.085;

  static double extentFor(Size size) =>
      (math.min(size.width, size.height) * 1.25).clamp(56.0, 220.0);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final alpha = opacity ?? defaultOpacity(brightness);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              if (!size.isFinite || size.isEmpty) {
                return const SizedBox.shrink();
              }
              final glyphSize = extent ?? extentFor(size);
              final overhang = glyphSize * bleed;
              final dx = alignment.x >= 0 ? null : -overhang;
              final dxRight = alignment.x >= 0 ? -overhang : null;
              final dy = alignment.y >= 0 ? null : -overhang;
              final dyBottom = alignment.y >= 0 ? -overhang : null;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: dx,
                    right: dxRight,
                    top: dy,
                    bottom: dyBottom,
                    child: Transform.translate(
                      offset: shift,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment(-alignment.x, -alignment.y),
                        child: Icon(
                          icon,
                          size: glyphSize,
                          color: color.withValues(alpha: alpha),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Pointer-only hover response for interactive art-directed surfaces.
///
/// Reports hover to [builder] and, when [lift] is set, raises the child by
/// a paint-only translation (layout never moves). Touch input never hovers.
/// With reduced motion ([MediaQuery.disableAnimationsOf]) there is no
/// movement; [builder] still receives the hover state so tint and edge can
/// answer without motion.
class KubusHoverResponse extends StatefulWidget {
  const KubusHoverResponse({
    super.key,
    required this.builder,
    this.lift = false,
    this.cursor = MouseCursor.defer,
    this.enabled = true,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final bool lift;
  final MouseCursor cursor;

  /// A disabled response never reports hover and never lifts, but keeps the
  /// same widget structure, so toggling it does not remount the child.
  final bool enabled;

  /// Hover answer timing, shared by everything built on this primitive.
  static const Duration duration = Duration(milliseconds: 180);
  static const double liftDistance = 2;

  /// Whether decorative movement is allowed in [context].
  static bool motionAllowed(BuildContext context) =>
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// Distance a navigation arrow travels toward its destination on hover.
  static const double arrowTravel = 2;

  /// Soft contextual shadow under a hovered, lifted surface.
  ///
  /// A tinted drop (offset down, negative spread) rather than a glow: it
  /// grounds the 2 px lift in the destination's own colour and never blooms
  /// around the tile. Dark grounds need more alpha before a coloured shadow
  /// registers at all.
  static List<BoxShadow> accentShadow(
    Color accent,
    Brightness brightness, {
    required bool hovered,
  }) {
    // The resting entry is the same shadow at **alpha 0**, not an empty list.
    //
    // An empty list looks like "nothing at rest", but it makes
    // [BoxShadow.lerpList] fall back to `BoxShadow.scale(t)`, which
    // interpolates blur and spread while leaving the colour — and therefore
    // the alpha — at its final value. The shadow then snaps to full strength
    // on the first animated frame and only grows its blur, which is exactly
    // the popping this helper exists to avoid. Keeping both ends of the lerp
    // present, with identical geometry, makes it a plain alpha fade.
    //
    // It costs nothing at rest: a `SrcOver` draw with alpha 0 has nothing to
    // draw, so the transparent blur is never rasterised.
    final peak = brightness == Brightness.dark ? 0.34 : 0.24;
    return <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: hovered ? peak : 0),
        blurRadius: 18,
        spreadRadius: -5,
        offset: const Offset(0, 8),
      ),
    ];
  }

  @override
  State<KubusHoverResponse> createState() => _KubusHoverResponseState();
}

class _KubusHoverResponseState extends State<KubusHoverResponse> {
  bool _hovered = false;

  void _set(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final motion = KubusHoverResponse.motionAllowed(context);
    final hovered = _hovered && widget.enabled;
    final child = widget.builder(context, hovered);
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (event) => _set(true),
      onExit: (_) => _set(false),
      child: !widget.lift
          ? child
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(
                end: hovered && motion ? -KubusHoverResponse.liftDistance : 0,
              ),
              duration: motion ? KubusHoverResponse.duration : Duration.zero,
              curve: Curves.easeOutCubic,
              child: child,
              builder: (context, dy, child) =>
                  Transform.translate(offset: Offset(0, dy), child: child),
            ),
    );
  }
}

class _CartographicTexture extends StatelessWidget {
  const _CartographicTexture({
    required this.brightness,
    required this.fadeFrom,
  });

  final Brightness brightness;
  final Alignment fadeFrom;

  /// The dark tile encodes streets as light on black: luminance is directly
  /// the line mask, in either theme. (The light tile is inverted, white
  /// roads on grey paper, so it cannot serve as a mask.)
  static const String maskAsset =
      'assets/images/backgrounds/background_map_dark.png';

  /// Turns the map tile into line work: street luminance becomes alpha and
  /// every street is drawn in [ink], so the texture sits on any surface in
  /// either theme instead of painting its own paper.
  static List<double> inkMatrix(Color ink) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    // ~10 ground maps to 0, the brightest streets (~68) to ~1.
    const k = 4.2, b = -42.0;
    return <double>[
      0, 0, 0, 0, ink.r * 255, //
      0, 0, 0, 0, ink.g * 255, //
      0, 0, 0, 0, ink.b * 255, //
      lr * k, lg * k, lb * k, 0, b,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final roles = KubusColorRoles.of(context);
    final fromRight = fadeFrom.x >= 0;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: fromRight ? Alignment.centerRight : Alignment.centerLeft,
            end: fromRight ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              roles.foreground.withValues(alpha: dark ? 0.30 : 0.26),
              roles.foreground.withValues(alpha: dark ? 0.12 : 0.10),
              roles.foreground.withValues(alpha: 0),
            ],
            stops: const [0, 0.5, 0.9],
          ).createShader(bounds),
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(
              inkMatrix(roles.foreground),
            ),
            // Drawn at 1.6x, anchored to the trailing edge: the tile's city
            // label (left of centre) leaves the frame, so only street line
            // work ever sits behind the text column.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math.max(
                  constraints.maxWidth * 1.6,
                  constraints.maxHeight * 1.6,
                );
                return ClipRect(
                  child: OverflowBox(
                    alignment: fromRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    minWidth: side,
                    maxWidth: side,
                    minHeight: side,
                    maxHeight: side,
                    child: Image.asset(
                      maskAsset,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
