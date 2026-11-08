import '../models/user_profile.dart';

String _trimmed(String? value) => value?.trim() ?? '';

/// Identifier used to load a profile's artist data (authored artworks and
/// collections). Profile id first, then account id: the backend resolves both
/// on `GET /api/profiles/:id/artworks` and `GET /api/collections?ownerId=`,
/// so a walletless artist and a wallet artist load through the same path. The
/// wallet address is only a legacy fallback for a profile that has neither id,
/// and the public actor id is the last resort. Returns an empty string when
/// nothing identifies the profile.
String profileArtistDataKey(UserProfile? profile) {
  if (profile == null) return '';
  for (final candidate in <String?>[
    profile.id,
    profile.userId,
    profile.walletAddress,
    profile.publicActorId,
  ]) {
    final value = _trimmed(candidate);
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// Key the profile events are matched against. Events reference creators by
/// wallet, so a profile with a wallet matches on it; a walletless profile
/// matches on its artist data key.
String profileEventsMatchKey(UserProfile? profile) {
  if (profile == null) return '';
  final wallet = _trimmed(profile.walletAddress);
  if (wallet.isNotEmpty) return wallet;
  return profileArtistDataKey(profile);
}
