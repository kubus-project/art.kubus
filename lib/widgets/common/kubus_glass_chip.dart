import 'package:flutter/material.dart';

import '../../providers/glass_capabilities_provider.dart';
import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';
import '../map/kubus_map_glass_surface.dart';

/// Reusable glass chip used for filter/sort selections.
class KubusGlassChip extends StatelessWidget {
  const KubusGlassChip({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onPressed,
    this.accentColor,
    this.borderRadius = 20,
    this.enableBlur = true,
    this.fullWidth = false,
    this.minWidth,
    this.minHeight,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;
  final Color? accentColor;
  final double borderRadius;
  final bool enableBlur;

  /// When `true`, the chip stretches to fill its parent's width and centres its
  /// content so the border wraps the whole button/cell (grid-style) instead of
  /// shrink-wrapping the icon + label. The parent must provide bounded width
  /// (e.g. a grid cell or stretched column).
  final bool fullWidth;

  /// Minimum cell width; ignored when [fullWidth] is set.
  final double? minWidth;

  /// Consistent cell height so a row/grid of chips reads with equal weight.
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final animationTheme = context.animationTheme;
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
      tintBase: accent,
    );
    final allowBlur = GlassCapabilitiesProvider.watchAllowBlurEnabled(context);

    final resolvedRadius = borderRadius.clamp(0.0, 999.0).toDouble();
    final radius = BorderRadius.circular(resolvedRadius);
    final constraints = BoxConstraints(
      minWidth: fullWidth ? double.infinity : (minWidth ?? 0.0),
      minHeight: minHeight ?? 0.0,
    );
    final idleTint = idleStyle.tintColor;
    final selectedTint = activeStyle.tintColor.withValues(
      alpha: allowBlur
          ? activeStyle.tintColor.a
          : KubusGlassEffects.fallbackOpaqueOpacity,
    );

    return Semantics(
      // Filter/layer chips are toggleable; expose the on/off state so screen
      // readers announce selection instead of a plain button. The inner Text
      // still provides the accessible label.
      button: true,
      toggled: active,
      enabled: onPressed != null,
      child: MouseRegion(
        cursor: onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: animationTheme.short,
          curve: animationTheme.defaultCurve,
          constraints: constraints,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.85)
                  : scheme.outline.withValues(
                      alpha: KubusGlassEffects.glassBorderOpacitySubtle,
                    ),
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
            enableBlur: enableBlur,
            onTap: onPressed,
            // When real blur is unavailable (mobile overlays over the MapLibre
            // platform view, or any reduced-transparency context) add the shared
            // static sheen so quick-filter chips read as glass rather than flat
            // tinted pills, matching the icon buttons and panels around them.
            child: wrapWithKubusMapGlassSheen(
              show: !(enableBlur && allowBlur),
              borderRadius: radius,
              isDark: isDark,
              child: Row(
                mainAxisSize:
                    fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: fullWidth
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: KubusHeaderMetrics.actionIcon - KubusSpacing.xxs,
                    color: active
                        ? accent
                        : scheme.onSurface.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          fullWidth ? TextAlign.center : TextAlign.start,
                      style: (active
                              ? theme.textTheme.labelLarge
                              : theme.textTheme.labelMedium)
                          ?.copyWith(color: active ? accent : scheme.onSurface),
                    ),
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
