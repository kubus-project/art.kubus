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
}
