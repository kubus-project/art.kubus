class WalletUtils {
  /// Returns a canonical room key for the given wallet address.
  /// Wallet addresses are case-sensitive, so we preserve the original casing
  /// and only trim surrounding whitespace.
  static String roomKey(String? wallet) => canonical(wallet);

  /// Returns a canonical identicon key for a wallet (case preserved).
  static String identiconKey(String? wallet) => canonical(wallet);

  /// Normalizes any wallet-like identifier by trimming whitespace while preserving case.
  static String normalize(String? wallet) {
    if (wallet == null) return '';
    return wallet.trim();
  }

  /// Returns true if the string looks like a valid wallet address format.
  ///
  /// Supports:
  /// - Ethereum (0x + 40 hex chars)
  /// - Solana (base58, 32-44 chars, no spaces, alphanumeric)
  /// - Other base58/base64 identifiers (>= 32 chars, no spaces or special chars)
  ///
  /// Returns false for display names, usernames, or obviously non-wallet strings.
  static bool looksLikeWallet(String? wallet) {
    final normalized = normalize(wallet);
    if (normalized.isEmpty) return false;
    // Reject known placeholder strings
    const placeholders = {'unknown', 'anonymous', 'n/a', 'none', 'null', 'undefined'};
    if (placeholders.contains(normalized.toLowerCase())) return false;
    // Reject strings with spaces (display names typically have spaces)
    if (normalized.contains(' ')) return false;
    // Reject strings with special characters typical of names but not wallets
    if (RegExp(r'[+@#\$%\^&\*\(\)!,\?]').hasMatch(normalized)) return false;
    // Ethereum address: 0x + 40 hex characters
    if (RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(normalized)) return true;
    // Solana address: base58, typically 32-44 characters
    // Base58 alphabet: 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz
    if (normalized.length >= 32 && normalized.length <= 44) {
      if (RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$').hasMatch(normalized)) return true;
    }
    // Generic: long alphanumeric string (>= 32 chars) without spaces
    if (normalized.length >= 32 && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  /// Returns a canonical representation for comparisons (case preserved).
  static String canonical(String? wallet) => normalize(wallet);

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

  /// Returns true if [value] looks like a valid Solana wallet address.
  /// Solana addresses are base58 encoded public keys, typically 32-44 characters,
  /// containing only alphanumeric characters (no 0, O, I, l to avoid ambiguity).
  static bool looksLikeWalletAddress(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    // Solana addresses are typically 32-44 chars, base58 (no 0, O, I, l)
    if (trimmed.length < 32 || trimmed.length > 44) return false;
    // Base58 alphabet: 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz
    // Quick check: must not contain spaces, must be alphanumeric
    if (trimmed.contains(' ')) return false;
    // Check for invalid base58 characters
    final invalidChars = RegExp(r'[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]');
    return !invalidChars.hasMatch(trimmed);
  }
}
