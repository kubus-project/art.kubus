import 'package:flutter/material.dart';

import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
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

/// Opens wallet backup protection from any surface.
///
/// Inside the desktop shell the screen is pushed into the shell's content
/// column, so the sidebar and header stay and Back returns to the caller. A
/// full-screen route would cover the shell. Elsewhere (mobile, or no shell in
/// scope) it is a normal route and the returned future completes on pop.
/// [onBackupStateChanged] runs after the backup state changes in both modes.
Future<void> openWalletBackupProtection(
  BuildContext context, {
  Future<void> Function()? onBackupStateChanged,
}) async {
  final shellScope = DesktopShellScope.of(context);
  if (shellScope != null) {
    shellScope.pushScreen(
      WalletBackupProtectionScreen(onBackupStateChanged: onBackupStateChanged),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => WalletBackupProtectionScreen(
        onBackupStateChanged: onBackupStateChanged,
      ),
    ),
  );
  if (!context.mounted) return;
  await onBackupStateChanged?.call();
}
