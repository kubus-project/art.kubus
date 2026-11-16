import 'wallet_utils.dart';

final RegExp _canonicalProfileId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Distinct identity keys for artwork lists: wallet-managed, own-account, and
/// public authored-by-profile are separate backend scopes.
class ArtworkAuthorKey {
  const ArtworkAuthorKey._({this.wallet, this.accountId, this.profileId});

  /// Trimmed wallet, exactly as passed to the backend for wallet accounts.
  final String? wallet;

  /// Account id, set only when the account has no wallet.
  final String? accountId;

  /// Canonical `profiles.id`, distinct from the `users.id` account id.
  final String? profileId;

  /// The single rule for choosing the author key: wallet first, else account.
  /// Returns null when neither identifier is known.
  static ArtworkAuthorKey? resolve({
    String? walletAddress,
    String? accountId,
    String? profileId,
  }) {
    final wallet = walletAddress?.trim() ?? '';
    if (wallet.isNotEmpty) {
      return ArtworkAuthorKey._(wallet: wallet);
    }
    final id = accountId?.trim() ?? '';
    final profileCandidate = profileId?.trim() ?? '';
    final profile = _canonicalProfileId.hasMatch(profileCandidate)
        ? profileCandidate.toLowerCase()
        : '';
    if (id.isNotEmpty || profile.isNotEmpty) {
      return ArtworkAuthorKey._(
        accountId: id.isEmpty ? null : id,
        profileId: profile.isEmpty ? null : profile,
      );
    }
    return null;
  }

  bool get isWallet => wallet != null;
  bool get isPublicProfile => profileId != null;

  /// Cache key. Wallets are canonical, as the wallet cache has always been.
  String get cacheKey {
    if (isWallet) return 'wallet:${WalletUtils.canonical(wallet)}';
    if (profileId == null) return 'account:${accountId ?? ''}';
    if (accountId == null) return 'profile:$profileId';
    return 'account:$accountId|profile:$profileId';
  }

  /// Loading-state key. Wallet keys keep their historical operation name.
  String get loadOperationKey {
    if (isWallet) {
      return 'load_artworks_wallet_${WalletUtils.canonical(wallet)}';
    }
    if (profileId == null) return 'load_artworks_account_${accountId ?? ''}';
    if (accountId == null) return 'load_artworks_profile_$profileId';
    return 'load_artworks_account_${accountId}_$profileId';
  }

  @override
  bool operator ==(Object other) =>
      other is ArtworkAuthorKey &&
      other.wallet == wallet &&
      other.accountId == accountId &&
      other.profileId == profileId;

  @override
  int get hashCode => Object.hash(wallet, accountId, profileId);

  @override
  String toString() => 'ArtworkAuthorKey($cacheKey)';
}
