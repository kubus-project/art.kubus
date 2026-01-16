import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';

class KubusButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const KubusButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = !isLoading && onPressed != null;

    final effectiveBackground = backgroundColor ?? colorScheme.primary;
    final effectiveForeground = foregroundColor ?? colorScheme.onPrimary;
    // Primary/colored buttons should look mostly opaque in their color, but still sit on glass.
    final glassTint = effectiveBackground.withValues(
      alpha: isEnabled ? (isDark ? 0.82 : 0.88) : (isDark ? 0.62 : 0.70),
    );
    final radius = KubusRadius.circular(KubusRadius.sm);
    
    Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveForeground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: KubusSpacing.sm),
              ],
              Text(
                label,
                style: KubusTypography.textTheme.labelLarge?.copyWith(
                  color: effectiveForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );

    final button = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: effectiveBackground.withValues(alpha: isEnabled ? 0.30 : 0.18),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: effectiveForeground,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: effectiveForeground.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.lg,
              vertical: KubusSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: radius,
            ),
            elevation: 0,
          ),
          child: content,
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class KubusOutlineButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const KubusOutlineButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = !isLoading && onPressed != null;

    final radius = KubusRadius.circular(KubusRadius.sm);
    final glassTint = colorScheme.surface.withValues(
      alpha: isEnabled ? (isDark ? 0.16 : 0.10) : (isDark ? 0.10 : 0.06),
    );

    Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: KubusSpacing.sm),
              ],
              Text(
                label,
                style: KubusTypography.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
          
    final button = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isEnabled ? 0.28 : 0.16),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.lg,
              vertical: KubusSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: radius,
            ),
          ),
          child: content,
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
