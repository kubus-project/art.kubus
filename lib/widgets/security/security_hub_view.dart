import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../inline_loading.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../screens/desktop/desktop_shell_scope.dart';
import '../../screens/web3/wallet/mnemonic_reveal_screen.dart';
import '../../services/backend_api_service.dart';
import '../../services/encrypted_wallet_backup_service.dart';
import '../../services/passkey_error_mapper.dart';
import '../../services/passkey_protection_service.dart';
import '../../services/security/pin_management.dart';
import '../../services/settings_service.dart';
import '../../services/wallet_backup_passkey_service.dart';
import '../../services/wallet_recovery_flow_service.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';
import '../kubus_button.dart';
import '../kubus_card.dart';
import '../kubus_snackbar.dart';
import '../wallet_backup_prompts.dart';
import 'security_danger_zone.dart';
import 'security_method_row.dart';
import 'security_state_pill.dart';
import 'security_summary_card.dart';

enum SecurityHubMode {
  requiredSetup,
  manage,
}

enum SecuritySection {
  localDevice,
  account,
  wallet,
  danger,
}

enum _RequiredSetupStep {
  pin,
  biometrics,
}

class SecurityHubView extends StatefulWidget {
  const SecurityHubView({
    super.key,
    required this.mode,
    this.initialSection = SecuritySection.account,
    this.onRequiredSetupComplete,
    this.onBackupStateChanged,
  });

  final SecurityHubMode mode;
  final SecuritySection initialSection;
  final VoidCallback? onRequiredSetupComplete;
  final Future<void> Function()? onBackupStateChanged;

  @override
  State<SecurityHubView> createState() => _SecurityHubViewState();
}

class _SecurityHubViewState extends State<SecurityHubView> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  static const _passkeyProtectionService = PasskeyProtectionService();

  _RequiredSetupStep _requiredStep = _RequiredSetupStep.pin;
  bool _busy = false;
  bool _loading = true;
  bool _hasPin = false;
  bool _biometricsAvailable = false;
  bool _backupPhraseRequired = false;
  bool _passkeysSupported = false;
  bool _allowRequiredPop = false;
  String? _statusError;
  String? _inlineError;
  AccountPasskeyStatus _accountPasskeyStatus = AccountPasskeyStatus.empty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isRequiredSetup => widget.mode == SecurityHubMode.requiredSetup;

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _refresh() async {
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();
    final l10n = AppLocalizations.of(context)!;
    String? statusError;
    var hasPin = false;
    var biometricsAvailable = false;
    var backupPhraseRequired = false;
    var passkeysSupported = false;
    var accountPasskeyStatus = AccountPasskeyStatus.empty;

    try {
      await gate.reloadSettings().timeout(const Duration(seconds: 3));
    } catch (_) {
      statusError = l10n.securityHubLocalSecuritySettingsUnavailable;
    }

    try {
      hasPin = await walletProvider
          .hasPin()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      biometricsAvailable = await walletProvider
          .canUseBiometrics()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      backupPhraseRequired = await walletProvider
          .isMnemonicBackupRequired()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (AppConfig.isFeatureEnabled('encryptedWalletBackup')) {
        try {
          await walletProvider
              .refreshEncryptedWalletBackupStatus()
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          statusError ??= l10n.securityHubEncryptedBackupStatusRefreshFailed;
        }
      }
      passkeysSupported =
          AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') &&
              kIsWeb &&
              await isWalletBackupPasskeySupported();
    } catch (_) {
      statusError ??= l10n.securityHubWalletSecurityStatusRefreshFailed;
    }

    if (_passkeyProtectionService.isAvailable &&
        walletProvider.authority.hasAccountSession) {
      try {
        accountPasskeyStatus = await _passkeyProtectionService
            .getAccountStatus(BackendApiService())
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        statusError ??= l10n.securityHubAccountPasskeyStatusUnavailable;
      }
    }

    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _biometricsAvailable = biometricsAvailable;
      _backupPhraseRequired = backupPhraseRequired;
      _passkeysSupported = passkeysSupported;
      _accountPasskeyStatus = accountPasskeyStatus;
      _statusError = statusError;
      _loading = false;
    });
  }

  Future<void> _completeRequiredSetup() async {
    _allowRequiredPop = true;
    widget.onRequiredSetupComplete?.call();
  }

  Future<void> _setLocalPin({String? pin, String? confirm}) async {
    if (_busy) return;
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final resolvedPin = (pin ?? _pinController.text).trim();
    final resolvedConfirm = (confirm ?? _confirmController.text).trim();

    setState(() {
      _busy = true;
      _inlineError = null;
    });

    try {
      final result = await PinManagement(wallet: walletProvider, gate: gate)
          .setOrReplacePin(resolvedPin, resolvedConfirm);
      if (!mounted) return;
      if (!result.isSuccess) {
        setState(() => _inlineError = switch (result.outcome) {
              PinManagementOutcome.invalid => switch (result.issue) {
                  PinFormatIssue.tooShort => l10n.settingsPinMinLengthError,
                  PinFormatIssue.mismatch => l10n.settingsPinMismatchError,
                  _ => l10n.settingsPinInvalidFormatError,
                },
              PinManagementOutcome.authenticationFailed => null,
              _ => l10n.settingsPinSetFailedToast,
            });
        return;
      }
      final current = await SettingsService.loadSettings();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.settingsPinSetSuccessToast)),
        tone: KubusSnackBarTone.success,
      );
      final canOfferBiometrics = _isRequiredSetup &&
          _isMobilePlatform &&
          !current.biometricsDeclined &&
          !current.biometricAuth &&
          await walletProvider.canUseBiometrics();
      if (!mounted) return;
      if (canOfferBiometrics) {
        setState(() => _requiredStep = _RequiredSetupStep.biometrics);
      } else if (_isRequiredSetup) {
        await _completeRequiredSetup();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = l10n.settingsPinSetFailedToast);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePin() async {
    if (_busy) return;
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    try {
      final result =
          await PinManagement(wallet: walletProvider, gate: gate).removePin();
      if (!mounted) return;
      if (result.outcome == PinManagementOutcome.authenticationFailed) return;
      if (!result.isSuccess) {
        setState(() => _inlineError = l10n.settingsPinClearFailedToast);
        return;
      }
      await _refresh();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.settingsPinClearedToast)),
        tone: KubusSnackBarTone.success,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPinSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: KubusSpacing.md,
              right: KubusSpacing.md,
              top: KubusSpacing.md,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                  KubusSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.securityHubSetLocalPin,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.commonPinLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.settingsConfirmPinLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_setLocalPin(
                      pin: pinController.text,
                      confirm: confirmController.text,
                    ));
                  },
                  icon: const Icon(Icons.lock_rounded),
                  label: Text(l10n.securityHubSavePin),
                ),
                Text(
                  l10n.securityHubPinStaysOnDevice,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.66),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
    pinController.dispose();
    confirmController.dispose();
  }

  Future<void> _enableBiometrics() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _inlineError = null;
    });

    try {
      final canUse = await walletProvider.canUseBiometrics();
      if (!mounted) return;
      if (!canUse) {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.securityHubBiometricsUnavailable)),
          tone: KubusSnackBarTone.neutral,
        );
        return;
      }
      final ok = await walletProvider.authenticateWithBiometrics();
      if (!mounted) return;
      if (!ok) {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.securityHubBiometricApprovalFailed)),
          tone: KubusSnackBarTone.error,
        );
        return;
      }
      final current = await SettingsService.loadSettings();
      await SettingsService.saveSettings(current.copyWith(
        requirePin: true,
        biometricAuth: true,
        biometricsDeclined: false,
        useBiometricsOnUnlock: true,
      ));
      await gate.reloadSettings();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.securityHubBiometricUnlockEnabled)),
        tone: KubusSnackBarTone.success,
      );
      if (_isRequiredSetup) await _completeRequiredSetup();
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = l10n.securityHubBiometricApprovalFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skipBiometrics() async {
    if (_busy) return;
    final gate = context.read<SecurityGateProvider>();
    setState(() => _busy = true);
    try {
      final current = await SettingsService.loadSettings();
      await SettingsService.saveSettings(current.copyWith(
        requirePin: true,
        biometricAuth: false,
        biometricsDeclined: true,
        useBiometricsOnUnlock: true,
      ));
      await gate.reloadSettings();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      await _completeRequiredSetup();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Adding or removing a passkey changes who can reach the account and, for a
  /// wallet recovery passkey, wraps the recovery phrase for a new key. It needs
  /// the same current local authentication as showing the phrase or changing the
  /// backup.
  Future<bool> _requireLocalAuthentication() async {
    final gate = context.read<SecurityGateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final verified = await gate.requireSensitiveActionVerification();
    if (!mounted) return false;
    if (!verified) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.securityHubAuthenticationFailed)),
        tone: KubusSnackBarTone.error,
      );
      return false;
    }
    return true;
  }

  Future<void> _createAccountPasskey() async {
    if (_busy) return;
    if (!await _requireLocalAuthentication() || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _passkeyProtectionService.registerAccountPasskey(
        api: BackendApiService(),
        deviceLabel: l10n.walletBackupProtectionDefaultPasskeyName,
        purpose: 'account_sign_in',
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.securityHubAccountPasskeyAdded)),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error, l10n))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAccountPasskey(String id) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmDestructive(
      title: l10n.securityHubRemoveAccountPasskeyTitle,
      body: l10n.securityHubRemoveAccountPasskeyBody,
      action: l10n.accountPasskeyRemoveAction,
    );
    if (!confirmed || !mounted) return;
    if (!await _requireLocalAuthentication() || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _passkeyProtectionService.revokeAccountPasskey(
        api: BackendApiService(),
        passkeyId: id,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.securityHubAccountPasskeyRemoved)),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error, l10n))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createWalletRecoveryPasskey() async {
    if (_busy) return;
    if (!await _requireLocalAuthentication() || !mounted) return;
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final nickname = await showWalletBackupTextPrompt(
      context: context,
      title: l10n.securityHubAddWalletRecoveryPasskey,
      label: l10n.walletBackupProtectionPasskeyNameLabel,
      description: l10n.securityHubWalletRecoveryPasskeyDescription,
      initialValue: l10n.walletBackupProtectionDefaultPasskeyName,
      actionLabel: l10n.securityHubAddWalletRecoveryPasskey,
    );
    if (!mounted || nickname == null) return;
    setState(() => _busy = true);
    try {
      final passkey = await walletProvider.enrollEncryptedWalletBackupPasskey(
        nickname: nickname,
      );
      if (!mounted) return;
      await _refresh();
      await widget.onBackupStateChanged?.call();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.securityHubWalletRecoveryPasskeyAdded(
              passkey.nickname ?? passkey.credentialId,
            ),
          ),
        ),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error, l10n))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeWalletRecoveryPasskey(String id) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmDestructive(
      title: l10n.securityHubRemoveWalletRecoveryPasskeyTitle,
      body: l10n.securityHubRemoveWalletRecoveryPasskeyBody,
      action: l10n.securityHubRemoveRecoveryPasskeyAction,
    );
    if (!confirmed || !mounted) return;
    if (!await _requireLocalAuthentication() || !mounted) return;
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await walletProvider.revokeEncryptedWalletBackupPasskey(id);
      if (!mounted) return;
      await _refresh();
      await widget.onBackupStateChanged?.call();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.securityHubWalletRecoveryPasskeyRemovedToast,
          ),
        ),
        tone: KubusSnackBarTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n.securityHubWalletRecoveryPasskeyRemoveFailedToast,
          ),
        ),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showWalletRecoveryPasskeys() async {
    final l10n = AppLocalizations.of(context)!;
    await showKubusDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return KubusAlertDialog(
          title: Text(
            l10n.securityHubManageWalletRecoveryPasskeys,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Consumer<WalletProvider>(
              builder: (context, walletProvider, _) {
                final passkeys = walletProvider.encryptedWalletBackupPasskeys;
                if (passkeys.isEmpty) {
                  return Text(
                    l10n.securityHubNoWalletRecoveryPasskeys,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: passkeys
                      .map(
                        (passkey) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: KubusSpacing.sm,
                          ),
                          child: _buildWalletRecoveryPasskeyItem(passkey),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonClose),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWalletRecoveryPasskeyItem(
    WalletBackupPasskeyDefinition passkey,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final passkeyId = (passkey.id ?? '').trim();
    final lastActivity = passkey.lastUsedAt != null
        ? l10n.securityHubLastUsedOn(_formatDate(passkey.lastUsedAt, l10n))
        : passkey.lastVerifiedAt != null
            ? l10n.securityHubLastVerifiedOn(
                _formatDate(passkey.lastVerifiedAt, l10n),
              )
            : l10n.securityHubLastUsedNever;
    final prfLabel = passkey.prfSupported
        ? l10n.securityHubPrfSupported
        : l10n.securityHubPrfNotSupported;
    final recoveryMaterial = passkey.hasEncryptedRecoveryKey
        ? l10n.securityHubRecoveryMaterialEncrypted
        : l10n.securityHubNoEncryptedRecoveryMaterial;

    return Container(
      key: ValueKey<String>(
        'wallet-recovery-passkey-${passkeyId.isEmpty ? passkey.credentialId : passkeyId}',
      ),
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.40),
        borderRadius: KubusRadius.circular(KubusRadius.sm),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.44),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.devices_other_rounded,
            color: passkey.prfSupported ? scheme.primary : KubusColors.warning,
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _walletRecoveryPasskeyLabel(passkey, l10n),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.securityHubCreatedOn(
                      _formatDate(passkey.createdAt, l10n)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                ),
                Text(
                  l10n.securityHubPasskeyStatusSummary(
                    lastActivity,
                    prfLabel,
                    recoveryMaterial,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.66),
                        height: 1.28,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: KubusSpacing.sm),
          IconButton.filledTonal(
            tooltip: l10n.commonDelete,
            onPressed: _busy || passkeyId.isEmpty
                ? null
                : () => _removeWalletRecoveryPasskey(passkeyId),
            icon: Icon(Icons.delete_outline, color: scheme.error),
          ),
        ],
      ),
    );
  }

  Future<void> _createOrUpdateBackup() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final gate = context.read<SecurityGateProvider>();
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final verified = await gate.requireSensitiveActionVerification();
    if (!mounted) return;
    if (!verified) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.securityHubAuthenticationFailed)),
        tone: KubusSnackBarTone.error,
      );
      return;
    }
    final password = await showWalletBackupPasswordPrompt(
      context: context,
      title: l10n.walletBackupProtectionCreateBackupTitle,
      description: l10n.securityHubCreateBackupDescription,
      confirm: true,
      actionLabel: l10n.securityHubSaveEncryptedBackup,
    );
    if (!mounted || password == null) return;
    setState(() => _busy = true);
    try {
      await walletProvider.createEncryptedWalletBackup(
        recoveryPassword: password,
      );
      if (!mounted) return;
      await _refresh();
      await widget.onBackupStateChanged?.call();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.walletBackupProtectionBackupSavedToast)),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error, l10n))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyBackup() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final password = await showWalletBackupPasswordPrompt(
      context: context,
      title: l10n.walletBackupProtectionVerifyBackupAction,
      description: l10n.securityHubVerifyBackupDescription,
      actionLabel: l10n.walletBackupProtectionVerifyBackupAction,
    );
    if (!mounted || password == null) return;
    setState(() => _busy = true);
    try {
      await walletProvider.verifyEncryptedWalletBackup(
        recoveryPassword: password,
      );
      if (!mounted) return;
      await _refresh();
      await widget.onBackupStateChanged?.call();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.walletBackupProtectionBackupVerifiedToast)),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error, l10n))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBackup() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmDestructive(
      title: l10n.walletBackupProtectionDeleteBackupTitle,
      body: l10n.securityHubDeleteBackupDialogBody,
      action: l10n.walletBackupProtectionDeleteBackupAction,
    );
    if (!confirmed || !mounted) return;
    final gate = context.read<SecurityGateProvider>();
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final verified = await gate.requireSensitiveActionVerification();
    if (!mounted) return;
    if (!verified) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.securityHubAuthenticationFailed)),
        tone: KubusSnackBarTone.error,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await walletProvider.deleteEncryptedWalletBackup();
      if (!mounted) return;
      await _refresh();
      await widget.onBackupStateChanged?.call();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.walletBackupProtectionBackupDeletedToast)),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error, l10n))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreSignerFromBackup() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final walletAddress = (walletProvider.currentWalletAddress ?? '').trim();
    if (walletAddress.isEmpty) return;
    setState(() => _busy = true);
    try {
      final result =
          await const WalletRecoveryFlowService().recoverSignerForAccountWallet(
        context: context,
        walletAddress: walletAddress,
        walletProvider: walletProvider,
        securityGateProvider: gate,
        origin: WalletRecoveryOrigin.walletSecurityScreen,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(result.restored
              ? l10n.walletBackupProtectionSignerRestoredToast
              : l10n.walletBackupProtectionSignerStillMissingToast),
        ),
        tone: result.restored
            ? KubusSnackBarTone.success
            : KubusSnackBarTone.neutral,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error, l10n))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revealRecoveryPhrase() async {
    final shell = DesktopShellScope.of(context);
    if (shell != null) {
      // Inside the desktop shell the phrase opens in the content column like
      // the backup screen that hosts this action, so the sidebar and header
      // stay. The shell shows only its top screen, so this view is rebuilt (and
      // reloads the backup state itself) when the reveal is popped.
      final onBackupStateChanged = widget.onBackupStateChanged;
      shell.pushScreen(
        MnemonicRevealScreen(
          onShellExit: (_) {
            shell.popScreen();
            unawaited(onBackupStateChanged?.call());
          },
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MnemonicRevealScreen()),
    );
    if (!mounted) return;
    await _refresh();
    await widget.onBackupStateChanged?.call();
  }

  Future<bool> _confirmDestructive({
    required String title,
    required String body,
    required String action,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        size: KubusDialogSize.compact,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _friendlySecurityError(Object error, AppLocalizations l10n) {
    final raw = error.toString().trim();
    if (error is PasskeyAppException || error is BackendApiRequestException) {
      return passkeyUserMessage(error);
    }
    if (raw.contains('InvalidStateError') ||
        raw.contains('NotAllowedError') ||
        raw.contains('SecurityError')) {
      return passkeyUserMessage(error);
    }
    const encryptedPrefix = 'EncryptedWalletBackupException(';
    if (raw.startsWith(encryptedPrefix) && raw.endsWith(')')) {
      return raw.substring(encryptedPrefix.length, raw.length - 1);
    }
    const statePrefix = 'Bad state: ';
    if (raw.startsWith(statePrefix)) {
      return raw.substring(statePrefix.length);
    }
    return raw.isEmpty ? l10n.securityHubActionFailed : raw;
  }

  String _walletLabel(String? walletAddress, AppLocalizations l10n) {
    final value = (walletAddress ?? '').trim();
    if (value.isEmpty) return l10n.securityHubNoWallet;
    if (value.length <= 14) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }

  String _walletRecoveryPasskeyLabel(
    WalletBackupPasskeyDefinition passkey,
    AppLocalizations l10n,
  ) {
    final nickname = (passkey.nickname ?? '').trim();
    if (nickname.isNotEmpty) return nickname;
    if (passkey.transports.contains('internal')) {
      return l10n.walletBackupProtectionDefaultPasskeyName;
    }
    if (passkey.transports.contains('hybrid')) {
      return l10n.securityHubLinkedDevice;
    }
    if (passkey.transports.contains('usb')) return l10n.securityHubSecurityKey;
    return l10n.securityHubWalletRecoveryPasskeyDefaultName;
  }

  String _formatDate(DateTime? date, AppLocalizations l10n) {
    if (date == null) return l10n.securityHubNever;
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  SecurityHubStatus _walletAccessStatus(WalletAuthoritySnapshot authority) {
    if (authority.canTransact) return SecurityHubStatus.secured;
    if (authority.canRestoreFromEncryptedBackup) {
      return SecurityHubStatus.recommended;
    }
    if (authority.hasWalletIdentity) return SecurityHubStatus.available;
    return SecurityHubStatus.disabled;
  }

  String _walletAccessLabel(
    WalletAuthoritySnapshot authority,
    AppLocalizations l10n,
  ) {
    return switch (authority.state) {
      WalletAuthorityState.localSignerReady => l10n.securityHubLocalSignerReady,
      WalletAuthorityState.externalWalletReady =>
        l10n.walletSessionStateExternalWalletReady,
      WalletAuthorityState.encryptedBackupAvailableSignerMissing =>
        l10n.securityHubRecoveryAvailable,
      WalletAuthorityState.walletReadOnly => l10n.securityHubStatusReadOnly,
      WalletAuthorityState.accountShellOnly => l10n.securityHubAccountOnly,
      WalletAuthorityState.recoveryNeeded =>
        l10n.walletSessionStateRecoveryNeeded,
      WalletAuthorityState.signedOut => l10n.walletSecuritySignedOutMethod,
    };
  }

  List<SecuritySummaryCard> _summaryCards(WalletProvider walletProvider) {
    final authority = walletProvider.authority;
    final l10n = AppLocalizations.of(context)!;
    final accountPasskeys = _accountPasskeyStatus.passkeys.length;
    final walletPasskeys = walletProvider.encryptedWalletBackupPasskeys.length;
    return [
      SecuritySummaryCard(
        title: l10n.walletSecurityWalletAddressLabel,
        value: _walletLabel(authority.walletAddress, l10n),
        detail: authority.hasWalletIdentity
            ? l10n.securityHubCurrentAccountWallet
            : l10n.securityHubConnectOrRestoreWallet,
        icon: Icons.account_balance_wallet_outlined,
        status: authority.hasWalletIdentity
            ? SecurityHubStatus.secured
            : SecurityHubStatus.disabled,
      ),
      SecuritySummaryCard(
        title: l10n.securityHubWalletAccess,
        value: _walletAccessLabel(authority, l10n),
        detail: authority.externalWalletConnected
            ? authority.externalWalletName ??
                l10n.securityHubExternalSignerConnected
            : authority.canTransact
                ? l10n.securityHubLocalWalletCanSign
                : l10n.securityHubRestoreSigningBeforeTransfers,
        icon: Icons.draw_outlined,
        status: _walletAccessStatus(authority),
      ),
      SecuritySummaryCard(
        title: l10n.walletBackupProtectionPasskeysTitle,
        value: l10n.securityHubPasskeyCounts(accountPasskeys, walletPasskeys),
        detail: l10n.securityHubSignInRecoverySeparate,
        icon: Icons.key_rounded,
        status: accountPasskeys > 0 || walletPasskeys > 0
            ? SecurityHubStatus.secured
            : SecurityHubStatus.available,
      ),
    ];
  }

  Widget _buildRequiredSetupPanel() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return KubusCard(
      key: const ValueKey('security-required-setup-card'),
      padding: const EdgeInsets.all(KubusSpacing.lg),
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.securityHubSecureThisDevice,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            _requiredStep == _RequiredSetupStep.pin
                ? l10n.securityHubSetUpLocalUnlockDescription
                : l10n.securityHubBiometricUnlockPromptDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          if (_requiredStep == _RequiredSetupStep.pin) ...[
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.commonPinLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.settingsConfirmPinLabel,
                border: OutlineInputBorder(),
              ),
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: KubusSpacing.sm),
              Text(_inlineError!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: KubusSpacing.md),
            KubusButton(
              onPressed: _busy ? null : () => _setLocalPin(),
              isLoading: _busy,
              icon: Icons.lock_rounded,
              label: l10n.commonContinue,
              isFullWidth: true,
            ),
          ] else ...[
            if (_inlineError != null) ...[
              Text(_inlineError!, style: TextStyle(color: scheme.error)),
              const SizedBox(height: KubusSpacing.sm),
            ],
            KubusButton(
              onPressed: _busy ? null : _enableBiometrics,
              isLoading: _busy,
              icon: Icons.fingerprint_rounded,
              label: l10n.securityHubEnableBiometrics,
              isFullWidth: true,
            ),
            const SizedBox(height: KubusSpacing.sm),
            KubusButton(
              onPressed: _busy ? null : _skipBiometrics,
              icon: Icons.schedule_rounded,
              label: l10n.commonSkipForNow,
              variant: KubusButtonVariant.secondary,
              isFullWidth: true,
            ),
          ],
          const SizedBox(height: KubusSpacing.sm),
          TextButton(
            onPressed: _busy
                ? null
                : () => context.read<SecurityGateProvider>().logout(),
            child: Text(l10n.settingsLogoutButton),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodsList(WalletProvider walletProvider) {
    final gate = context.watch<SecurityGateProvider>();
    final l10n = AppLocalizations.of(context)!;
    final authority = walletProvider.authority;
    final backupFeatureEnabled =
        AppConfig.isFeatureEnabled('encryptedWalletBackup');
    final passkeyRecoveryFeatureEnabled =
        AppConfig.isFeatureEnabled('walletBackupPasskeyWeb');
    final walletBackupReady =
        backupFeatureEnabled && walletProvider.hasEncryptedWalletBackup;
    final recoveryPasskeys = passkeyRecoveryFeatureEnabled && walletBackupReady
        ? walletProvider.encryptedWalletBackupPasskeys
        : const <WalletBackupPasskeyDefinition>[];
    final accountPasskeys = _accountPasskeyStatus.passkeys;
    final passkeyEnabled =
        _passkeyProtectionService.isAvailable && authority.hasAccountSession;
    final needsSignerRestore = authority.canRestoreFromEncryptedBackup;

    final rows = <Widget>[
      SecurityMethodRow(
        title: l10n.securityHubPinLocalLock,
        description: l10n.securityHubPinDescription,
        icon: Icons.lock_rounded,
        status:
            _hasPin ? SecurityHubStatus.secured : SecurityHubStatus.recommended,
        statusLabel: _hasPin
            ? l10n.securityHubStatusActive
            : l10n.securityHubStatusRecommended,
        actions: _hasPin
            ? [
                SecurityMethodAction(
                  label: l10n.settingsSetPinDialogTitle,
                  icon: Icons.lock_reset_rounded,
                  onPressed: _busy ? null : _showPinSheet,
                ),
                SecurityMethodAction(
                  label: l10n.settingsClearPinButton,
                  icon: Icons.lock_open_rounded,
                  onPressed: _busy ? null : _removePin,
                ),
              ]
            : [
                SecurityMethodAction(
                  label: l10n.securityHubSetPin,
                  icon: Icons.lock_rounded,
                  onPressed: _busy ? null : _showPinSheet,
                ),
              ],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.securityHubBiometricUnlock,
        description: l10n.securityHubBiometricUnlockDescription,
        icon: Icons.fingerprint_rounded,
        status: gate.biometricsEnabled
            ? SecurityHubStatus.secured
            : _biometricsAvailable
                ? SecurityHubStatus.available
                : SecurityHubStatus.disabled,
        statusLabel: gate.biometricsEnabled
            ? l10n.securityHubStatusActive
            : _biometricsAvailable
                ? l10n.walletSecurityAvailable
                : l10n.walletSecurityUnavailable,
        actions: !gate.biometricsEnabled && _biometricsAvailable
            ? [
                SecurityMethodAction(
                  label: l10n.commonEnable,
                  icon: Icons.fingerprint_rounded,
                  onPressed: _busy ? null : _enableBiometrics,
                ),
              ]
            : const <SecurityMethodAction>[],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.walletSecurityWalletAddressLabel,
        description: authority.hasWalletIdentity
            ? _walletLabel(authority.walletAddress, l10n)
            : l10n.securityHubNoWalletConnectedOnDevice,
        icon: Icons.account_balance_wallet_outlined,
        status: authority.hasWalletIdentity
            ? SecurityHubStatus.secured
            : SecurityHubStatus.disabled,
        statusLabel: authority.hasWalletIdentity
            ? l10n.securityHubStatusLinked
            : l10n.securityHubStatusMissing,
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.securityHubWalletAccessState,
        description: authority.canTransact
            ? l10n.securityHubThisDeviceCanSign
            : needsSignerRestore
                ? l10n.securityHubEncryptedBackupRestoreDescription
                : l10n.securityHubWalletAccessReadOnlyOrNotConnected,
        helper: authority.externalWalletConnected
            ? l10n.securityHubExternalWalletHelper(
                authority.externalWalletName ?? l10n.walletSecurityConnected,
              )
            : null,
        icon: Icons.verified_user_outlined,
        status: _walletAccessStatus(authority),
        statusLabel: _walletAccessLabel(authority, l10n),
        actions: needsSignerRestore
            ? [
                SecurityMethodAction(
                  label: l10n.securityHubRestoreAccess,
                  icon: Icons.login_rounded,
                  onPressed: _busy ? null : _restoreSignerFromBackup,
                ),
              ]
            : const <SecurityMethodAction>[],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.securityHubLocalSigner,
        description: authority.hasLocalSigner
            ? l10n.securityHubLocalWalletSignerAvailable
            : l10n.securityHubNoLocalSignerAvailable,
        icon: Icons.edit_note_rounded,
        status: authority.hasLocalSigner
            ? SecurityHubStatus.secured
            : SecurityHubStatus.recommended,
        statusLabel: authority.hasLocalSigner
            ? l10n.securityHubStatusReady
            : l10n.securityHubStatusMissing,
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.walletSecurityExternalWalletLabel,
        description: authority.hasExternalSigner
            ? authority.externalWalletName ??
                l10n.securityHubExternalWalletConnected
            : l10n.securityHubNoExternalSignerConnected,
        icon: Icons.link_rounded,
        status: authority.hasExternalSigner
            ? SecurityHubStatus.secured
            : SecurityHubStatus.disabled,
        statusLabel: authority.hasExternalSigner
            ? l10n.walletSecurityConnected
            : l10n.settingsWalletConnectionNotConnected,
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.securityHubEncryptedServerBackup,
        description: !backupFeatureEnabled
            ? l10n.securityHubEncryptedBackupDisabledDescription
            : walletBackupReady
                ? l10n.securityHubEncryptedBackupAvailableDescription
                : l10n.securityHubEncryptedBackupDescription,
        helper: walletProvider.encryptedWalletBackupLastVerifiedAt == null
            ? null
            : l10n.walletBackupProtectionLastVerifiedLabel(
                _formatDate(
                  walletProvider.encryptedWalletBackupLastVerifiedAt,
                  l10n,
                ),
              ),
        icon: Icons.cloud_done_outlined,
        status: !backupFeatureEnabled
            ? SecurityHubStatus.disabled
            : walletBackupReady
                ? SecurityHubStatus.secured
                : SecurityHubStatus.recommended,
        statusLabel: !backupFeatureEnabled
            ? l10n.commonDisabled
            : walletBackupReady
                ? l10n.walletSecurityConfigured
                : l10n.securityHubStatusRecommended,
        actions: backupFeatureEnabled
            ? [
                SecurityMethodAction(
                  label: walletBackupReady
                      ? l10n.securityHubUpdateBackup
                      : l10n.walletBackupProtectionCreateBackupAction,
                  icon: Icons.cloud_upload_outlined,
                  onPressed: _busy ? null : _createOrUpdateBackup,
                ),
                if (walletBackupReady)
                  SecurityMethodAction(
                    label: l10n.securityHubVerifyBackup,
                    icon: Icons.fact_check_outlined,
                    onPressed: _busy ? null : _verifyBackup,
                  ),
              ]
            : const <SecurityMethodAction>[],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.securityHubRecoveryPhrase,
        description: _backupPhraseRequired
            ? l10n.securityHubRecoveryPhraseOfflineDescription
            : l10n.securityHubNoRecoveryPhraseActionRequired,
        icon: Icons.description_outlined,
        status: _backupPhraseRequired
            ? SecurityHubStatus.recommended
            : SecurityHubStatus.secured,
        statusLabel: _backupPhraseRequired
            ? l10n.securityHubBackUpOffline
            : l10n.securityHubStatusChecked,
        actions: [
          SecurityMethodAction(
            label: l10n.settingsShowPhraseButton,
            icon: Icons.visibility_outlined,
            onPressed: _busy ? null : _revealRecoveryPhrase,
          ),
        ],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.securityHubAccountSignInPasskey,
        description: l10n.securityHubAccountSignInDescription,
        icon: Icons.key_rounded,
        status: _accountPasskeyStatus.accountSignInReady
            ? SecurityHubStatus.secured
            : passkeyEnabled
                ? SecurityHubStatus.available
                : SecurityHubStatus.disabled,
        statusLabel: _accountPasskeyStatus.accountSignInReady
            ? l10n.securityHubRegisteredCount(accountPasskeys.length)
            : passkeyEnabled
                ? l10n.walletSecurityAvailable
                : l10n.walletSecurityUnavailable,
        actions: passkeyEnabled
            ? [
                SecurityMethodAction(
                  label: l10n.securityHubAddAccountPasskey,
                  icon: Icons.add_rounded,
                  onPressed: _busy ? null : _createAccountPasskey,
                ),
              ]
            : const <SecurityMethodAction>[],
      ),
      ...accountPasskeys.expand(
        (passkey) => [
          const SizedBox(height: KubusSpacing.xs),
          SecurityMethodRow(
            title: passkey.deviceLabel ?? l10n.securityHubAccountSignInPasskey,
            description: l10n.securityHubCreatedAndLastUsed(
              _formatDate(passkey.createdAt, l10n),
              _formatDate(passkey.lastUsedAt, l10n),
            ),
            helper: passkey.prfSupported
                ? l10n.securityHubPasskeyPurposePrfCapable(
                    passkey.purpose ?? 'account_sign_in',
                  )
                : l10n.securityHubPasskeyPurpose(
                    passkey.purpose ?? 'account_sign_in',
                  ),
            icon: Icons.devices_rounded,
            status: SecurityHubStatus.secured,
            statusLabel: l10n.walletSecuritySignInMethodLabel,
            actions: [
              SecurityMethodAction(
                label: l10n.commonRemove,
                icon: Icons.delete_outline,
                destructive: true,
                onPressed:
                    _busy ? null : () => _removeAccountPasskey(passkey.id),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n.securityHubWalletRecoveryPasskey,
        description: l10n.securityHubWalletRecoveryPasskeyDescription,
        icon: Icons.settings_backup_restore_rounded,
        status: recoveryPasskeys.isNotEmpty
            ? SecurityHubStatus.secured
            : passkeyRecoveryFeatureEnabled &&
                    _passkeysSupported &&
                    walletBackupReady
                ? SecurityHubStatus.available
                : SecurityHubStatus.recommended,
        statusLabel: recoveryPasskeys.isNotEmpty
            ? l10n.securityHubRegisteredCount(recoveryPasskeys.length)
            : passkeyRecoveryFeatureEnabled &&
                    _passkeysSupported &&
                    walletBackupReady
                ? l10n.walletSecurityAvailable
                : !passkeyRecoveryFeatureEnabled
                    ? l10n.commonDisabled
                    : l10n.securityHubSetUpBackupFirst,
        helper: passkeyRecoveryFeatureEnabled && !_passkeysSupported && kIsWeb
            ? l10n.securityHubPrfUnsupportedBrowser
            : null,
        actions: [
          if (recoveryPasskeys.isNotEmpty)
            SecurityMethodAction(
              label: l10n.securityHubManageWalletRecoveryPasskeys,
              icon: Icons.manage_accounts_outlined,
              onPressed: _busy ? null : _showWalletRecoveryPasskeys,
            ),
          if (passkeyRecoveryFeatureEnabled &&
              _passkeysSupported &&
              walletBackupReady)
            SecurityMethodAction(
              label: l10n.securityHubAddWalletRecoveryPasskey,
              icon: Icons.add_rounded,
              onPressed: _busy ? null : _createWalletRecoveryPasskey,
            ),
        ],
      ),
    ];

    final dangerRows = <SecurityMethodRow>[
      if (walletBackupReady)
        SecurityMethodRow(
          title: l10n.walletBackupProtectionDeleteBackupAction,
          description: l10n.securityHubDeleteBackupRowDescription,
          icon: Icons.delete_forever_outlined,
          status: SecurityHubStatus.destructive,
          statusLabel: l10n.securityHubStatusDestructive,
          actions: [
            SecurityMethodAction(
              label: l10n.securityHubDeleteBackupAction,
              icon: Icons.delete_outline,
              destructive: true,
              onPressed: _busy ? null : _deleteBackup,
            ),
          ],
        ),
    ];

    return Column(
      key: const ValueKey('security-methods-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        const SizedBox(height: KubusSpacing.md),
        SecurityDangerZone(rows: dangerRows),
      ],
    );
  }

  Widget _buildStatusMessage() {
    final scheme = Theme.of(context).colorScheme;
    if (_statusError == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: KubusColors.warning.withValues(alpha: 0.12),
        borderRadius: KubusRadius.circular(KubusRadius.sm),
        border: Border.all(
          color: KubusColors.warning.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        _statusError!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.82),
              height: 1.35,
            ),
      ),
    );
  }

  Widget _buildHubContent(bool desktop, WalletProvider walletProvider) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final summary = Wrap(
      spacing: KubusSpacing.md,
      runSpacing: KubusSpacing.md,
      children: _summaryCards(walletProvider),
    );
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isRequiredSetup
              ? l10n.securityHubAccountSecurity
              : l10n.securityHubTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          _isRequiredSetup
              ? l10n.securityHubSetUpLocalUnlockStepsDescription
              : l10n.securityHubSummaryDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.72),
                height: 1.4,
              ),
        ),
      ],
    );

    final methods = _buildMethodsList(walletProvider);
    final requiredPanel = _isRequiredSetup ? _buildRequiredSetupPanel() : null;

    if (desktop) {
      return Row(
        key: ValueKey<String>(_isRequiredSetup
            ? 'security-setup-desktop-layout'
            : 'security-hub-manage-desktop-layout'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: KubusSpacing.lg),
                summary,
                const SizedBox(height: KubusSpacing.lg),
                _buildStatusMessage(),
                if (_statusError != null)
                  const SizedBox(height: KubusSpacing.md),
                methods,
              ],
            ),
          ),
          if (requiredPanel != null) ...[
            const SizedBox(width: KubusSpacing.lg),
            Expanded(flex: 4, child: requiredPanel),
          ],
        ],
      );
    }

    return Column(
      key: ValueKey<String>(_isRequiredSetup
          ? 'security-setup-mobile-layout'
          : 'security-hub-manage-mobile-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: KubusSpacing.md),
        summary,
        const SizedBox(height: KubusSpacing.md),
        _buildStatusMessage(),
        if (_statusError != null) const SizedBox(height: KubusSpacing.md),
        if (requiredPanel != null) ...[
          requiredPanel,
          const SizedBox(height: KubusSpacing.md),
        ],
        methods,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    return PopScope(
      canPop: !_isRequiredSetup || _allowRequiredPop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          final content = _loading
              ? const Center(child: InlineLoading(width: 40, height: 40))
              : _buildHubContent(desktop, walletProvider);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(
                desktop ? KubusSpacing.xl : KubusSpacing.md,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 32),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: desktop ? 1180 : 620,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey<String>(desktop
                          ? 'security-hub-desktop-layout'
                          : 'security-hub-mobile-layout'),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
