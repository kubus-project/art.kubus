import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'encrypted_wallet_backup_service.dart';

class WalletPasskeyWrappedRecoveryKey {
  const WalletPasskeyWrappedRecoveryKey({
    required this.encryptedWrappedRecoveryKey,
    required this.encryptedWrappedRecoveryKeyNonce,
    required this.wrappingAlgorithm,
  });

  final String encryptedWrappedRecoveryKey;
  final String encryptedWrappedRecoveryKeyNonce;
  final String wrappingAlgorithm;
}

class WalletPasskeyCryptoService {
  WalletPasskeyCryptoService({Random? random})
      : _random = random ?? Random.secure();

  static const String wrappingAlgorithm = 'webauthn-prf-hkdf-sha256-aes-gcm-v1';
  static const int _nonceLength = 12;

  final Random _random;
  final AesGcm _aesGcm = AesGcm.with256bits();

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  Uint8List _decodeBase64Url(String value) {
    return Uint8List.fromList(base64Url.decode(base64Url.normalize(value)));
  }

  String _encodeBase64Url(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<SecretKey> _deriveWrappingKey({
    required String prfOutputBase64,
    required String walletAddress,
    required String credentialId,
    required int backupVersion,
  }) {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final info = utf8.encode(
      'art.kubus.wallet-passkey-recovery.v1|'
      'wallet=${walletAddress.trim()}|'
      'credential=${credentialId.trim()}|'
      'backup=$backupVersion',
    );
    return hkdf.deriveKey(
      secretKey: SecretKey(_decodeBase64Url(prfOutputBase64)),
      nonce: utf8.encode('art.kubus passkey wallet recovery'),
      info: info,
    );
  }

  Future<WalletPasskeyWrappedRecoveryKey> wrapMnemonic({
    required String mnemonic,
    required String prfOutputBase64,
    required String walletAddress,
    required String credentialId,
    required int backupVersion,
  }) async {
    final key = await _deriveWrappingKey(
      prfOutputBase64: prfOutputBase64,
      walletAddress: walletAddress,
      credentialId: credentialId,
      backupVersion: backupVersion,
    );
    final nonce = _randomBytes(_nonceLength);
    final box = await _aesGcm.encrypt(
      utf8.encode(mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ')),
      secretKey: key,
      nonce: nonce,
    );
    return WalletPasskeyWrappedRecoveryKey(
      encryptedWrappedRecoveryKey: _encodeBase64Url(
        box.concatenation(nonce: false),
      ),
      encryptedWrappedRecoveryKeyNonce: _encodeBase64Url(nonce),
      wrappingAlgorithm: wrappingAlgorithm,
    );
  }

  Future<String> unwrapMnemonic({
    required String encryptedWrappedRecoveryKey,
    required String encryptedWrappedRecoveryKeyNonce,
    required String prfOutputBase64,
    required String walletAddress,
    required String credentialId,
    required int backupVersion,
    required String wrappingAlgorithm,
  }) async {
    if (wrappingAlgorithm.trim() !=
        WalletPasskeyCryptoService.wrappingAlgorithm) {
      throw EncryptedWalletBackupException(
        'Unsupported passkey wrapping algorithm: $wrappingAlgorithm',
      );
    }
    final combined = _decodeBase64Url(encryptedWrappedRecoveryKey);
    final macLength = _aesGcm.macAlgorithm.macLength;
    if (combined.length < macLength) {
      throw const EncryptedWalletBackupException(
        'Passkey recovery material is corrupted.',
      );
    }
    final cipherLength = combined.length - macLength;
    final key = await _deriveWrappingKey(
      prfOutputBase64: prfOutputBase64,
      walletAddress: walletAddress,
      credentialId: credentialId,
      backupVersion: backupVersion,
    );
    try {
      final mnemonicBytes = await _aesGcm.decrypt(
        SecretBox(
          Uint8List.sublistView(combined, 0, cipherLength),
          nonce: _decodeBase64Url(encryptedWrappedRecoveryKeyNonce),
          mac: Mac(Uint8List.sublistView(combined, cipherLength)),
        ),
        secretKey: key,
      );
      return utf8.decode(mnemonicBytes).trim();
    } on SecretBoxAuthenticationError {
      throw const EncryptedWalletBackupException(
        'Passkey recovery material could not be decrypted on this device.',
      );
    } on FormatException {
      throw const EncryptedWalletBackupException(
        'Passkey recovery material is corrupted.',
      );
    }
  }
}
