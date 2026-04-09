import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

class SharedSettingsRowTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;
  final bool showChevron;
  final Key? tileKey;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final Color? leadingBackgroundColor;
  final Color? leadingBorderColor;
  final double leadingBorderWidth;
  final Color? leadingIconColor;
  final double leadingBoxSize;
  final double leadingIconSize;
  final double horizontalGap;
  final double trailingGap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final bool useCardShadow;
  final Color? chevronColor;

  const SharedSettingsRowTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
    this.showChevron = true,
    this.tileKey,
    this.padding = const EdgeInsets.symmetric(
      horizontal: KubusSpacing.md,
      vertical: KubusSpacing.xs + KubusSpacing.xxs,
    ),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(KubusRadius.md)),
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.leadingBackgroundColor,
    this.leadingBorderColor,
    this.leadingBorderWidth = 1,
    this.leadingIconColor,
    this.leadingBoxSize = KubusHeaderMetrics.actionHitArea,
    this.leadingIconSize = KubusHeaderMetrics.actionIcon,
    this.horizontalGap = KubusSpacing.md,
    this.trailingGap = KubusSpacing.sm + KubusSpacing.xxs,
    this.titleStyle,
    this.subtitleStyle,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 2,
    this.useCardShadow = false,
    this.chevronColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor =
        isDestructive ? scheme.error : scheme.onSurface;
    final subtitleColor = scheme.onSurface.withValues(alpha: 0.5);
    final resolvedTitleStyle = titleStyle ??
        KubusTextStyles.sectionTitle.copyWith(
          color: titleColor,
        );
    final resolvedSubtitleStyle = subtitleStyle ??
        KubusTextStyles.sectionSubtitle.copyWith(
          color: subtitleColor,
        );
    final resolvedBorderColor = borderColor ??
        (isDestructive ? scheme.error.withValues(alpha: 0.3) : null);
    final resolvedBackgroundColor = backgroundColor;
    final resolvedLeadingBg = leadingBackgroundColor ??
        (isDestructive ? scheme.error.withValues(alpha: 0.1) : null);
    final resolvedLeadingBorder = leadingBorderColor ??
        (isDestructive ? scheme.error.withValues(alpha: 0.15) : null);
    final resolvedLeadingIconColor = leadingIconColor ??
        (isDestructive ? scheme.error : scheme.onSurface.withValues(alpha: 0.7));
    final shouldShowChevron = showChevron && trailing == null && onTap != null;
    final resolvedChevronColor = chevronColor ??
        scheme.onSurface.withValues(alpha: 0.3);

    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        key: tileKey,
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: padding,
          margin: margin,
          decoration: BoxDecoration(
            color: resolvedBackgroundColor,
            borderRadius: borderRadius,
            border: resolvedBorderColor == null
                ? null
                : Border.all(
                    color: resolvedBorderColor,
                    width: borderWidth,
                  ),
            boxShadow: useCardShadow
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: leadingBoxSize,
                height: leadingBoxSize,
                decoration: BoxDecoration(
                  color: resolvedLeadingBg,
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                  border: resolvedLeadingBorder == null
                      ? null
                      : Border.all(
                          color: resolvedLeadingBorder,
                          width: leadingBorderWidth,
                        ),
                ),
                child: Icon(
                  icon,
                  size: leadingIconSize,
                  color: resolvedLeadingIconColor,
                ),
              ),
              SizedBox(width: horizontalGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: resolvedTitleStyle,
                    ),
                    Text(
                      subtitle,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: resolvedSubtitleStyle,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: trailingGap),
                trailing!,
              ] else if (shouldShowChevron) ...[
                SizedBox(width: trailingGap),
                Icon(
                  Icons.arrow_forward_ios,
                  size: KubusSizes.trailingChevron,
                  color: resolvedChevronColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return content;
  }
}

class SharedSettingsToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Key? switchKey;
  final Color? activeColor;
  final EdgeInsetsGeometry padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double spacing;

  const SharedSettingsToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.switchKey,
    this.activeColor,
    this.padding = EdgeInsets.zero,
    this.titleStyle,
    this.subtitleStyle,
    this.spacing = KubusSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveValue = enabled ? value : false;
    final resolvedActiveColor = activeColor ?? scheme.primary;
    final resolvedTitleStyle = titleStyle ??
        KubusTextStyles.sectionTitle.copyWith(
          color: scheme.onSurface,
        );
    final resolvedSubtitleStyle = subtitleStyle ??
        KubusTextStyles.sectionSubtitle.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.5),
        );

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: resolvedTitleStyle,
                ),
                Text(
                  subtitle,
                  style: resolvedSubtitleStyle,
                ),
              ],
            ),
          ),
          SizedBox(width: spacing),
          Switch(
            key: switchKey,
            value: effectiveValue,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: resolvedActiveColor.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return resolvedActiveColor;
              }
              return null;
            }),
          ),
        ],
      ),
    );
  }
}
