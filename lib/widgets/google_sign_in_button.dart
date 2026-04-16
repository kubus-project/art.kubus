import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';

/// Google Sign-In button that works across platforms.
/// The handler should trigger the platform-appropriate GIS/SDK flow.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.colorScheme,
  });

  final Future<void> Function() onPressed;
  final bool isLoading;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        colorScheme.surface.withValues(alpha: isDark ? 0.9 : 0.96);
    // Match KubusButton geometry (more square than the previous pill-ish look).
    final radius = BorderRadius.circular(KubusRadius.sm);

    final baseForeground = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.12);

    final Widget leading = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(baseForeground),
            ),
          )
        : _GoogleGlyph(
            color: baseForeground,
          );

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: baseForeground,
          overlayColor: baseForeground.withValues(alpha: isDark ? 0.10 : 0.08),
          shadowColor: Colors.transparent,
          disabledForegroundColor: baseForeground.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.lg,
            vertical: KubusSpacing.md,
          ),
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        onPressed: isLoading ? null : () async => onPressed(),
        icon: leading,
        label: Text(
          isLoading ? 'Connecting...' : 'Continue with Google',
          style: KubusTextStyles.sectionTitle,
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'G',
          style: KubusTypography.inter(
            fontSize: KubusHeaderMetrics.screenSubtitle,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}
