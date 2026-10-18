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
}
