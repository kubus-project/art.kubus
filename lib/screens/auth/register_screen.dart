import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({
    super.key,
    this.embedded = false,
    this.onAuthCompleted,
    this.onVerificationRequired,
    this.onError,
    this.onSwitchToSignIn,
    this.redirectRoute,
    this.redirectArguments,
  });

  final bool embedded;
  final Future<void> Function()? onAuthCompleted;
  final ValueChanged<String>? onVerificationRequired;
  final ValueChanged<Object>? onError;
  final VoidCallback? onSwitchToSignIn;

  /// Route to return to once the account exists. Carried through from the
  /// contextual activation prompt so a guest lands back on the exact entity
  /// they were trying to act on instead of a generic shell.
  final String? redirectRoute;
  final Object? redirectArguments;

  @override
  Widget build(BuildContext context) {
    return AuthMethodsPanel(
      embedded: embedded,
      googleAuthOrigin: embedded ? 'onboarding' : 'register',
      redirectRoute: redirectRoute,
      redirectArguments: redirectArguments,
      onAuthSuccess: onAuthCompleted == null
          ? null
          : (_) async {
              await onAuthCompleted!();
            },
      onVerificationRequired: onVerificationRequired,
      onError: onError,
      onSwitchToSignIn: onSwitchToSignIn,
    );
  }
}
