import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';

class WalletBackupStatusSnapshot {
  const WalletBackupStatusSnapshot({
    required this.walletAddress,
    required this.hasWalletIdentity,
    required this.hasSigner,
    required this.isReadOnlySession,
    required this.mnemonicBackupRequired,
    required this.hasEncryptedServerBackup,
    required this.hasPasskeyProtection,
    this.encryptedBackupStatusKnown = true,
  });

  const WalletBackupStatusSnapshot.noWallet()
      : walletAddress = null,
        hasWalletIdentity = false,
        hasSigner = false,
        isReadOnlySession = false,
        mnemonicBackupRequired = false,
        hasEncryptedServerBackup = false,
        hasPasskeyProtection = false,
        encryptedBackupStatusKnown = true;

  final String? walletAddress;
  final bool hasWalletIdentity;
  final bool hasSigner;
  final bool isReadOnlySession;
  final bool mnemonicBackupRequired;
  final bool hasEncryptedServerBackup;
  final bool hasPasskeyProtection;
  final bool encryptedBackupStatusKnown;

  bool get encryptedBackupRequirementSatisfiedForGating =>
      hasEncryptedServerBackup || !encryptedBackupStatusKnown;

  bool get needsSignerRestore => hasWalletIdentity && !hasSigner;

  _WalletBackupStatusKind get _statusKind {
    if (!hasWalletIdentity) {
      return _WalletBackupStatusKind.noWallet;
    }
    if (needsSignerRestore && hasEncryptedServerBackup) {
      return _WalletBackupStatusKind.encryptedBackupRestoreAvailable;
    }
    if (needsSignerRestore) {
      return _WalletBackupStatusKind.readOnly;
    }
    if (mnemonicBackupRequired) {
      return _WalletBackupStatusKind.recoveryPhraseRequired;
    }
    if (hasPasskeyProtection) {
      return _WalletBackupStatusKind.passkeyProtection;
    }
    if (hasEncryptedServerBackup) {
      return _WalletBackupStatusKind.encryptedBackup;
    }
    return _WalletBackupStatusKind.noBackup;
  }

  String settingsSummary(AppLocalizations l10n) {
    switch (_statusKind) {
      case _WalletBackupStatusKind.noWallet:
        return l10n.settingsBackupStatusNoWallet;
      case _WalletBackupStatusKind.encryptedBackupRestoreAvailable:
        return l10n.settingsBackupStatusEncryptedBackupRestoreAvailable;
      case _WalletBackupStatusKind.readOnly:
        return l10n.settingsBackupStatusReadOnly;
      case _WalletBackupStatusKind.recoveryPhraseRequired:
        return l10n.settingsBackupStatusRecoveryPhraseRequired;
      case _WalletBackupStatusKind.passkeyProtection:
        return l10n.settingsBackupStatusPasskeyProtection;
      case _WalletBackupStatusKind.encryptedBackup:
        return l10n.settingsBackupStatusEncryptedServerBackup;
      case _WalletBackupStatusKind.noBackup:
        return l10n.settingsBackupStatusNoBackup;
    }
  }

  String protectionHeadline(AppLocalizations l10n) {
    switch (_statusKind) {
      case _WalletBackupStatusKind.noWallet:
        return l10n.walletBackupProtectionNoWalletHeadline;
      case _WalletBackupStatusKind.encryptedBackupRestoreAvailable:
        return l10n.walletBackupProtectionEncryptedRestoreHeadline;
      case _WalletBackupStatusKind.readOnly:
        return l10n.walletBackupProtectionReadOnlyHeadline;
      case _WalletBackupStatusKind.recoveryPhraseRequired:
        return l10n.walletBackupProtectionRecoveryPhraseHeadline;
      case _WalletBackupStatusKind.passkeyProtection:
        return l10n.walletBackupProtectionPasskeyHeadline;
      case _WalletBackupStatusKind.encryptedBackup:
        return l10n.walletBackupProtectionEncryptedHeadline;
      case _WalletBackupStatusKind.noBackup:
        return l10n.walletBackupProtectionNoBackupHeadline;
    }
  }

  String protectionBody(AppLocalizations l10n) {
    switch (_statusKind) {
      case _WalletBackupStatusKind.noWallet:
        return l10n.walletBackupProtectionNoWalletBody;
      case _WalletBackupStatusKind.encryptedBackupRestoreAvailable:
        return l10n.walletBackupProtectionEncryptedRestoreBody;
      case _WalletBackupStatusKind.readOnly:
        return l10n.walletBackupProtectionReadOnlyBody;
      case _WalletBackupStatusKind.recoveryPhraseRequired:
        return l10n.walletBackupProtectionRecoveryPhraseBody;
      case _WalletBackupStatusKind.passkeyProtection:
        return l10n.walletBackupProtectionPasskeyBody;
      case _WalletBackupStatusKind.encryptedBackup:
        return l10n.walletBackupProtectionEncryptedBody;
      case _WalletBackupStatusKind.noBackup:
        return l10n.walletBackupProtectionNoBackupBody;
    }
  }
}

enum _WalletBackupStatusKind {
  noWallet,
  encryptedBackupRestoreAvailable,
  readOnly,
  recoveryPhraseRequired,
  passkeyProtection,
  encryptedBackup,
  noBackup,
}

class WalletBackupStatusResolver {
  static Future<WalletBackupStatusSnapshot> resolve({
    required WalletProvider walletProvider,
    String? walletAddress,
    bool refreshRemote = true,
  }) async {
    final resolvedWallet =
        (walletAddress ?? walletProvider.currentWalletAddress ?? '').trim();
    final hasWalletIdentity =
        resolvedWallet.isNotEmpty || walletProvider.hasWalletIdentity;
    if (!hasWalletIdentity) {
      return const WalletBackupStatusSnapshot.noWallet();
    }

    var mnemonicBackupRequired = false;
    try {
      mnemonicBackupRequired = await walletProvider.isMnemonicBackupRequired(
        walletAddress: resolvedWallet,
      );
    } catch (_) {
      mnemonicBackupRequired = false;
    }

    final encryptedBackupEnabled =
        AppConfig.isFeatureEnabled('encryptedWalletBackup');
    final passkeyEnabled =
        kIsWeb && AppConfig.isFeatureEnabled('walletBackupPasskeyWeb');

    var hasEncryptedServerBackup = false;
    var hasPasskeyProtection = false;
    var encryptedBackupStatusKnown = !encryptedBackupEnabled;
    if (encryptedBackupEnabled) {
      try {
        final definition = await walletProvider.getEncryptedWalletBackup(
          walletAddress: resolvedWallet,
          refresh: refreshRemote,
        );
        hasEncryptedServerBackup = definition != null;
        hasPasskeyProtection =
            passkeyEnabled && (definition?.passkeys.isNotEmpty ?? false);
        encryptedBackupStatusKnown = true;
      } catch (_) {
        hasEncryptedServerBackup = false;
        hasPasskeyProtection = false;
        encryptedBackupStatusKnown = false;
      }
    }

    return WalletBackupStatusSnapshot(
      walletAddress: resolvedWallet.isEmpty ? null : resolvedWallet,
      hasWalletIdentity: hasWalletIdentity,
      hasSigner: walletProvider.hasSigner,
      isReadOnlySession: walletProvider.isReadOnlySession,
      mnemonicBackupRequired: mnemonicBackupRequired,
      hasEncryptedServerBackup: hasEncryptedServerBackup,
      hasPasskeyProtection: hasPasskeyProtection,
      encryptedBackupStatusKnown: encryptedBackupStatusKnown,
    );
  }
}
