import 'package:flutter/material.dart';

import '../../providers/glass_capabilities_provider.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

/// Reusable glass icon button used across map UIs.
class KubusGlassIconButton extends StatelessWidget {
  const KubusGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
    this.size = KubusHeaderMetrics.actionHitArea,
    this.accentColor,
    this.iconColor,
    this.activeIconColor,
    this.activeTint,
    this.tooltipMargin,
    this.tooltipPreferBelow,
    this.tooltipVerticalOffset,
    this.borderRadius = 999,
    this.enableBlur = true,
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
  final double borderRadius;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? scheme.primary;
    final idleStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.button,
      tintBase: scheme.surface,
    );
    final activeStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.button,
      tintBase: activeTint ?? accent,
    );
    final allowBlur =
        GlassCapabilitiesProvider.watchAllowBlurEnabled(context);
    final resolvedRadius = borderRadius.clamp(0.0, 999.0).toDouble();
    final radius = BorderRadius.circular(resolvedRadius);
    final idleTint = idleStyle.tintColor;
    final selectedBase =
        Color.lerp(scheme.surface, activeTint ?? accent, 0.18) ??
            scheme.surface;
    final selectedTint = selectedBase.withValues(
      alpha: allowBlur
          ? activeStyle.tintColor.a
          : KubusGlassEffects.fallbackOpaqueOpacity,
    );
    final resolvedIconColor =
        active ? (activeIconColor ?? accent) : (iconColor ?? scheme.onSurface);
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
                  : scheme.outlineVariant.withValues(
                      alpha: KubusGlassEffects.glassBorderOpacityStrong,
                    ),
              width: active ? 1.25 : KubusSizes.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: isDark
                      ? KubusGlassEffects.shadowOpacityDark
                      : KubusGlassEffects.shadowOpacityLight,
                ),
                blurRadius: active ? 16 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: radius,
            blurSigma: idleStyle.blurSigma,
            showBorder: false,
            backgroundColor: active ? selectedTint : idleTint,
            fallbackMinOpacity: idleStyle.fallbackMinOpacity,
            enableBlur: enableBlur,
            child: Center(
              child:
                  Icon(icon, size: resolvedIconSize, color: resolvedIconColor),
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
