import 'package:flutter/material.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class WalletReconnectAction {
  const WalletReconnectAction._();

  static Future<void> handleReadOnlyReconnect({
    required BuildContext context,
    required WalletProvider walletProvider,
    bool refreshBackendSession = true,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final managedEligible = await walletProvider.isManagedReconnectEligible();
    if (!managedEligible) {
      if (!context.mounted) return;
      navigator.pushNamed('/connect-wallet');
      return;
    }

    final outcome = await walletProvider.recoverManagedWalletSession(
      refreshBackendSession: refreshBackendSession,
    );
    if (!context.mounted) return;

    if (walletProvider.canTransact) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.walletReconnectSuccessToast)),
        tone: KubusSnackBarTone.success,
      );
      return;
    }

    if (outcome == ManagedWalletReconnectOutcome.manualConnectRequired) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.walletReconnectManualRequiredToast)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }

    messenger.showKubusSnackBar(
      SnackBar(content: Text(l10n.walletReconnectReadOnlyToast)),
      tone: KubusSnackBarTone.neutral,
    );
  }
}
