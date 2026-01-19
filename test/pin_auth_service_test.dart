import 'package:art_kubus/services/security/pin_auth_service.dart';
import 'package:art_kubus/services/pin_hashing.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements PinKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

void main() {
  test('PIN verify tracks attempts and staged lockout', () async {
    final store = _MemoryStore();
    final service = PinAuthService(
      store: store,
      policy: const PinLockoutPolicy(
        maxAttempts: 3,
        iterations: 10000,
        lockoutDurations: <Duration>[
          Duration(seconds: 1),
          Duration(seconds: 2),
        ],
      ),
    );

    await service.setPin('1234');

    final ok = await service.verifyPin('1234');
    expect(ok.isSuccess, isTrue);
    expect(ok.remainingAttempts, 3);
    expect(ok.maxAttempts, 3);

    final attempt1 = await service.verifyPin('0000');
    expect(attempt1.outcome, isNot(PinVerifyOutcome.success));
    expect(attempt1.remainingAttempts, 2);

    final attempt2 = await service.verifyPin('0000');
    expect(attempt2.outcome, isNot(PinVerifyOutcome.success));
    expect(attempt2.remainingAttempts, 1);

    final attempt3 = await service.verifyPin('0000');
    expect(attempt3.outcome, PinVerifyOutcome.lockedOut);
    expect(attempt3.remainingLockoutSeconds, greaterThan(0));
    expect(await store.read(PinAuthService.lockoutStageKey), '1');

    final locked = await service.verifyPin('1234');
    expect(locked.outcome, PinVerifyOutcome.lockedOut);

    // Expire lockout and verify correct PIN resets.
    await store.write(
      PinAuthService.lockoutUntilMsKey,
      DateTime.now().subtract(const Duration(seconds: 1)).millisecondsSinceEpoch.toString(),
    );
    final afterExpire = await service.verifyPin('1234');
    expect(afterExpire.outcome, PinVerifyOutcome.success);

    // Lock out again and ensure stage escalates.
    final wrongAgain1 = await service.verifyPin('0000');
    final wrongAgain2 = await service.verifyPin('0000');
    final wrongAgain3 = await service.verifyPin('0000');
    expect(wrongAgain1.outcome, PinVerifyOutcome.incorrect);
    expect(wrongAgain2.outcome, PinVerifyOutcome.incorrect);
    expect(wrongAgain3.outcome, PinVerifyOutcome.lockedOut);
    expect(await store.read(PinAuthService.lockoutStageKey), '1');

    await store.write(
      PinAuthService.lockoutUntilMsKey,
      DateTime.now().subtract(const Duration(seconds: 1)).millisecondsSinceEpoch.toString(),
    );
    await service.verifyPin('0000');
    await service.verifyPin('0000');
    final lockedStage2 = await service.verifyPin('0000');
    expect(lockedStage2.outcome, PinVerifyOutcome.lockedOut);
    expect(await store.read(PinAuthService.lockoutStageKey), '2');
  });
}
