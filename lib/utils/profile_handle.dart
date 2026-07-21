import 'username_policy.dart';

/// Canonical presentation of a human profile handle (`@username`).
///
/// This is the single source of truth for turning a stored username into a
/// presentable handle across **every** owner and public profile surface
/// (mobile, desktop, community overlay, home rails).
///
/// It owns no rules of its own: acceptance is delegated wholesale to
/// [UsernamePolicy], the same contract that backs profile-edit and onboarding
/// validation. That delegation is what guarantees the invariant asserted in
/// `test/utils/username_policy_test.dart` — *anything a human can save, a
/// profile can show.*
///
/// Unlike [CreatorDisplayFormat.normalizeUsername] — which derives a
/// *conservative* slug from noisy, untrusted rail payloads (lowercasing,
/// stripping Unicode, capping length) — this helper preserves the user's real
/// username exactly as entered.
class ProfileHandle {
  /// The bare handle without any `@` prefix, preserving case and Unicode.
  final String value;

  const ProfileHandle._(this.value);

  /// The display form with exactly one leading `@`.
  String get display => '@$value';

  /// Parses [raw] into a [ProfileHandle], or `null` when there is no valid
  /// human handle to show.
  ///
  /// Resolves to `null` for exactly the values [UsernamePolicy] refuses:
  /// empty input, wallet addresses, provisional `user_…` identifiers,
  /// placeholder tokens, and values outside the 3–50 character range.
  static ProfileHandle? parse(String? raw) {
    if (!UsernamePolicy.accepts(raw)) return null;
    return ProfileHandle._(UsernamePolicy.normalize(raw)!);
  }

  /// Convenience: the display handle (`@username`) or `null`.
  static String? normalize(String? raw) => parse(raw)?.display;

  /// Convenience: `true` when [raw] resolves to a presentable handle.
  static bool isPresentable(String? raw) => parse(raw) != null;
}
