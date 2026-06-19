import 'package:art_kubus/services/passkey_protection_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/passkey_error_mapper.dart';
import 'package:art_kubus/services/wallet_backup_passkey_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasskeyCapability semantics', () {
    test('unsupported supports neither sign-in nor recovery', () {
      const cap = PasskeyCapability.unsupported;
      expect(cap.supportsAccountSignIn, isFalse);
      expect(cap.maySupportWalletRecovery, isFalse);
      expect(cap.confirmedWalletRecovery, isFalse);
    });

    test('accountSignInSupported allows sign-in but not recovery', () {
      const cap = PasskeyCapability.accountSignInSupported;
      expect(cap.supportsAccountSignIn, isTrue);
      // PRF was confirmed missing -> wallet recovery must not be marked ready.
      expect(cap.maySupportWalletRecovery, isFalse);
      expect(cap.confirmedWalletRecovery, isFalse);
    });

    test('unknownUntilRegistration permits attempting recovery, not confirmed',
        () {
      const cap = PasskeyCapability.walletRecoveryPrfUnknownUntilRegistration;
      expect(cap.supportsAccountSignIn, isTrue);
      expect(cap.maySupportWalletRecovery, isTrue);
      expect(cap.confirmedWalletRecovery, isFalse);
    });

    test('walletRecoveryPrfSupported is confirmed', () {
      const cap = PasskeyCapability.walletRecoveryPrfSupported;
      expect(cap.supportsAccountSignIn, isTrue);
      expect(cap.maySupportWalletRecovery, isTrue);
      expect(cap.confirmedWalletRecovery, isTrue);
    });
  });

  group('prfOutputFromResponse', () {
    test('returns PRF output when present', () {
      final response = <String, dynamic>{
        'clientExtensionResults': {
          'prf': {'enabled': true, 'first': 'abc123'},
        },
      };
      expect(prfOutputFromResponse(response), 'abc123');
    });

    test('returns null when PRF absent or empty', () {
      expect(prfOutputFromResponse(null), isNull);
      expect(prfOutputFromResponse(<String, dynamic>{}), isNull);
      expect(
        prfOutputFromResponse(<String, dynamic>{
          'clientExtensionResults': {
            'prf': {'enabled': true, 'first': ''},
          },
        }),
        isNull,
      );
    });
  });

  group('AccountPasskeyStatus.fromJson', () {
    test('parses passkeys and derives accountSignInReady from purpose', () {
      final status = AccountPasskeyStatus.fromJson(<String, dynamic>{
        'passkeys': [
          {
            'id': 'pk-1',
            'credentialId': 'cred-1',
            'deviceLabel': 'Laptop',
            'purpose': 'account_sign_in',
            'transports': ['internal'],
            'prfSupported': false,
          },
        ],
      });
      expect(status.passkeys, hasLength(1));
      expect(status.passkeys.first.deviceLabel, 'Laptop');
      expect(status.accountSignInReady, isTrue);
    });

    test('wallet_recovery-only credential does not mark sign-in ready', () {
      final status = AccountPasskeyStatus.fromJson(<String, dynamic>{
        'accountSignInReady': false,
        'passkeys': [
          {
            'id': 'pk-2',
            'credentialId': 'cred-2',
            'purpose': 'wallet_recovery',
          },
        ],
      });
      expect(status.accountSignInReady, isFalse);
    });

    test('empty payload yields empty status', () {
      final status = AccountPasskeyStatus.fromJson(<String, dynamic>{});
      expect(status.passkeys, isEmpty);
      expect(status.accountSignInReady, isFalse);
    });
  });

  group('PasskeyProtectionResult', () {
    test('account-only result reports sign-in success without recovery', () {
      const result = PasskeyProtectionResult(
        accountSignInRegistered: true,
        walletRecoveryRegistered: false,
        walletRecoveryAttempted: false,
      );
      expect(result.anySucceeded, isTrue);
      expect(result.walletRecoveryRegistered, isFalse);
    });

    test('failed wallet recovery keeps account passkey and surfaces error', () {
      final result = PasskeyProtectionResult(
        accountSignInRegistered: true,
        walletRecoveryRegistered: false,
        walletRecoveryAttempted: true,
        walletRecoveryError: StateError('PRF not available'),
      );
      expect(result.accountSignInRegistered, isTrue);
      expect(result.walletRecoveryError, isNotNull);
    });
  });

  group('Passkey error mapping', () {
    test('maps InvalidStateError to duplicate credential', () {
      final error = mapWebAuthnException(
        Exception('InvalidStateError: credential exists'),
      );
      expect(error.code, PasskeyErrorCode.duplicateCredential);
      expect(error.message, 'This passkey is already registered.');
    });

    test('maps NotAllowedError to cancelled or timed out', () {
      final error = mapWebAuthnException(
        Exception('NotAllowedError: user cancelled'),
      );
      expect(error.code, PasskeyErrorCode.cancelled);
      expect(error.message, 'Browser prompt cancelled or timed out.');
    });

    test('maps null credential to cancelled', () {
      final error = passkeyCancelledException();
      expect(error.code, PasskeyErrorCode.cancelled);
      expect(error.message, 'Browser prompt cancelled or timed out.');
    });

    test('rejects malformed creation options before WebAuthn create', () {
      expect(
        () => validatePasskeyCreationOptions(<String, dynamic>{
          'challenge': '',
        }),
        throwsA(
          isA<PasskeyAppException>().having(
            (error) => error.code,
            'code',
            PasskeyErrorCode.malformedOptions,
          ),
        ),
      );
    });

    test('maps backend structured passkey errors', () {
      final error = mapBackendPasskeyException(
        const BackendApiRequestException(
          statusCode: 400,
          path: '/api/auth/passkey/login/verify',
          body:
              '{"success":false,"errorCode":"PASSKEY_CHALLENGE_EXPIRED","error":"expired"}',
        ),
      );
      expect(error.code, PasskeyErrorCode.challengeExpired);
      expect(error.message, contains('fresh challenge'));
    });
  });
}
