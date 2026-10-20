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

  group('a stronger lock replaces a pending sensitive prompt', () {
    Future<void> signedInGate() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'stored-token',
      });
      await gate.reloadSettings();
    }

    for (final reason in <SecurityLockReason>[
      SecurityLockReason.autoLock,
      SecurityLockReason.tokenExpired,
    ]) {
      test('${reason.name} survives Cancel', () async {
        await signedInGate();
        final pending = gate.requireSensitiveActionVerification();
        await Future<void>.delayed(Duration.zero);
        expect(gate.lockReason, SecurityLockReason.sensitiveAction);

        await gate.lock(reason);
        expect(gate.lockReason, reason);

        gate.cancel();
        expect(gate.isLocked, isTrue,
            reason: 'Cancel never unlocks an auto-locked or expired gate');
        // The waiting action is refused rather than left hanging.
        expect(await pending, isFalse);
        expect(gate.isResolving, isTrue);

        gate.completeForTesting(localAuthentication: true);
        expect(gate.isLocked, isFalse);
      });
    }

    test('a refused sensitive action is not credited with the later unlock',
        () async {
      await signedInGate();
      final pending = gate.requireSensitiveActionVerification();
      await Future<void>.delayed(Duration.zero);
      await gate.lock(SecurityLockReason.autoLock);
      gate.completeForTesting(localAuthentication: true);
      expect(await pending, isFalse);
    });

    test('a weaker request does not downgrade an existing lock', () async {
      await signedInGate();
      await gate.lock(SecurityLockReason.autoLock);
      final pending = gate.requireSensitiveActionVerification();
      await Future<void>.delayed(Duration.zero);
      expect(gate.lockReason, SecurityLockReason.autoLock);
      gate.cancel();
      expect(gate.isLocked, isTrue);
      gate.completeForTesting(localAuthentication: true);
      expect(await pending, isTrue);
    });
  });

  group('AuthSessionCoordinator.reset', () {
    Future<void> signedInGate() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'stored-token',
      });
      await gate.reloadSettings();
    }

    for (final reason in <SecurityLockReason>[
      SecurityLockReason.autoLock,
      SecurityLockReason.tokenExpired,
    ]) {
      test('does not clear a ${reason.name} lock', () async {
        await signedInGate();
        await gate.lock(reason);
        expect(gate.isLocked, isTrue);

        gate.reset();

        expect(gate.isLocked, isTrue);
        expect(gate.lockReason, reason);
        expect(gate.isResolving, isTrue);
      });
    }

    test('explicit logout fully unlocks an auto-locked gate', () async {
      await signedInGate();
      await gate.lock(SecurityLockReason.autoLock);
      expect(gate.isLocked, isTrue);

      await gate.logout();

      expect(gate.isLocked, isFalse);
      expect(gate.lockReason, isNull);
    });

    test('still releases a pending sensitive-action prompt', () async {
      await signedInGate();
      final pending = gate.requireSensitiveActionVerification();
      await Future<void>.delayed(Duration.zero);
      gate.reset();
      expect(gate.isLocked, isFalse);
      expect(await pending, isFalse);
    });
  });
}
