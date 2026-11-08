import '../models/user_profile.dart';

/// Identifier used to load a profile's artist data (authored artworks and
/// collections): the wallet address when the account has one, otherwise its
/// public actor, profile or account id so a walletless artist still resolves.
/// Returns an empty string when nothing identifies the profile.
String profileArtistDataKey(UserProfile? profile) {
  if (profile == null) return '';
  final wallet = profile.walletAddress.trim();
  if (wallet.isNotEmpty) return wallet;
  for (final candidate in <String?>[
    profile.publicActorId,
    profile.id,
    profile.userId,
  ]) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
