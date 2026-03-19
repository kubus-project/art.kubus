Future<bool> isWalletBackupPasskeySupported() async => false;

Future<Map<String, dynamic>> createWalletBackupPasskeyCredential(
  Map<String, dynamic> creationOptions,
) async {
  throw UnsupportedError('Wallet backup passkeys are only available on web.');
}

Future<Map<String, dynamic>> getWalletBackupPasskeyAssertion(
  Map<String, dynamic> requestOptions,
) async {
  throw UnsupportedError('Wallet backup passkeys are only available on web.');
}
