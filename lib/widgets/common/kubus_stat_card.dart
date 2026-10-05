import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import 'kubus_atmosphere.dart';
import 'kubus_context_icon.dart';

enum KubusStatCardLayout {
  standard,
  centered,
}

/// PRODUCT v5 metric tile: the number, its label and one contextual device.
///
/// The value is the primary information and the label names it. [accent] is
/// the metric's contextual colour (from [KubusColorRoles]) and is expressed
/// once, in one of two ways:
///
/// - **Expressive** (the default for [KubusStatCardLayout.centered]): the
///   metric's glyph is cropped oversized in the trailing corner
///   ([KubusGhostGlyph]), a diffuse field of the accent rises from that
///   corner and the top edge catches it. There is no foreground icon tile:
///   the ghost glyph is the metric's identity, and a small copy of the same
///   symbol beside the number would only say it twice.
/// - **Dense** (the default for [KubusStatCardLayout.standard]): a compact
///   context tile leads the row, for lists of metrics where a cropped glyph
///   would not be legible. No ghost glyph and no field.
///
/// Followers therefore read differently from artworks or governance without
/// the card turning into a colour block: the fill under the text is the plain
/// surface.
///
/// Hover (expressive tiles, pointer only) answers as one painted unit: the
/// whole surface lifts 2 px with a soft contextual accent shadow, the field
/// and edge brighten and the glyph grows and drifts a few pixels toward the
/// number. The number and label never reflow or move on their own. Reduced
/// motion keeps the brightening and the shadow state and drops the lift and
/// the drift. A tile without [onTap] answers hover visually but keeps the
/// default cursor and no button semantics. Touch never hovers.
///
/// The spoken label is `value title` (for example "1,284 Followers") so a
/// value is never announced without its meaning. Tappable tiles expose button
/// semantics and a 44 px minimum target. Labels wrap to [titleMaxLines]; the
/// caller's layout must give the tile room for them (a grid should use a
/// fixed `mainAxisExtent`, not an aspect ratio).
class KubusStatCard extends StatelessWidget {
  const KubusStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.accent,
    this.onTap,
    this.titleStyle,
    this.valueStyle,
    this.padding = defaultPadding,
    this.minHeight = 72,
    this.titleMaxLines = 1,
    this.borderRadius,
    this.change,
    this.isPositiveChange = true,
    this.layout = KubusStatCardLayout.standard,
    this.showIcon = true,
    this.semanticsLabel,
    this.expressive,
  });

  final String title;
  final String value;
  final IconData? icon;

  /// Contextual metric colour; defaults to the family active colour.
  final Color? accent;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final int titleMaxLines;
  final BorderRadius? borderRadius;
  final String? change;
  final bool isPositiveChange;
  final KubusStatCardLayout layout;
  final bool showIcon;

  /// Overrides the spoken `value title` (for units such as KUB8).
  final String? semanticsLabel;

  /// Ghost glyph, contextual field and edge light instead of the foreground
  /// context tile. Defaults to on for the centred (grid) layout and off for
  /// the dense standard row. Needs [icon].
  final bool? expressive;

  /// Strength of the contextual field rising from the glyph corner.
  static double fieldAlpha(Brightness b, {bool hovered = false}) =>
      (b == Brightness.dark ? 0.11 : 0.075) + (hovered ? 0.05 : 0);

  static const EdgeInsets defaultPadding = EdgeInsets.symmetric(
    horizontal: KubusSpacing.md,
    vertical: KubusSpacing.sm + KubusSpacing.xs,
  );

  /// Height a [KubusStatCardLayout.centered] tile needs for its number and
  /// [titleLines] label lines at the ambient text scale, measured
  /// with the same styles the tile paints. Grids of centred tiles pass it (or
  /// a larger floor) as `mainAxisExtent`, so 200 % text grows the tile
  /// instead of clipping the label.
  ///
  /// A centred tile with a non-null [change] stacks the change chip (and one
  /// [KubusSpacing.xs] gap) under the label. Pass [reserveChange] when any
  /// tile in the grid carries one so the cell fits the tallest valid tile; a
  /// grid without chips leaves it off and gains no empty space.
  static double centeredExtent(
    BuildContext context, {
    int titleLines = 2,
    TextStyle? valueStyle,
    TextStyle? titleStyle,
    EdgeInsets padding = defaultPadding,
    bool reserveChange = false,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final lines = _labelLines(scaler, titleLines);
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    // Resolve exactly as [Text] does: the ambient default style underneath.
    final ambient = DefaultTextStyle.of(context);
    double lineHeight(TextStyle style, int lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: List.filled(lines, 'Hg').join('\n'),
          style: ambient.style.merge(style),
        ),
        textDirection: direction,
        textScaler: scaler,
        textHeightBehavior: ambient.textHeightBehavior,
        maxLines: lines,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final valueLine = lineHeight(valueStyle ?? KubusTextStyles.statValue, 1);
    final label = lineHeight(titleStyle ?? KubusTextStyles.statLabel, lines);
    // The chip row is as tall as its icon or its (scaled) label, whichever
    // is larger; see [_KubusStatChangeChip].
    final chip = reserveChange
        ? KubusSpacing.xs +
            math.max(
              KubusHeaderMetrics.sectionSubtitle,
              lineHeight(KubusTextStyles.statChange, 1),
            )
        : 0.0;
    return (padding.vertical + valueLine + KubusSpacing.xs + label + chip)
        .ceilToDouble();
  }

  /// Large text (1.5x and up) gets one more label line so a two-line label
  /// wraps instead of being ellipsised; [centeredExtent] reserves it.
  static int _labelLines(TextScaler scaler, int lines) =>
      scaler.scale(10) >= 15 ? lines + 1 : lines;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final radius = borderRadius ?? BorderRadius.circular(KubusRadius.surface);
    final centered = layout == KubusStatCardLayout.centered;
    final resolvedAccent = accent ?? roles.active;
    final isExpressive = (expressive ?? centered) && showIcon && icon != null;
    // The foreground context tile is the dense row's only identity device.
    // Expressive tiles carry the metric's glyph as the cropped ghost glyph
    // instead, and the centred stack keeps the number as its first line.
    final contextIcon = showIcon && icon != null && !isExpressive && !centered
        ? KubusContextIcon(
            icon: icon!,
            accent: resolvedAccent,
            size: KubusContextIconSize.compact,
          )
        : null;

    final valueText = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: (valueStyle ?? KubusTextStyles.statValue).copyWith(
        color: roles.foreground,
      ),
    );
    final titleText = Text(
      title,
      maxLines: _labelLines(MediaQuery.textScalerOf(context), titleMaxLines),
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: (titleStyle ?? KubusTextStyles.statLabel).copyWith(
        color: roles.foregroundMuted,
      ),
    );
    final changeChip = change == null
        ? null
        : _KubusStatChangeChip(label: change!, isPositive: isPositiveChange);

    final Widget body;
    if (centered) {
      // A fixed stack (number, label) so a grid can reserve the exact height
      // with [centeredExtent]. A number wider than the tile scales down
      // rather than being ellipsised; the label wraps.
      body = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: valueText),
          const SizedBox(height: KubusSpacing.xs),
          titleText,
          if (changeChip != null) ...[
            const SizedBox(height: KubusSpacing.xs),
            Center(child: changeChip),
          ],
        ],
      );
    } else {
      body = Row(
        children: [
          if (contextIcon != null) ...[
            contextIcon,
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A value wider than the tile scales down; a number is
                // never ellipsised.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: valueText,
                ),
                const SizedBox(height: KubusSpacing.xxs),
                titleText,
              ],
            ),
          ),
          if (changeChip != null) ...[
            const SizedBox(width: KubusSpacing.xs),
            changeChip,
          ],
        ],
      );
    }

    final tile = Container(
      // A tap target never shrinks the caller's tile: keep the requested
      // height and guarantee the 44 px minimum on top of it.
      constraints: BoxConstraints(
        minHeight: onTap == null ? minHeight : math.max(minHeight, 44),
      ),
      padding: padding,
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: body,
    );

    final brightness = Theme.of(context).brightness;

    Widget surface(bool hovered) {
      final content = onTap == null
          ? tile
          : InkWell(
              onTap: onTap,
              focusColor: roles.focus.withValues(alpha: 0.12),
              hoverColor: isExpressive
                  ? resolvedAccent.withValues(alpha: 0)
                  : resolvedAccent.withValues(alpha: 0.06),
              child: tile,
            );
      final material = Material(
        color: roles.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: roles.rule, width: KubusSizes.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: !isExpressive
            ? content
            : Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: KubusHoverResponse.duration,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomRight,
                            radius: 1.1,
                            colors: [
                              resolvedAccent.withValues(
                                alpha: fieldAlpha(brightness, hovered: hovered),
                              ),
                              resolvedAccent.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: KubusGhostGlyph(
                      key: const ValueKey<String>('kubus_stat_ghost_glyph'),
                      icon: icon!,
                      color: resolvedAccent,
                      placement: KubusGhostGlyphPlacement.stat,
                      alignment: Alignment.bottomRight,
                      opacity: KubusGhostGlyph.defaultOpacity(brightness) +
                          (hovered ? 0.04 : 0),
                      hovered: hovered,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: KubusEdgeLight(
                      color: resolvedAccent,
                      strength: hovered ? 0.8 : 0.45,
                    ),
                  ),
                  content,
                ],
              ),
      );
      if (!isExpressive) return material;
      // The shadow lives outside the clipped Material so it can fall past the
      // tile's edge.
      return AnimatedContainer(
        duration: KubusHoverResponse.duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: KubusHoverResponse.accentShadow(
            resolvedAccent,
            brightness,
            hovered: hovered,
          ),
        ),
        child: material,
      );
    }

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticsLabel ?? '$value $title',
      excludeSemantics: true,
      onTap: onTap,
      child: isExpressive
          ? KubusHoverResponse(
              lift: true,
              cursor:
                  onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
              builder: (context, hovered) => surface(hovered),
            )
          : surface(false),
    );
  }
}

class _KubusStatChangeChip extends StatelessWidget {
  const _KubusStatChangeChip({
    required this.label,
    required this.isPositive,
  });

  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final changeColor =
        isPositive ? roles.positiveAction : roles.negativeAction;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
          size: KubusHeaderMetrics.sectionSubtitle,
          color: changeColor,
        ),
        const SizedBox(width: KubusSpacing.xxs),
        Text(
          label,
          style: KubusTextStyles.statChange.copyWith(color: changeColor),
        ),
      ],
    );
  }
}
