// ignore_for_file: depend_on_referenced_packages

import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Fake local_auth platform. [throwError] is raised from authenticate().
class _FakeLocalAuthPlatform extends LocalAuthPlatform
    with MockPlatformInterfaceMixin {
  Object? throwError;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> deviceSupportsBiometrics() async => true;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async =>
      const <BiometricType>[BiometricType.fingerprint];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    final error = throwError;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<bool> stopAuthentication() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeLocalAuthPlatform fake;
  late WalletProvider wallet;

  setUp(() {
    fake = _FakeLocalAuthPlatform();
    LocalAuthPlatform.instance = fake;
    wallet = WalletProvider(deferInit: true);
  });

  Future<BiometricAuthOutcome> outcomeFor(Object? error) async {
    fake.throwError = error;
    return wallet.authenticateWithBiometricsDetailed(
        localizedReason: 'Confirm');
  }

  test('a successful local_auth result maps to success', () async {
    expect(await outcomeFor(null), BiometricAuthOutcome.success);
  });

  final expected = <LocalAuthExceptionCode, BiometricAuthOutcome>{
    LocalAuthExceptionCode.userCanceled: BiometricAuthOutcome.cancelled,
    LocalAuthExceptionCode.systemCanceled: BiometricAuthOutcome.cancelled,
    LocalAuthExceptionCode.timeout: BiometricAuthOutcome.cancelled,
    LocalAuthExceptionCode.noBiometricsEnrolled:
        BiometricAuthOutcome.notAvailable,
    LocalAuthExceptionCode.noBiometricHardware:
        BiometricAuthOutcome.notAvailable,
    LocalAuthExceptionCode.noCredentialsSet: BiometricAuthOutcome.notAvailable,
    LocalAuthExceptionCode.temporaryLockout: BiometricAuthOutcome.lockedOut,
    LocalAuthExceptionCode.biometricLockout: BiometricAuthOutcome.lockedOut,
    LocalAuthExceptionCode.userRequestedFallback: BiometricAuthOutcome.failed,
    LocalAuthExceptionCode.authInProgress: BiometricAuthOutcome.error,
    LocalAuthExceptionCode.uiUnavailable: BiometricAuthOutcome.error,
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        BiometricAuthOutcome.error,
    LocalAuthExceptionCode.deviceError: BiometricAuthOutcome.error,
    LocalAuthExceptionCode.unknownError: BiometricAuthOutcome.error,
  };

  for (final entry in expected.entries) {
    test('LocalAuthException ${entry.key.name} maps to ${entry.value.name}',
        () async {
      expect(
        await outcomeFor(LocalAuthException(code: entry.key)),
        entry.value,
      );
    });
  }

  test('every LocalAuthExceptionCode has an explicit expectation', () {
    expect(expected.keys.toSet(), LocalAuthExceptionCode.values.toSet());
  });

  test('PlatformException mapping is still applied', () async {
    expect(
      await outcomeFor(PlatformException(code: 'userCanceled')),
      BiometricAuthOutcome.cancelled,
    );
    expect(
      await outcomeFor(PlatformException(code: 'LockedOut')),
      BiometricAuthOutcome.lockedOut,
    );
  });
}
