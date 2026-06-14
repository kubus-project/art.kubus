import 'package:flutter/material.dart';

import '../config/config.dart';
import '../l10n/app_localizations.dart';
import '../providers/security_gate_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/wallet_utils.dart';
import '../widgets/wallet_backup_prompts.dart';

enum WalletRecoveryResultKind {
  restored,
  cancelled,
  passkeyUnavailable,
  passkeyFailed,
  passwordFailed,
  mnemonicRequired,
  readOnlyChosen,
  noBackupAvailable,
  failed,
}

enum WalletRecoveryOrigin {
  postAuth,
  walletSecurityScreen,
  onboarding,
  manualWalletProtection,
}

enum WalletRecoveryRestoreMethod {
  localSigner,
  managedReconnect,
  passkey,
  recoveryPassword,
  recoveryPhrase,
}

class WalletRecoveryResult {
  const WalletRecoveryResult({
    required this.kind,
    this.walletAddress,
    this.error,
    this.restoreMethod,
  });

  final WalletRecoveryResultKind kind;
  final String? walletAddress;
  final Object? error;
  final WalletRecoveryRestoreMethod? restoreMethod;

  bool get restored => kind == WalletRecoveryResultKind.restored;
}

class WalletRecoveryFlowService {
  const WalletRecoveryFlowService();

  Future<WalletRecoveryResult> recoverSignerForAccountWallet({
    required BuildContext context,
    required String walletAddress,
    required WalletProvider walletProvider,
    required SecurityGateProvider securityGateProvider,
    required WalletRecoveryOrigin origin,
  }) async {
    final targetWallet = walletAddress.trim();
    if (targetWallet.isEmpty) {
      return const WalletRecoveryResult(kind: WalletRecoveryResultKind.failed);
    }

    bool signerReady() {
      return walletProvider.hasSigner &&
          WalletUtils.equals(walletProvider.currentWalletAddress, targetWallet);
    }

    if (signerReady()) {
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.restored,
        walletAddress: targetWallet,
        restoreMethod: WalletRecoveryRestoreMethod.localSigner,
      );
    }

    try {
      if (!WalletUtils.equals(
        walletProvider.currentWalletAddress,
        targetWallet,
      )) {
        await walletProvider.setReadOnlyWalletIdentity(targetWallet);
      }

      final managedOutcome = await walletProvider.recoverManagedWalletSession(
        walletAddress: targetWallet,
        refreshBackendSession: false,
      );
      if (managedOutcome == ManagedWalletReconnectOutcome.signerRestored &&
          signerReady()) {
        return WalletRecoveryResult(
          kind: WalletRecoveryResultKind.restored,
          walletAddress: targetWallet,
          restoreMethod: WalletRecoveryRestoreMethod.managedReconnect,
        );
      }
    } catch (error) {
      AppConfig.debugPrint(
        'WalletRecoveryFlowService: local reconnect failed: $error',
      );
    }

    if (signerReady()) {
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.restored,
        walletAddress: targetWallet,
        restoreMethod: WalletRecoveryRestoreMethod.localSigner,
      );
    }

    final backup = await walletProvider.getEncryptedWalletBackup(
      walletAddress: targetWallet,
      refresh: true,
    );
    if (!context.mounted) {
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.cancelled,
        walletAddress: targetWallet,
      );
    }

    Object? lastError;
    var fallbackKind = backup == null
        ? WalletRecoveryResultKind.noBackupAvailable
        : WalletRecoveryResultKind.mnemonicRequired;
    var fallbackTitle = _fallbackTitle(context, fallbackKind);
    var fallbackDescription = _fallbackDescription(context);

    if (backup != null && backup.passkeys.isNotEmpty) {
      try {
        final restored =
            await walletProvider.restoreSignerFromEncryptedWalletBackupPasskey(
          walletAddress: targetWallet,
        );
        if (restored && signerReady()) {
          return WalletRecoveryResult(
            kind: WalletRecoveryResultKind.restored,
            walletAddress: targetWallet,
            restoreMethod: WalletRecoveryRestoreMethod.passkey,
          );
        }
        if (!context.mounted) {
          return WalletRecoveryResult(
            kind: WalletRecoveryResultKind.cancelled,
            walletAddress: targetWallet,
          );
        }
        fallbackKind = WalletRecoveryResultKind.passkeyUnavailable;
        fallbackTitle = _fallbackTitle(context, fallbackKind);
      } catch (error) {
        lastError = error;
        if (!context.mounted) {
          return WalletRecoveryResult(
            kind: WalletRecoveryResultKind.cancelled,
            walletAddress: targetWallet,
            error: lastError,
          );
        }
        fallbackKind = WalletRecoveryResultKind.passkeyFailed;
        fallbackTitle = _fallbackTitle(context, fallbackKind);
      }
    }

    while (context.mounted) {
      final choice = await showWalletRecoveryFallbackChoicePrompt(
        context: context,
        title: fallbackTitle,
        description: fallbackDescription,
        showRecoveryPassword: backup != null,
        showRecoveryPhrase: true,
        showReadOnly: _readOnlyAllowed(origin),
      );
      if (!context.mounted) {
        return const WalletRecoveryResult(
          kind: WalletRecoveryResultKind.cancelled,
        );
      }
      if (choice == null) {
        return WalletRecoveryResult(
          kind: fallbackKind == WalletRecoveryResultKind.noBackupAvailable
              ? WalletRecoveryResultKind.noBackupAvailable
              : WalletRecoveryResultKind.cancelled,
          walletAddress: targetWallet,
          error: lastError,
        );
      }

      switch (choice) {
        case WalletRecoveryFallbackChoice.recoveryPassword:
          final result = await _recoverWithPassword(
            context: context,
            walletProvider: walletProvider,
            securityGateProvider: securityGateProvider,
            walletAddress: targetWallet,
          );
          if (result.restored) return result;
          lastError = result.error;
          if (!context.mounted) return result;
          fallbackKind = WalletRecoveryResultKind.passwordFailed;
          fallbackTitle = _fallbackTitle(context, fallbackKind);
          break;
        case WalletRecoveryFallbackChoice.recoveryPhrase:
          final result = await _recoverWithMnemonic(
            context: context,
            walletProvider: walletProvider,
            securityGateProvider: securityGateProvider,
            walletAddress: targetWallet,
          );
          if (result.restored) return result;
          lastError = result.error;
          if (!context.mounted) return result;
          fallbackKind = WalletRecoveryResultKind.mnemonicRequired;
          fallbackTitle = _fallbackTitle(context, fallbackKind);
          break;
        case WalletRecoveryFallbackChoice.readOnly:
          await walletProvider.setReadOnlyWalletIdentity(targetWallet);
          return WalletRecoveryResult(
            kind: WalletRecoveryResultKind.readOnlyChosen,
            walletAddress: targetWallet,
          );
      }
    }

    return WalletRecoveryResult(
      kind: WalletRecoveryResultKind.cancelled,
      walletAddress: targetWallet,
      error: lastError,
    );
  }

  Future<WalletRecoveryResult> _recoverWithPassword({
    required BuildContext context,
    required WalletProvider walletProvider,
    required SecurityGateProvider securityGateProvider,
    required String walletAddress,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final recoveryPassword = await showWalletBackupPasswordPrompt(
      context: context,
      title: l10n.authRestoreWalletTitle,
      description: l10n.authRestoreWalletForAccountDescription,
      actionLabel: l10n.authRestoreWalletAction,
    );
    if (!context.mounted || recoveryPassword == null) {
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.cancelled,
        walletAddress: walletAddress,
      );
    }

    final verified =
        await securityGateProvider.requireSensitiveActionVerification();
    if (!context.mounted || !verified) {
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.cancelled,
        walletAddress: walletAddress,
      );
    }

    try {
      final restored = await walletProvider.restoreSignerFromEncryptedWalletBackup(
        walletAddress: walletAddress,
        recoveryPassword: recoveryPassword,
      );
      if (restored &&
          walletProvider.hasSigner &&
          WalletUtils.equals(walletProvider.currentWalletAddress, walletAddress)) {
        return WalletRecoveryResult(
          kind: WalletRecoveryResultKind.restored,
          walletAddress: walletAddress,
          restoreMethod: WalletRecoveryRestoreMethod.recoveryPassword,
        );
      }
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.passwordFailed,
        walletAddress: walletAddress,
      );
    } catch (error) {
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.passwordFailed,
        walletAddress: walletAddress,
        error: error,
      );
    }
  }

  Future<WalletRecoveryResult> _recoverWithMnemonic({
    required BuildContext context,
    required WalletProvider walletProvider,
    required SecurityGateProvider securityGateProvider,
    required String walletAddress,
  }) async {
    final mnemonic = await showWalletRecoveryPhraseImportPrompt(
      context: context,
    );
    if (!context.mounted || mnemonic == null) {
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.cancelled,
        walletAddress: walletAddress,
      );
    }

    try {
      final derivedAddress =
          await walletProvider.deriveWalletAddressFromMnemonic(mnemonic);
      if (!WalletUtils.equals(derivedAddress, walletAddress)) {
        return WalletRecoveryResult(
          kind: WalletRecoveryResultKind.mnemonicRequired,
          walletAddress: walletAddress,
          error: 'mnemonic-wallet-mismatch',
        );
      }

      final verified =
          await securityGateProvider.requireSensitiveActionVerification();
      if (!context.mounted || !verified) {
        return WalletRecoveryResult(
          kind: WalletRecoveryResultKind.cancelled,
          walletAddress: walletAddress,
        );
      }

      final importedAddress = await walletProvider.importWalletFromMnemonic(
        mnemonic,
        markBackedUp: true,
      );
      if (WalletUtils.equals(importedAddress, walletAddress) &&
          walletProvider.hasSigner) {
        return WalletRecoveryResult(
          kind: WalletRecoveryResultKind.restored,
          walletAddress: walletAddress,
          restoreMethod: WalletRecoveryRestoreMethod.recoveryPhrase,
        );
      }
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.mnemonicRequired,
        walletAddress: walletAddress,
      );
    } catch (error) {
      return WalletRecoveryResult(
        kind: WalletRecoveryResultKind.mnemonicRequired,
        walletAddress: walletAddress,
        error: error,
      );
    }
  }

  bool _readOnlyAllowed(WalletRecoveryOrigin origin) {
    return origin != WalletRecoveryOrigin.onboarding;
  }

  String _fallbackTitle(
    BuildContext context,
    WalletRecoveryResultKind kind,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return switch (kind) {
      WalletRecoveryResultKind.passkeyFailed =>
        l10n.walletRecoveryPasskeyFailedTitle,
      WalletRecoveryResultKind.passkeyUnavailable =>
        l10n.walletRecoveryPasskeyUnavailableTitle,
      WalletRecoveryResultKind.passwordFailed =>
        l10n.walletRecoveryPasswordFailedTitle,
      WalletRecoveryResultKind.noBackupAvailable =>
        l10n.walletRecoveryNoBackupTitle,
      _ => l10n.walletRecoveryFallbackTitle,
    };
  }

  String _fallbackDescription(BuildContext context) {
    return AppLocalizations.of(context)!.walletRecoveryFallbackDescription;
  }
}
