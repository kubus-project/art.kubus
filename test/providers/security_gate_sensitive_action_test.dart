import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);

  bool pinStored = true;
  bool pinReadThrows = false;
  int pinReads = 0;

  @override
  Future<bool> hasPin() async => pinStored;

  @override
  Future<bool> hasPinOrThrow() async {
    pinReads++;
    if (pinReadThrows) throw StateError('secure storage unavailable');
    return pinStored;
  }

  @override
  Future<bool> canUseBiometrics() async => false;
}

/// A sensitive action (replace or remove the PIN, add or remove a passkey, show
/// the recovery phrase) is satisfied only by current LOCAL authentication.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecurityGateProvider gate;
  late _Wallet wallet;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    gate = SecurityGateProvider(promptCooldown: Duration.zero);
    wallet = _Wallet();
    gate.bindDependencies(
      profileProvider: ProfileProvider(),
      walletProvider: wallet,
      notificationProvider: NotificationProvider(),
    );
  });

  test('an unreadable PIN store fails closed instead of reading as "no PIN"',
      () async {
    wallet.pinReadThrows = true;
    expect(await gate.requireSensitiveActionVerification(), isFalse);
    expect(gate.isLocked, isFalse,
        reason: 'no prompt is shown for a state that cannot be decided');
  });

  test('with no PIN and no biometrics there is nothing to verify', () async {
    wallet.pinStored = false;
    expect(await gate.requireSensitiveActionVerification(), isTrue);
  });

  test('PIN or biometric unlock satisfies the action', () async {
    final result = gate.requireSensitiveActionVerification();
    await Future<void>.delayed(Duration.zero);
    expect(gate.isLocked, isTrue);
    gate.completeForTesting(localAuthentication: true);
    expect(await result, isTrue);
  });

  test('signing in again does NOT satisfy the action', () async {
    final result = gate.requireSensitiveActionVerification();
    await Future<void>.delayed(Duration.zero);
    gate.completeForTesting(localAuthentication: false);
    expect(await result, isFalse);
  });

  test('a later local unlock is not credited to an earlier sign-in', () async {
    final first = gate.requireSensitiveActionVerification();
    await Future<void>.delayed(Duration.zero);
    gate.completeForTesting(localAuthentication: false);
    expect(await first, isFalse);

    final second = gate.requireSensitiveActionVerification();
    await Future<void>.delayed(Duration.zero);
    gate.completeForTesting(localAuthentication: true);
    expect(await second, isTrue);
  });

  test('cancelling the prompt is a refusal', () async {
    final result = gate.requireSensitiveActionVerification();
    await Future<void>.delayed(Duration.zero);
    gate.cancel();
    expect(await result, isFalse);
  });
}
