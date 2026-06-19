import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const walletAddress = '7YgP1dXwz9exampleWallet111111111111111111';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('test-token');
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('revokeEncryptedWalletBackupPasskey calls wallet recovery revoke only',
      () async {
    final paths = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      paths.add(request.url.path);
      if (request.method == 'DELETE' &&
          request.url.path ==
              '/api/wallet-backup/passkey-recovery/credentials/wallet-passkey-1') {
        expect(request.url.queryParameters['walletAddress'], walletAddress);
        return http.Response(
          '{"success":true,"data":{"id":"wallet-passkey-1","revoked":true,"passkeys":[]}}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET' && request.url.path == '/api/wallet-backup') {
        expect(request.url.queryParameters['walletAddress'], walletAddress);
        return http.Response(
          '{"success":true,"data":{"walletAddress":"$walletAddress","version":1,"kdfName":"argon2id","kdfParams":{},"salt":"salt","wrappedDekNonce":"nonce","wrappedDekCiphertext":"cipher","mnemonicNonce":"mnemonicNonce","mnemonicCiphertext":"mnemonicCipher","passkeys":[]}}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      return http.Response('{"success":false,"error":"unexpected"}', 500);
    }));

    final provider = WalletProvider(deferInit: true)
      ..setCurrentWalletAddressForTesting(walletAddress)
      ..setEncryptedWalletBackupDefinitionForTesting(
        EncryptedWalletBackupDefinition(
          walletAddress: walletAddress,
          version: 1,
          kdfName: 'argon2id',
          kdfParams: const <String, dynamic>{},
          salt: 'salt',
          wrappedDekNonce: 'nonce',
          wrappedDekCiphertext: 'cipher',
          mnemonicNonce: 'mnemonicNonce',
          mnemonicCiphertext: 'mnemonicCipher',
          passkeys: [
            WalletBackupPasskeyDefinition(
              id: 'wallet-passkey-1',
              credentialId: 'credential-1',
              transports: const ['internal'],
              nickname: 'Laptop',
              prfSupported: true,
            ),
          ],
        ),
      );

    final passkeys = await provider.revokeEncryptedWalletBackupPasskey(
      'wallet-passkey-1',
    );

    expect(passkeys, isEmpty);
    expect(provider.encryptedWalletBackupPasskeys, isEmpty);
    expect(
        paths,
        contains(
            '/api/wallet-backup/passkey-recovery/credentials/wallet-passkey-1'));
    expect(paths, contains('/api/wallet-backup'));
    expect(paths, isNot(contains('/api/auth/passkey/wallet-passkey-1')));
  });
}
