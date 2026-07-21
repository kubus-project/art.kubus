/// Why a username was refused by [UsernamePolicy].
///
/// Every value maps 1:1 onto a localized profile-edit error, so validation and
/// presentation can never disagree about *which* rule fired.
enum UsernameRejection {
  /// Empty, whitespace-only, or nothing left after stripping `@`.
  empty,

  /// Shorter than [UsernamePolicy.minLength].
  tooShort,

  /// Longer than [UsernamePolicy.maxLength].
  tooLong,

  /// A system-reserved identifier a human can never persist: the provisional
  /// `user_…` prefix or a placeholder token.
  reserved,

  /// Indistinguishable from a blockchain wallet address.
  walletLike,
}

/// The single canonical username contract for art.kubus.
///
/// One policy backs **all four** username code paths, so a name accepted in one
/// place can never vanish in another:
///
/// 1. profile-edit validation (`ProfileEditFormUtils.validateUsername`);
/// 2. onboarding / auth-methods validation
///    (`validateAuthMethodsPanelUsername`);
/// 3. profile handle presentation (`ProfileHandle`);
/// 4. the round-trip invariant asserted in
///    `test/utils/username_policy_test.dart`.
///
/// ## Where the limits come from
///
/// * **min 3** — already enforced identically by profile edit
///   (`usernameMinLength`) and onboarding (`authMethodsPanelUsernameMinLength`).
/// * **max 50** — the database columns are `users.username character
///   varying(50)` and `profiles.username character varying(50)`; onboarding
///   already enforced 50 via `authMethodsPanelUsernameMaxLength` and the
///   localized string `profileEditUsernameMaxLengthError` ("Username must be 50
///   characters or fewer") already shipped in EN + SL. Profile edit was the
///   only path missing it.
/// * **`user_` is system-reserved** — the backend profile upsert drops any
///   client-supplied username starting with `user_`
///   (`backend/src/routes/profiles.js`: `if (provided.startsWith("user_"))
///   provided = "";`). The Flutter side mints the same shape as a provisional
///   local identifier (`user_<wallet prefix>`). A human therefore *cannot*
///   persist a `user_…` username through the edit flow, which is exactly the
///   documented exception to the "everything accepted is displayable"
///   invariant. Rejecting it in validation turns a silent server-side no-op
///   into an explicit, localized error.
/// * **wallet-shaped names are refused** — a handle must never let a wallet
///   address masquerade as a person.
///
/// ## Why not `WalletUtils.looksLikeWallet`
///
/// That helper deliberately over-matches ("any `[A-Za-z0-9_-]{32,}` is a
/// wallet") because its ~20 call sites resolve *untrusted identifiers* where a
/// false positive is harmless. For usernames a false positive silently deletes
/// a legitimate person's handle, so [isWalletIdentifier] below matches only the
/// two address formats art.kubus actually accepts. `looksLikeWallet` is left
/// untouched for its existing callers.
class UsernamePolicy {
  UsernamePolicy._();

  /// Shortest accepted username.
  static const int minLength = 3;

  /// Longest accepted username — matches `character varying(50)` on both
  /// `users.username` and `profiles.username`.
  static const int maxLength = 50;

  /// Prefix the backend refuses to persist from the human edit flow, and which
  /// the client uses for provisional wallet-derived identifiers.
  static const String reservedProvisionalPrefix = 'user_';

  /// Non-human tokens that must never be stored or rendered as a handle.
  static const Set<String> reservedNames = {
    'anonymous',
    'deleted',
    'guest',
    'n/a',
    'none',
    'null',
    'undefined',
    'unknown',
    'user',
  };

  /// Strips surrounding whitespace and any run of leading `@`.
  ///
  /// Returns `null` when nothing usable remains, so a lone `@`, `@@@`, or a
  /// whitespace-only value can never produce a `@@name` or bare `@` handle.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final withoutAt = raw.trim().replaceFirst(RegExp(r'^@+'), '').trim();
    return withoutAt.isEmpty ? null : withoutAt;
  }

  /// `true` when [value] is a wallet address art.kubus can actually hold.
  ///
  /// Matches only Ethereum (`0x` + 40 hex) and Solana base58 keys (32–44 chars).
  /// Base58 excludes `_`, `-`, `0`, `O`, `I` and `l`, so ordinary long
  /// usernames — which almost always contain one of those — stay displayable.
  static bool isWalletIdentifier(String value) {
    if (RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value)) return true;
    if (value.length >= 32 &&
        value.length <= 44 &&
        RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$').hasMatch(value)) {
      return true;
    }
    return false;
  }

  /// `true` when [value] is the provisional `user_…` shape the backend strips.
  static bool isProvisionalIdentifier(String value) =>
      value.toLowerCase().startsWith(reservedProvisionalPrefix);

  /// Why [raw] cannot be used as a username, or `null` when it is acceptable.
  ///
  /// This is the one function both validation and presentation call.
  static UsernameRejection? rejectionFor(String? raw) {
    final value = normalize(raw);
    if (value == null) return UsernameRejection.empty;

    final lower = value.toLowerCase();
    if (reservedNames.contains(lower) || isProvisionalIdentifier(value)) {
      return UsernameRejection.reserved;
    }
    if (isWalletIdentifier(value)) return UsernameRejection.walletLike;

    // Count runes, not UTF-16 code units, so a Unicode name is measured the way
    // the person typing it counts it.
    final length = value.runes.length;
    if (length < minLength) return UsernameRejection.tooShort;
    if (length > maxLength) return UsernameRejection.tooLong;
    return null;
  }

  /// `true` when [raw] is a username a human may store *and* see rendered.
  static bool accepts(String? raw) => rejectionFor(raw) == null;
}
