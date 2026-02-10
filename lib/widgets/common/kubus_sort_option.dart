import 'package:flutter/material.dart';

import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

/// Shared map sort option row.
class KubusSortOption extends StatelessWidget {
  const KubusSortOption({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.accentColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? scheme.primary;
    final animationTheme = context.animationTheme;

    final radius = BorderRadius.circular(12);
    final idleTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.12);
    final selectedTint = accent.withValues(alpha: isDark ? 0.12 : 0.14);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: animationTheme.short,
          curve: animationTheme.defaultCurve,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.85)
                  : scheme.outline.withValues(alpha: 0.18),
              width: selected ? 1.25 : 1,
            ),
            boxShadow: selected
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
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: radius,
            blurSigma: KubusGlassEffects.blurSigmaLight,
            showBorder: false,
            backgroundColor: selected ? selectedTint : idleTint,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? accent
                        : scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? accent : scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: accent,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
