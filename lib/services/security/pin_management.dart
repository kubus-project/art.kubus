/// The single path for creating, replacing and removing the local PIN.
///
/// Settings (mobile and desktop) and the Security Hub all call this, so a PIN
/// behaves identically wherever it is managed:
///
///  * A new PIN is 4 to 12 ASCII digits and must be confirmed. This bounds only
///    PINs that are *set*; an existing credential is verified against its stored
///    hash exactly as before, so no legitimate PIN is invalidated.
///  * Replacing or removing an existing PIN first requires the current local
///    authentication (the PIN or an enabled biometric) through the security
///    gate. A cancelled or failed verification changes nothing.
///  * Storage is read back after every write. If the PIN could not be written or
///    deleted the outcome is [PinManagementOutcome.storageFailed] and the
///    persisted `requirePin` setting is left as it was, so the UI never reports
///    a state that is not on disk.
///  * "Could not read the PIN store" is a failure, never "no PIN": an unreadable
///    store cannot be used to skip the authentication step.
///  * Nothing here throws to the caller and nothing logs a PIN.
library;

import 'package:flutter/foundation.dart';

import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../settings_service.dart';

/// Why a candidate PIN was refused.
enum PinFormatIssue { tooShort, tooLong, notDigits, mismatch }

class PinPolicy {
  const PinPolicy._();

  static const int minLength = 4;
  static const int maxLength = 12;

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  /// Null when [pin] (confirmed by [confirm]) may be set.
  static PinFormatIssue? validate(String pin, String confirm) {
    if (pin.length < minLength) return PinFormatIssue.tooShort;
    if (pin.length > maxLength) return PinFormatIssue.tooLong;
    if (!_digits.hasMatch(pin)) return PinFormatIssue.notDigits;
    if (pin != confirm) return PinFormatIssue.mismatch;
    return null;
  }
}

enum PinManagementOutcome {
  /// The change was made and read back.
  success,

  /// The candidate PIN was refused; see [PinManagementResult.issue].
  invalid,

  /// Current authentication was cancelled or failed; nothing changed.
  authenticationFailed,

  /// The secure store did not accept the change; nothing is reported changed.
  storageFailed,
}

class PinManagementResult {
  const PinManagementResult(this.outcome,
      {this.issue, this.cleanupFailed = false});

  final PinManagementOutcome outcome;
  final PinFormatIssue? issue;

  /// The change is in effect, but resetting the old attempt counters failed.
  final bool cleanupFailed;

  bool get isSuccess => outcome == PinManagementOutcome.success;
}

/// Reads and writes the persisted settings. Injectable for tests.
class PinSettingsStore {
  const PinSettingsStore();

  Future<SettingsState> load() => SettingsService.loadSettings();
  Future<void> save(SettingsState state) => SettingsService.saveSettings(state);
}

/// What [PinManagement] needs from the wallet's PIN storage.
abstract interface class PinStoragePort {
  /// Whether a PIN is stored. Throws when the store cannot be read.
  Future<bool> hasPin();
  Future<void> setPin(String pin);
  Future<void> clearPin();

  /// Whether the stored hash is the one for [pin]. Read-only; throws when the
  /// store cannot be read.
  Future<bool> matchesPin(String pin);
}

/// What [PinManagement] needs from the security gate.
abstract interface class PinGatePort {
  /// True when the user passed current local authentication (or none is set up).
  Future<bool> requireSensitiveActionVerification();
  Future<void> reloadSettings();
}

class _WalletPinStorage implements PinStoragePort {
  _WalletPinStorage(this._wallet);
  final WalletProvider _wallet;

  @override
  Future<bool> hasPin() => _wallet.hasPinOrThrow();
  @override
  Future<void> setPin(String pin) => _wallet.setPin(pin);
  @override
  Future<void> clearPin() => _wallet.clearPin();
  @override
  Future<bool> matchesPin(String pin) => _wallet.matchesStoredPin(pin);
}

class _GateAdapter implements PinGatePort {
  _GateAdapter(this._gate);
  final SecurityGateProvider _gate;

  @override
  Future<bool> requireSensitiveActionVerification() =>
      _gate.requireSensitiveActionVerification();
  @override
  Future<void> reloadSettings() => _gate.reloadSettings();
}

const _storageFailed = PinManagementResult(PinManagementOutcome.storageFailed);
const _authFailed =
    PinManagementResult(PinManagementOutcome.authenticationFailed);
const _done = PinManagementResult(PinManagementOutcome.success);

class PinManagement {
  PinManagement({
    required WalletProvider wallet,
    required SecurityGateProvider gate,
    PinSettingsStore settings = const PinSettingsStore(),
  })  : _storage = _WalletPinStorage(wallet),
        _gate = _GateAdapter(gate),
        _settings = settings;

  @visibleForTesting
  PinManagement.withPorts({
    required PinStoragePort storage,
    required PinGatePort gate,
    PinSettingsStore settings = const PinSettingsStore(),
  })  : _storage = storage,
        _gate = gate,
        _settings = settings;

  final PinStoragePort _storage;
  final PinGatePort _gate;
  final PinSettingsStore _settings;

  /// Tail of the queue that serializes every public mutating operation, so a
  /// first-PIN rollback can never interleave with another change.
  Future<void> _queue = Future<void>.value();

  Future<PinManagementResult> _serialized(
      Future<PinManagementResult> Function() operation) {
    final run = _queue.then((_) => operation());
    _queue = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  /// Stores the PIN requirement and reads it back, so a setting that did not
  /// persist is reported rather than assumed.
  Future<bool> _persistRequirePin(bool value,
      {bool clearBiometrics = false}) async {
    final current = await _settings.load();
    final needsChange = current.requirePin != value ||
        (clearBiometrics && current.biometricAuth);
    if (!needsChange) return true;
    await _settings.save(current.copyWith(
      requirePin: value,
      biometricAuth: clearBiometrics ? false : null,
      useBiometricsOnUnlock: clearBiometrics ? true : null,
    ));
    final stored = await _settings.load();
    return stored.requirePin == value &&
        (!clearBiometrics || !stored.biometricAuth);
  }

  /// The gate's local verification; a gate that throws counts as a refusal so
  /// nothing here ever throws.
  Future<bool> _verified() async {
    try {
      return await _gate.requireSensitiveActionVerification();
    } catch (_) {
      return false;
    }
  }

  Future<void> _reloadGate() async {
    try {
      await _gate.reloadSettings();
    } catch (_) {
      // The gate only refreshes its in-memory copy; the stored state is right.
    }
  }

  /// Sets the first PIN or replaces the existing one.
  Future<PinManagementResult> setOrReplacePin(String pin, String confirm) =>
      _serialized(() => _setOrReplace(pin, confirm));

  /// Removes the PIN, the PIN requirement and biometric app unlock, as the
  /// settings dialogs always did: biometrics fall back to the PIN, so the two
  /// are switched off together.
  Future<PinManagementResult> removePin() => _serialized(_remove);

  Future<PinManagementResult> _setOrReplace(String pin, String confirm) async {
    final issue = PinPolicy.validate(pin, confirm);
    if (issue != null) {
      return PinManagementResult(PinManagementOutcome.invalid, issue: issue);
    }

    final bool replacing;
    try {
      replacing = await _storage.hasPin();
    } catch (_) {
      return _storageFailed;
    }
    // Always asked, including for a first PIN: with biometrics as the only
    // factor, an unlocked session could otherwise add a PIN of its own choosing
    // and then unlock sensitive actions with it. The gate returns at once when
    // the device has no local factor at all, so a plain first PIN stays free.
    if (!await _verified()) return _authFailed;

    // A first PIN is kept only together with its requirement. A PIN left
    // stored after a failed step would make the retry a replacement, which
    // never turns the requirement on, so app lock would stay off for good.
    Future<PinManagementResult> failed() async {
      if (!replacing) {
        try {
          await _storage.clearPin();
        } catch (_) {
          // Nothing more to undo; the failure is still reported.
        }
      }
      return _storageFailed;
    }

    try {
      await _storage.setPin(pin);
    } catch (_) {
      if (!replacing) return failed();
      // The new hash may be in place even though the call threw (a later
      // counter reset failed). Only the new hash counts as the change.
      try {
        if (await _storage.matchesPin(pin)) {
          await _reloadGate();
          return const PinManagementResult(PinManagementOutcome.success,
              cleanupFailed: true);
        }
      } catch (_) {
        return _storageFailed;
      }
      return _storageFailed;
    }
    // Read back the exact new PIN, not merely that some hash exists.
    try {
      if (!await _storage.matchesPin(pin)) return failed();
    } catch (_) {
      return failed();
    }

    // A first PIN turns the PIN requirement on; replacing one leaves the user's
    // existing requirement choice alone.
    if (!replacing) {
      try {
        if (!await _persistRequirePin(true)) return failed();
      } catch (_) {
        return failed();
      }
    }
    await _reloadGate();
    return _done;
  }

  Future<PinManagementResult> _remove() async {
    final bool present;
    try {
      present = await _storage.hasPin();
    } catch (_) {
      return _storageFailed;
    }
    if (present && !await _verified()) return _authFailed;

    if (present) {
      try {
        await _storage.clearPin();
      } catch (_) {
        // The hash is deleted first, so a later key may have failed while the
        // PIN itself is already gone; the read-back below decides.
      }
      try {
        if (await _storage.hasPin()) return _storageFailed;
      } catch (_) {
        return _storageFailed;
      }
    }

    try {
      // Also repairs a stale requirement left behind with no PIN to back it.
      if (!await _persistRequirePin(false, clearBiometrics: present)) {
        return _storageFailed;
      }
    } catch (_) {
      return _storageFailed;
    }
    await _reloadGate();
    return _done;
  }
}
