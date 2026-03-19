import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'solana_wallet_service.dart';

class EncryptedWalletBackupException implements Exception {
  const EncryptedWalletBackupException(this.message);

  final String message;

  @override
  String toString() => 'EncryptedWalletBackupException($message)';
}

class WalletBackupPasskeyDefinition {
  const WalletBackupPasskeyDefinition({
    required this.credentialId,
    required this.transports,
    this.nickname,
    this.createdAt,
    this.lastUsedAt,
    this.lastVerifiedAt,
  });

  final String credentialId;
  final List<String> transports;
  final String? nickname;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final DateTime? lastVerifiedAt;

  factory WalletBackupPasskeyDefinition.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? raw) {
      final value = (raw ?? '').toString().trim();
      if (value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    final transportsRaw = json['transports'];
    final transports = transportsRaw is List
        ? transportsRaw.map((item) => item.toString()).toList(growable: false)
        : const <String>[];

    return WalletBackupPasskeyDefinition(
      credentialId: (json['credentialId'] ?? json['credential_id'] ?? '')
          .toString()
          .trim(),
      transports: transports,
      nickname: (json['nickname'] ?? '').toString().trim().isEmpty
          ? null
          : json['nickname'].toString().trim(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      lastUsedAt: parseDate(json['lastUsedAt'] ?? json['last_used_at']),
      lastVerifiedAt:
          parseDate(json['lastVerifiedAt'] ?? json['last_verified_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'credentialId': credentialId,
      'transports': transports,
      if (nickname != null) 'nickname': nickname,
      if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
      if (lastUsedAt != null)
        'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
      if (lastVerifiedAt != null)
        'lastVerifiedAt': lastVerifiedAt!.toUtc().toIso8601String(),
    };
  }
}

class EncryptedWalletBackupDefinition {
  const EncryptedWalletBackupDefinition({
    required this.walletAddress,
    required this.version,
    required this.kdfName,
    required this.kdfParams,
    required this.salt,
    required this.wrappedDekNonce,
    required this.wrappedDekCiphertext,
    required this.mnemonicNonce,
    required this.mnemonicCiphertext,
    this.createdAt,
    this.updatedAt,
    this.lastVerifiedAt,
    this.passkeys = const <WalletBackupPasskeyDefinition>[],
  });

  final String walletAddress;
  final int version;
  final String kdfName;
  final Map<String, dynamic> kdfParams;
  final String salt;
  final String wrappedDekNonce;
  final String wrappedDekCiphertext;
  final String mnemonicNonce;
  final String mnemonicCiphertext;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastVerifiedAt;
  final List<WalletBackupPasskeyDefinition> passkeys;

  factory EncryptedWalletBackupDefinition.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? raw) {
      final value = (raw ?? '').toString().trim();
      if (value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    final rawPasskeys = json['passkeys'];
    final passkeys = rawPasskeys is List
        ? rawPasskeys
            .whereType<Object>()
            .map((item) => WalletBackupPasskeyDefinition.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false)
        : const <WalletBackupPasskeyDefinition>[];

    return EncryptedWalletBackupDefinition(
      walletAddress: (json['walletAddress'] ?? json['wallet_address'] ?? '')
          .toString()
          .trim(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      kdfName: (json['kdfName'] ?? json['kdf_name'] ?? '').toString().trim(),
      kdfParams: Map<String, dynamic>.from(
          json['kdfParams'] ?? json['kdf_params'] ?? const <String, dynamic>{}),
      salt: (json['salt'] ?? '').toString().trim(),
      wrappedDekNonce:
          (json['wrappedDekNonce'] ?? json['wrapped_dek_nonce'] ?? '')
              .toString()
              .trim(),
      wrappedDekCiphertext:
          (json['wrappedDekCiphertext'] ?? json['wrapped_dek_ciphertext'] ?? '')
              .toString()
              .trim(),
      mnemonicNonce: (json['mnemonicNonce'] ?? json['mnemonic_nonce'] ?? '')
          .toString()
          .trim(),
      mnemonicCiphertext:
          (json['mnemonicCiphertext'] ?? json['mnemonic_ciphertext'] ?? '')
              .toString()
              .trim(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      lastVerifiedAt:
          parseDate(json['lastVerifiedAt'] ?? json['last_verified_at']),
      passkeys: passkeys,
    );
  }

  Map<String, dynamic> toApiPayload() {
    return <String, dynamic>{
      'walletAddress': walletAddress,
      'version': version,
      'kdfName': kdfName,
      'kdfParams': kdfParams,
      'salt': salt,
      'wrappedDekNonce': wrappedDekNonce,
      'wrappedDekCiphertext': wrappedDekCiphertext,
      'mnemonicNonce': mnemonicNonce,
      'mnemonicCiphertext': mnemonicCiphertext,
    };
  }

  EncryptedWalletBackupDefinition copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastVerifiedAt,
    List<WalletBackupPasskeyDefinition>? passkeys,
  }) {
    return EncryptedWalletBackupDefinition(
      walletAddress: walletAddress,
      version: version,
      kdfName: kdfName,
      kdfParams: kdfParams,
      salt: salt,
      wrappedDekNonce: wrappedDekNonce,
      wrappedDekCiphertext: wrappedDekCiphertext,
      mnemonicNonce: mnemonicNonce,
      mnemonicCiphertext: mnemonicCiphertext,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      passkeys: passkeys ?? this.passkeys,
    );
  }
}

class EncryptedWalletBackupService {
  EncryptedWalletBackupService({
    SolanaWalletService? solanaWalletService,
    Random? random,
  })  : _solanaWalletService = solanaWalletService ?? SolanaWalletService(),
        _random = random ?? Random.secure();

  static const int backupVersion = 1;
  static const String kdfName = 'argon2id';
  static const int _argonMemoryKiB = 19456;
  static const int _argonIterations = 2;
  static const int _argonParallelism = 1;
  static const int _dekLength = 32;
  static const int _saltLength = 32;
  static const int _nonceLength = 12;

  final SolanaWalletService _solanaWalletService;
  final Random _random;
  final AesGcm _aesGcm = AesGcm.with256bits();

  Map<String, dynamic> defaultKdfParams() {
    return <String, dynamic>{
      'memoryKiB': _argonMemoryKiB,
      'iterations': _argonIterations,
      'parallelism': _argonParallelism,
      'hashLength': _dekLength,
    };
  }

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

  Argon2id _buildArgon2(Map<String, dynamic> kdfParams) {
    final memory = (kdfParams['memoryKiB'] as num?)?.toInt() ?? _argonMemoryKiB;
    final iterations =
        (kdfParams['iterations'] as num?)?.toInt() ?? _argonIterations;
    final parallelism =
        (kdfParams['parallelism'] as num?)?.toInt() ?? _argonParallelism;
    final hashLength = (kdfParams['hashLength'] as num?)?.toInt() ?? _dekLength;
    return Argon2id(
      memory: memory,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    );
  }

  Future<EncryptedWalletBackupDefinition> buildEncryptedBackupDefinition({
    required String walletAddress,
    required String mnemonic,
    required String recoveryPassword,
  }) async {
    final normalizedMnemonic = mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!_solanaWalletService.validateMnemonic(normalizedMnemonic)) {
      throw const EncryptedWalletBackupException(
        'The wallet recovery phrase is invalid.',
      );
    }

    final derivedWallet =
        (await _solanaWalletService.derivePreferredKeyPair(normalizedMnemonic))
            .address;
    if (derivedWallet.trim() != walletAddress.trim()) {
      throw const EncryptedWalletBackupException(
        'The recovery phrase does not match the active wallet.',
      );
    }

    final saltBytes = _randomBytes(_saltLength);
    final dekBytes = _randomBytes(_dekLength);
    final wrappedDekNonceBytes = _randomBytes(_nonceLength);
    final mnemonicNonceBytes = _randomBytes(_nonceLength);
    final kdfParams = defaultKdfParams();
    final argon2 = _buildArgon2(kdfParams);
    final keyEncryptionKey = await argon2.deriveKeyFromPassword(
      password: recoveryPassword,
      nonce: saltBytes,
    );

    final wrappedDekSecretBox = await _aesGcm.encrypt(
      dekBytes,
      secretKey: keyEncryptionKey,
      nonce: wrappedDekNonceBytes,
    );
    final mnemonicSecretBox = await _aesGcm.encrypt(
      utf8.encode(normalizedMnemonic),
      secretKey: SecretKey(dekBytes),
      nonce: mnemonicNonceBytes,
    );

    return EncryptedWalletBackupDefinition(
      walletAddress: walletAddress.trim(),
      version: backupVersion,
      kdfName: kdfName,
      kdfParams: kdfParams,
      salt: _encodeBase64Url(saltBytes),
      wrappedDekNonce: _encodeBase64Url(wrappedDekNonceBytes),
      wrappedDekCiphertext: _encodeBase64Url(
        wrappedDekSecretBox.concatenation(nonce: false),
      ),
      mnemonicNonce: _encodeBase64Url(mnemonicNonceBytes),
      mnemonicCiphertext: _encodeBase64Url(
        mnemonicSecretBox.concatenation(nonce: false),
      ),
    );
  }

  SecretBox _secretBoxFromStoredCiphertext({
    required String ciphertext,
    required String nonce,
  }) {
    final combinedBytes = _decodeBase64Url(ciphertext);
    final nonceBytes = _decodeBase64Url(nonce);
    final macLength = _aesGcm.macAlgorithm.macLength;

    if (combinedBytes.length < macLength) {
      throw const EncryptedWalletBackupException(
        'Encrypted backup payload is corrupted.',
      );
    }

    final cipherLength = combinedBytes.length - macLength;
    return SecretBox(
      Uint8List.sublistView(combinedBytes, 0, cipherLength),
      nonce: nonceBytes,
      mac: Mac(Uint8List.sublistView(combinedBytes, cipherLength)),
    );
  }

  Future<String> decryptMnemonic({
    required EncryptedWalletBackupDefinition backupDefinition,
    required String recoveryPassword,
    required String expectedWalletAddress,
  }) async {
    if (backupDefinition.kdfName.trim().toLowerCase() != kdfName) {
      throw EncryptedWalletBackupException(
        'Unsupported backup KDF: ${backupDefinition.kdfName}',
      );
    }

    final argon2 = _buildArgon2(backupDefinition.kdfParams);
    final keyEncryptionKey = await argon2.deriveKeyFromPassword(
      password: recoveryPassword,
      nonce: _decodeBase64Url(backupDefinition.salt),
    );

    try {
      final dekBytes = await _aesGcm.decrypt(
        _secretBoxFromStoredCiphertext(
          ciphertext: backupDefinition.wrappedDekCiphertext,
          nonce: backupDefinition.wrappedDekNonce,
        ),
        secretKey: keyEncryptionKey,
      );
      final mnemonicBytes = await _aesGcm.decrypt(
        _secretBoxFromStoredCiphertext(
          ciphertext: backupDefinition.mnemonicCiphertext,
          nonce: backupDefinition.mnemonicNonce,
        ),
        secretKey: SecretKey(dekBytes),
      );
      final mnemonic = utf8.decode(mnemonicBytes).trim();
      if (!_solanaWalletService.validateMnemonic(mnemonic)) {
        throw const EncryptedWalletBackupException(
          'Decrypted recovery phrase is invalid.',
        );
      }

      final derivedWallet =
          (await _solanaWalletService.derivePreferredKeyPair(mnemonic)).address;
      if (derivedWallet.trim() != expectedWalletAddress.trim()) {
        throw const EncryptedWalletBackupException(
          'Backup recovery phrase does not match this account wallet.',
        );
      }

      return mnemonic;
    } on SecretBoxAuthenticationError {
      throw const EncryptedWalletBackupException(
        'Recovery password is incorrect or the backup data was tampered with.',
      );
    }
  }
}
