import '../models/artwork.dart';
import '../models/user_profile.dart';

/// "I am the creator" support shared by the artwork create and edit forms.
///
/// Three concepts stay distinct: the uploader, the attributed author profile
/// and the free-text artist name. Ticking the box only ever speaks for the
/// signed-in account itself; no account id is sent and no other identity is
/// referenced, the backend resolves the acting account from the session.
class AuthoredBySelf {
  const AuthoredBySelf._();

  /// The profile display name the artist field shows while the box is ticked,
  /// or null when the box cannot be used (guest, or a profile without a
  /// display name).
  static String? displayNameFor(
    UserProfile? profile, {
    required bool isSignedIn,
  }) {
    if (!isSignedIn || profile == null) return null;
    final name = profile.displayName.trim();
    return name.isEmpty ? null : name;
  }

  /// Whether [artwork] is attributed to the signed-in profile itself, so the
  /// edit form starts with the box ticked.
  static bool isAttributedTo(Artwork artwork, UserProfile? profile) {
    final author = artwork.authorProfile;
    if (author == null || profile == null) return false;
    final own = profile.id.trim().toLowerCase();
    return own.isNotEmpty && own == author.profileId.trim().toLowerCase();
  }

  /// The `authoredBySelf` entry of an artwork update, or null when the box is
  /// unchanged. Unticking a previously ticked box is sent as false, which
  /// withdraws only the signed-in account's own declaration.
  static bool? updateFlagFor({required bool initial, required bool current}) =>
      initial == current ? null : current;
}
