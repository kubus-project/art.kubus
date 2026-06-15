import 'wallet_backup_passkey_service_stub.dart'
    if (dart.library.js_interop) 'wallet_backup_passkey_service_web.dart'
    as impl;

/// Capability of the current device/browser for passkeys.
///
/// Account sign-in only needs a (platform) WebAuthn authenticator. Wallet
/// recovery additionally needs the WebAuthn PRF / hmac-secret extension so the
/// client can derive a wrapping key locally. There is no reliable way to probe
/// PRF support *before* a credential exists, so callers must treat
/// [walletRecoveryPrfUnknownUntilRegistration] as "try, then confirm from the
/// extension results produced during registration/assertion".
enum PasskeyCapability {
  /// No usable WebAuthn authenticator: neither sign-in nor recovery available.
  unsupported,

  /// Sign-in works, but PRF is known to be missing (e.g. confirmed at
  /// registration time), so passkey wallet recovery is not available.
  accountSignInSupported,

  /// PRF output was actually produced and verified — wallet recovery is ready.
  walletRecoveryPrfSupported,

  /// Sign-in works; PRF support cannot be determined until a registration or
  /// assertion ceremony has run and its extension results are inspected.
  walletRecoveryPrfUnknownUntilRegistration,
}

extension PasskeyCapabilityX on PasskeyCapability {
  /// Account sign-in passkeys can be created/used for any usable authenticator.
  bool get supportsAccountSignIn => this != PasskeyCapability.unsupported;

  /// Whether a PRF-backed wallet-recovery registration is worth attempting.
  /// True when PRF is confirmed or not-yet-known (we only learn the truth from
  /// the ceremony's extension results).
  bool get maySupportWalletRecovery =>
      this == PasskeyCapability.walletRecoveryPrfSupported ||
      this == PasskeyCapability.walletRecoveryPrfUnknownUntilRegistration;

  /// Whether PRF wallet recovery has been positively confirmed.
  bool get confirmedWalletRecovery =>
      this == PasskeyCapability.walletRecoveryPrfSupported;
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

/// Reports the device capability for passkeys.
///
/// Note: this intentionally does NOT use platform-authenticator availability as
/// a proxy for PRF support. When an authenticator is present we return
/// [PasskeyCapability.walletRecoveryPrfUnknownUntilRegistration]; the real PRF
/// result is only known after a ceremony (see [prfOutputFromResponse]).
Future<PasskeyCapability> getPasskeyCapability() async {
  final supported = await isWalletBackupPasskeySupported();
  if (!supported) return PasskeyCapability.unsupported;
  return PasskeyCapability.walletRecoveryPrfUnknownUntilRegistration;
}

/// Extracts the base64url PRF output ("first") from a WebAuthn credential or
/// assertion response's `clientExtensionResults`, or null when PRF did not run.
String? prfOutputFromResponse(Map<String, dynamic>? response) {
  if (response == null) return null;
  final extensions = response['clientExtensionResults'];
  final prf = extensions is Map ? extensions['prf'] : null;
  if (prf is! Map) return null;
  final output = (prf['first'] ?? '').toString().trim();
  return output.isEmpty ? null : output;
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
    final output = prfOutputFromResponse(response);
    final credentialId =
        (response['id'] ?? response['rawId'] ?? '').toString().trim();
    return PasskeyRecoveryAssertionResult(
      verified: true,
      prfSupported: output != null,
      prfOutputBase64: output,
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
