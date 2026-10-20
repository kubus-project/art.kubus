import 'package:art_kubus/services/pin_hashing.dart';
import 'package:art_kubus/services/security/pin_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements PinKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    await Future<void>.delayed(Duration.zero);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    await Future<void>.delayed(Duration.zero);
    values.remove(key);
  }
}

class _Clock {
  DateTime now = DateTime.utc(2030, 1, 1, 12);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

const _policy = PinLockoutPolicy(
  maxAttempts: 3,
  iterations: 10000,
  lockoutDurations: <Duration>[
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
  ],
);

void main() {
  late _MemoryStore store;
  late _Clock clock;
  late PinAuthService service;

  setUp(() async {
    store = _MemoryStore();
    clock = _Clock();
    service = PinAuthService(store: store, policy: _policy, clock: clock.call);
    await service.setPin('1234');
  });

  Future<PinVerifyResult> failOnce() => service.verifyPin('0000');

  Future<void> lockOut() async {
    await failOnce();
    await failOnce();
    final last = await failOnce();
    expect(last.outcome, PinVerifyOutcome.lockedOut);
  }

  group('lockout escalation', () {
    test('a lockout that ran out does not reset the escalation', () async {
      await lockOut();
      expect(store.values[PinAuthService.lockoutStageKey], '1');

      clock.advance(const Duration(seconds: 31));
      expect(await service.getLockoutRemainingSeconds(), 0);

      // One more wrong guess lands in the next, longer stage at once.
      final next = await failOnce();
      expect(next.outcome, PinVerifyOutcome.lockedOut);
      expect(store.values[PinAuthService.lockoutStageKey], '2');
      expect(next.remainingLockoutSeconds, inInclusiveRange(59, 60));
    });

    test('the correct PIN after a lockout still clears everything', () async {
      await lockOut();
      clock.advance(const Duration(seconds: 31));
      final ok = await service.verifyPin('1234');
      expect(ok.isSuccess, isTrue);
      expect(store.values.containsKey(PinAuthService.lockoutStageKey), isFalse);
      expect(
          store.values.containsKey(PinAuthService.failedAttemptsKey), isFalse);
    });
  });

  group('clock changes', () {
    test('moving the clock back never shortens a lockout', () async {
      await lockOut();
      final before = await service.getLockoutRemainingSeconds();

      clock.advance(const Duration(days: -1));
      expect(await service.getLockoutRemainingSeconds(),
          greaterThanOrEqualTo(before));
      expect((await service.verifyPin('1234')).outcome,
          PinVerifyOutcome.lockedOut);
    });

    test('a lockout that cannot be parsed counts as locked', () async {
      store.values[PinAuthService.lockoutUntilMsKey] = 'not-a-number';
      expect(await service.getLockoutRemainingSeconds(), greaterThan(0));
      expect((await service.verifyPin('1234')).outcome,
          PinVerifyOutcome.lockedOut);
    });
  });

  group('concurrency', () {
    test('parallel wrong guesses are each counted', () async {
      final results = await Future.wait([
        failOnce(),
        failOnce(),
        failOnce(),
      ]);
      expect(results.map((r) => r.outcome), [
        PinVerifyOutcome.incorrect,
        PinVerifyOutcome.incorrect,
        PinVerifyOutcome.lockedOut,
      ]);
      expect(store.values[PinAuthService.lockoutStageKey], '1');
    });
  });
}
