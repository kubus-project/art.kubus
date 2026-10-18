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
    Duration operationTimeout = defaultOperationTimeout,
  })  : _store = store,
        _policy = policy,
        _clock = clock ?? DateTime.now,
        _operationTimeout = operationTimeout;

  /// Upper bound for one queued storage action. A hung secure-storage call
  /// fails that action with a [TimeoutException] (callers treat it as an error,
  /// never as "PIN correct" or "no PIN") instead of blocking every later one.
  static const Duration defaultOperationTimeout = Duration(seconds: 10);

  final DateTime Function() _clock;

  final PinKeyValueStore _store;
  final PinLockoutPolicy _policy;
  final Duration _operationTimeout;

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

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous
        .then((_) => action().timeout(_operationTimeout))
        .whenComplete(done.complete);
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
    if (remainingLockoutSeconds > 0) {
      return PinVerifyResult(
        PinVerifyOutcome.lockedOut,
        remainingLockoutSeconds: remainingLockoutSeconds,
        remainingAttempts: 0,
        maxAttempts: _policy.maxAttempts,
      );
    }

    final stored = await _store.read(pinHashKey);

    // A guess against a recognised hash is counted BEFORE the hash is
    // compared, so the count (and any lockout it triggers) never depends on a
    // write that happens after the compare. A match clears it again below.
    final raw = (stored ?? '').trim();
    final _FailedAttemptPlan? plan = raw.isNotEmpty && _isRecognizedHash(raw)
        ? await _recordFailedAttempt()
        : null;

    final base = verifyPinAgainstStoredHash(pin, stored);

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

    if (base.outcome != PinVerifyOutcome.incorrect || plan == null) {
      return PinVerifyResult(
        base.outcome,
        remainingLockoutSeconds: base.remainingLockoutSeconds,
        remainingAttempts: 0,
        maxAttempts: _policy.maxAttempts,
        needsMigration: base.needsMigration,
      );
    }

    if (!plan.lockout) {
      return PinVerifyResult(
        PinVerifyOutcome.incorrect,
        remainingAttempts: plan.remainingAttempts,
        maxAttempts: _policy.maxAttempts,
      );
    }

    final remaining = await _lockoutRemaining();
    return PinVerifyResult(
      PinVerifyOutcome.lockedOut,
      remainingLockoutSeconds: remaining,
      remainingAttempts: 0,
      maxAttempts: _policy.maxAttempts,
    );
  }

  static final RegExp _legacyHashPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Hash formats [verifyPinAgainstStoredHash] can compare. Anything else is
  /// an error, not a wrong guess, so it is never counted.
  static bool _isRecognizedHash(String raw) =>
      PinHashV1.tryParse(raw) != null || _legacyHashPattern.hasMatch(raw);

  /// Persists one failed attempt. Writes the count, and at the limit the
  /// escalated stage and lockout, exactly as a wrong guess always did.
  Future<_FailedAttemptPlan> _recordFailedAttempt() async {
    final failedStr = await _store.read(failedAttemptsKey);
    var failed = int.tryParse(failedStr ?? '0') ?? 0;
    failed += 1;

    if (failed < _policy.maxAttempts) {
      await _store.write(failedAttemptsKey, failed.toString());
      final remainingAttempts =
          (_policy.maxAttempts - failed).clamp(0, _policy.maxAttempts).toInt();
      return _FailedAttemptPlan(
        lockout: false,
        remainingAttempts: remainingAttempts,
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
    return const _FailedAttemptPlan(lockout: true, remainingAttempts: 0);
  }
}

/// Outcome of counting one guess before its hash is compared.
class _FailedAttemptPlan {
  const _FailedAttemptPlan({
    required this.lockout,
    required this.remainingAttempts,
  });

  final bool lockout;
  final int remainingAttempts;
}
