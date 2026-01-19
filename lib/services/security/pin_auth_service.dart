import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pin_hashing.dart';

abstract class PinKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureStoragePinStore implements PinKeyValueStore {
  SecureStoragePinStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SharedPreferencesPinStore implements PinKeyValueStore {
  SharedPreferencesPinStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }
}

class PinLockoutPolicy {
  const PinLockoutPolicy({
    this.maxAttempts = 5,
    this.iterations = 120000,
    this.lockoutDurations = const <Duration>[
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
      Duration(hours: 1),
    ],
  });

  final int maxAttempts;
  final int iterations;
  final List<Duration> lockoutDurations;

  Duration lockoutForStage(int stage) {
    if (stage <= 0) return lockoutDurations.first;
    if (stage >= lockoutDurations.length) return lockoutDurations.last;
    return lockoutDurations[stage];
  }
}

class PinAuthService {
  PinAuthService({
    required PinKeyValueStore store,
    PinLockoutPolicy policy = const PinLockoutPolicy(),
  })  : _store = store,
        _policy = policy;

  final PinKeyValueStore _store;
  final PinLockoutPolicy _policy;

  static const String pinHashKey = 'app_pin_hash';
  static const String failedAttemptsKey = 'app_pin_failed_attempts';
  static const String lockoutUntilMsKey = 'app_pin_lockout_until_ms';
  static const String lockoutStageKey = 'app_pin_lockout_stage';

  static Future<PinAuthService> createDefault({
    PinLockoutPolicy policy = const PinLockoutPolicy(),
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return PinAuthService(store: SharedPreferencesPinStore(prefs), policy: policy);
    }
    return PinAuthService(store: SecureStoragePinStore(const FlutterSecureStorage()), policy: policy);
  }

  Future<bool> hasPin() async {
    final stored = await _store.read(pinHashKey);
    return stored != null && stored.trim().isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final hash = derivePinHashV1(pin, iterations: _policy.iterations);
    await _store.write(pinHashKey, hash.encode());
    await _store.delete(failedAttemptsKey);
    await _store.delete(lockoutUntilMsKey);
    await _store.delete(lockoutStageKey);
  }

  Future<void> clearPin() async {
    await _store.delete(pinHashKey);
    await _store.delete(failedAttemptsKey);
    await _store.delete(lockoutUntilMsKey);
    await _store.delete(lockoutStageKey);
  }

  Future<int> getLockoutRemainingSeconds() async {
    final lockoutStr = await _store.read(lockoutUntilMsKey);
    if (lockoutStr == null) return 0;
    final untilMs = int.tryParse(lockoutStr);
    if (untilMs == null) return 0;

    final remainingMs = untilMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) {
      await _store.delete(lockoutUntilMsKey);
      await _store.delete(failedAttemptsKey);
      return 0;
    }
    return (remainingMs / 1000).ceil();
  }

  Future<PinVerifyResult> verifyPin(String pin) async {
    final remainingLockoutSeconds = await getLockoutRemainingSeconds();
    final stored = await _store.read(pinHashKey);

    final base = verifyPinAgainstStoredHash(
      pin,
      stored,
      remainingLockoutSeconds: remainingLockoutSeconds,
    );

    if (base.outcome == PinVerifyOutcome.lockedOut) {
      return PinVerifyResult(
        PinVerifyOutcome.lockedOut,
        remainingLockoutSeconds: base.remainingLockoutSeconds,
        remainingAttempts: 0,
        maxAttempts: _policy.maxAttempts,
      );
    }

    if (base.isSuccess) {
      await _store.delete(failedAttemptsKey);
      await _store.delete(lockoutUntilMsKey);
      await _store.delete(lockoutStageKey);
      if (base.needsMigration) {
        await setPin(pin);
      }
      return PinVerifyResult(
        PinVerifyOutcome.success,
        remainingAttempts: _policy.maxAttempts,
        maxAttempts: _policy.maxAttempts,
      );
    }

    if (base.outcome != PinVerifyOutcome.incorrect) {
      return PinVerifyResult(
        base.outcome,
        remainingLockoutSeconds: base.remainingLockoutSeconds,
        remainingAttempts: 0,
        maxAttempts: _policy.maxAttempts,
        needsMigration: base.needsMigration,
      );
    }

    // Incorrect PIN: increment failed attempts.
    final failedStr = await _store.read(failedAttemptsKey);
    var failed = int.tryParse(failedStr ?? '0') ?? 0;
    failed += 1;

    final remainingAttempts = (_policy.maxAttempts - failed).clamp(0, _policy.maxAttempts);
    if (failed < _policy.maxAttempts) {
      await _store.write(failedAttemptsKey, failed.toString());
      return PinVerifyResult(
        PinVerifyOutcome.incorrect,
        remainingAttempts: remainingAttempts,
        maxAttempts: _policy.maxAttempts,
      );
    }

    // Lockout: escalate stage.
    final stageStr = await _store.read(lockoutStageKey);
    final currentStage = int.tryParse(stageStr ?? '0') ?? 0;
    final nextStage = (currentStage + 1).clamp(1, 1000000);
    final duration = _policy.lockoutForStage(nextStage - 1);

    final lockoutUntilMs = DateTime.now().add(duration).millisecondsSinceEpoch;
    await _store.write(lockoutUntilMsKey, lockoutUntilMs.toString());
    await _store.write(lockoutStageKey, nextStage.toString());
    await _store.delete(failedAttemptsKey);

    final remaining = await getLockoutRemainingSeconds();
    return PinVerifyResult(
      PinVerifyOutcome.lockedOut,
      remainingLockoutSeconds: remaining,
      remainingAttempts: 0,
      maxAttempts: _policy.maxAttempts,
    );
  }
}

