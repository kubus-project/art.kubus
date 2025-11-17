class WalletUtils {
  /// Returns a canonical room key for the given wallet address.
  /// Ensures consistent lowercase formatting for sockets and server room names.
  static String roomKey(String? wallet) {
    if (wallet == null) return '';
    return wallet.toLowerCase();
  }

  /// Returns a canonical identicon key for a wallet (lowercased for stable URL)
  static String identiconKey(String? wallet) {
    if (wallet == null) return '';
    return wallet.toLowerCase();
  }
}
