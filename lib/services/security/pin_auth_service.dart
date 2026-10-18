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
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

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
    DateTime Function()? clock,
  })  : _store = store,
        _policy = policy,
        _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  final PinKeyValueStore _store;
  final PinLockoutPolicy _policy;

  static const String pinHashKey = 'app_pin_hash';
  static const String failedAttemptsKey = 'app_pin_failed_attempts';
  static const String lockoutUntilMsKey = 'app_pin_lockout_until_ms';
  static const String lockoutStageKey = 'app_pin_lockout_stage';
  static const String lockoutWrittenMsKey = 'app_pin_lockout_written_ms';

  static Future<PinAuthService> createDefault({
    PinLockoutPolicy policy = const PinLockoutPolicy(),
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return PinAuthService(
          store: SharedPreferencesPinStore(prefs), policy: policy);
    }
    return PinAuthService(
        store: SecureStoragePinStore(const FlutterSecureStorage()),
        policy: policy);
  }

  Future<bool> hasPin() async {
    final stored = await _store.read(pinHashKey);
    return stored != null && stored.trim().isNotEmpty;
  }

  Future<void> setPin(String pin) => _exclusive(() => _setPin(pin));

  Future<void> _setPin(String pin) async {
    final hash = derivePinHashV1(pin, iterations: _policy.iterations);
    await _store.write(pinHashKey, hash.encode());
    await _clearCounters();
  }

  Future<void> clearPin() => _exclusive(() async {
        await _store.delete(pinHashKey);
        await _clearCounters();
      });

  Future<void> _clearCounters() async {
    await _store.delete(failedAttemptsKey);
    await _store.delete(lockoutUntilMsKey);
    await _store.delete(lockoutWrittenMsKey);
    await _store.delete(lockoutStageKey);
  }

  /// Whether [pin] matches the stored hash. Read-only: it never counts as an
  /// attempt and ignores a running lockout, so it can confirm that a change
  /// the app made itself actually landed.
  Future<bool> matchesStoredPin(String pin) async {
    final stored = await _store.read(pinHashKey);
    return verifyPinAgainstStoredHash(pin, stored).isSuccess;
  }

  /// Verifications, lockout bookkeeping and PIN writes run one at a time, so
  /// parallel calls cannot share a stale attempt counter. The chain is shared
  /// by every instance because they all front the same storage.
  static Future<void> _tail = Future<void>.value();

  static Future<T> _exclusive<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }

  Future<int> getLockoutRemainingSeconds() => _exclusive(_lockoutRemaining);

  Future<int> _lockoutRemaining() async {
    final lockoutStr = await _store.read(lockoutUntilMsKey);
    if (lockoutStr == null) return 0;
    final nowMs = _clock().millisecondsSinceEpoch;
    final untilMs = int.tryParse(lockoutStr);
    if (untilMs == null) {
      // A lockout that cannot be read is still a lockout: fail closed with a
      // fresh one at the current stage instead of treating it as "none".
      final stage = int.tryParse(await _store.read(lockoutStageKey) ?? '') ?? 1;
      final duration = _policy.lockoutForStage((stage - 1).clamp(0, 1000000));
      await _writeLockout(nowMs, nowMs + duration.inMilliseconds);
      return duration.inSeconds;
    }

    var remainingMs = untilMs - nowMs;
    final writtenMs =
        int.tryParse(await _store.read(lockoutWrittenMsKey) ?? '');
    if (writtenMs != null && nowMs < writtenMs) {
      // The clock is earlier than when the lockout was recorded: it was set
      // back. That never shortens the lockout.
      final full = untilMs - writtenMs;
      if (full > remainingMs) remainingMs = full;
    }
    if (remainingMs <= 0) {
      // Expiry ends the wait, not the escalation: the failed-attempt count and
      // the stage stay, so the next wrong guess locks at the next stage.
      await _store.delete(lockoutUntilMsKey);
      await _store.delete(lockoutWrittenMsKey);
      return 0;
    }
    return (remainingMs / 1000).ceil();
  }

  Future<void> _writeLockout(int writtenMs, int untilMs) async {
    await _store.write(lockoutWrittenMsKey, writtenMs.toString());
    await _store.write(lockoutUntilMsKey, untilMs.toString());
  }

  Future<PinVerifyResult> verifyPin(String pin) =>
      _exclusive(() => _verifyPin(pin));

  Future<PinVerifyResult> _verifyPin(String pin) async {
    final remainingLockoutSeconds = await _lockoutRemaining();
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
      await _clearCounters();
      if (base.needsMigration) {
        await _setPin(pin);
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

    final remainingAttempts =
        (_policy.maxAttempts - failed).clamp(0, _policy.maxAttempts);
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

    final nowMs = _clock().millisecondsSinceEpoch;
    // One guess short of the limit stays on record, so once this lockout runs
    // out the very next wrong guess locks again at the escalated stage.
    await _store.write(failedAttemptsKey, (_policy.maxAttempts - 1).toString());
    await _store.write(lockoutStageKey, nextStage.toString());
    await _writeLockout(nowMs, nowMs + duration.inMilliseconds);

    final remaining = await _lockoutRemaining();
    return PinVerifyResult(
      PinVerifyOutcome.lockedOut,
      remainingLockoutSeconds: remaining,
      remainingAttempts: 0,
      maxAttempts: _policy.maxAttempts,
    );
  }
}
