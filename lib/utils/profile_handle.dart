import 'profile_edit_form_utils.dart';
import 'wallet_utils.dart';

/// Canonical normalization for a human profile handle (`@username`).
///
/// This is the single source of truth for turning a raw stored username into a
/// presentable handle across **every** owner and public profile surface
/// (mobile, desktop, community overlay, home rails). Unlike
/// [CreatorDisplayFormat.normalizeUsername] — which derives a *conservative*
/// slug from noisy, untrusted rail payloads (lowercasing, stripping Unicode,
/// capping length) — this helper preserves the user's real username exactly as
/// entered. It never invents an arbitrary maximum length and never mutates
/// valid Unicode.
///
/// A value resolves to *no handle* (`null`) when it is empty, a wallet address
/// or wallet-like fallback, a provisional generated identifier (`user_…`), a
/// known placeholder, or shorter than the application's enforced minimum
/// ([ProfileEditFormUtils.usernameMinLength]).
class ProfileHandle {
  /// The bare handle without any `@` prefix, preserving case and Unicode.
  final String value;

  const ProfileHandle._(this.value);

  /// The display form with exactly one leading `@`.
  String get display => '@$value';

  /// Known non-human placeholder tokens that must never render as a handle.
  static const Set<String> _placeholders = {
    'unknown',
    'anonymous',
    'n/a',
    'none',
    'null',
    'undefined',
    'user',
    'guest',
    'deleted',
  };

  /// Parses [raw] into a [ProfileHandle], or `null` when there is no valid
  /// human handle to show.
  ///
  /// Rules:
  /// - trims surrounding whitespace;
  /// - collapses one-or-more leading `@` into a single prefix;
  /// - rejects empty input;
  /// - rejects wallet addresses / wallet-like fallbacks;
  /// - rejects provisional generated identifiers (`user_…`) and placeholders;
  /// - rejects values below [ProfileEditFormUtils.usernameMinLength];
  /// - preserves valid Unicode usernames and original casing;
  /// - imposes no arbitrary maximum length.
  static ProfileHandle? parse(String? raw) {
    if (raw == null) return null;
    var handle = raw.trim();
    if (handle.isEmpty) return null;

    // Collapse any run of leading '@' into a single (removed) prefix.
    handle = handle.replaceFirst(RegExp(r'^@+'), '').trim();
    if (handle.isEmpty) return null;

    final lower = handle.toLowerCase();
    if (_placeholders.contains(lower)) return null;

    // Provisional generated identifier (e.g. `user_ab12cd`).
    if (lower.startsWith('user_')) return null;

    // Wallet address or wallet-like fallback must never masquerade as a handle.
    if (WalletUtils.looksLikeWallet(handle)) return null;

    // Honour the application's enforced minimum username length so we never
    // surface truncated or provisional fragments.
    if (handle.length < ProfileEditFormUtils.usernameMinLength) return null;

    return ProfileHandle._(handle);
  }

  /// Convenience: the display handle (`@username`) or `null`.
  static String? normalize(String? raw) => parse(raw)?.display;

  /// Convenience: `true` when [raw] resolves to a presentable handle.
  static bool isPresentable(String? raw) => parse(raw) != null;
}
