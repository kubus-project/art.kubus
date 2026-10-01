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

/// PRODUCT v5 metric tile: a ruled surface, a small contextual icon tile,
/// the number and its label.
///
/// [accent] is the metric's contextual colour (from [KubusColorRoles]).
/// Expressive tiles (the default for [KubusStatCardLayout.centered]) also
/// use it as composition: the metric's glyph returns oversized and cropped
/// in the trailing corner ([KubusGhostGlyph]), a diffuse field of the accent
/// rises from that corner and the top edge catches it. Followers therefore
/// read differently from artworks or governance without the card turning
/// into a colour block: the fill under the text is the plain surface.
///
/// Hover answers inside the clipped tile only: the glyph grows and drifts a
/// few pixels toward the number and the field and edge brighten. The tile
/// and its text never move. Reduced motion keeps the brightening and drops
/// the drift. Touch never hovers.
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

  /// Ghost glyph, contextual field and edge light. Defaults to on for the
  /// centred (grid) layout and off for the dense standard row. Needs [icon].
  final bool? expressive;

  /// Strength of the contextual field rising from the glyph corner.
  static double fieldAlpha(Brightness b, {bool hovered = false}) =>
      (b == Brightness.dark ? 0.11 : 0.075) + (hovered ? 0.05 : 0);

  static const EdgeInsets defaultPadding = EdgeInsets.symmetric(
    horizontal: KubusSpacing.md,
    vertical: KubusSpacing.sm + KubusSpacing.xs,
  );

  /// Height a [KubusStatCardLayout.centered] tile needs for its icon tile,
  /// number and [titleLines] label lines at the ambient text scale, measured
  /// with the same styles the tile paints. Grids of centred tiles pass it (or
  /// a larger floor) as `mainAxisExtent`, so 200 % text grows the tile
  /// instead of clipping the label.
  static double centeredExtent(
    BuildContext context, {
    int titleLines = 2,
    TextStyle? valueStyle,
    TextStyle? titleStyle,
    EdgeInsets padding = defaultPadding,
    bool withIcon = true,
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
    final iconBlock =
        withIcon ? KubusContextIconSize.compact.box + KubusSpacing.xs : 0.0;
    return (padding.vertical + iconBlock + valueLine + KubusSpacing.xs + label)
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
    final contextIcon = showIcon && icon != null
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
      // A fixed stack (icon tile, number, label) so a grid can reserve the
      // exact height with [centeredExtent]. A number wider than the tile
      // scales down rather than being ellipsised; the label wraps.
      body = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (contextIcon != null) ...[
            Center(child: contextIcon),
            const SizedBox(height: KubusSpacing.xs),
          ],
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

    final isExpressive = (expressive ?? centered) && showIcon && icon != null;
    final brightness = Theme.of(context).brightness;

    Widget surface(bool hovered) {
      final motion = KubusHoverResponse.motionAllowed(context);
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
      return Material(
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
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: hovered ? 1 : 0),
                      duration:
                          motion ? KubusHoverResponse.duration : Duration.zero,
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => KubusGhostGlyph(
                        key: const ValueKey<String>('kubus_stat_ghost_glyph'),
                        icon: icon!,
                        color: resolvedAccent,
                        alignment: Alignment.bottomRight,
                        // Mostly cropped: a fragment of the symbol, so the
                        // label in front of it stays the readable layer.
                        bleed: 0.36,
                        opacity: KubusGhostGlyph.defaultOpacity(brightness) +
                            0.04 * (hovered ? 1 : 0),
                        scale: motion ? 1 + 0.06 * t : 1,
                        shift: motion ? Offset(-4 * t, -4 * t) : Offset.zero,
                      ),
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
    }

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticsLabel ?? '$value $title',
      excludeSemantics: true,
      onTap: onTap,
      child: isExpressive
          ? KubusHoverResponse(
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
