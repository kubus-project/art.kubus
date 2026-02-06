import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../glass_components.dart';

/// Shared "glass" pill chip used across map screens (mobile + desktop).
///
/// Intentionally:
/// - no provider reads
/// - no feature flags
/// - purely presentational + caller-owned callbacks
class KubusMapGlassChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  const KubusMapGlassChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.24 : 0.18)
        : scheme.surface.withValues(alpha: isDark ? 0.34 : 0.42);
    final border = selected
        ? accent.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.30);
    final fg = selected ? accent : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(999),
            showBorder: false,
            backgroundColor: bg,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: KubusTypography.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
