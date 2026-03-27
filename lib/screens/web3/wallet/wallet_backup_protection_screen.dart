import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/web3/wallet/mnemonic_reveal_screen.dart';
import 'package:art_kubus/services/wallet_backup_passkey_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/wallet_backup_status.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/wallet_backup_prompts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WalletBackupProtectionScreen extends StatefulWidget {
  const WalletBackupProtectionScreen({
    super.key,
    this.onBackupStateChanged,
  });

  final Future<void> Function()? onBackupStateChanged;

  @override
  State<WalletBackupProtectionScreen> createState() =>
      _WalletBackupProtectionScreenState();
}

class _WalletBackupProtectionScreenState
    extends State<WalletBackupProtectionScreen> {
  bool _backupRequired = false;
  bool _passkeysSupported = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final walletProvider = context.read<WalletProvider>();
    var backupRequired = false;
    var passkeysSupported = false;

    try {
      backupRequired = await walletProvider.isMnemonicBackupRequired();
      passkeysSupported = kIsWeb && await isWalletBackupPasskeySupported();
      try {
        await walletProvider.refreshEncryptedWalletBackupStatus();
      } catch (_) {
        // Preserve local backup access even when the remote backup status lookup
        // fails (for example, wallet-only sessions without backend auth).
      }
    } catch (_) {
      backupRequired = false;
      passkeysSupported = false;
    }

    if (!mounted) return;
    setState(() {
      _backupRequired = backupRequired;
      _passkeysSupported = passkeysSupported;
      _loading = false;
    });
  }

  Future<void> _runProtectedAction(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      await _refresh();
      await widget.onBackupStateChanged?.call();
    } catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(e.toString())),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Future<void> _createOrUpdateBackup() async {
    final gate = context.read<SecurityGateProvider>();
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final verified = await gate.requireSensitiveActionVerification();
    if (!mounted) return;
    if (!verified) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.lockAuthenticationFailedToast)),
        tone: KubusSnackBarTone.error,
      );
      return;
    }

    final recoveryPassword = await showWalletBackupPasswordPrompt(
      context: context,
      title: 'Create encrypted backup',
      description:
          'Choose a recovery password. This password decrypts the wallet backup on a new device.',
      confirm: true,
      actionLabel: 'Create backup',
    );
    if (!mounted || recoveryPassword == null) return;

    await _runProtectedAction(() async {
      await walletProvider.createEncryptedWalletBackup(
        recoveryPassword: recoveryPassword,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Encrypted wallet backup saved.')),
      );
    });
  }

  Future<void> _verifyBackup() async {
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await _runProtectedAction(() async {
      if (kIsWeb &&
          AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') &&
          walletProvider.encryptedWalletBackupPasskeys.isNotEmpty) {
        await walletProvider.authenticateEncryptedWalletBackupPasskey();
      }
      if (!mounted) return;
      final recoveryPassword = await showWalletBackupPasswordPrompt(
        context: context,
        title: 'Verify encrypted backup',
        description:
            'Enter the recovery password to verify the encrypted backup can be decrypted locally.',
        actionLabel: 'Verify backup',
      );
      if (!mounted || recoveryPassword == null) return;
      await walletProvider.verifyEncryptedWalletBackup(
        recoveryPassword: recoveryPassword,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Encrypted backup verified.')),
      );
    });
  }

  Future<void> _deleteBackup() async {
    final gate = context.read<SecurityGateProvider>();
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showKubusDialog<bool>(
          context: context,
          builder: (dialogContext) => KubusAlertDialog(
            title: const Text('Delete encrypted backup?'),
            content: const Text(
              'This removes the encrypted server backup for the current wallet. Make sure you still have the recovery phrase stored safely offline.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final verified = await gate.requireSensitiveActionVerification();
    if (!mounted) return;
    if (!verified) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.lockAuthenticationFailedToast)),
        tone: KubusSnackBarTone.error,
      );
      return;
    }

    await _runProtectedAction(() async {
      await walletProvider.deleteEncryptedWalletBackup();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Encrypted wallet backup deleted.')),
      );
    });
  }

  Future<void> _revealRecoveryPhrase() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MnemonicRevealScreen()),
    );
    if (!mounted) return;
    await _refresh();
    await widget.onBackupStateChanged?.call();
  }

  Future<void> _enrollPasskey() async {
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nickname = await showWalletBackupTextPrompt(
      context: context,
      title: 'Add a passkey',
      label: 'Passkey name',
      description:
          'Give this passkey a label so you can recognize the device or browser later.',
      initialValue: 'This device',
      actionLabel: 'Add passkey',
    );
    if (!mounted || nickname == null) return;

    await _runProtectedAction(() async {
      final passkey = await walletProvider.enrollEncryptedWalletBackupPasskey(
        nickname: nickname,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            'Passkey "${passkey.nickname ?? passkey.credentialId}" added.',
          ),
        ),
      );
    });
  }

  Future<void> _restoreSignerFromBackup() async {
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await _runProtectedAction(() async {
      if (kIsWeb &&
          AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') &&
          walletProvider.encryptedWalletBackupPasskeys.isNotEmpty) {
        await walletProvider.authenticateEncryptedWalletBackupPasskey();
      }
      if (!mounted) return;
      final recoveryPassword = await showWalletBackupPasswordPrompt(
        context: context,
        title: 'Restore wallet signer',
        description:
            'Enter the recovery password for the encrypted server backup to restore signing access on this device.',
        actionLabel: 'Restore signer',
      );
      if (!mounted || recoveryPassword == null) return;
      final restored =
          await walletProvider.restoreSignerFromEncryptedWalletBackup(
        recoveryPassword: recoveryPassword,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            restored
                ? 'Wallet signer restored on this device.'
                : 'Unable to restore wallet signer.',
          ),
        ),
        tone: restored ? KubusSnackBarTone.success : KubusSnackBarTone.error,
      );
    });
  }

  String _walletLabel(String? walletAddress) {
    final value = (walletAddress ?? '').trim();
    if (value.length <= 14) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final walletProvider = context.watch<WalletProvider>();
    final walletAddress = walletProvider.currentWalletAddress;
    final backup = walletProvider.encryptedWalletBackupDefinition;
    final hasEncryptedBackup = walletProvider.hasEncryptedWalletBackup;
    final isBusy = _loading ||
        walletProvider.isEncryptedWalletBackupLoading ||
        walletProvider.isWalletBackupRecoveryInProgress;
    final passkeysEnabled = kIsWeb &&
        AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') &&
        hasEncryptedBackup &&
        _passkeysSupported;
    final backupStatus = WalletBackupStatusSnapshot(
      walletAddress: walletAddress,
      hasWalletIdentity: walletProvider.hasWalletIdentity,
      hasSigner: walletProvider.hasSigner,
      isReadOnlySession: walletProvider.isReadOnlySession,
      mnemonicBackupRequired: _backupRequired,
      hasEncryptedServerBackup: hasEncryptedBackup,
      hasPasskeyProtection: passkeysEnabled &&
          walletProvider.encryptedWalletBackupPasskeys.isNotEmpty,
    );
    final needsSignerRestore = backupStatus.needsSignerRestore;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protect your web3 wallet'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          children: <Widget>[
            LiquidGlassCard(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Current wallet',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _walletLabel(walletAddress),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    backupStatus.protectionHeadline(l10n),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    backupStatus.protectionBody(l10n),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.78),
                          height: 1.4,
                        ),
                  ),
                  if (_backupRequired && !hasEncryptedBackup) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'Back up the recovery phrase offline and store the encrypted backup recovery password separately.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                    ),
                  ],
                  if (backup?.lastVerifiedAt != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'Last verified: ${backup!.lastVerifiedAt!.toLocal()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: KubusSpacing.lg),
            if (needsSignerRestore && hasEncryptedBackup) ...<Widget>[
              FilledButton.tonalIcon(
                onPressed: isBusy ? null : _restoreSignerFromBackup,
                icon: const Icon(Icons.login_outlined),
                label: const Text('Restore wallet signer'),
              ),
              const SizedBox(height: KubusSpacing.sm),
            ],
            FilledButton.icon(
              onPressed: isBusy ? null : _createOrUpdateBackup,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                hasEncryptedBackup
                    ? 'Update encrypted server backup'
                    : 'Create encrypted server backup',
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            OutlinedButton.icon(
              onPressed: isBusy ? null : _revealRecoveryPhrase,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Reveal and copy recovery phrase'),
            ),
            if (hasEncryptedBackup) ...<Widget>[
              const SizedBox(height: KubusSpacing.sm),
              OutlinedButton.icon(
                onPressed: isBusy ? null : _verifyBackup,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Verify encrypted backup'),
              ),
              const SizedBox(height: KubusSpacing.sm),
              OutlinedButton.icon(
                onPressed: isBusy ? null : _deleteBackup,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete encrypted backup'),
              ),
            ],
            if (passkeysEnabled) ...<Widget>[
              const SizedBox(height: KubusSpacing.lg),
              LiquidGlassCard(
                padding: const EdgeInsets.all(KubusSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Passkeys',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      'On web, passkeys can gate access to the encrypted backup before the recovery password prompt is shown.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    FilledButton.tonalIcon(
                      onPressed: isBusy ? null : _enrollPasskey,
                      icon: const Icon(Icons.phishing_outlined),
                      label: const Text('Add passkey'),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    ...walletProvider.encryptedWalletBackupPasskeys.map(
                      (passkey) => FrostedContainer(
                        margin: const EdgeInsets.only(bottom: KubusSpacing.sm),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(passkey.nickname ?? passkey.credentialId),
                          subtitle: Text(
                            passkey.transports.isEmpty
                                ? 'Stored passkey'
                                : 'Transports: ${passkey.transports.join(', ')}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (walletProvider.encryptedWalletBackupError != null &&
                walletProvider.encryptedWalletBackupError!
                    .trim()
                    .isNotEmpty) ...<Widget>[
              const SizedBox(height: KubusSpacing.lg),
              FrostedContainer(
                backgroundColor: scheme.errorContainer.withValues(alpha: 0.28),
                child: Text(
                  walletProvider.encryptedWalletBackupError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
