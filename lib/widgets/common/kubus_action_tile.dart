import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../inline_loading.dart';
import 'kubus_atmosphere.dart';

enum KubusActionTileLayout {
  /// Phone grid: the title anchored low, the destination glyph cropped in
  /// the opposite corner.
  stacked,

  /// Desktop strip: title and a navigation arrow in one row.
  inline,

  /// Dense management destination (settings, security, account): a full-width
  /// row with the title, an optional one-line subtitle, an optional [status]
  /// and the arrow, over a small cropped glyph. It answers hover quietly
  /// (field, edge and a leading indicator; no lift, no shadow, no drift) so a
  /// list of them does not bob.
  compact,
}

/// PRODUCT v5 destination tile (home quick actions, settings destinations and
/// similar shortcuts).
///
/// One semantic idea per layer: the title names the destination, the
/// destination's contextual colour (map teal, studio coral, institution
/// blue, governance green, …) sets the field and the edge light, and on the
/// stacked tile the destination's glyph sits cropped oversized in the
/// trailing corner as decorative identity. There is no foreground icon box:
/// it would only repeat what the title, colour and glyph already say. The
/// inline tile is too short for a legible glyph, so it is field, title and a
/// navigation arrow (the arrow is the affordance, not identity). The compact
/// tile carries a small cropped glyph for scanability in long lists; it never
/// moves.
///
/// Hover contract (pointer only; touch never hovers):
///
/// - stacked and inline: a 2 px paint-only lift, a stronger accent field and
///   edge, a soft contextual accent shadow ([KubusHoverResponse.accentShadow])
///   and, for stacked, a 2-4 px / 1.03x drift of the clipped ghost glyph or,
///   for inline, a 2 px arrow travel. 180 ms ease-out. Nothing reflows.
/// - compact: field, edge and a leading indicator only.
/// - reduced motion: no lift, no glyph drift, no arrow travel; the field,
///   edge and shadow state still change so the tile still answers.
///
/// The title owns the button semantics (the optional [subtitle] is its hint);
/// the glyph and arrow are excluded from the tree. Minimum 44 px target,
/// titles wrap to two lines and the tile grows with the text.
///
/// Width contract: stacked and compact tiles fill their slot. An inline tile
/// sizes to its title but never exceeds [inlineMaxWidth] (scaled with the
/// text), so it still wraps when its parent gives it an unbounded width, as
/// in a horizontally scrolling strip. A narrower slot wins.
class KubusActionTile extends StatelessWidget {
  const KubusActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.layout = KubusActionTileLayout.stacked,
    this.minHeight,
    this.subtitle,
    this.status,
    this.enabled = true,
    this.loading = false,
  });

  final String title;

  /// Destination glyph, drawn as the stacked tile's cropped ghost glyph.
  final IconData icon;

  /// Destination colour from [KubusColorRoles] / `AppColorUtils`.
  final Color accent;
  final VoidCallback onTap;
  final KubusActionTileLayout layout;
  final double? minHeight;

  /// One-line explanation under the title ([KubusActionTileLayout.stacked]
  /// and [KubusActionTileLayout.compact] only; the inline strip is too short).
  final String? subtitle;

  /// A state that coexists with the destination (verification, connection,
  /// locked, labs): before the arrow on a [KubusActionTileLayout.compact]
  /// tile, above the title on a [KubusActionTileLayout.stacked] one. It says
  /// something the title does not, so it is not a second identity.
  final Widget? status;

  /// A disabled tile drops its colour to the muted family tone, takes no tap
  /// and does not answer hover. Say why in [subtitle].
  final bool enabled;

  /// An action in flight: a spinner replaces the arrow (compact) or sits in
  /// the glyph corner (stacked), and the tile takes no further taps.
  final bool loading;

  /// Widest an inline tile grows at 1x text, before the text scale.
  static const double inlineMaxWidth = 280;

  /// Cropped glyph size on a compact tile.
  static const double compactGlyphExtent = 56;

  /// Ghost glyph drift on a hovered stacked tile (paint only).
  static const double glyphShift = 3;
  static const double glyphScale = 1.03;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final brightness = Theme.of(context).brightness;
    final interactive = enabled && !loading;
    final accent = enabled ? this.accent : roles.foregroundSubtle;
    final motion = KubusHoverResponse.motionAllowed(context);
    final stacked = layout == KubusActionTileLayout.stacked;
    final compact = layout == KubusActionTileLayout.compact;
    final lifts = !compact;
    final hasSubtitle =
        subtitle != null && !(layout == KubusActionTileLayout.inline);
    final radius = BorderRadius.circular(KubusRadius.md);
    final maxWidth = layout == KubusActionTileLayout.inline
        ? MediaQuery.textScalerOf(context).scale(inlineMaxWidth)
        : double.infinity;

    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      style: KubusTextStyles.detailCardTitle.copyWith(
        color: enabled ? roles.foreground : roles.foregroundSubtle,
        fontWeight: FontWeight.w600,
      ),
    );
    final subtitleText = hasSubtitle
        ? Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KubusTextStyles.detailCaption.copyWith(
              color: roles.foregroundMuted,
            ),
          )
        : null;

    Widget arrow(bool hovered) => loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: InlineLoading(
              expand: true,
              shape: BoxShape.circle,
              tileSize: 3,
            ),
          )
        : ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                end: hovered && motion && lifts
                    ? KubusHoverResponse.arrowTravel
                    : 0,
              ),
              duration: motion ? KubusHoverResponse.duration : Duration.zero,
              curve: Curves.easeOutCubic,
              builder: (context, dx, child) =>
                  Transform.translate(offset: Offset(dx, 0), child: child),
              child: Icon(Icons.arrow_forward, size: 16, color: accent),
            ),
          );

    Widget body(bool hovered) {
      if (stacked) {
        // The title sits on the lower edge, clear of the glyph's corner, so
        // the composition reads diagonally: glyph above-right, name
        // below-left. A [status] stands above the title.
        final text = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleText,
            if (subtitleText != null) ...[
              const SizedBox(height: KubusSpacing.xxs),
              subtitleText,
            ],
          ],
        );
        return Align(
          alignment: Alignment.bottomLeft,
          child: status == null
              ? text
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    status!,
                    const SizedBox(height: KubusSpacing.sm),
                    text,
                  ],
                ),
        );
      }
      if (compact) {
        // At large text a trailing status would squeeze the copy to nothing,
        // so it moves above the title instead.
        final statusAbove = status != null &&
            MediaQuery.textScalerOf(context).scale(14) >= 14 * 1.4;
        return Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (statusAbove) ...[
                    status!,
                    const SizedBox(height: KubusSpacing.xs),
                  ],
                  titleText,
                  if (subtitleText != null) ...[
                    const SizedBox(height: KubusSpacing.xxs),
                    subtitleText,
                  ],
                ],
              ),
            ),
            if (status != null && !statusAbove) ...[
              const SizedBox(width: KubusSpacing.sm),
              status!,
            ],
            const SizedBox(width: KubusSpacing.md),
            arrow(hovered),
          ],
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: titleText),
          const SizedBox(width: KubusSpacing.md),
          arrow(hovered),
        ],
      );
    }

    final double resolvedMinHeight =
        minHeight ?? (stacked ? 112 : (compact ? (hasSubtitle ? 64 : 52) : 56));

    return Semantics(
      button: true,
      enabled: interactive,
      label: title,
      hint: subtitle,
      excludeSemantics: true,
      onTap: interactive ? onTap : null,
      child: KubusHoverResponse(
        lift: lifts && interactive,
        cursor:
            interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (context, rawHover) {
          final hovered = rawHover && interactive;
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: resolvedMinHeight,
              maxWidth: maxWidth,
            ),
            child: AnimatedContainer(
              duration: KubusHoverResponse.duration,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: lifts
                    ? KubusHoverResponse.accentShadow(
                        accent,
                        brightness,
                        hovered: hovered,
                      )
                    : null,
              ),
              child: Material(
                color: roles.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: hovered ? accent.withValues(alpha: 0.5) : roles.rule,
                    width: KubusSizes.hairline,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  // The ink area fills the whole tile, including min height.
                  fit: StackFit.passthrough,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: KubusHoverResponse.duration,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.topRight,
                              radius: stacked ? 1.2 : 1.6,
                              colors: [
                                accent.withValues(
                                  alpha: (brightness == Brightness.dark
                                          ? 0.14
                                          : 0.09) +
                                      (hovered ? 0.06 : 0),
                                ),
                                accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The inline tile is too short for a legible ghost glyph;
                    // its arrow carries the accent instead.
                    if (compact)
                      Positioned.fill(
                        child: KubusGhostGlyph(
                          key: const ValueKey<String>(
                              'kubus_action_tile_compact_glyph'),
                          icon: icon,
                          color: accent,
                          alignment: Alignment.topRight,
                          extent: compactGlyphExtent,
                          bleed: 0.3,
                        ),
                      ),
                    if (stacked)
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: hovered && motion ? 1 : 0),
                          duration: motion
                              ? KubusHoverResponse.duration
                              : Duration.zero,
                          curve: Curves.easeOutCubic,
                          builder: (context, t, _) => KubusGhostGlyph(
                            key: const ValueKey<String>(
                                'kubus_action_tile_ghost_glyph'),
                            icon: icon,
                            color: accent,
                            alignment: Alignment.topRight,
                            bleed: 0.3,
                            scale: 1 + (glyphScale - 1) * t,
                            shift: Offset(-glyphShift * t, glyphShift * t),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: KubusEdgeLight(
                        color: accent,
                        strength: hovered ? 0.85 : 0.5,
                      ),
                    ),
                    if (compact)
                      Positioned(
                        left: 0,
                        top: KubusSpacing.sm,
                        bottom: KubusSpacing.sm,
                        child: IgnorePointer(
                          child: AnimatedContainer(
                            key: const ValueKey<String>(
                                'kubus_action_tile_indicator'),
                            duration: KubusHoverResponse.duration,
                            width: 3,
                            decoration: BoxDecoration(
                              color:
                                  accent.withValues(alpha: hovered ? 0.9 : 0),
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (stacked && loading)
                      const Positioned(
                        top: KubusSpacing.md,
                        right: KubusSpacing.md,
                        width: 16,
                        height: 16,
                        child: IgnorePointer(
                          child: InlineLoading(
                            expand: true,
                            shape: BoxShape.circle,
                            tileSize: 3,
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: interactive ? onTap : null,
                      focusColor: roles.focus.withValues(alpha: 0.14),
                      hoverColor: accent.withValues(alpha: 0),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: KubusSpacing.md,
                          vertical: stacked ? KubusSpacing.md : KubusSpacing.sm,
                        ),
                        child: body(hovered),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
