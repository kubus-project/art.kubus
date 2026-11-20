import 'package:art_kubus/services/account_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// True when the session has an identity to publish as: a stored wallet, or a
/// signed-in account. A walletless account posts as itself; the backend keys
/// its posts by account id. A guest (no account id) has neither.
Future<bool> communityPostingHasIdentity() async {
  if (await readCommunityPostingWallet() != null) return true;
  return AccountIdentity.accountKey.trim().isNotEmpty;
}

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
