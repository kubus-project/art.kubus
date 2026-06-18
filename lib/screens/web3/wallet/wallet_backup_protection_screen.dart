import 'package:flutter/material.dart';

import 'package:art_kubus/screens/security/security_hub_screen.dart';
import 'package:art_kubus/widgets/security/security_hub_view.dart';

class WalletBackupProtectionScreen extends StatelessWidget {
  const WalletBackupProtectionScreen({
    super.key,
    this.onBackupStateChanged,
  });

  final Future<void> Function()? onBackupStateChanged;

  @override
  Widget build(BuildContext context) {
    return SecurityHubScreen(
      mode: SecurityHubMode.manage,
      initialSection: SecuritySection.wallet,
      onBackupStateChanged: onBackupStateChanged,
    );
  }
}
