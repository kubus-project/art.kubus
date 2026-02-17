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
  });

  final bool embedded;
  final Future<void> Function()? onAuthCompleted;
  final ValueChanged<String>? onVerificationRequired;
  final ValueChanged<Object>? onError;
  final VoidCallback? onSwitchToSignIn;

  @override
  Widget build(BuildContext context) {
    return AuthMethodsPanel(
      embedded: embedded,
      onAuthSuccess: onAuthCompleted,
      onVerificationRequired: onVerificationRequired,
      onError: onError,
      onSwitchToSignIn: onSwitchToSignIn,
    );
  }
}
