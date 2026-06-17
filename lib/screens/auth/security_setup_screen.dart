import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import '../../config/config.dart';
import '../../utils/design_tokens.dart';
import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/passkey_protection_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/kubus_card.dart';
import '../../widgets/kubus_snackbar.dart';

enum _SecuritySetupStep {
  pin,
  biometrics,
}

enum _SecurityHubState {
  secured,
  available,
  recommended,
  failed,
}

class _SecurityHubItem {
  const _SecurityHubItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _SecurityHubState state;
}

class _SecurityCopy {
  const _SecurityCopy(this.l10n);

  final AppLocalizations? l10n;

  String get title =>
      l10n?.settingsSecuritySettingsDialogTitle ?? 'Account security';
  String get subtitle =>
      'Set up local unlock, passkeys, and wallet recovery before you continue.';
  String get statusTitle => 'Security status';
  String get actionTitle => 'Secure this device';
  String get pinTitle => l10n?.settingsSetPinTileTitle ?? 'Set a PIN';
  String get pinSubtitle =>
      l10n?.settingsSetPinTileSubtitle ??
      'Use a local PIN to unlock protected wallet and account actions.';
  String get biometricTitle =>
      l10n?.settingsBiometricTileTitle ?? 'Enable biometrics';
  String get biometricSubtitle =>
      l10n?.settingsBiometricTileSubtitle ??
      'Use this device biometric prompt when available.';
  String get pinMinLength =>
      l10n?.settingsPinMinLengthError ?? 'PIN must be at least 4 digits.';
  String get pinMismatch =>
      l10n?.settingsPinMismatchError ?? 'PIN entries do not match.';
  String get pinSetFailed =>
      l10n?.settingsPinSetFailedToast ?? 'Could not set PIN.';
  String get pinSetSuccess => l10n?.settingsPinSetSuccessToast ?? 'PIN set.';
  String get biometricUnavailable =>
      l10n?.settingsBiometricUnavailableToast ?? 'Biometrics unavailable.';
  String get biometricFailed =>
      l10n?.settingsBiometricFailedToast ?? 'Biometric approval failed.';
  String get actionFailed => l10n?.commonActionFailedToast ?? 'Action failed.';
  String get pinLabel => l10n?.commonPinLabel ?? 'PIN';
  String get confirmPin => l10n?.settingsConfirmPinLabel ?? 'Confirm PIN';
  String get proceed => l10n?.commonProceed ?? 'Continue';
  String get logout => l10n?.settingsLogoutButton ?? 'Log out';
  String get skip => l10n?.commonSkipForNow ?? 'Skip for now';
  String get working => l10n?.commonWorking ?? 'Working';
}

class SecuritySetupScreen extends StatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  _SecuritySetupStep _step = _SecuritySetupStep.pin;
  bool _busy = false;
  bool _statusLoading = true;
  bool _hasPin = false;
  bool _biometricsAvailable = false;
  bool _walletBackupReady = false;
  bool _backupPhraseRequired = false;
  AccountPasskeyStatus _passkeyStatus = AccountPasskeyStatus.empty;
  String? _statusError;
  String? _inlineError;
  bool _allowPop = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshSecurityStatus());
    });
  }

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _completeAndExit() async {
    if (!mounted) return;
    _allowPop = true;
    Navigator.of(context).pop(true);
  }

  Future<void> _refreshSecurityStatus() async {
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();

    var hasPin = false;
    var biometricsAvailable = false;
    var walletBackupReady = false;
    var backupPhraseRequired = false;
    var passkeyStatus = AccountPasskeyStatus.empty;
    String? statusError;

    try {
      await gate.reloadSettings().timeout(const Duration(seconds: 3));
    } catch (_) {
      statusError = 'Local security settings could not be refreshed.';
    }

    try {
      hasPin = await walletProvider
          .hasPin()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      biometricsAvailable = await walletProvider
          .canUseBiometrics()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      walletBackupReady = walletProvider.hasEncryptedWalletBackup;
      backupPhraseRequired = await walletProvider
          .isMnemonicBackupRequired()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (_) {
      statusError ??= 'Wallet security status could not be refreshed.';
    }

    if (kIsWeb && AppConfig.isFeatureEnabled('passkeySignIn')) {
      try {
        passkeyStatus = await const PasskeyProtectionService()
            .getAccountStatus(BackendApiService())
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        statusError ??= 'Passkey status is temporarily unavailable.';
      }
    }

    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _biometricsAvailable = biometricsAvailable;
      _walletBackupReady = walletBackupReady;
      _backupPhraseRequired = backupPhraseRequired;
      _passkeyStatus = passkeyStatus;
      _statusError = statusError;
      _statusLoading = false;
    });
  }

  Future<void> _handleSetPin() async {
    if (_busy) return;
    final copy = _SecurityCopy(AppLocalizations.of(context));
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();

    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length < 4 || confirm.length < 4) {
      setState(() => _inlineError = copy.pinMinLength);
      return;
    }
    if (pin != confirm) {
      setState(() => _inlineError = copy.pinMismatch);
      return;
    }

    setState(() {
      _busy = true;
      _inlineError = null;
    });

    try {
      await walletProvider.setPin(pin);
      final hasPin = await walletProvider.hasPin();
      if (!mounted) return;
      if (!hasPin) {
        setState(() => _inlineError = copy.pinSetFailed);
        return;
      }

      final current = await SettingsService.loadSettings();
      final next = current.copyWith(requirePin: true);
      await SettingsService.saveSettings(next);
      await gate.reloadSettings();

      if (!mounted) return;
      await _refreshSecurityStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(copy.pinSetSuccess)),
      );

      final canOfferBiometrics = _isMobilePlatform &&
          !next.biometricsDeclined &&
          !next.biometricAuth &&
          await walletProvider.canUseBiometrics();
      if (!mounted) return;
      if (!canOfferBiometrics) {
        await _completeAndExit();
        return;
      }

      setState(() {
        _step = _SecuritySetupStep.biometrics;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = copy.pinSetFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleEnableBiometrics() async {
    if (_busy) return;
    final copy = _SecurityCopy(AppLocalizations.of(context));
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();

    setState(() {
      _busy = true;
      _inlineError = null;
    });

    try {
      final canUse = await walletProvider.canUseBiometrics();
      if (!mounted) return;
      if (!canUse) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(copy.biometricUnavailable)),
        );
        return;
      }

      final ok = await walletProvider.authenticateWithBiometrics();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(copy.biometricFailed)),
        );
        return;
      }

      final current = await SettingsService.loadSettings();
      final next = current.copyWith(
        requirePin: true,
        biometricAuth: true,
        biometricsDeclined: false,
        useBiometricsOnUnlock: true,
      );
      await SettingsService.saveSettings(next);
      await gate.reloadSettings();
      if (!mounted) return;
      await _refreshSecurityStatus();
      if (!mounted) return;
      await _completeAndExit();
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = copy.biometricFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSkipBiometrics() async {
    if (_busy) return;
    final gate = context.read<SecurityGateProvider>();
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    try {
      final current = await SettingsService.loadSettings();
      final next = current.copyWith(
        requirePin: true,
        biometricAuth: false,
        biometricsDeclined: true,
        useBiometricsOnUnlock: true,
      );
      await SettingsService.saveSettings(next);
      await gate.reloadSettings();
      if (!mounted) return;
      await _refreshSecurityStatus();
      if (!mounted) return;
      await _completeAndExit();
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError =
          _SecurityCopy(AppLocalizations.of(context)).actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildPinStep(_SecurityCopy copy, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          copy.pinTitle,
          style: KubusTypography.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          copy.pinSubtitle,
          style: KubusTypography.inter(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: copy.pinLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmController,
          keyboardType: TextInputType.number,
          obscureText: true,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: copy.confirmPin,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_inlineError != null) ...[
          const SizedBox(height: 12),
          Text(
            _inlineError!,
            style: KubusTypography.inter(color: scheme.error),
          ),
        ],
        const SizedBox(height: 16),
        KubusButton(
          onPressed: _busy ? null : _handleSetPin,
          isLoading: _busy,
          icon: _busy ? null : Icons.lock_rounded,
          label: _busy ? copy.working : copy.proceed,
          isFullWidth: true,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy
              ? null
              : () => context.read<SecurityGateProvider>().logout(),
          child: Text(
            copy.logout,
            style: KubusTypography.inter(
                color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricsStep(_SecurityCopy copy, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          copy.biometricTitle,
          style: KubusTypography.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          copy.biometricSubtitle,
          style: KubusTypography.inter(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        if (_inlineError != null) ...[
          const SizedBox(height: 12),
          Text(
            _inlineError!,
            style: KubusTypography.inter(color: scheme.error),
          ),
        ],
        const SizedBox(height: 16),
        KubusButton(
          onPressed: _busy ? null : _handleEnableBiometrics,
          isLoading: _busy,
          icon: _busy ? null : Icons.fingerprint,
          label: _busy ? copy.working : copy.biometricTitle,
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        KubusButton(
          onPressed: _busy ? null : _handleSkipBiometrics,
          icon: Icons.schedule_rounded,
          label: copy.skip,
          isFullWidth: true,
        ),
      ],
    );
  }

  Color _stateColor(_SecurityHubState state) {
    return switch (state) {
      _SecurityHubState.secured => KubusColors.success,
      _SecurityHubState.available => KubusColors.accentBlue,
      _SecurityHubState.recommended => KubusColors.warning,
      _SecurityHubState.failed => KubusColors.error,
    };
  }

  String _stateLabel(_SecurityHubState state) {
    return switch (state) {
      _SecurityHubState.secured => 'Secured',
      _SecurityHubState.available => 'Available',
      _SecurityHubState.recommended => 'Recommended',
      _SecurityHubState.failed => 'Failed',
    };
  }

  List<_SecurityHubItem> _securityItems(SecurityGateProvider gate) {
    final passkeyEnabled =
        kIsWeb && AppConfig.isFeatureEnabled('passkeySignIn');
    final hasPasskeys = _passkeyStatus.passkeys.isNotEmpty;
    final passkeyReady = _passkeyStatus.accountSignInReady;
    final passkeyState = _statusError?.contains('Passkey') == true
        ? _SecurityHubState.failed
        : passkeyReady
            ? _SecurityHubState.secured
            : passkeyEnabled
                ? _SecurityHubState.available
                : _SecurityHubState.recommended;

    return <_SecurityHubItem>[
      _SecurityHubItem(
        title: 'PIN / local lock',
        subtitle: _hasPin
            ? 'Local unlock is active on this device.'
            : 'Add a PIN before sensitive wallet or account actions.',
        icon: Icons.lock_rounded,
        state:
            _hasPin ? _SecurityHubState.secured : _SecurityHubState.recommended,
      ),
      _SecurityHubItem(
        title: 'Passkey sign-in',
        subtitle: passkeyReady
            ? 'Passwordless account sign-in is ready.'
            : passkeyEnabled
                ? 'Create a passkey after setup for browser sign-in.'
                : 'Passkey sign-in is not enabled for this device.',
        icon: Icons.key_rounded,
        state: passkeyState,
      ),
      _SecurityHubItem(
        title: 'Wallet recovery',
        subtitle: _walletBackupReady
            ? 'Encrypted wallet recovery is configured.'
            : 'Set up an encrypted wallet backup from wallet security.',
        icon: Icons.settings_backup_restore_rounded,
        state: _walletBackupReady
            ? _SecurityHubState.secured
            : _SecurityHubState.recommended,
      ),
      _SecurityHubItem(
        title: 'Backup phrase',
        subtitle: _backupPhraseRequired
            ? 'Recovery phrase backup is still recommended.'
            : 'No recovery phrase action is currently required.',
        icon: Icons.description_outlined,
        state: _backupPhraseRequired
            ? _SecurityHubState.recommended
            : _SecurityHubState.secured,
      ),
      _SecurityHubItem(
        title: 'Registered passkeys',
        subtitle: hasPasskeys
            ? '${_passkeyStatus.passkeys.length} passkey${_passkeyStatus.passkeys.length == 1 ? '' : 's'} registered.'
            : 'No account passkeys registered yet.',
        icon: Icons.devices_rounded,
        state: hasPasskeys
            ? _SecurityHubState.secured
            : passkeyEnabled
                ? _SecurityHubState.available
                : _SecurityHubState.recommended,
      ),
      _SecurityHubItem(
        title: 'Biometric unlock',
        subtitle: gate.biometricsEnabled
            ? 'Biometric unlock is active for this device.'
            : _biometricsAvailable
                ? 'Available after the PIN is created.'
                : 'Unavailable on this device.',
        icon: Icons.fingerprint_rounded,
        state: gate.biometricsEnabled
            ? _SecurityHubState.secured
            : _biometricsAvailable
                ? _SecurityHubState.available
                : _SecurityHubState.recommended,
      ),
    ];
  }

  Widget _buildStatusPanel(
    BuildContext context,
    _SecurityCopy copy,
    SecurityGateProvider gate,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = _securityItems(gate);
    final securedCount =
        items.where((item) => item.state == _SecurityHubState.secured).length;
    final progress = items.isEmpty ? 0.0 : securedCount / items.length;
    final statusColor = progress >= 0.66
        ? KubusColors.success
        : progress >= 0.34
            ? KubusColors.accentBlue
            : KubusColors.warning;

    return KubusCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      color: Color.lerp(scheme.surface, statusColor, 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.shield_rounded, color: statusColor),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.statusTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$securedCount of ${items.length} protections active',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.68),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(KubusRadius.xl),
            child: LinearProgressIndicator(
              value: _statusLoading ? null : progress,
              minHeight: 8,
              backgroundColor: scheme.surface.withValues(alpha: 0.32),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          if (_statusError != null) ...[
            const SizedBox(height: KubusSpacing.sm),
            _buildStatusMessage(scheme),
          ],
          const SizedBox(height: KubusSpacing.md),
          ...items.map(_buildStatusRow),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: KubusColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
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

  Widget _buildStatusRow(_SecurityHubItem item) {
    final scheme = Theme.of(context).colorScheme;
    final color = _stateColor(item.state);
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(KubusSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: color, size: 22),
            const SizedBox(width: KubusSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.66),
                          height: 1.25,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.sm,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(KubusRadius.xl),
              ),
              child: Text(
                _stateLabel(item.state),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel(_SecurityCopy copy, ColorScheme scheme) {
    return KubusCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.actionTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            copy.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _step == _SecuritySetupStep.pin
                ? _buildPinStep(copy, scheme)
                : _buildBiometricsStep(copy, scheme),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = _SecurityCopy(AppLocalizations.of(context));
    final scheme = Theme.of(context).colorScheme;
    final gate = context.watch<SecurityGateProvider>();

    return PopScope(
      canPop: _allowPop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            copy.title,
            style: KubusTypography.inter(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              final content = desktop
                  ? Row(
                      key: const ValueKey('security-setup-desktop-layout'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildStatusPanel(context, copy, gate),
                        ),
                        const SizedBox(width: KubusSpacing.lg),
                        Expanded(
                          flex: 4,
                          child: _buildActionPanel(copy, scheme),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('security-setup-mobile-layout'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusPanel(context, copy, gate),
                        const SizedBox(height: KubusSpacing.md),
                        _buildActionPanel(copy, scheme),
                      ],
                    );
              return SingleChildScrollView(
                padding: EdgeInsets.all(
                  desktop ? KubusSpacing.xl : KubusSpacing.md,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 32),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: desktop ? 1120 : 560,
                      ),
                      child: content,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
