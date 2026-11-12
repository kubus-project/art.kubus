import '../models/user_profile.dart';

String _trimmed(String? value) => value?.trim() ?? '';

/// Ids the app invents locally while the authoritative profile is unavailable
/// (`profile_<user id>`, `profile_fallback_<wallet prefix>`). They are not
/// backend ids and must never be sent as a profile/account id.
bool isSyntheticProfileId(String? value) =>
    _trimmed(value).startsWith('profile_');

/// Identifier used to load a profile's artist data (locally generated
/// `profile_...` ids are skipped, so a cached placeholder profile falls back to
/// its real wallet) (authored artworks and
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
    if (value.isNotEmpty && !isSyntheticProfileId(value)) return value;
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

/// Number of authored works of the signed-in owner when no wallet-keyed stats
/// snapshot exists (a walletless account).
///
/// The canonical figure is the `total` of
/// `GET /api/profiles/:id/artworks?relationship=authored`, the same set and
/// visibility the wallet-keyed `authoredArtworks` counter reports. Older
/// backends do not honour `relationship` and send no total; then the loaded
/// list is the count only when it is complete (shorter than the page that was
/// requested), never a page-capped length. Null means unknown.
int? ownerAuthoredWorksCount({
  required int? serverTotal,
  required int loadedCount,
  int loadLimit = 6,
}) {
  if (serverTotal != null && serverTotal >= 0) return serverTotal;
  if (loadedCount > 0 && loadedCount < loadLimit) return loadedCount;
  return null;
}

/// The profile's own wallet, as the legacy collections fallback of
/// [profileArtistDataKey]: only when the key is an id (collections made before
/// accounts owned them carry the wallet, not `owner_id`). Empty for a
/// walletless profile and for a wallet-keyed one, which needs no fallback.
String profileLegacyWalletKey(UserProfile? profile) {
  final key = profileArtistDataKey(profile);
  final wallet = _trimmed(profile?.walletAddress);
  if (key.isEmpty || wallet.isEmpty || key == wallet) return '';
  return wallet;
}
