import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/google_auth_service.dart';
import 'package:art_kubus/utils/auth_google_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
  });

  test('returns null when no signer-backed wallet is available', () {
    expect(
      signerBackedGoogleWalletAddress(
        hasSigner: false,
        currentWalletAddress: 'wallet-123',
      ),
      isNull,
    );
  });

  test('returns signer-backed wallet when local signer exists', () {
    expect(
      signerBackedGoogleWalletAddress(
        hasSigner: true,
        currentWalletAddress: ' wallet-123 ',
      ),
      'wallet-123',
    );
  });

  test('detects backend wallet requirement for new google accounts', () {
    const error = BackendApiRequestException(
      statusCode: 400,
      path: '/api/auth/login/google',
      body: '{"success":false,"errorCode":"WALLET_REQUIRED_FOR_NEW_ACCOUNT"}',
    );

    expect(isWalletRequiredForNewGoogleAccount(error), isTrue);
  });

  test('ignores unrelated backend errors', () {
    const error = BackendApiRequestException(
      statusCode: 409,
      path: '/api/auth/login/google',
      body: '{"success":false,"errorCode":"EMAIL_ACCOUNT_AMBIGUOUS"}',
    );

    expect(isWalletRequiredForNewGoogleAccount(error), isFalse);
  });

  test('retries google login after provisioning a signer-backed wallet',
      () async {
    final api = BackendApiService();
    var loginAttempts = 0;
    String? firstWalletAddress;
    String? secondWalletAddress;
    var walletProvisionCalls = 0;

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/auth/login/google') {
          return http.Response('Not found', 404);
        }

        final body = request.body;
        final decoded = body.isEmpty
            ? <String, dynamic>{}
            : request.headers['content-type']?.contains('application/json') ==
                    true
                ? Map<String, dynamic>.from(
                    (jsonDecode(body) as Map),
                  )
                : <String, dynamic>{};
        loginAttempts += 1;
        final walletAddress = (decoded['walletAddress'] ?? '').toString();
        if (loginAttempts == 1) {
          firstWalletAddress = walletAddress;
          return http.Response(
            '{"success":false,"errorCode":"WALLET_REQUIRED_FOR_NEW_ACCOUNT"}',
            400,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        secondWalletAddress = walletAddress;
        return http.Response(
          '{"success":true,"data":{"token":"jwt-token"}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await loginWithGoogleWalletRecovery(
      api: api,
      googleResult: GoogleAuthResult(
        idToken: 'google-id-token',
        email: 'new-user@example.com',
        displayName: 'New User',
      ),
      walletAddress: null,
      createSignerBackedWallet: () async {
        walletProvisionCalls += 1;
        return 'wallet-created-123';
      },
    );

    expect(result['success'], isTrue);
    expect(loginAttempts, 2);
    expect(firstWalletAddress, isEmpty);
    expect(secondWalletAddress, 'wallet-created-123');
    expect(walletProvisionCalls, 1);
  });

  test('does not retry google login for non-wallet backend errors', () async {
    final api = BackendApiService();
    var walletProvisionCalls = 0;

    api.setHttpClient(
      MockClient((request) async {
        return http.Response(
          '{"success":false,"errorCode":"GOOGLE_EMAIL_MISSING"}',
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      () => loginWithGoogleWalletRecovery(
        api: api,
        googleResult: GoogleAuthResult(
          idToken: 'google-id-token',
          email: 'new-user@example.com',
          displayName: 'New User',
        ),
        walletAddress: null,
        createSignerBackedWallet: () async {
          walletProvisionCalls += 1;
          return 'wallet-created-123';
        },
      ),
      throwsA(isA<BackendApiRequestException>()),
    );
    expect(walletProvisionCalls, 0);
  });
}
