import 'package:flutter/material.dart';

import '../security/security_hub_screen.dart';
import '../../widgets/security/security_hub_view.dart';

class SecuritySetupScreen extends StatelessWidget {
  const SecuritySetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SecurityHubScreen(
      mode: SecurityHubMode.requiredSetup,
      initialSection: SecuritySection.localDevice,
    );
  }
}
