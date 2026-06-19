import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/security/security_hub_view.dart';

class SecurityHubScreen extends StatelessWidget {
  const SecurityHubScreen({
    super.key,
    required this.mode,
    this.initialSection = SecuritySection.account,
    this.onBackupStateChanged,
  });

  final SecurityHubMode mode;
  final SecuritySection initialSection;
  final Future<void> Function()? onBackupStateChanged;

  @override
  Widget build(BuildContext context) {
    final canNavigateBack = mode == SecurityHubMode.manage;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: canNavigateBack,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          mode == SecurityHubMode.requiredSetup
              ? l10n?.securityHubAccountSecurity ?? 'Account security'
              : l10n?.securityHubTitle ?? 'Security hub',
        ),
      ),
      body: SafeArea(
        child: SecurityHubView(
          mode: mode,
          initialSection: initialSection,
          onBackupStateChanged: onBackupStateChanged,
          onRequiredSetupComplete: () {
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );
  }
}
