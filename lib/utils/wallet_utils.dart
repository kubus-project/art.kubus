class WalletUtils {
  /// Returns a canonical room key for the given wallet address.
  /// Ensures consistent lowercase formatting for sockets and server room names.
  static String roomKey(String? wallet) => canonical(wallet);

  /// Returns a canonical identicon key for a wallet (lowercased for stable URL)
  static String identiconKey(String? wallet) => canonical(wallet);

  /// Normalizes any wallet-like identifier by trimming whitespace while preserving case.
  static String normalize(String? wallet) {
    if (wallet == null) return '';
    return wallet.trim();
  }

  /// Returns a lowercase canonical representation for comparisons.
  static String canonical(String? wallet) => normalize(wallet).toLowerCase();

  /// Returns true when both wallets resolve to the same canonical identifier.
  static bool equals(String? a, String? b) => canonical(a) == canonical(b);

  /// Resolves the best wallet identifier from known keys within a payload.
  /// Falls back to [fallback] when no keys contain a value.
  static String resolveFromMap(Map<String, dynamic>? payload, {String? fallback}) {
    if (payload != null) {
      for (final key in const ['wallet_address', 'walletAddress', 'wallet', 'id', 'address', 'publicKey', 'public_key']) {
        final value = payload[key];
        if (value == null) continue;
        final normalized = normalize(value.toString());
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return normalize(fallback);
  }

  /// Picks the first non-empty identifier from the provided candidates and normalizes it.
  static String coalesce({String? walletAddress, String? wallet, String? userId, String? fallback}) {
    for (final candidate in [walletAddress, wallet, userId, fallback]) {
      final normalized = normalize(candidate);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }
}
