import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/auth_google_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
