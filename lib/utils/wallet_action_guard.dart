import 'package:flutter/material.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/contextual_auth_gate.dart';
import 'package:art_kubus/utils/wallet_reconnect_action.dart';

enum WalletSignerActionBlock {
  signInRequired,
  walletRequired,
  signerRequired,
}

class WalletSessionAccessSnapshot {
  const WalletSessionAccessSnapshot({
    required this.isSignedIn,
    required this.hasWalletIdentity,
    required this.hasSigner,
    required this.authorityState,
    required this.canRestoreFromEncryptedBackup,
  });

  factory WalletSessionAccessSnapshot.fromProviders({
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
  }) {
    final authority = walletProvider.authority;
    return WalletSessionAccessSnapshot(
      isSignedIn: authority.accountSignedIn,
      hasWalletIdentity: authority.hasWalletIdentity,
      hasSigner: authority.canTransact,
      authorityState: authority.state,
      canRestoreFromEncryptedBackup: authority.canRestoreFromEncryptedBackup,
    );
  }

  final bool isSignedIn;
  final bool hasWalletIdentity;
  final bool hasSigner;
  final WalletAuthorityState authorityState;
  final bool canRestoreFromEncryptedBackup;

  bool get canTransact => hasWalletIdentity && hasSigner;
  bool get isReadOnlySession => hasWalletIdentity && !hasSigner;

  WalletSignerActionBlock? signerActionBlock({
    bool requireSignedIn = true,
  }) {
    if (requireSignedIn && !isSignedIn) {
      return WalletSignerActionBlock.signInRequired;
    }
    if (!hasWalletIdentity) {
      return WalletSignerActionBlock.walletRequired;
    }
    if (!hasSigner) {
      return WalletSignerActionBlock.signerRequired;
    }
    return null;
  }

  String accountStatusLabel(AppLocalizations l10n) {
    return isSignedIn
        ? l10n.walletSessionAccountSignedIn
        : l10n.walletSessionAccountSignedOut;
  }

  String walletStatusLabel(AppLocalizations l10n) {
    return hasWalletIdentity
        ? l10n.settingsWalletConnectionConnected
        : l10n.settingsWalletConnectionNotConnected;
  }

  String signerStatusLabel(AppLocalizations l10n) {
    if (!hasWalletIdentity) {
      return l10n.commonNotAvailableShort;
    }
    return canTransact
        ? l10n.walletSessionSignerReady
        : l10n.walletSessionSignerMissing;
  }

  String settingsStatusSummary(AppLocalizations l10n) {
    return l10n.walletSessionStatusSummary(
      accountStatusLabel(l10n),
      walletStatusLabel(l10n),
      signerStatusLabel(l10n),
    );
  }

  String blockMessage(
    AppLocalizations l10n,
    WalletSignerActionBlock block,
  ) {
    switch (block) {
      case WalletSignerActionBlock.signInRequired:
        return l10n.walletActionSignInRequiredToast;
      case WalletSignerActionBlock.walletRequired:
        if (authorityState == WalletAuthorityState.accountShellOnly) {
          return l10n.walletActionAccountShellNeedsWalletToast;
        }
        return l10n.walletActionConnectWalletRequiredToast;
      case WalletSignerActionBlock.signerRequired:
        switch (authorityState) {
          case WalletAuthorityState.encryptedBackupAvailableSignerMissing:
            return l10n.walletActionEncryptedBackupRestoreToast;
          case WalletAuthorityState.recoveryNeeded:
            return l10n.walletActionRecoveryNeededToast;
          case WalletAuthorityState.walletReadOnly:
            return l10n.walletActionReadOnlyReconnectToast;
          case WalletAuthorityState.localSignerReady:
          case WalletAuthorityState.externalWalletReady:
          case WalletAuthorityState.accountShellOnly:
          case WalletAuthorityState.signedOut:
            return l10n.walletReconnectManualRequiredToast;
        }
    }
  }
}

class WalletActionGuard {
  static Future<bool> ensureSignerAccess({
    required BuildContext context,
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
    bool requireSignedIn = true,
    bool refreshBackendSession = true,
  }) async {
    final access = WalletSessionAccessSnapshot.fromProviders(
      profileProvider: profileProvider,
      walletProvider: walletProvider,
    );
    final block = access.signerActionBlock(requireSignedIn: requireSignedIn);
    if (block == null) {
      return true;
    }

    if (block == WalletSignerActionBlock.signerRequired) {
      await WalletReconnectAction.handleReadOnlyReconnect(
        context: context,
        walletProvider: walletProvider,
        refreshBackendSession: refreshBackendSession,
      );
      return walletProvider.canTransact;
    }

    // Missing account/wallet capability is acquisition, not signer recovery.
    // It enters the same contextual account flow as the rest of the app. The
    // attempted financial operation is intentionally not captured, so it must
    // be explicitly started again after setup.
    final requestedRoute = ModalRoute.of(context)?.settings.name;
    await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: AppLocalizations.of(context)!.commonContinue,
      returnRoute: requestedRoute ?? '/wallet',
      requirements: ProtectedActionRequirements.wallet,
    );
    return false;
  }
}
