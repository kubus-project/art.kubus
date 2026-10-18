import 'dart:async';

import 'package:art_kubus/services/pin_hashing.dart';
import 'package:art_kubus/services/security/pin_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements PinKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// A store whose reads never complete, like a hung secure-storage call.
class _HungReadStore extends _MemoryStore {
  @override
  Future<String?> read(String key) => Completer<String?>().future;
}

/// Lets the first [allowedOps] operations finish, then every later one hangs.
class _HangAfterStore extends _MemoryStore {
  _HangAfterStore(this.allowedOps);

  final int allowedOps;
  int _ops = 0;

  Future<T> _gate<T>(T Function() op) {
    _ops += 1;
    if (_ops > allowedOps) return Completer<T>().future;
    return Future<T>.value(op());
  }

  @override
  Future<String?> read(String key) => _gate<String?>(() => values[key]);

  @override
  Future<void> write(String key, String value) => _gate<void>(() {
        values[key] = value;
      });
}

const _policy = PinLockoutPolicy(
  maxAttempts: 3,
  iterations: 10000,
  lockoutDurations: <Duration>[Duration(seconds: 30)],
);

void main() {
  // Short injected timeout: the production default is 10 seconds.
  const timeout = Duration(milliseconds: 50);

  test('a hung storage read fails the call and the queue keeps moving',
      () async {
    final healthy = _MemoryStore();
    final seeded = PinAuthService(
      store: healthy,
      policy: _policy,
      operationTimeout: timeout,
    );
    await seeded.setPin('1234');

    final hung = PinAuthService(
      store: _HungReadStore(),
      policy: _policy,
      operationTimeout: timeout,
    );
    await expectLater(
      hung.verifyPin('1234'),
      throwsA(isA<TimeoutException>()),
    );

    // The shared chain advanced past the hung action, so a later operation on
    // a healthy store completes and reports the correct PIN.
    final after = PinAuthService(
      store: healthy,
      policy: _policy,
      operationTimeout: timeout,
    );
    final result = await after.verifyPin('1234');
    expect(result.outcome, PinVerifyOutcome.success);
  });

  test('a hung write fails setPin and does not block a following read',
      () async {
    final hung = PinAuthService(
      store: _HungReadStore(),
      policy: _policy,
      operationTimeout: timeout,
    );
    await expectLater(
      hung.getLockoutRemainingSeconds(),
      throwsA(isA<TimeoutException>()),
    );

    final healthy = PinAuthService(
      store: _MemoryStore(),
      policy: _policy,
      operationTimeout: timeout,
    );
    expect(await healthy.hasPin(), isFalse);
    expect(await healthy.getLockoutRemainingSeconds(), 0);
  });

  test(
      'a wrong guess is counted before the hash compare, so a later hang '
      'cannot drop it', () async {
    final healthy = _MemoryStore();
    await PinAuthService(store: healthy, policy: _policy).setPin('1234');

    // Lockout read, hash read, failed-count read and failed-count write are
    // four operations. Nothing after them can hang, so the count must land.
    final store = _HangAfterStore(4)..values.addAll(healthy.values);
    final service = PinAuthService(
      store: store,
      policy: _policy,
      operationTimeout: timeout,
    );
    final result = await service.verifyPin('0000');
    expect(result.outcome, PinVerifyOutcome.incorrect);
    expect(result.remainingAttempts, _policy.maxAttempts - 1);
    expect(store.values[PinAuthService.failedAttemptsKey], '1');

    final reread = _MemoryStore()..values.addAll(store.values);
    final after = PinAuthService(store: reread, policy: _policy);
    final next = await after.verifyPin('0000');
    expect(next.remainingAttempts, _policy.maxAttempts - 2);
  });

  test('a hung failed-count write times out and never reports a wrong PIN',
      () async {
    final healthy = _MemoryStore();
    await PinAuthService(store: healthy, policy: _policy).setPin('1234');

    // Only the lockout read and the hash read complete; the count write hangs.
    final store = _HangAfterStore(2)..values.addAll(healthy.values);
    final service = PinAuthService(
      store: store,
      policy: _policy,
      operationTimeout: timeout,
    );
    await expectLater(
      service.verifyPin('0000'),
      throwsA(isA<TimeoutException>()),
    );
    expect(store.values.containsKey(PinAuthService.failedAttemptsKey), isFalse);
  });

  test('the correct PIN resets the failed-attempt count to zero', () async {
    final store = _MemoryStore();
    final service = PinAuthService(store: store, policy: _policy);
    await service.setPin('1234');
    await service.verifyPin('0000');
    await service.verifyPin('0000');
    expect(store.values[PinAuthService.failedAttemptsKey], '2');

    final ok = await service.verifyPin('1234');
    expect(ok.outcome, PinVerifyOutcome.success);
    expect(store.values.containsKey(PinAuthService.failedAttemptsKey), isFalse);

    final again = await service.verifyPin('0000');
    expect(again.remainingAttempts, _policy.maxAttempts - 1);
  });
}
