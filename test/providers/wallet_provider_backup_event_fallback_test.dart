import 'dart:convert';

import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BackupEventFallbackWalletProvider extends WalletProvider {
  _BackupEventFallbackWalletProvider({
    required this.backupDefinition,
    required this.decryptedMnemonic,
  }) : super(deferInit: true) {
    setCurrentWalletAddressForTesting(backupDefinition.walletAddress);
  }

  final EncryptedWalletBackupDefinition backupDefinition;
  final String decryptedMnemonic;

  String? importedMnemonic;
  int refreshCalls = 0;

  @override
  Future<EncryptedWalletBackupDefinition?> getEncryptedWalletBackup({
    String? walletAddress,
    bool refresh = false,
  }) async {
    return backupDefinition;
  }

  @override
  Future<String> decryptEncryptedWalletBackupMnemonic({
    required EncryptedWalletBackupDefinition backupDefinition,
    required String recoveryPassword,
    required String expectedWalletAddress,
  }) async {
    expect(recoveryPassword, 'correct horse battery staple');
    expect(expectedWalletAddress, this.backupDefinition.walletAddress);
    return decryptedMnemonic;
  }

  @override
  Future<String> importWalletFromMnemonic(
    String mnemonic, {
    DerivedKeyPairResult? preDerived,
    bool markBackedUp = true,
  }) async {
    importedMnemonic = mnemonic;
    setCurrentWalletAddressForTesting(backupDefinition.walletAddress);
    return backupDefinition.walletAddress;
  }

  @override
  Future<EncryptedWalletBackupDefinition?> refreshEncryptedWalletBackupStatus({
    String? walletAddress,
    bool notify = true,
  }) async {
    refreshCalls += 1;
    return backupDefinition;
  }

  @override
  bool get hasSigner => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const walletAddress = 'wallet-backup-1';
  const recoveryPassword = 'correct horse battery staple';
  const mnemonic = 'alpha beta gamma delta epsilon zeta eta theta';
  const missingEndpointResponse = '{"success":false,"error":"not found"}';

  const backupDefinition = EncryptedWalletBackupDefinition(
    walletAddress: walletAddress,
    version: 1,
    kdfName: 'argon2id',
    kdfParams: <String, dynamic>{
      'memoryKiB': 19456,
      'iterations': 2,
      'parallelism': 1,
      'hashLength': 32,
    },
    salt: 'salt',
    wrappedDekNonce: 'wrapped-dek-nonce',
    wrappedDekCiphertext: 'wrapped-dek-ciphertext',
    mnemonicNonce: 'mnemonic-nonce',
    mnemonicCiphertext: 'mnemonic-ciphertext',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setPreferredWalletAddress(null);
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/wallet-backup/events') {
          return http.Response(
            missingEndpointResponse,
            404,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode(<String, dynamic>{'success': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('verifyEncryptedWalletBackup tolerates missing backup event endpoint',
      () async {
    final walletProvider = _BackupEventFallbackWalletProvider(
      backupDefinition: backupDefinition,
      decryptedMnemonic: mnemonic,
    );

    final result = await walletProvider.verifyEncryptedWalletBackup(
      recoveryPassword: recoveryPassword,
      walletAddress: walletAddress,
    );

    expect(result, mnemonic);
    expect(walletProvider.encryptedWalletBackupError, isNull);
  });

  test(
      'restoreSignerFromEncryptedWalletBackup succeeds when backup event endpoint is unavailable',
      () async {
    final walletProvider = _BackupEventFallbackWalletProvider(
      backupDefinition: backupDefinition,
      decryptedMnemonic: mnemonic,
    );

    final restored =
        await walletProvider.restoreSignerFromEncryptedWalletBackup(
      recoveryPassword: recoveryPassword,
      walletAddress: walletAddress,
    );

    expect(restored, isTrue);
    expect(walletProvider.importedMnemonic, mnemonic);
    expect(walletProvider.refreshCalls, 1);
    expect(walletProvider.encryptedWalletBackupError, isNull);
  });
}
