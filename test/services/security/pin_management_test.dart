import 'package:art_kubus/services/security/pin_management.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage implements PinStoragePort {
  String? pin;
  bool failWrite = false;
  bool failDelete = false;
  bool deleteSilentlyKeepsPin = false;
  bool writeSilentlyDropsPin = false;
  bool failRead = false;
  bool deleteThenThrow = false;
  bool writeThenThrow = false;
  int writes = 0;

  @override
  Future<bool> hasPin() async {
    if (failRead) throw StateError('secure storage read failed');
    return pin != null;
  }

  @override
  Future<void> setPin(String value) async {
    writes++;
    if (failWrite) throw StateError('secure storage write failed');
    if (!writeSilentlyDropsPin) pin = value;
    if (writeThenThrow) throw StateError('lockout key reset failed');
  }

  @override
  Future<void> clearPin() async {
    if (failDelete) throw StateError('secure storage delete failed');
    if (!deleteSilentlyKeepsPin) pin = null;
    if (deleteThenThrow) throw StateError('lockout key delete failed');
  }
}

class _Gate implements PinGatePort {
  bool authenticates = true;
  int verifications = 0;
  int reloads = 0;
  bool reloadThrows = false;
  bool throws = false;

  @override
  Future<bool> requireSensitiveActionVerification() async {
    verifications++;
    if (throws) throw StateError('gate failed');
    return authenticates;
  }

  @override
  Future<void> reloadSettings() async {
    reloads++;
    if (reloadThrows) throw StateError('gate reload failed');
  }
}

class _Settings extends PinSettingsStore {
  _Settings(this.state);
  SettingsState state;
  int saves = 0;
  bool dropWrites = false;
  bool saveThrows = false;
  bool loadThrows = false;

  @override
  Future<SettingsState> load() async {
    if (loadThrows) throw StateError('settings unreadable');
    return state;
  }

  @override
  Future<void> save(SettingsState value) async {
    saves++;
    if (saveThrows) throw StateError('settings write failed');
    if (!dropWrites) state = value;
  }
}

({PinManagement management, _Storage storage, _Gate gate, _Settings settings})
    _rig(
        {String? existingPin,
        bool requirePin = false,
        bool biometric = false}) {
  final storage = _Storage()..pin = existingPin;
  final gate = _Gate();
  final settings = _Settings(SettingsState.defaults().copyWith(
    requirePin: requirePin,
    biometricAuth: biometric,
    useBiometricsOnUnlock: false,
  ));
  return (
    management: PinManagement.withPorts(
      storage: storage,
      gate: gate,
      settings: settings,
    ),
    storage: storage,
    gate: gate,
    settings: settings,
  );
}

void main() {
  group('PinPolicy', () {
    test('accepts 4 to 12 confirmed digits', () {
      expect(PinPolicy.validate('1234', '1234'), isNull);
      expect(PinPolicy.validate('123456789012', '123456789012'), isNull);
    });

    test('refuses short, long, non-numeric and unconfirmed PINs', () {
      expect(PinPolicy.validate('123', '123'), PinFormatIssue.tooShort);
      expect(PinPolicy.validate('', ''), PinFormatIssue.tooShort);
      expect(PinPolicy.validate('1234567890123', '1234567890123'),
          PinFormatIssue.tooLong);
      expect(PinPolicy.validate('12a4', '12a4'), PinFormatIssue.notDigits);
      expect(PinPolicy.validate('12 4', '12 4'), PinFormatIssue.notDigits);
      expect(PinPolicy.validate('1234', '1235'), PinFormatIssue.mismatch);
    });
  });

  group('setting a first PIN', () {
    test(
        'stores it and turns the requirement on; the gate passes at once '
        'when no factor exists', () async {
      final r = _rig();
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.isSuccess, isTrue);
      expect(r.storage.pin, '4821');
      expect(r.gate.verifications, 1);
      expect(r.settings.state.requirePin, isTrue);
      expect(r.gate.reloads, 1);
    });

    test('a first PIN is refused when another factor does not verify',
        () async {
      // Biometrics are the only factor: an unlocked session must not be able to
      // add a PIN of its own and unlock sensitive actions with it.
      final r = _rig(biometric: true)..gate.authenticates = false;
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.outcome, PinManagementOutcome.authenticationFailed);
      expect(r.storage.pin, isNull);
      expect(r.storage.writes, 0);
      expect(r.settings.saves, 0);
    });

    test('a gate that throws refuses the change instead of escaping', () async {
      final r = _rig(existingPin: '1111');
      r.gate.throws = true;
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.outcome, PinManagementOutcome.authenticationFailed);
      expect(r.storage.pin, '1111');
      final removed = await r.management.removePin();
      expect(removed.outcome, PinManagementOutcome.authenticationFailed);
      expect(r.storage.pin, '1111');
    });

    test('an invalid PIN writes nothing and does not ask for authentication',
        () async {
      final r = _rig();
      final result = await r.management.setOrReplacePin('12', '12');
      expect(result.outcome, PinManagementOutcome.invalid);
      expect(result.issue, PinFormatIssue.tooShort);
      expect(r.storage.writes, 0);
      expect(r.gate.verifications, 0);
      expect(r.settings.saves, 0);
    });

    test('a write the store rejects is reported and leaves settings alone',
        () async {
      final r = _rig()..storage.failWrite = true;
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.settings.saves, 0);
      expect(r.settings.state.requirePin, isFalse);
    });

    test('a write that does not read back is a failure, not a success',
        () async {
      final r = _rig()..storage.writeSilentlyDropsPin = true;
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.settings.state.requirePin, isFalse);
    });
  });

  group('replacing an existing PIN', () {
    test('requires current authentication first', () async {
      final r = _rig(existingPin: '1111', requirePin: true);
      final result = await r.management.setOrReplacePin('2222', '2222');
      expect(result.isSuccess, isTrue);
      expect(r.gate.verifications, 1);
      expect(r.storage.pin, '2222');
    });

    test('a cancelled or failed authentication changes nothing', () async {
      final r = _rig(existingPin: '1111', requirePin: true);
      r.gate.authenticates = false;
      final result = await r.management.setOrReplacePin('2222', '2222');
      expect(result.outcome, PinManagementOutcome.authenticationFailed);
      expect(r.storage.pin, '1111');
      expect(r.storage.writes, 0);
      expect(r.settings.saves, 0);
    });

    test('keeps the user\'s requirement choice', () async {
      final r = _rig(existingPin: '1111', requirePin: false);
      await r.management.setOrReplacePin('2222', '2222');
      expect(r.settings.state.requirePin, isFalse);
      expect(r.settings.saves, 0);
    });

    test('an invalid replacement is refused before authentication', () async {
      final r = _rig(existingPin: '1111');
      final result = await r.management.setOrReplacePin('2222', '3333');
      expect(result.issue, PinFormatIssue.mismatch);
      expect(r.gate.verifications, 0);
      expect(r.storage.pin, '1111');
    });
  });

  group('removing the PIN', () {
    test('requires current authentication, then clears PIN and biometrics',
        () async {
      final r = _rig(existingPin: '1111', requirePin: true, biometric: true);
      final result = await r.management.removePin();
      expect(result.isSuccess, isTrue);
      expect(r.gate.verifications, 1);
      expect(r.storage.pin, isNull);
      expect(r.settings.state.requirePin, isFalse);
      expect(r.settings.state.biometricAuth, isFalse);
      expect(r.settings.state.useBiometricsOnUnlock, isTrue);
      expect(r.gate.reloads, 1);
    });

    test('a cancelled authentication keeps the PIN and the settings', () async {
      final r = _rig(existingPin: '1111', requirePin: true, biometric: true);
      r.gate.authenticates = false;
      final result = await r.management.removePin();
      expect(result.outcome, PinManagementOutcome.authenticationFailed);
      expect(r.storage.pin, '1111');
      expect(r.settings.state.requirePin, isTrue);
      expect(r.settings.state.biometricAuth, isTrue);
      expect(r.settings.saves, 0);
    });

    test('a delete the store rejects never reports the PIN as cleared',
        () async {
      final r = _rig(existingPin: '1111', requirePin: true)
        ..storage.failDelete = true;
      final result = await r.management.removePin();
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.storage.pin, '1111');
      expect(r.settings.state.requirePin, isTrue,
          reason: 'the persisted requirement must still match the stored PIN');
      expect(r.settings.saves, 0);
    });

    test('a delete that leaves the PIN behind is a failure', () async {
      final r = _rig(existingPin: '1111', requirePin: true)
        ..storage.deleteSilentlyKeepsPin = true;
      final result = await r.management.removePin();
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.settings.state.requirePin, isTrue);
    });

    test('with no PIN there is nothing to authenticate or change', () async {
      final r = _rig();
      final result = await r.management.removePin();
      expect(result.isSuccess, isTrue);
      expect(r.gate.verifications, 0);
      expect(r.settings.saves, 0);
    });
  });

  group('an unreadable store is a failure, never "no PIN"', () {
    test('replacing does not skip authentication and writes nothing', () async {
      final r = _rig(existingPin: '1111', requirePin: true)
        ..storage.failRead = true;
      final result = await r.management.setOrReplacePin('2222', '2222');
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.storage.writes, 0);
      expect(r.storage.pin, '1111');
      expect(r.settings.saves, 0);
    });

    test('removing does not report a PIN cleared that is still stored',
        () async {
      final r = _rig(existingPin: '1111', requirePin: true)
        ..storage.failRead = true;
      final result = await r.management.removePin();
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.storage.pin, '1111');
      expect(r.settings.state.requirePin, isTrue);
    });

    test('a read-back that fails after the write is a failure', () async {
      final r = _rig();
      final storage = r.storage;
      // Readable before the write, unreadable after it.
      final management = PinManagement.withPorts(
        storage: _ReadFailsAfterWrite(storage),
        gate: r.gate,
        settings: r.settings,
      );
      final result = await management.setOrReplacePin('4821', '4821');
      expect(result.outcome, PinManagementOutcome.storageFailed);
    });
  });

  group('partial and persisted-state failures', () {
    test('a leftover lockout key failing after the hash is gone is a success',
        () async {
      final r = _rig(existingPin: '1111', requirePin: true)
        ..storage.deleteThenThrow = true;
      final result = await r.management.removePin();
      expect(result.isSuccess, isTrue);
      expect(r.storage.pin, isNull);
      expect(r.settings.state.requirePin, isFalse);
    });

    test('removing with no PIN repairs a stale requirement without asking',
        () async {
      final r = _rig(requirePin: true);
      final result = await r.management.removePin();
      expect(result.isSuccess, isTrue);
      expect(r.gate.verifications, 0);
      expect(r.settings.state.requirePin, isFalse);
    });

    test('a requirement that does not persist is reported', () async {
      final r = _rig()..settings.dropWrites = true;
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.storage.pin, isNull,
          reason: 'a first PIN without its requirement is rolled back');
    });

    test('a first PIN whose write fails after storing the hash is rolled back',
        () async {
      final r = _rig()..storage.writeThenThrow = true;
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.storage.pin, isNull);
      expect(r.settings.state.requirePin, isFalse);

      // The retry is a first PIN again, so it turns the requirement on.
      r.storage.writeThenThrow = false;
      final retry = await r.management.setOrReplacePin('4821', '4821');
      expect(retry.isSuccess, isTrue);
      expect(r.storage.pin, '4821');
      expect(r.settings.state.requirePin, isTrue);
    });

    test('a failed replacement keeps the existing PIN', () async {
      final r = _rig(existingPin: '1111', requirePin: true)
        ..storage.failWrite = true;
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.outcome, PinManagementOutcome.storageFailed);
      expect(r.storage.pin, '1111');
      expect(r.settings.state.requirePin, isTrue);
    });

    test('settings errors never escape as exceptions', () async {
      final first = _rig()..settings.saveThrows = true;
      expect((await first.management.setOrReplacePin('4821', '4821')).outcome,
          PinManagementOutcome.storageFailed);
      final second = _rig(existingPin: '1111', requirePin: true)
        ..settings.loadThrows = true;
      expect((await second.management.removePin()).outcome,
          PinManagementOutcome.storageFailed);
    });

    test('a failing gate reload does not undo or hide a completed change',
        () async {
      final r = _rig(existingPin: '1111', requirePin: true)
        ..gate.reloadThrows = true;
      final result = await r.management.removePin();
      expect(result.isSuccess, isTrue);
      expect(r.storage.pin, isNull);
    });
  });
}

/// Readable until the first write, then every read throws.
class _ReadFailsAfterWrite implements PinStoragePort {
  _ReadFailsAfterWrite(this._inner);
  final _Storage _inner;
  bool _written = false;

  @override
  Future<bool> hasPin() async {
    if (_written) throw StateError('read failed after write');
    return _inner.hasPin();
  }

  @override
  Future<void> setPin(String pin) async {
    await _inner.setPin(pin);
    _written = true;
  }

  @override
  Future<void> clearPin() => _inner.clearPin();
}
