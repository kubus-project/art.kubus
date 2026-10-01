import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_context_icon.dart';

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
    final titleColor = isDestructive ? scheme.error : scheme.onSurface;
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
        (isDestructive
            ? scheme.error
            : scheme.onSurface.withValues(alpha: 0.7));
    final shouldShowChevron = showChevron && trailing == null && onTap != null;
    final resolvedChevronColor =
        chevronColor ?? scheme.onSurface.withValues(alpha: 0.3);

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

/// A settings toggle: Sofia Sans title and subtitle beside a platform-native
/// switch ([Switch.adaptive]). ON is the structural family teal
/// ([KubusColorRoles.active]), never the personal accent.
///
/// [mandatory] rows (essential account/wallet/transactional mail) always show
/// ON and cannot be changed; their [subtitle] or group note says why.
class SharedSettingsToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final bool mandatory;
  final Key? switchKey;
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
    this.mandatory = false,
    this.switchKey,
    this.padding = EdgeInsets.zero,
    this.titleStyle,
    this.subtitleStyle,
    this.spacing = KubusSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    // A disabled optional toggle reads as off (for example a category under
    // a master switch that is off); a mandatory one is always on.
    final effectiveValue = mandatory ? true : (enabled ? value : false);
    final interactive = enabled && !mandatory;
    final resolvedTitleStyle = titleStyle ??
        KubusTextStyles.sectionTitle.copyWith(color: roles.foreground);
    final resolvedSubtitleStyle = subtitleStyle ??
        KubusTextStyles.sectionSubtitle.copyWith(color: roles.foregroundMuted);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: resolvedTitleStyle),
                Text(subtitle, style: resolvedSubtitleStyle),
              ],
            ),
          ),
          SizedBox(width: spacing),
          // Adaptive: platform-native toggle on iOS/macOS, Material elsewhere.
          Switch.adaptive(
            key: switchKey,
            value: effectiveValue,
            onChanged: interactive ? onChanged : null,
            activeTrackColor: roles.active,
            activeThumbColor: roles.onActive,
            inactiveTrackColor: roles.surfaceRaised,
            inactiveThumbColor: roles.foregroundMuted,
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? roles.active
                  : roles.ruleStrong,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section identity for a settings surface: a contextual icon tile, the
/// section title and an optional one-line explanation.
class SharedSettingsSectionHeader extends StatelessWidget {
  const SharedSettingsSectionHeader({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
  });

  final IconData icon;

  /// Contextual accent from [KubusColorRoles].
  final Color accent;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KubusContextIcon(icon: icon, accent: accent),
        const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: KubusTextStyles.detailCardTitle
                      .copyWith(color: roles.foreground),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: KubusSpacing.xxs),
                Text(
                  subtitle!,
                  style: KubusTextStyles.detailCaption
                      .copyWith(color: roles.foregroundMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A group of related settings rows under a Space Mono structural label.
///
/// Groups are separated from each other by space, rows inside a group by a
/// subtle hairline. No panel of its own: a group sits inside the section's
/// one surface, never as another card.
class SharedSettingsGroup extends StatelessWidget {
  const SharedSettingsGroup({
    super.key,
    this.label,
    this.note,
    required this.children,
  });

  /// Structural label, rendered uppercase (controls/notions register).
  final String? label;

  /// Optional explanation under the label (for example why rows are locked).
  final String? note;
  final List<Widget> children;

  /// Vertical rhythm between rows; the rule sits in the middle.
  static const double rowGap = KubusSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Semantics(
            header: true,
            child: Text(
              label!.toUpperCase(),
              style: KubusTextStyles.structuralLabel.copyWith(
                color: roles.foregroundMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
        if (note != null) ...[
          const SizedBox(height: KubusSpacing.xs),
          Text(
            note!,
            style: KubusTextStyles.detailCaption
                .copyWith(color: roles.foregroundMuted),
          ),
        ],
        if (label != null || note != null)
          const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: rowGap,
              thickness: KubusSizes.hairline,
              color: roles.rule,
            ),
          children[i],
        ],
      ],
    );
  }
}
