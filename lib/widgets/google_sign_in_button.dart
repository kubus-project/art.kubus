import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'glass_components.dart';

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
    // Match KubusButton geometry (more square than the previous pill-ish look).
    final radius = BorderRadius.circular(8);

    // Google-like neutral button styling: black on dark, white on light.
    final baseBackground = isDark ? Colors.black : Colors.white;
    final baseForeground = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final borderColor = isDark ? Colors.transparent : const Color(0x1F000000);
    final glassTint = baseBackground.withValues(alpha: isDark ? 0.88 : 0.94);

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

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: baseForeground,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: baseForeground.withValues(alpha: 0.55),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(borderRadius: radius),
              elevation: 0,
            ),
            onPressed: isLoading ? null : onPressed,
            icon: leading,
            label: Text(
              isLoading ? 'Connecting...' : 'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}

