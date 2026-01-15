import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';

class KubusCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  const KubusCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget card = Card(
      color: color ?? theme.cardTheme.color,
      margin: EdgeInsets.zero,
      elevation: theme.cardTheme.elevation,
      shape: theme.cardTheme.shape,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(KubusSpacing.md),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: KubusRadius.circular(KubusRadius.md),
        child: card,
      );
    }

    return card;
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
    return Chip(
      label: Text(
        label,
        style: KubusTypography.textTheme.labelMedium?.copyWith(
          color: textColor ?? Colors.white,
        ),
      ),
      backgroundColor: backgroundColor ?? KubusColors.primary,
      deleteIconColor: textColor ?? Colors.white,
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
