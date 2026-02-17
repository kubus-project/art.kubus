import 'package:art_kubus/screens/onboarding/onboarding_intro_screen.dart';
import 'package:flutter/material.dart';

class DesktopOnboardingScreen extends StatelessWidget {
  const DesktopOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingIntroScreen(forceDesktop: true);
  }
}
