import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';
import 'google_sign_in_button.dart';

/// Web Google Sign-In button rendered entirely by Flutter widgets.
///
/// We intentionally avoid the platform-rendered HTML GIS button here because
/// it can float above modal/sheet/card layers and create z-index issues in the
/// auth surface (especially while switching between auth methods).
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
        try {
          final result = await GoogleAuthService().signIn();
          if (result == null) {
            throw StateError('Google sign-in cancelled or unavailable.');
          }
          await onAuthResult(result);
        } catch (error) {
          onAuthError?.call(error);
        }
      },
    );
  }
}
