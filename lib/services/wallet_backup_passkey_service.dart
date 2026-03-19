import 'wallet_backup_passkey_service_stub.dart'
    if (dart.library.js_interop) 'wallet_backup_passkey_service_web.dart'
    as impl;

Future<bool> isWalletBackupPasskeySupported() =>
    impl.isWalletBackupPasskeySupported();

Future<Map<String, dynamic>> createWalletBackupPasskeyCredential(
  Map<String, dynamic> creationOptions,
) =>
    impl.createWalletBackupPasskeyCredential(creationOptions);

Future<Map<String, dynamic>> getWalletBackupPasskeyAssertion(
  Map<String, dynamic> requestOptions,
) =>
    impl.getWalletBackupPasskeyAssertion(requestOptions);
