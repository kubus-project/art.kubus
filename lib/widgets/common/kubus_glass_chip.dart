import 'package:flutter/material.dart';

import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

/// Reusable glass chip used for filter/sort selections.
class KubusGlassChip extends StatelessWidget {
  const KubusGlassChip({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onPressed,
    this.accentColor,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final animationTheme = context.animationTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? scheme.primary;

    final radius = BorderRadius.circular(20);
    final idleTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12);
    final selectedTint = accent.withValues(alpha: isDark ? 0.14 : 0.16);

    return MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.85)
                : scheme.outline.withValues(alpha: 0.18),
            width: active ? 1.25 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: LiquidGlassPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.sm + KubusSpacing.xs,
            vertical: KubusSpacing.sm + KubusSpacing.xxs,
          ),
          margin: EdgeInsets.zero,
          borderRadius: radius,
          blurSigma: KubusGlassEffects.blurSigmaLight,
          showBorder: false,
          backgroundColor: active ? selectedTint : idleTint,
          onTap: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? accent : scheme.onSurface.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: (active ? theme.textTheme.labelLarge : theme.textTheme.labelMedium)
                    ?.copyWith(color: active ? accent : scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
