import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import 'kubus_atmosphere.dart';

enum KubusActionTileLayout {
  /// Phone grid: the title anchored low, the destination glyph cropped in
  /// the opposite corner.
  stacked,

  /// Desktop strip: title and a navigation arrow in one row.
  inline,
}

/// PRODUCT v5 destination tile (home quick actions and similar shortcuts).
///
/// One semantic idea per layer: the title names the destination, the
/// destination's contextual colour (map teal, studio coral, institution
/// blue, governance green, …) sets the field and the edge light, and on the
/// stacked tile the destination's glyph sits cropped oversized in the
/// trailing corner as decorative identity. There is no foreground icon box:
/// it would only repeat what the title, colour and glyph already say. The
/// inline tile is too short for a legible glyph, so it is field, title and a
/// navigation arrow (the arrow is the affordance, not identity).
///
/// On a pointer the tile lifts 2 px (paint only) and the field and edge
/// brighten; with reduced motion it only brightens. Touch never hovers.
/// Minimum 44 px target, button semantics, titles wrap to two lines and the
/// tile grows with the text.
///
/// Width contract: a stacked tile fills its slot. An inline tile sizes to its
/// title but never exceeds [inlineMaxWidth] (scaled with the text), so it
/// still wraps when its parent gives it an unbounded width, as in a
/// horizontally scrolling strip. A narrower slot wins.
class KubusActionTile extends StatelessWidget {
  const KubusActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.layout = KubusActionTileLayout.stacked,
    this.minHeight,
  });

  final String title;

  /// Destination glyph, drawn as the stacked tile's cropped ghost glyph.
  final IconData icon;

  /// Destination colour from [KubusColorRoles] / `AppColorUtils`.
  final Color accent;
  final VoidCallback onTap;
  final KubusActionTileLayout layout;
  final double? minHeight;

  /// Widest an inline tile grows at 1x text, before the text scale.
  static const double inlineMaxWidth = 280;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final brightness = Theme.of(context).brightness;
    final stacked = layout == KubusActionTileLayout.stacked;
    final radius = BorderRadius.circular(KubusRadius.md);
    final maxWidth = stacked
        ? double.infinity
        : MediaQuery.textScalerOf(context).scale(inlineMaxWidth);

    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      style: KubusTextStyles.detailCardTitle.copyWith(
        color: roles.foreground,
        fontWeight: FontWeight.w600,
      ),
    );
    final body = stacked
        // The title sits on the lower edge, clear of the glyph's corner, so
        // the composition reads diagonally: glyph above-right, name
        // below-left.
        ? Align(alignment: Alignment.bottomLeft, child: titleText)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: titleText),
              const SizedBox(width: KubusSpacing.md),
              ExcludeSemantics(
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: accent,
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: KubusHoverResponse(
        lift: true,
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minHeight ?? (stacked ? 112 : 56),
            maxWidth: maxWidth,
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
                // The inline strip is too short for a legible ghost glyph;
                // its chevron carries the accent instead.
                if (stacked)
                  Positioned.fill(
                    child: KubusGhostGlyph(
                      icon: icon,
                      color: accent,
                      alignment: Alignment.topRight,
                      bleed: 0.3,
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
                InkWell(
                  onTap: onTap,
                  focusColor: roles.focus.withValues(alpha: 0.14),
                  hoverColor: accent.withValues(alpha: 0),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: KubusSpacing.md,
                      vertical: stacked ? KubusSpacing.md : KubusSpacing.sm,
                    ),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
