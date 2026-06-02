import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/design_tokens.dart';
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
      leading: _GoogleGlyph(
        color: baseForeground,
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
