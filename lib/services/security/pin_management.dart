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
///  * Nothing here logs a PIN.
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
  const PinManagementResult(this.outcome, {this.issue});

  final PinManagementOutcome outcome;
  final PinFormatIssue? issue;

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
  Future<bool> hasPin();
  Future<void> setPin(String pin);
  Future<void> clearPin();
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
  Future<bool> hasPin() => _wallet.hasPin();
  @override
  Future<void> setPin(String pin) => _wallet.setPin(pin);
  @override
  Future<void> clearPin() => _wallet.clearPin();
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

  /// Sets the first PIN or replaces the existing one.
  Future<PinManagementResult> setOrReplacePin(
      String pin, String confirm) async {
    final issue = PinPolicy.validate(pin, confirm);
    if (issue != null) {
      return PinManagementResult(PinManagementOutcome.invalid, issue: issue);
    }

    final replacing = await _storage.hasPin();
    if (replacing && !await _gate.requireSensitiveActionVerification()) {
      return const PinManagementResult(
          PinManagementOutcome.authenticationFailed);
    }

    try {
      await _storage.setPin(pin);
    } catch (_) {
      return const PinManagementResult(PinManagementOutcome.storageFailed);
    }
    if (!await _storage.hasPin()) {
      return const PinManagementResult(PinManagementOutcome.storageFailed);
    }

    // A first PIN turns the PIN requirement on; replacing one leaves the user's
    // existing requirement choice alone.
    if (!replacing) {
      final current = await _settings.load();
      if (!current.requirePin) {
        await _settings.save(current.copyWith(requirePin: true));
      }
    }
    await _gate.reloadSettings();
    return const PinManagementResult(PinManagementOutcome.success);
  }

  /// Removes the PIN, the PIN requirement and biometric app unlock, as the
  /// settings dialogs always did: biometrics fall back to the PIN, so the two
  /// are switched off together.
  Future<PinManagementResult> removePin() async {
    if (!await _storage.hasPin()) {
      return const PinManagementResult(PinManagementOutcome.success);
    }
    if (!await _gate.requireSensitiveActionVerification()) {
      return const PinManagementResult(
          PinManagementOutcome.authenticationFailed);
    }

    try {
      await _storage.clearPin();
    } catch (_) {
      return const PinManagementResult(PinManagementOutcome.storageFailed);
    }
    if (await _storage.hasPin()) {
      return const PinManagementResult(PinManagementOutcome.storageFailed);
    }

    final current = await _settings.load();
    await _settings.save(current.copyWith(
      requirePin: false,
      biometricAuth: false,
      useBiometricsOnUnlock: true,
    ));
    await _gate.reloadSettings();
    return const PinManagementResult(PinManagementOutcome.success);
  }
}
