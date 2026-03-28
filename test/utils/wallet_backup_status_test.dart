import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/encrypted_wallet_backup_service.dart';
import 'package:art_kubus/utils/wallet_backup_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider({
    required this.walletAddress,
    required this.mnemonicBackupRequiredValue,
    this.backupDefinition,
    this.backupError,
  }) : super(deferInit: true);

  final String walletAddress;
  final bool mnemonicBackupRequiredValue;
  final EncryptedWalletBackupDefinition? backupDefinition;
  final Object? backupError;

  @override
  String? get currentWalletAddress => walletAddress;

  @override
  bool get hasWalletIdentity => walletAddress.trim().isNotEmpty;

  @override
  bool get hasSigner => true;

  @override
  bool get isReadOnlySession => false;

  @override
  Future<bool> isMnemonicBackupRequired({String? walletAddress}) async {
    return mnemonicBackupRequiredValue;
  }

  @override
  Future<EncryptedWalletBackupDefinition?> getEncryptedWalletBackup({
    String? walletAddress,
    bool refresh = false,
  }) async {
    if (backupError != null) {
      throw backupError!;
    }
    return backupDefinition;
  }
}

EncryptedWalletBackupDefinition _backupDefinition(String walletAddress) {
  return EncryptedWalletBackupDefinition(
    walletAddress: walletAddress,
    version: 1,
    kdfName: 'argon2id',
    kdfParams: const <String, dynamic>{'memory': 1},
    salt: 'salt',
    wrappedDekNonce: 'wrapped-nonce',
    wrappedDekCiphertext: 'wrapped-ciphertext',
    mnemonicNonce: 'mnemonic-nonce',
    mnemonicCiphertext: 'mnemonic-ciphertext',
  );
}

void main() {
  test('lookup failures do not hard-fail encrypted backup gating', () async {
    final provider = _FakeWalletProvider(
      walletAddress: '4Nd1m5sP3v1bE7c9Q2w6z8YkLmNoPrStUvWxYzABcDeF',
      mnemonicBackupRequiredValue: false,
      backupError: StateError('backend unavailable'),
    );

    final status = await WalletBackupStatusResolver.resolve(
      walletProvider: provider,
      refreshRemote: true,
    );

    expect(status.hasEncryptedServerBackup, isFalse);
    expect(status.encryptedBackupStatusKnown, isFalse);
    expect(status.encryptedBackupRequirementSatisfiedForGating, isTrue);
  });

  test('known missing encrypted backup still requires gating', () async {
    final provider = _FakeWalletProvider(
      walletAddress: '4Nd1m5sP3v1bE7c9Q2w6z8YkLmNoPrStUvWxYzABcDeF',
      mnemonicBackupRequiredValue: false,
      backupDefinition: null,
    );

    final status = await WalletBackupStatusResolver.resolve(
      walletProvider: provider,
      refreshRemote: true,
    );

    expect(status.hasEncryptedServerBackup, isFalse);
    expect(status.encryptedBackupStatusKnown, isTrue);
    expect(status.encryptedBackupRequirementSatisfiedForGating, isFalse);
  });

  test('known encrypted backup satisfies gating', () async {
    const walletAddress = '4Nd1m5sP3v1bE7c9Q2w6z8YkLmNoPrStUvWxYzABcDeF';
    final provider = _FakeWalletProvider(
      walletAddress: walletAddress,
      mnemonicBackupRequiredValue: false,
      backupDefinition: _backupDefinition(walletAddress),
    );

    final status = await WalletBackupStatusResolver.resolve(
      walletProvider: provider,
      refreshRemote: true,
    );

    expect(status.hasEncryptedServerBackup, isTrue);
    expect(status.encryptedBackupStatusKnown, isTrue);
    expect(status.encryptedBackupRequirementSatisfiedForGating, isTrue);
  });
}
