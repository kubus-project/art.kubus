import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';

/// Web-only Google Sign-In button.
///
/// On non-web platforms this widget renders nothing.
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
    return const SizedBox.shrink();
  }
}
