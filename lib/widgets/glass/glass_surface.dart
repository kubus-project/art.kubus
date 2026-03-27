import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/glass_capabilities_provider.dart';
import '../../utils/design_tokens.dart';

/// The canonical glass surface widget for the Kubus design system.
///
/// Wraps its [child] in a clipped, optionally blurred, tinted container that
/// produces the app's "liquid glass" look. When the [GlassCapabilitiesProvider]
/// indicates that blur should be disabled (low-end device, WebGL context lost,
/// or user preference), the surface falls back to a higher-opacity tint with a
/// subtle shadow so it still looks intentional.
///
/// **Layering order (when blur is on):**
/// `ClipRRect → BackdropFilter → DecoratedBox(tint + border) → child`
///
/// All higher-level glass widgets (`LiquidGlassPanel`, `FrostedContainer`,
/// `BackdropGlassSheet`, etc.) should compose this widget rather than
/// reimplementing the blur/fallback logic.
class GlassSurface extends StatelessWidget {
  /// The content rendered inside the glass surface.
  final Widget child;

  /// Corner radius of the clipping region and decoration.
  final BorderRadius borderRadius;

  /// Blur intensity when blur is active.
  final double blurSigma;

  /// Override tint color. When `null`, uses the theme surface color
  /// ([KubusColors.surfaceDark] / [KubusColors.surfaceLight]).
  final Color? tintColor;

  /// Tint opacity when blur is active. When `null`, uses the design-token
  /// defaults ([KubusGlassEffects.glassOpacityDark] / `glassOpacityLight`).
  ///
  /// In fallback (no blur) mode this opacity is clamped by
  /// [fallbackMinOpacity] so the surface remains legible without backdrop blur.
  final double? tintOpacity;

  /// Minimum tint opacity used when blur is disabled.
  ///
  /// Use lower values for broad background surfaces (sidebar/header/panels) so
  /// the global gradient stays visible in low-power mode, and higher values for
  /// cards/buttons that need stronger legibility.
  final double fallbackMinOpacity;

  /// Whether to draw a thin border around the surface.
  final bool showBorder;

  /// Optional custom border (takes precedence over [showBorder]).
  final BoxBorder? border;

  /// Allows callers to force the opaque fallback path while still using the
  /// canonical glass tint/border/shadow logic.
  final bool enableBlur;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(KubusRadius.lg)),
    this.blurSigma = KubusGlassEffects.blurSigma,
    this.tintColor,
    this.tintOpacity,
    this.fallbackMinOpacity = KubusGlassEffects.fallbackOpaqueOpacity,
    this.showBorder = true,
    this.border,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    // Determine blur mode from the provider. If the provider is missing
    // (e.g. in a test harness), default to blur enabled.
    final useBlur = enableBlur && _resolveBlurEnabled(context);

    // --- Tint ---
    final blurTint = tintColor ??
        (isDark ? KubusColors.surfaceDark : KubusColors.surfaceLight);
    final fallbackTintBase = Color.lerp(
          scheme.surface,
          tintColor ?? scheme.surface,
          tintColor == null ? 0.0 : KubusGlassEffects.fallbackTintBlend,
        ) ??
        scheme.surface;
    final baseTint = useBlur ? blurTint : fallbackTintBase;

    // Determine opacity:
    // 1. Explicit tintOpacity always wins.
    // 2. If tintColor was provided with an alpha, honour that alpha.
    // 3. Otherwise fall back to the design-token defaults.
    final double nominalOpacity;
    if (tintOpacity != null) {
      nominalOpacity = tintOpacity!;
    } else if (tintColor != null) {
      nominalOpacity = tintColor!.a;
    } else {
      nominalOpacity = isDark
          ? KubusGlassEffects.glassOpacityDark
          : KubusGlassEffects.glassOpacityLight;
    }

    // In fallback mode, ensure the tint is at least `fallbackMinOpacity`
    // so text stays readable even without the backdrop blur.
    final resolvedOpacity = useBlur
        ? nominalOpacity
        : fallbackMinOpacity
            .clamp(KubusGlassEffects.fallbackOpaqueOpacity, 1.0)
            .toDouble();

    // Keep a slight tonal shift when blur is enabled, but stay more uniform in
    // opaque fallback mode.
    final tintPrimary = baseTint.withValues(alpha: resolvedOpacity);
    final tintSecondary = baseTint.withValues(
      alpha: resolvedOpacity * (useBlur ? 0.85 : 0.94),
    );

    // --- Border ---
    final effectiveBorder = border ??
        (showBorder
            ? Border.all(
                color: isDark
                    ? KubusColors.glassBorderDark
                    : KubusColors.glassBorderLight,
                width: KubusSizes.hairline,
              )
            : null);

    // --- Decoration ---
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [tintPrimary, tintSecondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: borderRadius,
      border: effectiveBorder,
      boxShadow: useBlur
          ? null
          : [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: isDark
                      ? KubusGlassEffects.shadowOpacityDark
                      : KubusGlassEffects.shadowOpacityLight,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );

    final tintedBox = DecoratedBox(
      decoration: decoration,
      child: child,
    );

    // Always clip to the border radius, even without blur, to keep corners
    // consistent.
    if (useBlur) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: tintedBox,
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: tintedBox,
    );
  }

  /// Resolve blur state from the provider tree, with a safe fallback.
  bool _resolveBlurEnabled(BuildContext context) {
    try {
      return context.watch<GlassCapabilitiesProvider>().allowBlur;
    } catch (_) {
      return true;
    }
  }
}
