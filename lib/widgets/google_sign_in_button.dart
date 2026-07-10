// ignore_for_file: kubus_no_raw_color
// Grandfathered kubus design-token violations. Remove this header
// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'kubus_auth_method_button.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final isDark = colorScheme.brightness == Brightness.dark;
    final baseForeground = isDark ? Colors.white : const Color(0xFF1F1F1F);

    return KubusAuthMethodButton(
      onPressed: isLoading ? null : () async => onPressed(),
      isLoading: isLoading,
      label: l10n.authContinueWithGoogleLabel,
      loadingLabel: l10n.authGoogleConnectingLabel,
      foregroundColor: baseForeground,
      isFullWidth: true,
      leading: const _GoogleGlyph(),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: KubusAuthMethodMetrics.iconSize,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  const _GoogleGlyphPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18, size.height / 18);
    _drawPath(canvas, _blue, _bluePath());
    _drawPath(canvas, _green, _greenPath());
    _drawPath(canvas, _yellow, _yellowPath());
    _drawPath(canvas, _red, _redPath());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  void _drawPath(Canvas canvas, Color color, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  Path _bluePath() {
    return Path()
      ..moveTo(17.64, 9.20)
      ..cubicTo(17.64, 8.57, 17.58, 7.95, 17.48, 7.36)
      ..lineTo(9.0, 7.36)
      ..lineTo(9.0, 10.85)
      ..lineTo(13.84, 10.85)
      ..cubicTo(13.63, 11.97, 13.0, 12.93, 12.05, 13.56)
      ..lineTo(12.05, 15.82)
      ..lineTo(14.96, 15.82)
      ..cubicTo(16.66, 14.25, 17.64, 11.95, 17.64, 9.20)
      ..close();
  }

  Path _greenPath() {
    return Path()
      ..moveTo(9.0, 18.0)
      ..cubicTo(11.43, 18.0, 13.47, 17.19, 14.96, 15.82)
      ..lineTo(12.05, 13.56)
      ..cubicTo(11.24, 14.10, 10.21, 14.42, 9.0, 14.42)
      ..cubicTo(6.66, 14.42, 4.67, 12.84, 3.96, 10.71)
      ..lineTo(0.96, 10.71)
      ..lineTo(0.96, 13.04)
      ..cubicTo(2.44, 15.98, 5.48, 18.0, 9.0, 18.0)
      ..close();
  }

  Path _yellowPath() {
    return Path()
      ..moveTo(3.96, 10.71)
      ..cubicTo(3.78, 10.17, 3.68, 9.59, 3.68, 9.0)
      ..cubicTo(3.68, 8.41, 3.78, 7.83, 3.96, 7.29)
      ..lineTo(3.96, 4.96)
      ..lineTo(0.96, 4.96)
      ..cubicTo(0.35, 6.17, 0.0, 7.55, 0.0, 9.0)
      ..cubicTo(0.0, 10.45, 0.35, 11.83, 0.96, 13.04)
      ..lineTo(3.96, 10.71)
      ..close();
  }

  Path _redPath() {
    return Path()
      ..moveTo(9.0, 3.58)
      ..cubicTo(10.32, 3.58, 11.51, 4.03, 12.44, 4.93)
      ..lineTo(15.02, 2.34)
      ..cubicTo(13.46, 0.89, 11.43, 0.0, 9.0, 0.0)
      ..cubicTo(5.48, 0.0, 2.44, 2.02, 0.96, 4.96)
      ..lineTo(3.96, 7.29)
      ..cubicTo(4.67, 5.16, 6.66, 3.58, 9.0, 3.58)
      ..close();
  }
}
