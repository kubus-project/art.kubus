import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/app_mode_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/web3/wallet/mnemonic_reveal_screen.dart';
import 'package:art_kubus/services/wallet_backup_passkey_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/wallet_backup_status.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/app_mode_unavailable_state.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/wallet_backup_prompts.dart';
import 'package:art_kubus/widgets/wallet_custody_status_panel.dart';
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
      title: l10n.walletBackupProtectionCreateBackupTitle,
      description: l10n.walletBackupProtectionCreateBackupDescription,
      confirm: true,
      actionLabel: l10n.walletBackupProtectionCreateBackupAction,
    );
    if (!mounted || recoveryPassword == null) return;

    await _runProtectedAction(() async {
      await walletProvider.createEncryptedWalletBackup(
        recoveryPassword: recoveryPassword,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.walletBackupProtectionBackupSavedToast)),
      );
    });
  }

  Future<void> _verifyBackup() async {
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    await _runProtectedAction(() async {
      if (kIsWeb &&
          AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') &&
          walletProvider.encryptedWalletBackupPasskeys.isNotEmpty) {
        await walletProvider.authenticateEncryptedWalletBackupPasskey();
      }
      if (!mounted) return;
      final recoveryPassword = await showWalletBackupPasswordPrompt(
        context: context,
        title: l10n.walletBackupProtectionVerifyBackupTitle,
        description: l10n.walletBackupProtectionVerifyBackupDescription,
        actionLabel: l10n.walletBackupProtectionVerifyBackupAction,
      );
      if (!mounted || recoveryPassword == null) return;
      await walletProvider.verifyEncryptedWalletBackup(
        recoveryPassword: recoveryPassword,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.walletBackupProtectionBackupVerifiedToast)),
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
            title: Text(l10n.walletBackupProtectionDeleteBackupTitle),
            content: Text(l10n.walletBackupProtectionDeleteBackupBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.walletBackupProtectionDeleteBackupAction),
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
        SnackBar(content: Text(l10n.walletBackupProtectionBackupDeletedToast)),
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
    final l10n = AppLocalizations.of(context)!;
    final nickname = await showWalletBackupTextPrompt(
      context: context,
      title: l10n.walletBackupProtectionAddPasskeyTitle,
      label: l10n.walletBackupProtectionPasskeyNameLabel,
      description: l10n.walletBackupProtectionAddPasskeyDescription,
      initialValue: l10n.walletBackupProtectionDefaultPasskeyName,
      actionLabel: l10n.walletBackupProtectionAddPasskeyAction,
    );
    if (!mounted || nickname == null) return;

    await _runProtectedAction(() async {
      final passkey = await walletProvider.enrollEncryptedWalletBackupPasskey(
        nickname: nickname,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.walletBackupProtectionPasskeyAddedToast(
            passkey.nickname ?? passkey.credentialId,
          )),
        ),
      );
    });
  }

  Future<void> _restoreSignerFromBackup() async {
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    await _runProtectedAction(() async {
      if (kIsWeb &&
          AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') &&
          walletProvider.encryptedWalletBackupPasskeys.isNotEmpty) {
        await walletProvider.authenticateEncryptedWalletBackupPasskey();
      }
      if (!mounted) return;
      final recoveryPassword = await showWalletBackupPasswordPrompt(
        context: context,
        title: l10n.walletBackupProtectionRestoreSignerTitle,
        description: l10n.walletBackupProtectionRestoreSignerDescription,
        actionLabel: l10n.walletBackupProtectionRestoreSignerAction,
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
                ? l10n.walletBackupProtectionSignerRestoredToast
                : l10n.walletBackupProtectionSignerRestoreFailedToast,
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

  Widget _buildStateRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(KubusRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.66),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onPressed,
    required String actionLabel,
    bool emphasized = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = emphasized ? scheme.primary : scheme.secondary;
    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: KubusSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.74),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: KubusSpacing.md),
          SizedBox(
            width: double.infinity,
            child: emphasized
                ? FilledButton.icon(
                    onPressed: onPressed,
                    icon: Icon(icon, size: 18),
                    label: Text(actionLabel),
                  )
                : OutlinedButton.icon(
                    onPressed: onPressed,
                    icon: Icon(icon, size: 18),
                    label: Text(actionLabel),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appModeProvider = context.watch<AppModeProvider?>();
    final scheme = Theme.of(context).colorScheme;
    final walletProvider = context.watch<WalletProvider>();
    final authority = walletProvider.authority;
    final isIpfsFallbackMode = appModeProvider?.isIpfsFallbackMode ?? false;
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
      hasAccountSession: authority.hasAccountSession,
      hasWalletIdentity: walletProvider.hasWalletIdentity,
      hasSigner: walletProvider.hasSigner,
      isReadOnlySession: walletProvider.isReadOnlySession,
      mnemonicBackupRequired: _backupRequired,
      hasEncryptedServerBackup: hasEncryptedBackup,
      hasPasskeyProtection: passkeysEnabled &&
          walletProvider.encryptedWalletBackupPasskeys.isNotEmpty,
      encryptedBackupStatusKnown: authority.encryptedBackupStatusKnown,
    );
    final needsSignerRestore = backupStatus.needsSignerRestore;
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final isWide = mediaWidth >= 920;
    final crossAxisCount = isWide ? 2 : 1;
    final actionCards = <Widget>[
      if (needsSignerRestore && hasEncryptedBackup)
        _buildActionCard(
          context: context,
          icon: Icons.login_outlined,
          title: l10n.walletBackupProtectionRestoreSignerAction,
          description: l10n.walletBackupProtectionRestoreSignerDescription,
          onPressed: isBusy ? null : _restoreSignerFromBackup,
          actionLabel: l10n.walletBackupProtectionRestoreSignerAction,
          emphasized: true,
        ),
      _buildActionCard(
        context: context,
        icon: Icons.cloud_upload_outlined,
        title: hasEncryptedBackup
            ? l10n.walletBackupProtectionUpdateEncryptedBackupButton
            : l10n.walletBackupProtectionCreateEncryptedBackupButton,
        description: l10n.walletBackupProtectionCreateBackupDescription,
        onPressed: isBusy ? null : _createOrUpdateBackup,
        actionLabel: hasEncryptedBackup
            ? l10n.walletBackupProtectionUpdateEncryptedBackupButton
            : l10n.walletBackupProtectionCreateEncryptedBackupButton,
        emphasized: !hasEncryptedBackup,
      ),
      _buildActionCard(
        context: context,
        icon: Icons.visibility_outlined,
        title: l10n.walletBackupProtectionRevealRecoveryPhraseButton,
        description: l10n.walletBackupProtectionOfflineReminder,
        onPressed: isBusy ? null : _revealRecoveryPhrase,
        actionLabel: l10n.walletBackupProtectionRevealRecoveryPhraseButton,
      ),
      if (hasEncryptedBackup)
        _buildActionCard(
          context: context,
          icon: Icons.verified_user_outlined,
          title: l10n.walletBackupProtectionVerifyBackupAction,
          description: l10n.walletBackupProtectionVerifyBackupDescription,
          onPressed: isBusy ? null : _verifyBackup,
          actionLabel: l10n.walletBackupProtectionVerifyBackupAction,
        ),
      if (passkeysEnabled)
        _buildActionCard(
          context: context,
          icon: Icons.phishing_outlined,
          title: l10n.walletBackupProtectionAddPasskeyAction,
          description: l10n.walletBackupProtectionPasskeysBody,
          onPressed: isBusy ? null : _enrollPasskey,
          actionLabel: l10n.walletBackupProtectionAddPasskeyAction,
        ),
      if (hasEncryptedBackup)
        _buildActionCard(
          context: context,
          icon: Icons.delete_outline,
          title: l10n.walletBackupProtectionDeleteBackupAction,
          description: l10n.walletBackupProtectionDeleteBackupBody,
          onPressed: isBusy ? null : _deleteBackup,
          actionLabel: l10n.walletBackupProtectionDeleteBackupAction,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletBackupProtectionTitle),
      ),
      body: isIpfsFallbackMode
          ? AppModeUnavailableState(
              featureLabel: l10n.walletBackupProtectionFeatureLabel,
              title: l10n.walletBackupProtectionUnavailableTitle,
              icon: Icons.backup_outlined,
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.all(isWide ? KubusSpacing.xl : KubusSpacing.lg),
                children: <Widget>[
                  LiquidGlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(KubusSpacing.lg),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                scheme.primaryContainer.withValues(alpha: 0.92),
                                scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.82),
                                scheme.surface.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.walletBackupProtectionCurrentWalletLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color:
                                          scheme.onSurface.withValues(alpha: 0.72),
                                    ),
                              ),
                              const SizedBox(height: KubusSpacing.xs),
                              Text(
                                backupStatus.hasWalletIdentity
                                    ? _walletLabel(walletAddress)
                                    : backupStatus.settingsSummary(l10n),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: KubusSpacing.md),
                              Wrap(
                                spacing: KubusSpacing.sm,
                                runSpacing: KubusSpacing.sm,
                                children: <Widget>[
                                  WalletStatusChip(
                                    label: backupStatus.settingsSummary(l10n),
                                    icon: needsSignerRestore
                                        ? Icons.login_outlined
                                        : authority.canTransact
                                            ? Icons.verified_user_outlined
                                            : Icons.visibility_outlined,
                                    color: needsSignerRestore
                                        ? scheme.primary
                                        : authority.canTransact
                                            ? scheme.tertiary
                                            : scheme.secondary,
                                  ),
                                  WalletStatusChip(
                                    label: authority.state ==
                                            WalletAuthorityState.accountShellOnly
                                        ? l10n.walletSessionStateAccountShellOnly
                                        : authority.state ==
                                                WalletAuthorityState
                                                    .localSignerReady
                                            ? l10n
                                                .walletSessionStateLocalSignerReady
                                            : authority.state ==
                                                    WalletAuthorityState
                                                        .externalWalletReady
                                                ? l10n
                                                    .walletSessionStateExternalWalletReady
                                                : authority.state ==
                                                        WalletAuthorityState
                                                            .encryptedBackupAvailableSignerMissing
                                                    ? l10n
                                                        .walletSessionStateEncryptedBackupAvailable
                                                    : authority.state ==
                                                            WalletAuthorityState
                                                                .recoveryNeeded
                                                        ? l10n
                                                            .walletSessionStateRecoveryNeeded
                                                        : authority.state ==
                                                                WalletAuthorityState
                                                                    .walletReadOnly
                                                            ? l10n
                                                                .walletSessionStateWalletReadOnly
                                                            : l10n
                                                                .walletSessionAccountSignedOut,
                                    icon: Icons.shield_outlined,
                                    color: scheme.secondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: KubusSpacing.md),
                              Text(
                                backupStatus.protectionHeadline(l10n),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color:
                                          scheme.onSurface.withValues(alpha: 0.88),
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: KubusSpacing.sm),
                              Text(
                                backupStatus.protectionBody(l10n),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          scheme.onSurface.withValues(alpha: 0.76),
                                      height: 1.45,
                                    ),
                              ),
                              if (backup?.lastVerifiedAt != null) ...<Widget>[
                                const SizedBox(height: KubusSpacing.md),
                                Text(
                                  l10n.walletBackupProtectionLastVerifiedLabel(
                                    backup!.lastVerifiedAt!.toLocal().toString(),
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.72),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  WalletCustodyStatusPanel(
                    authority: authority,
                    compact: !isWide,
                    onRestoreSigner: needsSignerRestore && hasEncryptedBackup
                        ? _restoreSignerFromBackup
                        : null,
                    onConnectExternalWallet: !authority.canTransact
                        ? () => Navigator.of(context).pushNamed('/connect-wallet')
                        : null,
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  LiquidGlassCard(
                    padding: const EdgeInsets.all(KubusSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.walletSecurityStatusTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: KubusSpacing.xs),
                        Text(
                          l10n.walletSecurityBackendBackupClarifier,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.72),
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: KubusSpacing.md),
                        GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          crossAxisSpacing: KubusSpacing.md,
                          mainAxisSpacing: KubusSpacing.md,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: isWide ? 2.9 : 2.5,
                          children: <Widget>[
                            _buildStateRow(
                              context: context,
                              icon: Icons.account_balance_wallet_outlined,
                              label: l10n.walletSecurityWalletAddressLabel,
                              value: backupStatus.hasWalletIdentity
                                  ? _walletLabel(walletAddress)
                                  : backupStatus.settingsSummary(l10n),
                              color: backupStatus.hasWalletIdentity
                                  ? scheme.primary
                                  : scheme.secondary,
                            ),
                            _buildStateRow(
                              context: context,
                              icon: Icons.draw_outlined,
                              label: l10n.walletSecuritySignerStatusLabel,
                              value: authority.canTransact
                                  ? authority.signerSource ==
                                          WalletSignerSource.external
                                      ? l10n
                                          .walletSecuritySignerExternalReadyValue
                                      : l10n.walletSecuritySignerLocalReadyValue
                                  : needsSignerRestore
                                      ? l10n
                                          .walletSecuritySignerRestoreAvailableValue
                                      : l10n.walletSecuritySignerMissingValue,
                              color: authority.canTransact
                                  ? scheme.tertiary
                                  : needsSignerRestore
                                      ? scheme.primary
                                      : scheme.error,
                            ),
                            _buildStateRow(
                              context: context,
                              icon: Icons.visibility_outlined,
                              label: l10n.walletBackupProtectionRevealRecoveryPhraseButton,
                              value: _backupRequired
                                  ? l10n
                                      .walletBackupProtectionRecoveryPhraseHeadline
                                  : l10n.walletSecurityConfigured,
                              color: _backupRequired
                                  ? scheme.error
                                  : scheme.tertiary,
                            ),
                            _buildStateRow(
                              context: context,
                              icon: Icons.cloud_done_outlined,
                              label: l10n.walletSecurityEncryptedBackupLabel,
                              value: authority.hasEncryptedBackup
                                  ? l10n.walletSecurityAvailable
                                  : authority.encryptedBackupStatusKnown
                                      ? l10n.walletSecurityUnavailable
                                      : l10n.walletSecurityUnknown,
                              color: authority.hasEncryptedBackup
                                  ? scheme.tertiary
                                  : authority.encryptedBackupStatusKnown
                                      ? scheme.secondary
                                      : scheme.outline,
                            ),
                            _buildStateRow(
                              context: context,
                              icon: Icons.fingerprint,
                              label: l10n.walletSecurityPasskeyLabel,
                              value: backupStatus.hasPasskeyProtection
                                  ? l10n.walletSecurityConfigured
                                  : l10n.walletSecurityNotConfigured,
                              color: backupStatus.hasPasskeyProtection
                                  ? scheme.tertiary
                                  : scheme.secondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    crossAxisSpacing: KubusSpacing.md,
                    mainAxisSpacing: KubusSpacing.md,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 1.45 : 1.16,
                    children: actionCards,
                  ),
                  if (passkeysEnabled) ...<Widget>[
                    const SizedBox(height: KubusSpacing.lg),
                    LiquidGlassCard(
                      padding: const EdgeInsets.all(KubusSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.walletBackupProtectionPasskeysTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: KubusSpacing.xs),
                          Text(
                            l10n.walletBackupProtectionPasskeysBody,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.78),
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: KubusSpacing.sm),
                          FilledButton.tonalIcon(
                            onPressed: isBusy ? null : _enrollPasskey,
                            icon: const Icon(Icons.phishing_outlined),
                            label: Text(
                                l10n.walletBackupProtectionAddPasskeyAction),
                          ),
                          const SizedBox(height: KubusSpacing.sm),
                          ...walletProvider.encryptedWalletBackupPasskeys.map(
                            (passkey) => FrostedContainer(
                              margin: const EdgeInsets.only(
                                  bottom: KubusSpacing.sm),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                    passkey.nickname ?? passkey.credentialId),
                                subtitle: Text(
                                  passkey.transports.isEmpty
                                      ? l10n
                                          .walletBackupProtectionStoredPasskeyLabel
                                      : l10n
                                          .walletBackupProtectionPasskeyTransports(
                                          passkey.transports.join(', '),
                                        ),
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
                      backgroundColor:
                          scheme.errorContainer.withValues(alpha: 0.28),
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
