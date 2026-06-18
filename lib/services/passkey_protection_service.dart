import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../providers/wallet_provider.dart';
import 'backend_api_service.dart';
import 'passkey_error_mapper.dart';
import 'wallet_backup_passkey_service.dart';

/// A single account sign-in passkey credential as reported by the backend
/// (`GET /api/auth/passkey/credentials`).
class AccountPasskey {
  const AccountPasskey({
    required this.id,
    required this.credentialId,
    this.deviceLabel,
    this.purpose,
    this.transports = const <String>[],
    this.prfSupported = false,
    this.createdAt,
    this.lastUsedAt,
  });

  final String id;
  final String credentialId;
  final String? deviceLabel;
  final String? purpose;
  final List<String> transports;
  final bool prfSupported;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  static DateTime? _parseDate(Object? value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  factory AccountPasskey.fromJson(Map<String, dynamic> json) {
    final transportsRaw = json['transports'];
    return AccountPasskey(
      id: (json['id'] ?? '').toString(),
      credentialId:
          (json['credentialId'] ?? json['credential_id'] ?? '').toString(),
      deviceLabel: (json['deviceLabel'] ?? json['device_label'])?.toString(),
      purpose: (json['purpose'])?.toString(),
      transports: transportsRaw is List
          ? transportsRaw.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      prfSupported:
          json['prfSupported'] == true || json['prf_supported'] == true,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      lastUsedAt: _parseDate(json['lastUsedAt'] ?? json['last_used_at']),
    );
  }
}

class AccountPasskeyStatus {
  const AccountPasskeyStatus({
    required this.passkeys,
    required this.accountSignInReady,
  });

  final List<AccountPasskey> passkeys;
  final bool accountSignInReady;

  static const empty = AccountPasskeyStatus(
      passkeys: <AccountPasskey>[], accountSignInReady: false);

  factory AccountPasskeyStatus.fromJson(Map<String, dynamic> json) {
    final list = json['passkeys'];
    final passkeys = list is List
        ? list
            .whereType<Map>()
            .map((e) => AccountPasskey.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <AccountPasskey>[];
    return AccountPasskeyStatus(
      passkeys: passkeys,
      accountSignInReady: json['accountSignInReady'] == true ||
          passkeys.any(
              (p) => p.purpose == 'account_sign_in' || p.purpose == 'both'),
    );
  }
}

/// Outcome of the combined "Enable passkey protection" flow. Account sign-in and
/// wallet recovery are independent capabilities, so each is reported separately.
class PasskeyProtectionResult {
  const PasskeyProtectionResult({
    required this.accountSignInRegistered,
    required this.walletRecoveryRegistered,
    required this.walletRecoveryAttempted,
    this.accountError,
    this.walletRecoveryError,
  });

  final bool accountSignInRegistered;
  final bool walletRecoveryRegistered;

  /// Whether wallet-recovery registration was attempted at all (false when PRF
  /// is unsupported or no signer/mnemonic was available).
  final bool walletRecoveryAttempted;
  final Object? accountError;
  final Object? walletRecoveryError;

  bool get anySucceeded => accountSignInRegistered || walletRecoveryRegistered;
}

/// Orchestrates account sign-in passkeys and the combined protection flow.
///
/// Account sign-in credentials live in `user_passkey_credentials` (no secrets);
/// wallet recovery credentials live in `wallet_backup_passkeys` and store only
/// PRF-wrapped recovery material. This service never sees or stores secrets.
class PasskeyProtectionService {
  const PasskeyProtectionService();

  bool get isAvailable => kIsWeb && AppConfig.isFeatureEnabled('passkeySignIn');

  Future<AccountPasskeyStatus> getAccountStatus(BackendApiService api) async {
    final data = await api.getAccountPasskeyStatus();
    return AccountPasskeyStatus.fromJson(data);
  }

  /// Registers an account sign-in passkey for the authenticated user.
  ///
  /// [purpose] is one of `account_sign_in` or `both` (when this credential is
  /// also intended for wallet recovery, where the backend contract allows it).
  Future<AccountPasskey> registerAccountPasskey({
    required BackendApiService api,
    String? deviceLabel,
    String purpose = 'account_sign_in',
  }) async {
    if (!kIsWeb) {
      throw const PasskeyAppException(
        PasskeyErrorCode.unavailable,
        'Passkeys are only available in the web app.',
      );
    }
    final supported = await isWalletBackupPasskeySupported();
    if (!supported) {
      throw const PasskeyAppException(
        PasskeyErrorCode.unavailable,
        'Passkeys are not available in this browser.',
      );
    }
    try {
      final options = await api.getAccountPasskeyRegisterOptions(
        deviceLabel: deviceLabel,
        purpose: purpose,
      );
      final credential = await createWalletBackupPasskeyCredential(options);
      final prfSupported = prfOutputFromResponse(credential) != null;
      final verify = await api.verifyAccountPasskeyRegister(
        responsePayload: credential,
        deviceLabel: deviceLabel,
        purpose: purpose,
        prfSupported: prfSupported,
      );
      final passkeyPayload = verify['passkey'] is Map
          ? Map<String, dynamic>.from(verify['passkey'] as Map)
          : verify;
      return AccountPasskey.fromJson(passkeyPayload);
    } catch (error) {
      throw mapBackendPasskeyException(error);
    }
  }

  Future<void> revokeAccountPasskey({
    required BackendApiService api,
    required String passkeyId,
  }) async {
    await api.revokeAccountPasskey(passkeyId: passkeyId);
  }

  /// Combined "Enable passkey protection" uses exactly one WebAuthn create()
  /// ceremony. It registers an account sign-in passkey with `purpose='both'`
  /// so this API cannot silently trigger a second browser prompt.
  ///
  /// Wallet recovery/unlock passkeys require PRF-wrapped recovery material and
  /// are now an explicit separate user action in the canonical security hub.
  Future<PasskeyProtectionResult> enablePasskeyProtection({
    required BackendApiService api,
    required WalletProvider walletProvider,
    String? deviceLabel,
  }) async {
    final accountPasskey = await registerAccountPasskey(
      api: api,
      deviceLabel: deviceLabel,
      purpose: 'both',
    );

    return PasskeyProtectionResult(
      accountSignInRegistered: true,
      walletRecoveryRegistered: false,
      walletRecoveryAttempted: false,
      walletRecoveryError: accountPasskey.prfSupported
          ? null
          : const PasskeyAppException(
              PasskeyErrorCode.unavailable,
              'This passkey can sign into the account, but wallet recovery passkey setup needs a PRF-capable device.',
            ),
    );
  }
}
