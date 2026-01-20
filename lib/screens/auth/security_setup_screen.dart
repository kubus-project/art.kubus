import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/settings_service.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/kubus_card.dart';
import '../../widgets/kubus_snackbar.dart';

enum _SecuritySetupStep {
  pin,
  biometrics,
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
  String? _inlineError;
  bool _allowPop = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _completeAndExit() async {
    if (!mounted) return;
    _allowPop = true;
    Navigator.of(context).pop(true);
  }

  Future<void> _handleSetPin() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = context.read<WalletProvider>();
    final gate = context.read<SecurityGateProvider>();

    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length < 4 || confirm.length < 4) {
      setState(() => _inlineError = l10n.settingsPinMinLengthError);
      return;
    }
    if (pin != confirm) {
      setState(() => _inlineError = l10n.settingsPinMismatchError);
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
        setState(() => _inlineError = l10n.settingsPinSetFailedToast);
        return;
      }

      final current = await SettingsService.loadSettings();
      final next = current.copyWith(requirePin: true);
      await SettingsService.saveSettings(next);
      await gate.reloadSettings();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.settingsPinSetSuccessToast)),
      );

      final canOfferBiometrics =
          _isMobilePlatform &&
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
      setState(() => _inlineError = l10n.settingsPinSetFailedToast);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleEnableBiometrics() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
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
          SnackBar(content: Text(l10n.settingsBiometricUnavailableToast)),
        );
        return;
      }

      final ok = await walletProvider.authenticateWithBiometrics();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.settingsBiometricFailedToast)),
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
      await _completeAndExit();
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = l10n.settingsBiometricFailedToast);
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
      await _completeAndExit();
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = AppLocalizations.of(context)!.commonActionFailedToast);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildPinStep(AppLocalizations l10n, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsSetPinTileTitle,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.settingsSetPinTileSubtitle,
          style: GoogleFonts.inter(
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
            labelText: l10n.commonPinLabel,
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
            labelText: l10n.settingsConfirmPinLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_inlineError != null) ...[
          const SizedBox(height: 12),
          Text(
            _inlineError!,
            style: GoogleFonts.inter(color: scheme.error),
          ),
        ],
        const SizedBox(height: 16),
        KubusButton(
          onPressed: _busy ? null : _handleSetPin,
          isLoading: _busy,
          icon: _busy ? null : Icons.lock_rounded,
          label: l10n.commonProceed,
          isFullWidth: true,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy ? null : () => context.read<SecurityGateProvider>().logout(),
          child: Text(
            l10n.settingsLogoutButton,
            style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricsStep(AppLocalizations l10n, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsBiometricTileTitle,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.settingsBiometricTileSubtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        if (_inlineError != null) ...[
          const SizedBox(height: 12),
          Text(
            _inlineError!,
            style: GoogleFonts.inter(color: scheme.error),
          ),
        ],
        const SizedBox(height: 16),
        KubusButton(
          onPressed: _busy ? null : _handleEnableBiometrics,
          isLoading: _busy,
          icon: _busy ? null : Icons.fingerprint,
          label: l10n.settingsBiometricTileTitle,
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        KubusButton(
          onPressed: _busy ? null : _handleSkipBiometrics,
          icon: Icons.schedule_rounded,
          label: l10n.commonSkipForNow,
          isFullWidth: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

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
            l10n.settingsSecuritySettingsDialogTitle,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: KubusCard(
                  padding: const EdgeInsets.all(16),
                  color: scheme.surfaceContainerHighest,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _step == _SecuritySetupStep.pin
                        ? _buildPinStep(l10n, scheme)
                        : _buildBiometricsStep(l10n, scheme),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
