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
    return const SizedBox(
      width: 22,
      height: 22,
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
    final strokeWidth = size.width * 0.18;
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    Paint segment(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, -0.05, 1.08, false, segment(_blue));
    canvas.drawArc(rect, 1.03, 1.10, false, segment(_green));
    canvas.drawArc(rect, 2.12, 0.82, false, segment(_yellow));
    canvas.drawArc(rect, 2.92, 1.18, false, segment(_red));

    final centerY = size.height * 0.51;
    canvas.drawLine(
      Offset(size.width * 0.52, centerY),
      Offset(size.width * 0.91, centerY),
      segment(_blue)..strokeCap = StrokeCap.square,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, centerY),
      Offset(size.width * 0.82, size.height * 0.68),
      segment(_blue)..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
