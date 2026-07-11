// ignore_for_file: kubus_no_raw_color
// Grandfathered kubus design-token violations. Remove this header
// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
import 'package:flutter/material.dart';

import '../providers/glass_capabilities_provider.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';
import 'kubus_button.dart';

class KubusAuthMethodMetrics {
  const KubusAuthMethodMetrics._();

  static const double height = 56;
  static const double iconSlot = 24;
  static const double iconSize = 20;
}

class KubusAuthMethodButton extends StatelessWidget {
  const KubusAuthMethodButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loadingLabel,
    this.icon,
    this.leading,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.variant = KubusButtonVariant.secondary,
    this.height = KubusAuthMethodMetrics.height,
  }) : assert(icon == null || leading == null);

  final VoidCallback? onPressed;
  final String label;
  final String? loadingLabel;
  final IconData? icon;
  final Widget? leading;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final KubusButtonVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = KubusAuthMethodButtonStyle.resolve(
      context,
      variant: variant,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      enabled: !isLoading && onPressed != null,
    );
    final labelText = isLoading ? (loadingLabel ?? label) : label;

    final content = isLoading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: KubusAuthMethodMetrics.iconSlot,
                child: Center(
                  child: SizedBox.square(
                    dimension: KubusAuthMethodMetrics.iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(style.foregroundColor),
                    ),
                  ),
                ),
              ),
              if (loadingLabel != null) ...[
                const SizedBox(width: KubusSpacing.sm),
                Flexible(
                  child: Text(
                    labelText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTypography.textTheme.labelLarge?.copyWith(
                      color: style.foregroundColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  SizedBox.square(
                    dimension: KubusAuthMethodMetrics.iconSlot,
                    child: Center(
                      child: IconTheme(
                        data: IconThemeData(
                          color: style.foregroundColor,
                          size: KubusAuthMethodMetrics.iconSize,
                        ),
                        child: leading!,
                      ),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                ] else if (icon != null) ...[
                  SizedBox.square(
                    dimension: KubusAuthMethodMetrics.iconSlot,
                    child: Center(
                      child: Icon(
                        icon,
                        size: KubusAuthMethodMetrics.iconSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                ],
                Text(
                  labelText,
                  style: KubusTypography.textTheme.labelLarge?.copyWith(
                    color: style.foregroundColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );

    final buttonChild = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: style.foregroundColor,
        overlayColor: style.foregroundColor.withValues(
          alpha: style.isDark ? 0.10 : 0.08,
        ),
        shadowColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        disabledForegroundColor: style.foregroundColor.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.lg,
          vertical: KubusSpacing.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: style.radius),
        elevation: 0,
      ),
      child: content,
    );

    final button = KubusAuthMethodButtonShell(
      isLoading: false,
      variant: variant,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      enabled: !isLoading && onPressed != null,
      height: height,
      child: buttonChild,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class KubusAuthMethodButtonShell extends StatelessWidget {
  const KubusAuthMethodButtonShell({
    super.key,
    required this.child,
    this.isLoading = false,
    this.loadingLabel,
    this.variant = KubusButtonVariant.secondary,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.enabled = true,
    this.height = KubusAuthMethodMetrics.height,
  });

  final Widget child;
  final bool isLoading;
  final String? loadingLabel;
  final KubusButtonVariant variant;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isInteractive = enabled && !isLoading;
    final style = KubusAuthMethodButtonStyle.resolve(
      context,
      variant: variant,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      enabled: isInteractive,
    );
    final allowBlur = GlassCapabilitiesProvider.watchAllowBlurEnabled(context);

    final clippedChild = ClipRRect(
      borderRadius: style.radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (isLoading)
            _KubusAuthLoadingOverlay(style: style, label: loadingLabel),
        ],
      ),
    );

    final surface = allowBlur
        ? LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: style.radius,
            showBorder: false,
            backgroundColor: style.glassTint,
            child: clippedChild,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: style.fallbackColor,
              borderRadius: style.radius,
            ),
            child: clippedChild,
          );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: style.radius,
          border: Border.all(color: style.borderColor),
        ),
        child: surface,
      ),
    );
  }
}

class KubusAuthMethodButtonSkeleton extends StatelessWidget {
  const KubusAuthMethodButtonSkeleton({
    super.key,
    this.label,
    this.variant = KubusButtonVariant.secondary,
    this.height = KubusAuthMethodMetrics.height,
  });

  final String? label;
  final KubusButtonVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    return KubusAuthMethodButtonShell(
      variant: variant,
      enabled: false,
      height: height,
      child: Center(
        child: label == null
            ? SizedBox(
                width: KubusAuthMethodMetrics.iconSlot,
                height: KubusAuthMethodMetrics.iconSlot,
                child: Center(
                  child: SizedBox.square(
                    dimension: KubusAuthMethodMetrics.iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              )
            : Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KubusTypography.textTheme.labelLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.66),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

@immutable
class KubusAuthMethodButtonStyle {
  const KubusAuthMethodButtonStyle({
    required this.foregroundColor,
    required this.glassTint,
    required this.fallbackColor,
    required this.borderColor,
    required this.radius,
    required this.isDark,
  });

  final Color foregroundColor;
  final Color glassTint;
  final Color fallbackColor;
  final Color borderColor;
  final BorderRadius radius;
  final bool isDark;

  static KubusAuthMethodButtonStyle resolve(
    BuildContext context, {
    required KubusButtonVariant variant,
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final defaultBackground = switch (variant) {
      KubusButtonVariant.primary =>
        isDark ? Colors.white : const Color(0xFF1A1A1A),
      KubusButtonVariant.secondary =>
        scheme.surface.withValues(alpha: isDark ? 0.9 : 0.96),
    };
    final defaultForeground = switch (variant) {
      KubusButtonVariant.primary =>
        isDark ? const Color(0xFF1A1A1A) : Colors.white,
      KubusButtonVariant.secondary => scheme.onSurface,
    };
    final effectiveBackground = backgroundColor ?? defaultBackground;
    final effectiveForeground = foregroundColor ?? defaultForeground;
    final glassTint = switch (variant) {
      KubusButtonVariant.primary => effectiveBackground.withValues(
          alpha: enabled ? (isDark ? 0.96 : 0.92) : (isDark ? 0.76 : 0.74),
        ),
      KubusButtonVariant.secondary => effectiveBackground.withValues(
          alpha: enabled ? (isDark ? 0.92 : 0.98) : (isDark ? 0.74 : 0.82),
        ),
    };
    final resolvedBorderColor = borderColor ??
        switch (variant) {
          KubusButtonVariant.primary => effectiveBackground.withValues(
              alpha: enabled ? (isDark ? 0.72 : 0.30) : (isDark ? 0.34 : 0.18),
            ),
          KubusButtonVariant.secondary => scheme.outlineVariant.withValues(
              alpha: isDark ? (enabled ? 0.24 : 0.14) : (enabled ? 0.16 : 0.10),
            ),
        };

    return KubusAuthMethodButtonStyle(
      foregroundColor: effectiveForeground,
      glassTint: glassTint,
      fallbackColor: variant == KubusButtonVariant.primary
          ? effectiveBackground.withValues(alpha: enabled ? 1.0 : 0.82)
          : glassTint,
      borderColor: resolvedBorderColor,
      radius: KubusRadius.circular(KubusRadius.sm),
      isDark: isDark,
    );
  }
}

class _KubusAuthLoadingOverlay extends StatelessWidget {
  const _KubusAuthLoadingOverlay({
    required this.style,
    this.label,
  });

  final KubusAuthMethodButtonStyle style;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: style.glassTint.withValues(alpha: style.isDark ? 0.82 : 0.88),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: KubusAuthMethodMetrics.iconSlot,
              child: Center(
                child: SizedBox.square(
                  dimension: KubusAuthMethodMetrics.iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      style.foregroundColor,
                    ),
                  ),
                ),
              ),
            ),
            if (label != null) ...[
              const SizedBox(width: KubusSpacing.sm),
              Flexible(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTypography.textTheme.labelLarge?.copyWith(
                    color: style.foregroundColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
