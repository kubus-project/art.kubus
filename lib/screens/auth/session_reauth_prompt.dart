import 'package:flutter/material.dart';

import '../../services/pin_hashing.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/glass_components.dart';
import '../../utils/design_tokens.dart';

enum SessionReauthDecision {
  verified,
  signIn,
  cancelled,
}

class SessionReauthPrompt extends StatefulWidget {
  const SessionReauthPrompt({
    super.key,
    required this.title,
    required this.message,
    required this.showBiometrics,
    required this.showPin,
    required this.onBiometric,
    required this.onVerifyPin,
    required this.getPinLockoutSeconds,
    required this.biometricButtonLabel,
    required this.pinLabel,
    required this.pinSubmitLabel,
    required this.cancelLabel,
    required this.signInLabel,
    required this.pinIncorrectMessage,
    required this.pinLockedMessage,
    required this.biometricUnavailableMessage,
    required this.biometricFailedMessage,
  });

  final String title;
  final String message;

  final bool showBiometrics;
  final bool showPin;

  final Future<BiometricAuthOutcome> Function() onBiometric;
  final Future<PinVerifyResult> Function(String pin) onVerifyPin;
  final Future<int> Function() getPinLockoutSeconds;

  final String biometricButtonLabel;
  final String pinLabel;
  final String pinSubmitLabel;
  final String cancelLabel;
  final String signInLabel;

  final String pinIncorrectMessage;
  final String Function(int seconds) pinLockedMessage;
  final String biometricUnavailableMessage;
  final String biometricFailedMessage;

  @override
  State<SessionReauthPrompt> createState() => _SessionReauthPromptState();
}

class _SessionReauthPromptState extends State<SessionReauthPrompt> {
  final TextEditingController _pinController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _runWithBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleBiometric() async {
    await _runWithBusy(() async {
      final outcome = await widget.onBiometric();
      if (!mounted) return;
      if (outcome == BiometricAuthOutcome.success) {
        Navigator.of(context).pop(SessionReauthDecision.verified);
        return;
      }
      if (outcome == BiometricAuthOutcome.cancelled) {
        return;
      }
      if (outcome == BiometricAuthOutcome.notAvailable) {
        setState(() => _error = widget.biometricUnavailableMessage);
        return;
      }
      setState(() => _error = widget.biometricFailedMessage);
    });
  }

  Future<void> _handlePin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    await _runWithBusy(() async {
      final remaining = await widget.getPinLockoutSeconds();
      if (!mounted) return;
      if (remaining > 0) {
        setState(() => _error = widget.pinLockedMessage(remaining));
        return;
      }

      final result = await widget.onVerifyPin(pin);
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.of(context).pop(SessionReauthDecision.verified);
        return;
      }

      if (result.outcome == PinVerifyOutcome.lockedOut) {
        final seconds = result.remainingLockoutSeconds;
        setState(() => _error = widget.pinLockedMessage(seconds));
        return;
      }

      setState(() => _error = widget.pinIncorrectMessage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showSignInFallback = !widget.showBiometrics && !widget.showPin;

    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: LiquidGlassPanel(
          blurSigma: KubusGlassEffects.blurSigmaHeavy,
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  widget.message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: KubusSpacing.md),
                  Text(
                    _error!,
                    key: const Key('reauth_error'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: KubusSpacing.lg),
                if (widget.showBiometrics) ...[
                  ElevatedButton(
                    key: const Key('reauth_biometric_button'),
                    onPressed: _busy ? null : _handleBiometric,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.biometricButtonLabel),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                ],
                if (widget.showPin) ...[
                  TextField(
                    key: const Key('reauth_pin_input'),
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: widget.pinLabel,
                    ),
                    onSubmitted: (_) => _handlePin(),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  ElevatedButton(
                    key: const Key('reauth_pin_submit'),
                    onPressed: _busy ? null : _handlePin,
                    child: Text(widget.pinSubmitLabel),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                ],
                Row(
                  children: [
                    TextButton(
                      key: const Key('reauth_cancel'),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(SessionReauthDecision.cancelled),
                      child: Text(widget.cancelLabel),
                    ),
                    const Spacer(),
                    if (showSignInFallback)
                      TextButton(
                        key: const Key('reauth_sign_in'),
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(SessionReauthDecision.signIn),
                        child: Text(widget.signInLabel),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
