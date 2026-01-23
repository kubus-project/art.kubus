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
    final radius = BorderRadius.circular(14);

    // Brand-ish tones (not exact logo assets; avoids bundling trademarked art).
    const googleBlue = Color(0xFF4285F4);
    const googleAmber = Color(0xFFFBBC05);

    final brandBackground = isDark ? googleBlue : googleAmber;
    final brandForeground = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final glassTint = brandBackground.withValues(alpha: isDark ? 0.78 : 0.86);

    final Widget leading = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(brandForeground),
            ),
          )
        : _GoogleBadgeG(
            foreground: googleBlue,
            borderColor: colorScheme.onSurface.withValues(alpha: 0.10),
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: brandBackground.withValues(alpha: 0.35),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: brandForeground,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
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

class _GoogleBadgeG extends StatelessWidget {
  const _GoogleBadgeG({
    required this.foreground,
    required this.borderColor,
  });

  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: foreground,
          height: 1,
        ),
      ),
    );
  }
}

