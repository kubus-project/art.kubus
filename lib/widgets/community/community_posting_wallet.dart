import 'package:shared_preferences/shared_preferences.dart';

/// Wallet address stored for the current account, or null when the account
/// has no wallet (email-only accounts). Mirrors the mobile posting gate.
Future<String?> readCommunityPostingWallet() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in const <String>[
    'wallet',
    'wallet_address',
    'walletAddress'
  ]) {
    final value = (prefs.getString(key) ?? '').trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

/// True when a post was rejected because the account has no wallet. The
/// backend answers 403 with `{ errorCode: 'WALLET_REQUIRED' }`, and
/// BackendApiRequestException.toString() carries that response body.
bool isCommunityWalletRequiredError(Object error) {
  return error.toString().contains('WALLET_REQUIRED');
}
