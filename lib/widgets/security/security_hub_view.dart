import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../screens/web3/wallet/mnemonic_reveal_screen.dart';
import '../../services/backend_api_service.dart';
import '../../services/encrypted_wallet_backup_service.dart';
import '../../services/passkey_error_mapper.dart';
import '../../services/passkey_protection_service.dart';
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
    String? statusError;
    var hasPin = false;
    var biometricsAvailable = false;
    var backupPhraseRequired = false;
    var passkeysSupported = false;
    var accountPasskeyStatus = AccountPasskeyStatus.empty;

    try {
      await gate.reloadSettings().timeout(const Duration(seconds: 3));
    } catch (_) {
      statusError = 'Local security settings are temporarily unavailable.';
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
          statusError ??=
              'Encrypted wallet backup status could not be refreshed.';
        }
      }
      passkeysSupported =
          AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') &&
              kIsWeb &&
              await isWalletBackupPasskeySupported();
    } catch (_) {
      statusError ??= 'Wallet security status could not be refreshed.';
    }

    if (_passkeyProtectionService.isAvailable &&
        walletProvider.authority.hasAccountSession) {
      try {
        accountPasskeyStatus = await _passkeyProtectionService
            .getAccountStatus(BackendApiService())
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        statusError ??= 'Account passkey status is temporarily unavailable.';
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
    final resolvedPin = (pin ?? _pinController.text).trim();
    final resolvedConfirm = (confirm ?? _confirmController.text).trim();

    if (resolvedPin.length < 4 || resolvedConfirm.length < 4) {
      setState(() => _inlineError = 'PIN must be at least 4 digits.');
      return;
    }
    if (resolvedPin != resolvedConfirm) {
      setState(() => _inlineError = 'PIN entries do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _inlineError = null;
    });

    try {
      await walletProvider.setPin(resolvedPin);
      final current = await SettingsService.loadSettings();
      await SettingsService.saveSettings(current.copyWith(requirePin: true));
      await gate.reloadSettings();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('PIN set.')),
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
      setState(() => _inlineError = 'Could not set PIN.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPinSheet() async {
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
                  'Set local PIN',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
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
                  label: const Text('Save PIN'),
                ),
                Text(
                  'PIN stays on this device and protects sensitive wallet actions.',
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
          const SnackBar(content: Text('Biometrics unavailable.')),
          tone: KubusSnackBarTone.neutral,
        );
        return;
      }
      final ok = await walletProvider.authenticateWithBiometrics();
      if (!mounted) return;
      if (!ok) {
        messenger.showKubusSnackBar(
          const SnackBar(content: Text('Biometric approval failed.')),
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
        const SnackBar(content: Text('Biometric unlock enabled.')),
        tone: KubusSnackBarTone.success,
      );
      if (_isRequiredSetup) await _completeRequiredSetup();
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = 'Biometric approval failed.');
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

  Future<void> _createAccountPasskey() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _passkeyProtectionService.registerAccountPasskey(
        api: BackendApiService(),
        deviceLabel:
            l10n?.walletBackupProtectionDefaultPasskeyName ?? 'This device',
        purpose: 'account_sign_in',
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Account sign-in passkey added.')),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAccountPasskey(String id) async {
    if (_busy) return;
    final confirmed = await _confirmDestructive(
      title: 'Remove account sign-in passkey?',
      body: 'This passkey will no longer sign into art.kubus on this account.',
      action: 'Remove passkey',
    );
    if (!confirmed || !mounted) return;
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
        const SnackBar(content: Text('Account sign-in passkey removed.')),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createWalletRecoveryPasskey() async {
    if (_busy) return;
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final nickname = await showWalletBackupTextPrompt(
      context: context,
      title: l10n?.securityHubAddWalletRecoveryPasskey ??
          'Add wallet recovery passkey',
      label: l10n?.walletBackupProtectionPasskeyNameLabel ?? 'Passkey name',
      description: 'Used to restore local wallet access from encrypted backup.',
      initialValue:
          l10n?.walletBackupProtectionDefaultPasskeyName ?? 'This device',
      actionLabel: l10n?.securityHubAddWalletRecoveryPasskey ??
          'Add wallet recovery passkey',
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
            'Wallet recovery passkey "${passkey.nickname ?? passkey.credentialId}" added.',
          ),
        ),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeWalletRecoveryPasskey(String id) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDestructive(
      title: l10n?.securityHubRemoveWalletRecoveryPasskeyTitle ??
          'Remove wallet recovery passkey?',
      body:
          'This device passkey will no longer unlock the encrypted wallet backup.',
      action: 'Remove recovery passkey',
    );
    if (!confirmed || !mounted) return;
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
            l10n?.securityHubWalletRecoveryPasskeyRemovedToast ??
                'Wallet recovery passkey removed.',
          ),
        ),
        tone: KubusSnackBarTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n?.securityHubWalletRecoveryPasskeyRemoveFailedToast ??
                'Could not remove wallet recovery passkey. Try again.',
          ),
        ),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showWalletRecoveryPasskeys() async {
    final l10n = AppLocalizations.of(context);
    await showKubusDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return KubusAlertDialog(
          title: Text(
            l10n?.securityHubManageWalletRecoveryPasskeys ??
                'Manage wallet recovery passkeys',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Consumer<WalletProvider>(
              builder: (context, walletProvider, _) {
                final passkeys = walletProvider.encryptedWalletBackupPasskeys;
                if (passkeys.isEmpty) {
                  return Text(
                    'No wallet recovery passkeys are registered.',
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
              child: Text(l10n?.commonClose ?? 'Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWalletRecoveryPasskeyItem(
    WalletBackupPasskeyDefinition passkey,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final passkeyId = (passkey.id ?? '').trim();
    final lastActivity = passkey.lastUsedAt != null
        ? 'Last used ${_formatDate(passkey.lastUsedAt)}'
        : passkey.lastVerifiedAt != null
            ? 'Last verified ${_formatDate(passkey.lastVerifiedAt)}'
            : 'Last used never';
    final prfLabel =
        passkey.prfSupported ? 'PRF supported' : 'PRF not supported';
    final recoveryMaterial = passkey.hasEncryptedRecoveryKey
        ? 'Recovery material encrypted'
        : 'No encrypted recovery material';

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
                  _walletRecoveryPasskeyLabel(passkey),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Created ${_formatDate(passkey.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                ),
                Text(
                  '$lastActivity. $prfLabel. $recoveryMaterial.',
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
            tooltip: 'Delete',
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
    final gate = context.read<SecurityGateProvider>();
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final verified = await gate.requireSensitiveActionVerification();
    if (!mounted) return;
    if (!verified) {
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Authentication failed.')),
        tone: KubusSnackBarTone.error,
      );
      return;
    }
    final password = await showWalletBackupPasswordPrompt(
      context: context,
      title: 'Create encrypted backup',
      description:
          'Choose a recovery password. It decrypts the wallet backup on a new device.',
      confirm: true,
      actionLabel: 'Save encrypted backup',
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
        const SnackBar(content: Text('Encrypted wallet backup saved.')),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyBackup() async {
    if (_busy) return;
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final password = await showWalletBackupPasswordPrompt(
      context: context,
      title: 'Verify encrypted backup',
      description:
          'Enter the recovery password to verify this backup can be decrypted locally.',
      actionLabel: 'Verify encrypted backup',
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
        const SnackBar(content: Text('Encrypted backup verified.')),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBackup() async {
    if (_busy) return;
    final confirmed = await _confirmDestructive(
      title: 'Delete encrypted backup?',
      body:
          'This removes the encrypted server backup for the current wallet. Keep the recovery phrase stored safely offline.',
      action: 'Delete encrypted backup',
    );
    if (!confirmed || !mounted) return;
    final gate = context.read<SecurityGateProvider>();
    final walletProvider = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final verified = await gate.requireSensitiveActionVerification();
    if (!mounted) return;
    if (!verified) {
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Authentication failed.')),
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
        const SnackBar(content: Text('Encrypted wallet backup deleted.')),
        tone: KubusSnackBarTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreSignerFromBackup() async {
    if (_busy) return;
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
              ? 'Wallet access restored on this device.'
              : 'Wallet access is still read-only on this device.'),
        ),
        tone: result.restored
            ? KubusSnackBarTone.success
            : KubusSnackBarTone.neutral,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(_friendlySecurityError(error))),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revealRecoveryPhrase() async {
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
    final l10n = AppLocalizations.of(context);
    final result = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
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

  String _friendlySecurityError(Object error) {
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
    return raw.isEmpty ? 'Action failed. Try again.' : raw;
  }

  String _walletLabel(String? walletAddress) {
    final value = (walletAddress ?? '').trim();
    if (value.isEmpty) return 'No wallet';
    if (value.length <= 14) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }

  String _walletRecoveryPasskeyLabel(WalletBackupPasskeyDefinition passkey) {
    final nickname = (passkey.nickname ?? '').trim();
    if (nickname.isNotEmpty) return nickname;
    if (passkey.transports.contains('internal')) return 'This device';
    if (passkey.transports.contains('hybrid')) return 'Linked device';
    if (passkey.transports.contains('usb')) return 'Security key';
    return 'Wallet recovery passkey';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
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

  String _walletAccessLabel(WalletAuthoritySnapshot authority) {
    return switch (authority.state) {
      WalletAuthorityState.localSignerReady => 'Local signer ready',
      WalletAuthorityState.externalWalletReady => 'External wallet ready',
      WalletAuthorityState.encryptedBackupAvailableSignerMissing =>
        'Recovery available',
      WalletAuthorityState.walletReadOnly => 'Read-only',
      WalletAuthorityState.accountShellOnly => 'Account only',
      WalletAuthorityState.recoveryNeeded => 'Recovery needed',
      WalletAuthorityState.signedOut => 'Signed out',
    };
  }

  List<SecuritySummaryCard> _summaryCards(WalletProvider walletProvider) {
    final authority = walletProvider.authority;
    final accountPasskeys = _accountPasskeyStatus.passkeys.length;
    final walletPasskeys = walletProvider.encryptedWalletBackupPasskeys.length;
    return [
      SecuritySummaryCard(
        title: 'Wallet address',
        value: _walletLabel(authority.walletAddress),
        detail: authority.hasWalletIdentity
            ? 'Current account wallet'
            : 'Connect or restore a wallet',
        icon: Icons.account_balance_wallet_outlined,
        status: authority.hasWalletIdentity
            ? SecurityHubStatus.secured
            : SecurityHubStatus.disabled,
      ),
      SecuritySummaryCard(
        title: 'Wallet access',
        value: _walletAccessLabel(authority),
        detail: authority.externalWalletConnected
            ? authority.externalWalletName ?? 'External signer connected'
            : authority.canTransact
                ? 'Local wallet can sign'
                : 'Restore signing before transfers',
        icon: Icons.draw_outlined,
        status: _walletAccessStatus(authority),
      ),
      SecuritySummaryCard(
        title: 'Passkeys',
        value: '$accountPasskeys account / $walletPasskeys recovery',
        detail: 'Sign-in and wallet recovery are managed separately',
        icon: Icons.key_rounded,
        status: accountPasskeys > 0 || walletPasskeys > 0
            ? SecurityHubStatus.secured
            : SecurityHubStatus.available,
      ),
    ];
  }

  Widget _buildRequiredSetupPanel() {
    final scheme = Theme.of(context).colorScheme;
    return KubusCard(
      key: const ValueKey('security-required-setup-card'),
      padding: const EdgeInsets.all(KubusSpacing.lg),
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Secure this device',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            _requiredStep == _RequiredSetupStep.pin
                ? 'Set up local unlock before sensitive wallet and account actions.'
                : 'Enable biometric unlock on this device, or skip it for now.',
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
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
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
              label: 'Continue',
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
              label: 'Enable biometrics',
              isFullWidth: true,
            ),
            const SizedBox(height: KubusSpacing.sm),
            KubusButton(
              onPressed: _busy ? null : _skipBiometrics,
              icon: Icons.schedule_rounded,
              label: 'Skip for now',
              variant: KubusButtonVariant.secondary,
              isFullWidth: true,
            ),
          ],
          const SizedBox(height: KubusSpacing.sm),
          TextButton(
            onPressed: _busy
                ? null
                : () => context.read<SecurityGateProvider>().logout(),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodsList(WalletProvider walletProvider) {
    final gate = context.watch<SecurityGateProvider>();
    final l10n = AppLocalizations.of(context);
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
        title: l10n?.securityHubPinLocalLock ?? 'PIN / local lock',
        description:
            'Protects sensitive account and wallet actions on this device.',
        icon: Icons.lock_rounded,
        status:
            _hasPin ? SecurityHubStatus.secured : SecurityHubStatus.recommended,
        statusLabel: _hasPin ? 'Active' : 'Recommended',
        actions: _hasPin
            ? const <SecurityMethodAction>[]
            : [
                SecurityMethodAction(
                  label: 'Set PIN',
                  icon: Icons.lock_rounded,
                  onPressed: _busy ? null : _showPinSheet,
                ),
              ],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: 'Biometric unlock',
        description:
            'Uses this device biometric prompt after a local PIN exists.',
        icon: Icons.fingerprint_rounded,
        status: gate.biometricsEnabled
            ? SecurityHubStatus.secured
            : _biometricsAvailable
                ? SecurityHubStatus.available
                : SecurityHubStatus.disabled,
        statusLabel: gate.biometricsEnabled
            ? 'Active'
            : _biometricsAvailable
                ? 'Available'
                : 'Unavailable',
        actions: !gate.biometricsEnabled && _biometricsAvailable
            ? [
                SecurityMethodAction(
                  label: 'Enable',
                  icon: Icons.fingerprint_rounded,
                  onPressed: _busy ? null : _enableBiometrics,
                ),
              ]
            : const <SecurityMethodAction>[],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: 'Wallet address',
        description: authority.hasWalletIdentity
            ? _walletLabel(authority.walletAddress)
            : 'No wallet is connected on this device.',
        icon: Icons.account_balance_wallet_outlined,
        status: authority.hasWalletIdentity
            ? SecurityHubStatus.secured
            : SecurityHubStatus.disabled,
        statusLabel: authority.hasWalletIdentity ? 'Linked' : 'Missing',
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: 'Wallet access state',
        description: authority.canTransact
            ? 'This device can sign wallet actions.'
            : needsSignerRestore
                ? 'Encrypted backup can restore local wallet access.'
                : 'Wallet access is read-only or not connected.',
        helper: authority.externalWalletConnected
            ? 'External wallet: ${authority.externalWalletName ?? 'Connected'}'
            : null,
        icon: Icons.verified_user_outlined,
        status: _walletAccessStatus(authority),
        statusLabel: _walletAccessLabel(authority),
        actions: needsSignerRestore
            ? [
                SecurityMethodAction(
                  label: 'Restore access',
                  icon: Icons.login_rounded,
                  onPressed: _busy ? null : _restoreSignerFromBackup,
                ),
              ]
            : const <SecurityMethodAction>[],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: 'Local signer',
        description: authority.hasLocalSigner
            ? 'Local wallet signer is available on this device.'
            : 'No local signer is available on this device.',
        icon: Icons.edit_note_rounded,
        status: authority.hasLocalSigner
            ? SecurityHubStatus.secured
            : SecurityHubStatus.recommended,
        statusLabel: authority.hasLocalSigner ? 'Ready' : 'Missing',
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: 'External wallet',
        description: authority.hasExternalSigner
            ? authority.externalWalletName ?? 'External wallet connected.'
            : 'No external wallet signer is connected.',
        icon: Icons.link_rounded,
        status: authority.hasExternalSigner
            ? SecurityHubStatus.secured
            : SecurityHubStatus.disabled,
        statusLabel:
            authority.hasExternalSigner ? 'Connected' : 'Not connected',
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title:
            l10n?.securityHubEncryptedServerBackup ?? 'Encrypted server backup',
        description: !backupFeatureEnabled
            ? 'Encrypted wallet backup is disabled in this build.'
            : walletBackupReady
                ? 'Encrypted wallet backup is available for recovery.'
                : 'Create a password-protected encrypted backup for recovery.',
        helper: walletProvider.encryptedWalletBackupLastVerifiedAt == null
            ? null
            : 'Last verified: ${_formatDate(walletProvider.encryptedWalletBackupLastVerifiedAt)}',
        icon: Icons.cloud_done_outlined,
        status: !backupFeatureEnabled
            ? SecurityHubStatus.disabled
            : walletBackupReady
                ? SecurityHubStatus.secured
                : SecurityHubStatus.recommended,
        statusLabel: !backupFeatureEnabled
            ? 'Disabled'
            : walletBackupReady
                ? 'Configured'
                : 'Recommended',
        actions: backupFeatureEnabled
            ? [
                SecurityMethodAction(
                  label: walletBackupReady ? 'Update backup' : 'Create backup',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: _busy ? null : _createOrUpdateBackup,
                ),
                if (walletBackupReady)
                  SecurityMethodAction(
                    label: 'Verify',
                    icon: Icons.fact_check_outlined,
                    onPressed: _busy ? null : _verifyBackup,
                  ),
              ]
            : const <SecurityMethodAction>[],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title: l10n?.securityHubRecoveryPhrase ?? 'Recovery phrase',
        description: _backupPhraseRequired
            ? 'Store the recovery phrase offline before you rely on this wallet.'
            : 'No recovery phrase action is currently required.',
        icon: Icons.description_outlined,
        status: _backupPhraseRequired
            ? SecurityHubStatus.recommended
            : SecurityHubStatus.secured,
        statusLabel: _backupPhraseRequired ? 'Back up offline' : 'Checked',
        actions: [
          SecurityMethodAction(
            label: 'Show phrase',
            icon: Icons.visibility_outlined,
            onPressed: _busy ? null : _revealRecoveryPhrase,
          ),
        ],
      ),
      const SizedBox(height: KubusSpacing.sm),
      SecurityMethodRow(
        title:
            l10n?.securityHubAccountSignInPasskey ?? 'Account sign-in passkey',
        description:
            'Used to sign into art.kubus without email, Google, or wallet signature.',
        icon: Icons.key_rounded,
        status: _accountPasskeyStatus.accountSignInReady
            ? SecurityHubStatus.secured
            : passkeyEnabled
                ? SecurityHubStatus.available
                : SecurityHubStatus.disabled,
        statusLabel: _accountPasskeyStatus.accountSignInReady
            ? '${accountPasskeys.length} registered'
            : passkeyEnabled
                ? 'Available'
                : 'Unavailable',
        actions: passkeyEnabled
            ? [
                SecurityMethodAction(
                  label: 'Add account passkey',
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
            title: passkey.deviceLabel ?? 'Account sign-in passkey',
            description:
                'Created ${_formatDate(passkey.createdAt)}. Last used ${_formatDate(passkey.lastUsedAt)}.',
            helper:
                'Purpose: ${passkey.purpose ?? 'account_sign_in'}${passkey.prfSupported ? ' - PRF capable' : ''}',
            icon: Icons.devices_rounded,
            status: SecurityHubStatus.secured,
            statusLabel: 'Account sign-in',
            actions: [
              SecurityMethodAction(
                label: 'Remove',
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
        title: l10n?.securityHubWalletRecoveryPasskey ??
            'Wallet recovery / unlock passkey',
        description:
            'Used to restore local wallet access from encrypted backup.',
        icon: Icons.settings_backup_restore_rounded,
        status: recoveryPasskeys.isNotEmpty
            ? SecurityHubStatus.secured
            : passkeyRecoveryFeatureEnabled &&
                    _passkeysSupported &&
                    walletBackupReady
                ? SecurityHubStatus.available
                : SecurityHubStatus.recommended,
        statusLabel: recoveryPasskeys.isNotEmpty
            ? '${recoveryPasskeys.length} registered'
            : passkeyRecoveryFeatureEnabled &&
                    _passkeysSupported &&
                    walletBackupReady
                ? 'Available'
                : !passkeyRecoveryFeatureEnabled
                    ? 'Disabled'
                    : 'Set up backup first',
        helper: passkeyRecoveryFeatureEnabled && !_passkeysSupported && kIsWeb
            ? 'This browser does not expose wallet-recovery PRF support.'
            : null,
        actions: [
          if (recoveryPasskeys.isNotEmpty)
            SecurityMethodAction(
              label: l10n?.securityHubManageWalletRecoveryPasskeys ??
                  'Manage wallet recovery passkeys',
              icon: Icons.manage_accounts_outlined,
              onPressed: _busy ? null : _showWalletRecoveryPasskeys,
            ),
          if (passkeyRecoveryFeatureEnabled &&
              _passkeysSupported &&
              walletBackupReady)
            SecurityMethodAction(
              label: l10n?.securityHubAddWalletRecoveryPasskey ??
                  'Add wallet recovery passkey',
              icon: Icons.add_rounded,
              onPressed: _busy ? null : _createWalletRecoveryPasskey,
            ),
        ],
      ),
    ];

    final dangerRows = <SecurityMethodRow>[
      if (walletBackupReady)
        SecurityMethodRow(
          title: 'Delete encrypted backup',
          description:
              'Removes the encrypted server backup for the current wallet.',
          icon: Icons.delete_forever_outlined,
          status: SecurityHubStatus.destructive,
          statusLabel: 'Destructive',
          actions: [
            SecurityMethodAction(
              label: 'Delete backup',
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
    final l10n = AppLocalizations.of(context);
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
              ? l10n?.securityHubAccountSecurity ?? 'Account security'
              : l10n?.securityHubTitle ?? 'Security hub',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          _isRequiredSetup
              ? 'Set up local unlock, passkeys, and wallet recovery before you continue.'
              : 'Manage account sign-in, device unlock, wallet access, encrypted backups, and recovery credentials in one place.',
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
              ? const Center(child: CircularProgressIndicator())
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
