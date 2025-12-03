import 'package:flutter/material.dart';
import '../../auth/sign_in_screen.dart';

/// Desktop-friendly wrapper for the shared SignInScreen.
class DesktopSignInScreen extends StatelessWidget {
  const DesktopSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SignInScreen();
  }
}
