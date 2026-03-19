import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _tamperBase64Url(String value) {
  if (value.isEmpty) {
    return value;
  }

  final chars = value.split('');
  final index = chars.length - 1;
  chars[index] = chars[index] == 'A' ? 'B' : 'A';
  return chars.join();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SolanaWalletService solanaWalletService;
  late EncryptedWalletBackupService backupService;
  late String mnemonic;
  late String walletAddress;

  setUp(() async {
    solanaWalletService = SolanaWalletService();
    backupService = EncryptedWalletBackupService(
      solanaWalletService: solanaWalletService,
    );
    mnemonic = solanaWalletService.generateMnemonic();
    walletAddress =
        (await solanaWalletService.derivePreferredKeyPair(mnemonic)).address;
  });

  test('encrypts and decrypts a wallet backup round trip', () async {
    final backupDefinition = await backupService.buildEncryptedBackupDefinition(
      walletAddress: walletAddress,
      mnemonic: mnemonic,
      recoveryPassword: 'correct horse battery staple',
    );

    final restoredMnemonic = await backupService.decryptMnemonic(
      backupDefinition: backupDefinition,
      recoveryPassword: 'correct horse battery staple',
      expectedWalletAddress: walletAddress,
    );

    expect(restoredMnemonic, mnemonic);
    expect(backupDefinition.walletAddress, walletAddress);
    expect(backupDefinition.kdfName, EncryptedWalletBackupService.kdfName);
  });

  test('rejects the wrong recovery password', () async {
    final backupDefinition = await backupService.buildEncryptedBackupDefinition(
      walletAddress: walletAddress,
      mnemonic: mnemonic,
      recoveryPassword: 'correct horse battery staple',
    );

    expect(
      () => backupService.decryptMnemonic(
        backupDefinition: backupDefinition,
        recoveryPassword: 'wrong password',
        expectedWalletAddress: walletAddress,
      ),
      throwsA(
        isA<EncryptedWalletBackupException>().having(
          (error) => error.message,
          'message',
          contains('incorrect'),
        ),
      ),
    );
  });

  test('rejects tampered encrypted backup ciphertext', () async {
    final backupDefinition = await backupService.buildEncryptedBackupDefinition(
      walletAddress: walletAddress,
      mnemonic: mnemonic,
      recoveryPassword: 'correct horse battery staple',
    );
    final tamperedDefinition = EncryptedWalletBackupDefinition(
      walletAddress: backupDefinition.walletAddress,
      version: backupDefinition.version,
      kdfName: backupDefinition.kdfName,
      kdfParams: backupDefinition.kdfParams,
      salt: backupDefinition.salt,
      wrappedDekNonce: backupDefinition.wrappedDekNonce,
      wrappedDekCiphertext: backupDefinition.wrappedDekCiphertext,
      mnemonicNonce: backupDefinition.mnemonicNonce,
      mnemonicCiphertext: _tamperBase64Url(backupDefinition.mnemonicCiphertext),
      createdAt: backupDefinition.createdAt,
      updatedAt: backupDefinition.updatedAt,
      lastVerifiedAt: backupDefinition.lastVerifiedAt,
      passkeys: backupDefinition.passkeys,
    );

    expect(
      () => backupService.decryptMnemonic(
        backupDefinition: tamperedDefinition,
        recoveryPassword: 'correct horse battery staple',
        expectedWalletAddress: walletAddress,
      ),
      throwsA(
        isA<EncryptedWalletBackupException>().having(
          (error) => error.message,
          'message',
          contains('tampered'),
        ),
      ),
    );
  });

  test(
      'rejects recovery when the decrypted mnemonic matches a different wallet',
      () async {
    final backupDefinition = await backupService.buildEncryptedBackupDefinition(
      walletAddress: walletAddress,
      mnemonic: mnemonic,
      recoveryPassword: 'correct horse battery staple',
    );
    final otherMnemonic = solanaWalletService.generateMnemonic();
    final otherWalletAddress =
        (await solanaWalletService.derivePreferredKeyPair(otherMnemonic))
            .address;

    expect(
      () => backupService.decryptMnemonic(
        backupDefinition: backupDefinition,
        recoveryPassword: 'correct horse battery staple',
        expectedWalletAddress: otherWalletAddress,
      ),
      throwsA(
        isA<EncryptedWalletBackupException>().having(
          (error) => error.message,
          'message',
          contains('does not match this account wallet'),
        ),
      ),
    );
  });
}
