import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';
 

class KubusCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool isGlass;

  const KubusCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.isGlass = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = KubusRadius.circular(KubusRadius.md);
    final glassTint = (color ?? scheme.surface)
        .withValues(alpha: isDark ? 0.16 : 0.10);
    
    if (isGlass) {
      return LiquidGlassPanel(
        padding: padding ?? const EdgeInsets.all(KubusSpacing.md),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: true,
        backgroundColor: glassTint,
        onTap: onTap,
        child: child,
      );
    }

    Widget solid = Card(
      margin: EdgeInsets.zero,
      elevation: theme.cardTheme.elevation,
      shape: theme.cardTheme.shape,
      color: color ?? theme.cardTheme.color,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(KubusSpacing.md),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: solid,
      );
    }

    return solid;
  }
}

class KubusChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onDeleted;

  const KubusChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallbackText = textColor ?? scheme.onPrimary;
    final bg = backgroundColor ?? scheme.primary;
    return Chip(
      label: Text(
        label,
        style: KubusTypography.textTheme.labelMedium?.copyWith(
          color: fallbackText,
        ),
      ),
      backgroundColor: bg,
      deleteIconColor: fallbackText,
      onDeleted: onDeleted,
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xs, vertical: 0),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: KubusRadius.circular(KubusRadius.xl),
      ),
    );
  }
}
