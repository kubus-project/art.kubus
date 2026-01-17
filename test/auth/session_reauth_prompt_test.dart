import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/session_reauth_prompt.dart';
import 'package:art_kubus/services/pin_hashing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('biometric success returns verified', (tester) async {
    SessionReauthDecision? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showDialog<SessionReauthDecision>(
                  context: context,
                  builder: (_) => Center(
                    child: SessionReauthPrompt(
                      title: 'Session expired',
                      message: 'Verify to continue',
                      showBiometrics: true,
                      showPin: false,
                      onBiometric: () async => BiometricAuthOutcome.success,
                      onVerifyPin: (_) async => const PinVerifyResult(PinVerifyOutcome.notSet),
                      getPinLockoutSeconds: () async => 0,
                      biometricButtonLabel: 'Biometric',
                      pinLabel: 'PIN',
                      pinSubmitLabel: 'Unlock',
                      cancelLabel: 'Cancel',
                      signInLabel: 'Sign in',
                      pinIncorrectMessage: 'Incorrect PIN',
                      pinLockedMessage: (s) => 'Locked $s',
                      biometricUnavailableMessage: 'No biometrics',
                      biometricFailedMessage: 'Biometric failed',
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reauth_biometric_button')));
    await tester.pumpAndSettle();

    expect(result, SessionReauthDecision.verified);
  });

  testWidgets('PIN success returns verified when biometrics unavailable', (tester) async {
    SessionReauthDecision? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showDialog<SessionReauthDecision>(
                  context: context,
                  builder: (_) => Center(
                    child: SessionReauthPrompt(
                      title: 'Session expired',
                      message: 'Verify to continue',
                      showBiometrics: false,
                      showPin: true,
                      onBiometric: () async => BiometricAuthOutcome.notAvailable,
                      onVerifyPin: (_) async => const PinVerifyResult(PinVerifyOutcome.success),
                      getPinLockoutSeconds: () async => 0,
                      biometricButtonLabel: 'Biometric',
                      pinLabel: 'PIN',
                      pinSubmitLabel: 'Unlock',
                      cancelLabel: 'Cancel',
                      signInLabel: 'Sign in',
                      pinIncorrectMessage: 'Incorrect PIN',
                      pinLockedMessage: (s) => 'Locked $s',
                      biometricUnavailableMessage: 'No biometrics',
                      biometricFailedMessage: 'Biometric failed',
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('reauth_pin_input')), '1234');
    await tester.tap(find.byKey(const Key('reauth_pin_submit')));
    await tester.pumpAndSettle();

    expect(result, SessionReauthDecision.verified);
  });
}
