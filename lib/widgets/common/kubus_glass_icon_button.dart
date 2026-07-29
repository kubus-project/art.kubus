import 'package:flutter/material.dart';

import '../../providers/glass_capabilities_provider.dart';
import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';
import '../map/kubus_map_glass_surface.dart';
import 'kubus_badge.dart';

/// Reusable glass icon button used across map UIs.
class KubusGlassIconButton extends StatefulWidget {
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
    this.badgeCount,
    this.semanticsLabel,
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

  /// Optional count rendered inside the button bounds with the canonical
  /// [KubusBadge] treatment. Values above 99 are abbreviated to `99+`.
  final int? badgeCount;

  /// Overrides the tooltip as the accessibility label. The active state is
  /// exposed as the selected state, and the badge remains decorative so
  /// callers can provide one complete localized label here.
  final String? semanticsLabel;

  final EdgeInsetsGeometry? tooltipMargin;
  final bool? tooltipPreferBelow;
  final double? tooltipVerticalOffset;
  final double borderRadius;
  final bool enableBlur;

  @override
  State<KubusGlassIconButton> createState() => _KubusGlassIconButtonState();
}

class _KubusGlassIconButtonState extends State<KubusGlassIconButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final onPressed = widget.onPressed;
    final tooltip = widget.tooltip;
    final active = widget.active;
    final activeTint = widget.activeTint;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ?? scheme.primary;
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
    final allowBlur = GlassCapabilitiesProvider.watchAllowBlurEnabled(context);
    final resolvedRadius = widget.borderRadius.clamp(0.0, 999.0).toDouble();
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
    final resolvedIconColor = active
        ? (widget.activeIconColor ?? accent)
        : (widget.iconColor ?? scheme.onSurface);
    final resolvedSize = widget.size.clamp(32.0, 56.0).toDouble();
    final resolvedIconSize = (resolvedSize * 0.46).clamp(16.0, 22.0).toDouble();
    final enabled = onPressed != null;
    final badgeCount = widget.badgeCount;
    final showBadge = badgeCount != null && badgeCount > 0;

    // Visible hover/focus emphasis (desktop/web focus requirement) while the
    // active state keeps precedence.
    final borderColor = active
        ? accent.withValues(alpha: 0.85)
        : _focused && enabled
            ? accent.withValues(alpha: 0.70)
            : scheme.outlineVariant.withValues(
                alpha: _hovered && enabled
                    ? KubusGlassEffects.glassBorderOpacityStrong + 0.16
                    : KubusGlassEffects.glassBorderOpacityStrong,
              );

    Widget button = Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: widget.semanticsLabel ?? (tooltip.isEmpty ? null : tooltip),
      child: SizedBox.square(
        dimension: resolvedSize,
        child: Stack(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                mouseCursor: enabled
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                borderRadius: radius,
                onTap: onPressed,
                onHover: (value) {
                  if (_hovered != value) setState(() => _hovered = value);
                },
                onFocusChange: (value) {
                  if (_focused != value) setState(() => _focused = value);
                },
                child: AnimatedContainer(
                  duration: context.animationTheme.short,
                  curve: context.animationTheme.defaultCurve,
                  width: resolvedSize,
                  height: resolvedSize,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: borderColor,
                      width: active || (_focused && enabled)
                          ? 1.25
                          : KubusSizes.hairline,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(
                          alpha: isDark
                              ? KubusGlassEffects.shadowOpacityDark
                              : KubusGlassEffects.shadowOpacityLight,
                        ),
                        blurRadius: active || (_hovered && enabled) ? 16 : 14,
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
                    enableBlur: widget.enableBlur,
                    // Match the panel/card glass treatment: when real blur is
                    // off, add the shared static sheen so control buttons
                    // read as glass rather than flat tinted chips.
                    child: wrapWithKubusMapGlassSheen(
                      show: !(widget.enableBlur && allowBlur),
                      borderRadius: radius,
                      isDark: isDark,
                      child: Center(
                        child: Icon(
                          icon,
                          size: resolvedIconSize,
                          color: resolvedIconColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showBadge)
              Positioned(
                top: 0,
                right: 0,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: KubusBadge(
                      text: badgeCount > 99 ? '99+' : '$badgeCount',
                      variant: KubusBadgeVariant.count,
                      accent: accent,
                      compact: true,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (tooltip.isEmpty) return button;

    return Tooltip(
      message: tooltip,
      margin: widget.tooltipMargin,
      preferBelow: widget.tooltipPreferBelow,
      verticalOffset: widget.tooltipVerticalOffset ?? 0,
      child: button,
    );
  }
}
