import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/security_gate_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/pin_hashing.dart';
import '../utils/app_animations.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';

class SecurityGateOverlay extends StatefulWidget {
  const SecurityGateOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SecurityGateOverlay> createState() => _SecurityGateOverlayState();
}

class _SecurityGateOverlayState extends State<SecurityGateOverlay> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SecurityGateProvider>(
      builder: (context, gate, child) {
        final animationTheme = context.animationTheme;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => gate.onUserInteraction(),
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !gate.isLocked,
                  child: AnimatedSwitcher(
                    duration: animationTheme.medium,
                    switchInCurve: animationTheme.fadeCurve,
                    switchOutCurve: animationTheme.fadeCurve,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: gate.isLocked
                        ? const _SecurityLockOverlay(key: ValueKey('security_locked'))
                        : const SizedBox.shrink(key: ValueKey('security_unlocked')),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _SecurityLockOverlay extends StatefulWidget {
  const _SecurityLockOverlay({super.key});

  @override
  State<_SecurityLockOverlay> createState() => _SecurityLockOverlayState();
}

class _SecurityLockOverlayState extends State<_SecurityLockOverlay> {
  final TextEditingController _pinController = TextEditingController();
  Timer? _lockoutTimer;
  int _lockoutRemainingSeconds = 0;
  bool _autoBiometricAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshLockout();
    _startLockoutTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeAutoPromptBiometrics();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshLockout();
    });
  }

  Future<void> _refreshLockout() async {
    final wallet = context.read<WalletProvider>();
    final remaining = await wallet.getPinLockoutRemainingSeconds();
    if (!mounted) return;
    if (remaining == _lockoutRemainingSeconds) return;
    setState(() => _lockoutRemainingSeconds = remaining);
  }

  Future<bool> _canShowBiometrics(SecurityGateProvider gate) async {
    if (!gate.biometricsEnabled || !gate.useBiometricsOnUnlock) return false;
    final wallet = context.read<WalletProvider>();
    return await wallet.canUseBiometrics();
  }

  Future<void> _maybeAutoPromptBiometrics() async {
    if (_autoBiometricAttempted) return;
    final gate = context.read<SecurityGateProvider>();
    final show = await _canShowBiometrics(gate);
    if (!mounted) return;
    if (!show) return;

    _autoBiometricAttempted = true;
    final l10n = AppLocalizations.of(context)!;
    final outcome = await gate.unlockWithBiometrics(
      localizedReason: _reasonMessageForBiometric(gate, l10n),
    );
    if (!mounted) return;
    if (outcome == BiometricAuthOutcome.success) return;
    if (outcome == BiometricAuthOutcome.cancelled) return;

    setState(() {
      _error = _biometricErrorMessage(outcome, l10n);
    });
  }

  String _reasonMessageForBiometric(SecurityGateProvider gate, AppLocalizations l10n) {
    if (gate.lockReason == SecurityLockReason.tokenExpired) {
      return l10n.authReauthDialogMessage;
    }
    return l10n.lockAppLockedDescription;
  }

  String _biometricErrorMessage(BiometricAuthOutcome outcome, AppLocalizations l10n) {
    if (outcome == BiometricAuthOutcome.notAvailable) return l10n.settingsBiometricUnavailableToast;
    if (outcome == BiometricAuthOutcome.lockedOut || outcome == BiometricAuthOutcome.permanentlyLockedOut) {
      return l10n.settingsBiometricFailedToast;
    }
    return l10n.settingsBiometricFailedToast;
  }

  Future<void> _handleBiometric() async {
    final gate = context.read<SecurityGateProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _error = null);
    final outcome = await gate.unlockWithBiometrics(
      localizedReason: _reasonMessageForBiometric(gate, l10n),
    );
    if (!mounted) return;
    if (outcome == BiometricAuthOutcome.success) return;
    if (outcome == BiometricAuthOutcome.cancelled) return;
    setState(() => _error = _biometricErrorMessage(outcome, l10n));
  }

  Future<void> _handlePin() async {
    final l10n = AppLocalizations.of(context)!;
    final gate = context.read<SecurityGateProvider>();
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    setState(() => _error = null);

    if (_lockoutRemainingSeconds > 0) {
      setState(() => _error = l10n.mnemonicRevealPinLockedError(_lockoutRemainingSeconds));
      return;
    }

    final result = await gate.unlockWithPin(pin);
    if (!mounted) return;
    if (result.isSuccess) return;

    if (result.outcome == PinVerifyOutcome.lockedOut) {
      await _refreshLockout();
      if (!mounted) return;
      setState(() => _error = l10n.mnemonicRevealPinLockedError(_lockoutRemainingSeconds));
      return;
    }

    if (result.outcome == PinVerifyOutcome.incorrect) {
      final attempts = (result.maxAttempts > 0)
          ? l10n.securityPinAttemptsRemaining(result.remainingAttempts, result.maxAttempts)
          : l10n.mnemonicRevealIncorrectPinError;
      setState(() => _error = attempts);
      return;
    }

    setState(() => _error = l10n.lockAuthenticationFailedToast);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gate = context.watch<SecurityGateProvider>();
    final scheme = Theme.of(context).colorScheme;

    final title = gate.lockReason == SecurityLockReason.tokenExpired ? l10n.authReauthDialogTitle : l10n.lockAppLockedTitle;
    final message = gate.lockReason == SecurityLockReason.tokenExpired ? l10n.authReauthDialogMessage : l10n.lockAppLockedDescription;
    final showSignIn = gate.lockReason == SecurityLockReason.tokenExpired;
    final showCancel = gate.lockReason == SecurityLockReason.sensitiveAction;

    return Material(
      color: scheme.surface.withValues(alpha: 0.65),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LiquidGlassPanel(
              blurSigma: KubusGlassEffects.blurSigmaHeavy,
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: KubusSpacing.sm),
                  Text(
                    message,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: KubusSpacing.md),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: KubusSpacing.lg),
                  FutureBuilder<bool>(
                    future: _canShowBiometrics(gate),
                    builder: (context, snapshot) {
                      final show = snapshot.data == true;
                      if (!show) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: gate.isBusy ? null : _handleBiometric,
                            child: gate.isBusy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.settingsBiometricTileTitle),
                          ),
                          const SizedBox(height: KubusSpacing.md),
                        ],
                      );
                    },
                  ),
                  FutureBuilder<bool>(
                    future: context.read<WalletProvider>().hasPin(),
                    builder: (context, snapshot) {
                      final hasPin = snapshot.data == true;
                      if (!hasPin) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            enabled: !gate.isBusy,
                            decoration: InputDecoration(
                              labelText: l10n.commonPinLabel,
                            ),
                            onSubmitted: (_) => _handlePin(),
                          ),
                          const SizedBox(height: KubusSpacing.md),
                          ElevatedButton(
                            onPressed: gate.isBusy ? null : _handlePin,
                            child: Text(l10n.commonUnlock),
                          ),
                          const SizedBox(height: KubusSpacing.md),
                        ],
                      );
                    },
                  ),
                  Row(
                    children: [
                      if (showCancel)
                        TextButton(
                          onPressed: gate.isBusy ? null : () => gate.cancel(),
                          child: Text(l10n.commonCancel),
                        ),
                      if (showCancel) const Spacer(),
                      if (showSignIn)
                        TextButton(
                          onPressed: gate.isBusy ? null : () => gate.unlockWithSignIn(),
                          child: Text(l10n.commonSignIn),
                        ),
                      if (showSignIn) const Spacer(),
                      TextButton(
                        onPressed: gate.isBusy ? null : () => gate.logout(),
                        child: Text(l10n.settingsLogoutButton),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
