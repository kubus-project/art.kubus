import '../config/api_keys.dart';

/// Which assets are canonical KUB8 and SOL, KUB8's bundled logo, and which
/// image URLs count as token metadata. Shared by `SolanaWalletService` and
/// the wallet UI (`KubusTokenIdentity`), so it carries no Flutter UI code.
abstract final class TokenIdentityRules {
  /// The official kubus lattice mark bundled with the app, KUB8's known logo
  /// and the fallback whenever its metadata offers no usable image.
  static const String kub8LogoAsset = 'assets/images/logo.png';

  /// The sentinel `SolanaWalletService` uses for the chain's own asset, which
  /// has no mint account of its own.
  static const String nativeSolMint = 'native';

  /// Wrapped SOL. A real mint, and Solana's own, so it earns the mark too.
  static const String wrappedSolMint =
      'So11111111111111111111111111111111111111112';

  /// Whether [url] is a metadata image the wallet may load: a remote
  /// http(s) URL. The bundled asset path and empty values are not metadata.
  static bool isUsableMetadataImage(String? url) {
    final value = (url ?? '').trim();
    if (value.isEmpty || value == kub8LogoAsset) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  /// Whether [mint] is the KUB8 mint this build was configured with.
  ///
  /// A symbol is metadata: any SPL token can set its own to `KUB8`, and
  /// `SolanaWalletService._getTokenInfo` will happily read it from on-chain or
  /// off-chain metadata. The mint account is the identity, and it cannot be
  /// claimed. Base58 is case-sensitive, so this compares exactly.
  static bool isCanonicalKub8(String? mint) {
    final value = (mint ?? '').trim();
    if (value.isEmpty) return false;
    final expected = ApiKeys.kub8MintAddress.trim();
    return expected.isNotEmpty && value == expected;
  }

  /// Whether [mint] is SOL itself rather than a token calling itself SOL.
  static bool isCanonicalSol(String? mint) {
    final value = (mint ?? '').trim();
    return value == nativeSolMint || value == wrappedSolMint;
  }
}
