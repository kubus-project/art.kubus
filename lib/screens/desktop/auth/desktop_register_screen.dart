import 'package:flutter/material.dart';
import '../../auth/register_screen.dart';

/// Desktop-friendly wrapper for the shared RegisterScreen.
class DesktopRegisterScreen extends StatelessWidget {
  const DesktopRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RegisterScreen();
  }
}
