import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/google_auth_service.dart';
import 'google_sign_in_button.dart';

/// Web-only Google Sign-In button.
///
/// On non-web platforms this widget falls back to the standard
/// [GoogleSignInButton] flow.
class GoogleSignInWebButton extends StatelessWidget {
  const GoogleSignInWebButton({
    super.key,
    required this.onAuthResult,
    this.onAuthError,
    required this.isLoading,
    required this.colorScheme,
  });

  final Future<void> Function(GoogleAuthResult result) onAuthResult;
  final void Function(Object error)? onAuthError;
  final bool isLoading;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return GoogleSignInButton(
      isLoading: isLoading,
      colorScheme: colorScheme,
      onPressed: () async {
        final l10n = AppLocalizations.of(context)!;
        try {
          final result = await GoogleAuthService().signIn();
          if (result == null) {
            throw StateError(l10n.authGoogleUnavailableError);
          }
          await onAuthResult(result);
        } catch (error) {
          onAuthError?.call(error);
        }
      },
    );
  }
}
