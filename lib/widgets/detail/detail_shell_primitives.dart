import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../common/kubus_screen_header.dart';
import '../glass_components.dart';
import 'detail_shell_sections.dart';
import 'detail_shell_tokens.dart';

/// A unified card component for detail screens with consistent styling.
class DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool showBorder;
  final double borderRadius;
  final VoidCallback? onTap;

  const DetailCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.showBorder = true,
    this.borderRadius = DetailRadius.md,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final radius = BorderRadius.circular(borderRadius);
    final glassTint = (backgroundColor ?? scheme.surface)
        .withValues(alpha: isDark ? 0.16 : 0.10);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: showBorder
            ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35))
            : null,
      ),
      child: LiquidGlassPanel(
        padding: padding ?? const EdgeInsets.all(DetailSpacing.lg),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// A section header with optional action button.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: KubusHeaderText(
            title: title,
            kind: KubusHeaderKind.section,
          ),
        ),
        if (trailing != null) trailing!,
        if (onAction != null && trailing == null)
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(
              actionIcon ?? Icons.arrow_forward,
              size: KubusHeaderMetrics.actionIcon,
            ),
            label: Text(
              actionLabel ?? '',
              style: DetailTypography.button(context),
            ),
          ),
      ],
    );
  }
}

/// An info row with icon and label.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final TextStyle? labelStyle;
  final Color? iconColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.labelStyle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DetailSpacing.sm),
      child: Row(
        children: [
          Icon(
            icon,
            size: KubusHeaderMetrics.actionIcon,
            color: iconColor ?? scheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: DetailSpacing.sm),
          Expanded(
            child: Text(
              value != null ? '$label: $value' : label,
              style: labelStyle ?? DetailTypography.caption(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stat chip for displaying counts/metrics inline.
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final Color? color;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DetailSpacing.md,
        vertical: DetailSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DetailRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: DetailSpacing.xs),
          Text(
            value,
            style: KubusTextStyles.navMetaLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: DetailSpacing.xs),
            Text(
              label!,
              style: KubusTextStyles.navMetaLabel.copyWith(
                color: effectiveColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A unified action button for detail screens with consistent styling.
class DetailActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const DetailActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveActiveColor = activeColor ?? scheme.primary;

    final isEnabled = onPressed != null;
    final bgColor = backgroundColor ??
        (isActive
            ? effectiveActiveColor.withValues(alpha: isDark ? 0.22 : 0.16)
            : scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10));
    final fgColor =
        foregroundColor ?? (isActive ? effectiveActiveColor : scheme.onSurface);

    final radius = BorderRadius.circular(DetailRadius.md);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: isActive
              ? effectiveActiveColor.withValues(alpha: 0.28)
              : scheme.outlineVariant
                  .withValues(alpha: isEnabled ? 0.35 : 0.22),
        ),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(
          vertical: DetailSpacing.md,
          horizontal: DetailSpacing.lg,
        ),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: bgColor,
        onTap: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(width: DetailSpacing.sm),
            Flexible(
              child: Text(
                label,
                style:
                    DetailTypography.button(context).copyWith(color: fgColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailMetaItem {
  const DetailMetaItem({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
}

class DetailMetadataBlock extends StatelessWidget {
  const DetailMetadataBlock({
    super.key,
    required this.items,
    this.compact = false,
    this.spacing,
  });

  final List<DetailMetaItem> items;
  final bool compact;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dense = compact;
    final rowSpacing = spacing ?? (dense ? DetailSpacing.sm : DetailSpacing.md);

    final visible = items
        .where((item) => item.label.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  visible[i].icon,
                  size: dense ? 15 : 16,
                  color: visible[i].iconColor ??
                      scheme.onSurfaceVariant.withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(width: DetailSpacing.sm),
              Expanded(
                child: Text(
                  visible[i].label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DetailTypography.caption(context).copyWith(
                    fontSize: dense
                        ? KubusHeaderMetrics.sectionSubtitle - 2
                        : KubusHeaderMetrics.sectionSubtitle - 1,
                    color: scheme.onSurfaceVariant,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ),
          if (i < visible.length - 1) SizedBox(height: rowSpacing),
        ],
      ],
    );
  }
}

class DetailContextItem {
  const DetailContextItem({
    required this.icon,
    required this.value,
    this.label,
    this.color,
  });

  final IconData icon;
  final String value;
  final String? label;
  final Color? color;
}

class DetailContextCluster extends StatelessWidget {
  const DetailContextCluster({
    super.key,
    required this.items,
    this.spacing = DetailSpacing.sm,
    this.runSpacing = DetailSpacing.sm,
    this.compact = false,
  });

  final List<DetailContextItem> items;
  final double spacing;
  final double runSpacing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = items
        .where((item) => item.value.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    final padH = compact ? DetailSpacing.sm : DetailSpacing.md;
    final padV = compact ? DetailSpacing.xs : DetailSpacing.sm;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final item in visible)
          Container(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.28 : 0.46,
              ),
              borderRadius: BorderRadius.circular(DetailRadius.sm),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.26),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: compact ? 14 : 15,
                  color: item.color ?? scheme.onSurfaceVariant,
                ),
                const SizedBox(width: DetailSpacing.xs),
                Text(
                  item.value,
                  style: DetailTypography.button(context).copyWith(
                    fontSize: compact
                        ? KubusHeaderMetrics.sectionSubtitle - 2
                        : KubusHeaderMetrics.sectionSubtitle - 1,
                    color: item.color ?? scheme.onSurface,
                  ),
                ),
                if ((item.label ?? '').trim().isNotEmpty) ...[
                  const SizedBox(width: DetailSpacing.xs),
                  Text(
                    item.label!,
                    style: DetailTypography.label(context).copyWith(
                      fontSize: compact
                          ? KubusHeaderMetrics.sectionSubtitle - 3
                          : KubusHeaderMetrics.sectionSubtitle - 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class DetailSecondaryAction {
  const DetailSecondaryAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.activeColor,
    this.tooltip,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final Color? activeColor;
  final String? tooltip;
  final String? semanticsLabel;
}

class DetailSecondaryActionCluster extends StatelessWidget {
  const DetailSecondaryActionCluster({
    super.key,
    required this.actions,
    this.maxVisible = 4,
  });

  final List<DetailSecondaryAction> actions;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = actions
        .where((action) => action.label.trim().isNotEmpty)
        .take(maxVisible)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: DetailSpacing.sm,
      runSpacing: DetailSpacing.sm,
      children: [
        for (final action in visible)
          _QuietActionButton(
            action: action,
            scheme: scheme,
            isDark: theme.brightness == Brightness.dark,
          ),
      ],
    );
  }
}

class _QuietActionButton extends StatelessWidget {
  const _QuietActionButton({
    required this.action,
    required this.scheme,
    required this.isDark,
  });

  final DetailSecondaryAction action;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final activeColor = action.activeColor ?? scheme.primary;
    final fg = action.isActive ? activeColor : scheme.onSurfaceVariant;

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DetailRadius.md),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DetailSpacing.md,
            vertical: DetailSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DetailRadius.md),
            color: action.isActive
                ? activeColor.withValues(alpha: isDark ? 0.22 : 0.14)
                : scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10),
            border: Border.all(
              color: action.isActive
                  ? activeColor.withValues(alpha: 0.35)
                  : scheme.outlineVariant.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 16, color: fg),
              const SizedBox(width: DetailSpacing.xs),
              Text(
                action.label,
                style: DetailTypography.button(context).copyWith(
                  color: fg,
                  fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if ((action.semanticsLabel ?? '').trim().isNotEmpty) {
      button = Semantics(
        label: action.semanticsLabel,
        button: true,
        child: button,
      );
    }

    if ((action.tooltip ?? '').trim().isNotEmpty) {
      button = Tooltip(message: action.tooltip!, child: button);
    }

    return button;
  }
}

class DetailIdentityBlock extends StatelessWidget {
  const DetailIdentityBlock({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? kicker;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((kicker ?? '').trim().isNotEmpty) ...[
                Text(
                  kicker!,
                  style: DetailTypography.label(context).copyWith(
                    fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: DetailSpacing.xs),
              ],
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: DetailTypography.screenTitle(context).copyWith(
                  fontSize: KubusHeaderMetrics.screenTitle,
                  height: 1.16,
                ),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: DetailSpacing.sm),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DetailTypography.caption(context).copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: DetailSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class DetailManagementSection extends StatelessWidget {
  const DetailManagementSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DetailCard(
      backgroundColor:
          scheme.surfaceContainerHighest.withValues(alpha: 0.24),
      child: DetailSection(
        title: title,
        collapsible: true,
        initiallyExpanded: initiallyExpanded,
        child: child,
      ),
    );
  }
}
