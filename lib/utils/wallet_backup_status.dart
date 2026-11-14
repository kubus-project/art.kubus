import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter/foundation.dart';

class WalletBackupStatusSnapshot {
  const WalletBackupStatusSnapshot({
    required this.walletAddress,
    required this.hasAccountSession,
    required this.hasWalletIdentity,
    required this.hasSigner,
    required this.isReadOnlySession,
    required this.mnemonicBackupRequired,
    required this.hasEncryptedServerBackup,
    required this.hasPasskeyProtection,
    this.encryptedBackupStatusKnown = true,
    this.resolved = true,
  });

  /// Nothing has been resolved yet: the copy stays neutral and never reads as
  /// "no wallet" or "restore" before the account's wallet linkage is known.
  const WalletBackupStatusSnapshot.pending()
      : walletAddress = null,
        hasAccountSession = false,
        hasWalletIdentity = false,
        hasSigner = false,
        isReadOnlySession = false,
        mnemonicBackupRequired = false,
        hasEncryptedServerBackup = false,
        hasPasskeyProtection = false,
        encryptedBackupStatusKnown = true,
        resolved = false;

  const WalletBackupStatusSnapshot.noWallet()
      : walletAddress = null,
        hasAccountSession = false,
        hasWalletIdentity = false,
        hasSigner = false,
        isReadOnlySession = false,
        mnemonicBackupRequired = false,
        hasEncryptedServerBackup = false,
        hasPasskeyProtection = false,
        encryptedBackupStatusKnown = true,
        resolved = true;

  final String? walletAddress;
  final bool hasAccountSession;
  final bool hasWalletIdentity;
  final bool hasSigner;
  final bool isReadOnlySession;
  final bool mnemonicBackupRequired;
  final bool hasEncryptedServerBackup;
  final bool hasPasskeyProtection;
  final bool encryptedBackupStatusKnown;
  final bool resolved;

  bool get encryptedBackupRequirementSatisfiedForGating =>
      hasEncryptedServerBackup || !encryptedBackupStatusKnown;

  bool get needsSignerRestore => hasWalletIdentity && !hasSigner;

  /// [linkagePending] is the live linkage state from
  /// [WalletPresentationStateResolver.linkagePendingFor]. While it is pending
  /// and no wallet identity is known, nothing can honestly be said about
  /// wallet absence, so the copy is the neutral loading state.
  _WalletBackupStatusKind _statusKind({required bool linkagePending}) {
    if (!resolved) {
      return _WalletBackupStatusKind.loading;
    }
    if (!hasWalletIdentity) {
      if (linkagePending) {
        return _WalletBackupStatusKind.loading;
      }
      // A wallet is optional for an account. Nothing exists to restore here,
      // so this is never a restore state.
      if (hasAccountSession) {
        return _WalletBackupStatusKind.walletless;
      }
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

  String settingsSummary(
    AppLocalizations l10n, {
    bool linkagePending = false,
  }) {
    switch (_statusKind(linkagePending: linkagePending)) {
      case _WalletBackupStatusKind.loading:
        return l10n.settingsBackupStatusChecking;
      case _WalletBackupStatusKind.noWallet:
        return l10n.settingsBackupStatusNoWallet;
      case _WalletBackupStatusKind.walletless:
        return l10n.settingsBackupStatusWalletless;
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

  String protectionHeadline(
    AppLocalizations l10n, {
    bool linkagePending = false,
  }) {
    switch (_statusKind(linkagePending: linkagePending)) {
      case _WalletBackupStatusKind.loading:
        return l10n.walletBackupProtectionCheckingHeadline;
      case _WalletBackupStatusKind.noWallet:
        return l10n.walletBackupProtectionNoWalletHeadline;
      case _WalletBackupStatusKind.walletless:
        return l10n.walletBackupProtectionWalletlessHeadline;
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

  String protectionBody(
    AppLocalizations l10n, {
    bool linkagePending = false,
  }) {
    switch (_statusKind(linkagePending: linkagePending)) {
      case _WalletBackupStatusKind.loading:
        return l10n.walletBackupProtectionCheckingBody;
      case _WalletBackupStatusKind.noWallet:
        return l10n.walletBackupProtectionNoWalletBody;
      case _WalletBackupStatusKind.walletless:
        return l10n.walletBackupProtectionWalletlessBody;
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
  loading,
  noWallet,
  walletless,
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
      // Keep the account session: a signed-in account without a wallet is a
      // walletless account, which must not be read as signed out.
      return WalletBackupStatusSnapshot(
        walletAddress: null,
        hasAccountSession: walletProvider.authority.hasAccountSession,
        hasWalletIdentity: false,
        hasSigner: false,
        isReadOnlySession: false,
        mnemonicBackupRequired: false,
        hasEncryptedServerBackup: false,
        hasPasskeyProtection: false,
      );
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
      hasAccountSession: walletProvider.authority.hasAccountSession,
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
