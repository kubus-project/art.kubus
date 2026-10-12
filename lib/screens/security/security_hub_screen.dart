import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/security/security_hub_view.dart';
import '../desktop/desktop_shell_scope.dart';

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
    // Inside the desktop shell the screen sits in the shell's own stack, not on
    // a route, so the implied Back would target the outer route.
    final inShell = DesktopShellScope.of(context)?.canPop ?? false;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: canNavigateBack && !inShell,
        leading: canNavigateBack && inShell
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.commonBack,
                onPressed: () => popDesktopShellAware(context),
              )
            : null,
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
