import 'package:art_kubus/services/security/pin_management.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PinStorage implements PinStoragePort {
  String? pin;

  @override
  Future<bool> hasPin() async => pin != null;
  @override
  Future<void> setPin(String value) async => pin = value;
  @override
  Future<void> clearPin() async => pin = null;
  @override
  Future<bool> matchesPin(String value) async => pin == value;
}

class _AllowGate implements PinGatePort {
  @override
  Future<bool> requireSensitiveActionVerification() async => true;
  @override
  Future<void> reloadSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('auto-lock loosening: longer or never is looser, shorter is not', () {
    expect(SettingsService.isAutoLockLoosening(300, 0), isTrue);
    expect(SettingsService.isAutoLockLoosening(300, 3600), isTrue);
    expect(SettingsService.isAutoLockLoosening(60, 300), isTrue);
    expect(SettingsService.isAutoLockLoosening(-1, 10), isTrue);
    expect(SettingsService.isAutoLockLoosening(0, 300), isFalse);
    expect(SettingsService.isAutoLockLoosening(300, 60), isFalse);
    expect(SettingsService.isAutoLockLoosening(300, -1), isFalse);
    expect(SettingsService.isAutoLockLoosening(300, 300), isFalse);
    expect(SettingsService.isAutoLockLoosening(0, 0), isFalse);
  });

  test('updateStoredSettings writes one field and reads it back', () async {
    final before = await SettingsService.loadSettings();
    expect(before.requirePin, isFalse);

    final stored = await SettingsService.updateStoredSettings(
      (current) => current.copyWith(requirePin: true),
    );

    expect(stored.requirePin, isTrue);
    expect((await SettingsService.loadSettings()).requirePin, isTrue);
  });

  test('a stale generic save keeps stored security fields', () async {
    // Stored state as the Security Hub left it.
    final stored = await SettingsService.updateStoredSettings(
      (current) => current.copyWith(
        requirePin: true,
        biometricAuth: true,
        autoLockTime: 'Never',
        autoLockSeconds: 0,
      ),
    );

    // A settings screen loaded before the change still holds the old values,
    // and a derived biometric value (false here) must not be persisted either.
    final staleScreenState = stored.copyWith(
      pushNotifications: !stored.pushNotifications,
      requirePin: false,
      biometricAuth: false,
      autoLockTime: '5 minutes',
      autoLockSeconds: 300,
    );
    await SettingsService.saveSettings(
      SettingsService.withStoredSecurityFields(
        staleScreenState,
        await SettingsService.loadSettings(),
      ),
    );

    final after = await SettingsService.loadSettings();
    expect(after.requirePin, isTrue);
    expect(after.biometricAuth, isTrue);
    expect(after.autoLockTime, 'Never');
    expect(after.autoLockSeconds, 0);
    expect(after.pushNotifications, staleScreenState.pushNotifications,
        reason: 'non-security fields still come from the screen');
  });

  test('PIN set in the Security Hub survives an unrelated generic save',
      () async {
    // The screen loaded while no PIN existed.
    final screenSnapshot = await SettingsService.loadSettings();
    expect(screenSnapshot.requirePin, isFalse);

    // The Hub sets the first PIN, which turns the requirement on in storage.
    final pins = PinManagement.withPorts(
      storage: _PinStorage(),
      gate: _AllowGate(),
    );
    final result = await pins.setOrReplacePin('1234', '1234');
    expect(result.isSuccess, isTrue);
    expect((await SettingsService.loadSettings()).requirePin, isTrue);

    // Then an unrelated toggle on the stale screen saves its whole state.
    await SettingsService.saveSettings(
      SettingsService.withStoredSecurityFields(
        screenSnapshot.copyWith(twoFactorAuth: true),
        await SettingsService.loadSettings(),
      ),
    );

    final after = await SettingsService.loadSettings();
    expect(after.requirePin, isTrue);
    expect(after.twoFactorAuth, isTrue);
  });
}
