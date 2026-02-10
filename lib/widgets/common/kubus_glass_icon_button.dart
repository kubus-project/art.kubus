import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../glass_components.dart';

/// Reusable circular glass icon button used across map UIs.
class KubusGlassIconButton extends StatelessWidget {
  const KubusGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
    this.size = 42,
    this.accentColor,
    this.iconColor,
    this.activeIconColor,
    this.activeTint,
    this.tooltipMargin,
    this.tooltipPreferBelow,
    this.tooltipVerticalOffset,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool active;
  final double size;
  final Color? accentColor;
  final Color? iconColor;
  final Color? activeIconColor;
  final Color? activeTint;
  final EdgeInsetsGeometry? tooltipMargin;
  final bool? tooltipPreferBelow;
  final double? tooltipVerticalOffset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? scheme.primary;
    final radius = BorderRadius.circular(999);
    final idleTint = scheme.surface.withValues(alpha: isDark ? 0.46 : 0.52);
    final selectedTint =
        activeTint ?? accent.withValues(alpha: isDark ? 0.14 : 0.16);
    final resolvedIconColor = active
        ? (activeIconColor ?? accent)
        : (iconColor ?? scheme.onSurface);
    final resolvedSize = size.clamp(32.0, 56.0).toDouble();
    final resolvedIconSize =
        (resolvedSize * 0.46).clamp(16.0, 22.0).toDouble();

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        borderRadius: radius,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: resolvedSize,
          height: resolvedSize,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.85)
                  : scheme.outlineVariant.withValues(alpha: 0.35),
              width: active ? 1.25 : KubusSizes.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: active ? 16 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: radius,
            blurSigma: KubusGlassEffects.blurSigmaLight,
            showBorder: false,
            backgroundColor: active ? selectedTint : idleTint,
            child: Center(
              child: Icon(icon, size: resolvedIconSize, color: resolvedIconColor),
            ),
          ),
        ),
      ),
    );

    if (tooltip.isEmpty) return button;

    return Tooltip(
      message: tooltip,
      margin: tooltipMargin,
      preferBelow: tooltipPreferBelow,
      verticalOffset: tooltipVerticalOffset ?? 0,
      child: button,
    );
  }
}
