import 'wallet_backup_passkey_service_stub.dart'
    if (dart.library.js_interop) 'wallet_backup_passkey_service_web.dart'
    as impl;

enum PasskeyCapability {
  unsupported,
  accountSignInOnly,
  walletRecoveryPrfSupported,
}

class PasskeyRecoveryAssertionResult {
  const PasskeyRecoveryAssertionResult({
    required this.verified,
    required this.prfSupported,
    this.prfOutputBase64,
    this.credentialId,
    this.response,
    this.error,
  });

  final bool verified;
  final bool prfSupported;
  final String? prfOutputBase64;
  final String? credentialId;
  final Map<String, dynamic>? response;
  final Object? error;
}

Future<bool> isWalletBackupPasskeySupported() =>
    impl.isWalletBackupPasskeySupported();

Future<PasskeyCapability> getPasskeyCapability() async {
  final supported = await isWalletBackupPasskeySupported();
  if (!supported) return PasskeyCapability.unsupported;
  final prfSupported = await impl.isWalletBackupPasskeyPrfSupported();
  return prfSupported
      ? PasskeyCapability.walletRecoveryPrfSupported
      : PasskeyCapability.accountSignInOnly;
}

Future<Map<String, dynamic>> createWalletBackupPasskeyCredential(
  Map<String, dynamic> creationOptions,
) =>
    impl.createWalletBackupPasskeyCredential(creationOptions);

Future<Map<String, dynamic>> getWalletBackupPasskeyAssertion(
  Map<String, dynamic> requestOptions,
) =>
    impl.getWalletBackupPasskeyAssertion(requestOptions);

Future<PasskeyRecoveryAssertionResult> getWalletBackupPasskeyRecoveryAssertion(
  Map<String, dynamic> requestOptions,
) async {
  try {
    final response = await impl.getWalletBackupPasskeyAssertion(requestOptions);
    final extensions = response['clientExtensionResults'];
    final prf = extensions is Map ? extensions['prf'] : null;
    final prfMap = prf is Map ? prf : const <String, dynamic>{};
    final output = (prfMap['first'] ?? '').toString().trim();
    final credentialId =
        (response['id'] ?? response['rawId'] ?? '').toString().trim();
    return PasskeyRecoveryAssertionResult(
      verified: true,
      prfSupported: output.isNotEmpty,
      prfOutputBase64: output.isEmpty ? null : output,
      credentialId: credentialId.isEmpty ? null : credentialId,
      response: response,
    );
  } catch (error) {
    return PasskeyRecoveryAssertionResult(
      verified: false,
      prfSupported: false,
      error: error,
    );
  }
}
