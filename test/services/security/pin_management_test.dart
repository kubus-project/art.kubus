import 'package:art_kubus/services/security/pin_management.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage implements PinStoragePort {
  String? pin;
  bool failWrite = false;
  bool failDelete = false;
  bool deleteSilentlyKeepsPin = false;
  bool writeSilentlyDropsPin = false;
  int writes = 0;

  @override
  Future<bool> hasPin() async => pin != null;

  @override
  Future<void> setPin(String value) async {
    writes++;
    if (failWrite) throw StateError('secure storage write failed');
    if (!writeSilentlyDropsPin) pin = value;
  }

  @override
  Future<void> clearPin() async {
    if (failDelete) throw StateError('secure storage delete failed');
    if (!deleteSilentlyKeepsPin) pin = null;
  }
}

class _Gate implements PinGatePort {
  bool authenticates = true;
  int verifications = 0;
  int reloads = 0;

  @override
  Future<bool> requireSensitiveActionVerification() async {
    verifications++;
    return authenticates;
  }

  @override
  Future<void> reloadSettings() async => reloads++;
}

class _Settings extends PinSettingsStore {
  _Settings(this.state);
  SettingsState state;
  int saves = 0;

  @override
  Future<SettingsState> load() async => state;

  @override
  Future<void> save(SettingsState value) async {
    saves++;
    state = value;
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
    test('stores it, turns the requirement on and needs no authentication',
        () async {
      final r = _rig();
      final result = await r.management.setOrReplacePin('4821', '4821');
      expect(result.isSuccess, isTrue);
      expect(r.storage.pin, '4821');
      expect(r.gate.verifications, 0);
      expect(r.settings.state.requirePin, isTrue);
      expect(r.gate.reloads, 1);
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
}
