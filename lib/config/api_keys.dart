/// API keys and environment configuration for the art.kubus Flutter app.
///
/// This file is **safe to commit**: it contains no secrets.
///
/// Runtime values are injected via `--dart-define` (compile-time environment)
/// in CI/CD or local builds.
///
/// Example:
///   flutter build apk --release \
///     --dart-define=KUBUS_WALLETCONNECT_PROJECT_ID=... \
///     --dart-define=KUBUS_PINATA_API_KEY=... \
///     --dart-define=KUBUS_PINATA_SECRET_KEY=...
class ApiKeys {
  // ================= Backend & API =================
  static const String backendUrl = String.fromEnvironment(
    'KUBUS_BACKEND_URL',
    defaultValue: 'https://api.kubus.site',
  );

  // ================= Solana / Web3 =================
  static const String solanaMainnetRpc = String.fromEnvironment(
    'KUBUS_SOLANA_MAINNET_RPC',
    defaultValue: 'https://api.mainnet-beta.solana.com',
  );
  static const String solanaDevnetRpc = String.fromEnvironment(
    'KUBUS_SOLANA_DEVNET_RPC',
    defaultValue: 'https://api.devnet.solana.com',
  );
  static const String solanaTestnetRpc = String.fromEnvironment(
    'KUBUS_SOLANA_TESTNET_RPC',
    defaultValue: 'https://api.testnet.solana.com',
  );
  static const String defaultSolanaNetwork = String.fromEnvironment(
    'KUBUS_DEFAULT_SOLANA_NETWORK',
    defaultValue: 'devnet',
  );
  static const String splTokenProgramId = String.fromEnvironment(
    'KUBUS_SPL_TOKEN_PROGRAM_ID',
    defaultValue: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
  );
  static const String kub8MintAddress = String.fromEnvironment(
    'KUBUS_KUB8_MINT_ADDRESS',
    defaultValue: 'BnRyTep3pLBJrBDt9UxbRYeh3jzQt4nrG99FT3yoKXrm',
  );
  static const int kub8Decimals = int.fromEnvironment(
    'KUBUS_KUB8_DECIMALS',
    defaultValue: 6,
  );
  static const String kubusTeamWallet = String.fromEnvironment(
    'KUBUS_TEAM_WALLET',
    defaultValue: 'A8FtJ7fvJHZfsmMLfT85rTE6itNCf4qu26A4nU9LeCZ2',
  );
  static const String kubusTreasuryWallet = String.fromEnvironment(
    'KUBUS_TREASURY_WALLET',
    defaultValue: 'F81jSXoiB15kcEERt8nxYabm5kgZ37jGbC9fmAQZMSws',
  );
  static const String wrappedSolMintAddress = String.fromEnvironment(
    'KUBUS_WRAPPED_SOL_MINT_ADDRESS',
    defaultValue: 'So11111111111111111111111111111111111111112',
  );

  // Dart (and Flutter) only support bool/int/String.fromEnvironment as consts.
  // For doubles, we parse at runtime from a compile-time string.
  static const String _kubusTeamFeePctRaw = String.fromEnvironment(
    'KUBUS_TEAM_FEE_PCT',
    defaultValue: '0.02',
  );
  static const String _kubusTreasuryFeePctRaw = String.fromEnvironment(
    'KUBUS_TREASURY_FEE_PCT',
    defaultValue: '0.03',
  );

  static double get kubusTeamFeePct => double.tryParse(_kubusTeamFeePctRaw) ?? 0.02;
  static double get kubusTreasuryFeePct => double.tryParse(_kubusTreasuryFeePctRaw) ?? 0.03;
  static const String jupiterBaseUrl = String.fromEnvironment(
    'KUBUS_JUPITER_BASE_URL',
    defaultValue: 'https://quote-api.jup.ag/v6',
  );

  // WalletConnect / Reown
  static const String walletConnectProjectId = String.fromEnvironment(
    'KUBUS_WALLETCONNECT_PROJECT_ID',
    defaultValue: '',
  );

  // ================= IPFS / Pinata =================
  static const String ipfsApiUrl = String.fromEnvironment(
    'KUBUS_IPFS_API_URL',
    defaultValue: 'https://api.pinata.cloud/pinning/pinFileToIPFS',
  );
  static const String pinataApiKey = String.fromEnvironment(
    'KUBUS_PINATA_API_KEY',
    defaultValue: '',
  );
  static const String pinataSecretKey = String.fromEnvironment(
    'KUBUS_PINATA_SECRET_KEY',
    defaultValue: '',
  );

  // ================= Google Auth =================
  /// Web OAuth client ID used for Google Sign-In token verification.
  /// (Client IDs are not secrets, but still configurable.)
  static const String googleClientId = String.fromEnvironment(
    'KUBUS_GOOGLE_CLIENT_ID',
    defaultValue: '623807687386-h0cbiqegcaint6s7gf4av9fvcvs1jmor.apps.googleusercontent.com',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'KUBUS_GOOGLE_WEB_CLIENT_ID',
    defaultValue: '623807687386-b08lhv474n1li9kkaasq46sag1s8gjcp.apps.googleusercontent.com',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'KUBUS_GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
}
