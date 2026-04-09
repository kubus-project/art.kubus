import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../common/kubus_screen_header.dart';
import '../glass_components.dart';
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
