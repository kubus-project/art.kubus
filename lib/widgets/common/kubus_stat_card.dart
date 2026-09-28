import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

enum KubusStatCardLayout {
  standard,
  centered,
}

/// PRODUCT v5 metric tile: flat surface, hairline rule, the number first and
/// its label below. No glass, no tinted fill, no watermark glyph, no hover
/// motion: numbers are context, not decoration.
///
/// The spoken label is `value title` (for example "1,284 Followers") so
/// a value is never announced without its meaning. Tappable tiles expose
/// button semantics and a 44 px minimum target.
///
/// Colour parameters ([accent], [tintBase], [borderColor]) and the watermark
/// parameters are accepted for call-site compatibility; the accent only tints
/// the small leading icon of the standard layout.
class KubusStatCard extends StatelessWidget {
  const KubusStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.accent,
    this.tintBase,
    this.onTap,
    this.borderColor,
    this.titleStyle,
    this.valueStyle,
    this.padding = const EdgeInsets.all(KubusChromeMetrics.compactCardPadding),
    this.minHeight = 72,
    this.titleMaxLines = 1,
    this.iconBoxSize = KubusSizes.sidebarActionIconBox - KubusSpacing.sm,
    this.iconSize = KubusSizes.sidebarActionIcon,
    this.borderRadius,
    this.change,
    this.isPositiveChange = true,
    this.layout = KubusStatCardLayout.standard,
    this.showIcon = true,
    this.centeredWatermarkAlignment,
    this.centeredWatermarkScale = 1.0,
    this.centeredWatermarkVerticalBias = 0.18,
    this.centeredWatermarkHovered,
    this.semanticsLabel,
  });

  final String title;
  final String value;
  final IconData? icon;
  final Color? accent;
  final Color? tintBase;
  final VoidCallback? onTap;
  final Color? borderColor;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final int titleMaxLines;
  final double iconBoxSize;
  final double iconSize;
  final BorderRadius? borderRadius;
  final String? change;
  final bool isPositiveChange;
  final KubusStatCardLayout layout;
  final bool showIcon;
  final Alignment? centeredWatermarkAlignment;
  final double centeredWatermarkScale;
  final double centeredWatermarkVerticalBias;
  final bool? centeredWatermarkHovered;

  /// Overrides the spoken `value title` (for units such as KUB8).
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final radius = borderRadius ?? BorderRadius.circular(KubusRadius.surface);
    final centered = layout == KubusStatCardLayout.centered;

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
      maxLines: titleMaxLines,
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
      body = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: valueText),
          const SizedBox(height: KubusSpacing.xxs),
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
          if (showIcon && icon != null) ...[
            Icon(
              icon,
              size: iconSize,
              color: accent == null ? roles.foregroundMuted : accent!,
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticsLabel ?? '$value $title',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: roles.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: roles.rule, width: KubusSizes.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? tile
            : InkWell(
                onTap: onTap,
                focusColor: roles.focus.withValues(alpha: 0.12),
                hoverColor: roles.foreground.withValues(alpha: 0.04),
                child: tile,
              ),
      ),
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
