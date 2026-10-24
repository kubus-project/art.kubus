import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/wallet_utils.dart';

/// The one place that tracks which account this device is signed in as, and
/// announces when that identity changes: a session was cleared (sign-out, a
/// token for another wallet, a suspended or deleted account), a wallet was
/// disconnected, or a token for another account was set.
///
/// Listeners run synchronously when [notifyChanged] is called, before its first
/// await, so account-scoped caches are dropped at the change itself. The
/// device-level records that belong to one account (blocks and reports) are
/// stored under a key scoped to that account, so a returning account finds
/// them again. Other device-level data of the previous account is purged.
abstract final class AccountIdentity {
  static final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Device-level records kept per account. The unscoped keys are the legacy
  /// form, adopted once by the first account that signs in.
  static const String blockedWalletsKey = 'blocked_wallets_v1';
  static const String reportedPostsKey = 'reported_posts';

  /// Preference keys purged on every identity change: data the previous
  /// account must not leave behind for the next one on this device.
  static const List<String> _purgedKeys = <String>[
    // Artwork view history: what the previous account browsed.
    'artwork_view_history_v1',
    // Local collectible and institution stores.
    'collectibles_v1',
    'collectible_series_v1',
    'institutions_v1',
    'institution_events_v1',
  ];

  /// Key prefixes purged the same way, for per-event registration records.
  static const List<String> _purgedKeyPrefixes = <String>[
    'event_registrations_v1_',
  ];

  /// The stable id of the signed-in account, or empty for a guest.
  static String _accountKey = '';

  /// The one-time adoption of the legacy unscoped records, shared by every
  /// caller. Set by the first signed-in account; later accounts do not adopt.
  static Future<void>? _legacyAdoption;

  @visibleForTesting
  static int get listenerCount => _listeners.length;

  /// The signed-in account's stable id, or empty for a guest.
  static String get accountKey => _accountKey;

  /// Records which account the session belongs to. Does not announce a change;
  /// the caller that ends or switches a session calls [notifyChanged] too.
  static void setAccountKey(String key) {
    _accountKey = key.trim();
    if (_accountKey.isNotEmpty) unawaited(adoptLegacyRecords(_accountKey));
  }

  /// A preference key for [base] that belongs to one account. Null for a guest,
  /// who has no stored copy of such records.
  static String? scopedKey(String base, {String? accountKey}) {
    final owner = (accountKey ?? _accountKey).trim();
    if (owner.isEmpty) return null;
    final safe = owner.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return '$base.$safe';
  }

  /// Moves the legacy unscoped block and report records to [key] and deletes
  /// the unscoped copies. Runs once per device: the first signed-in account
  /// adopts them, and the same future answers every later caller. On a shared
  /// device, an account that signs in first after the upgrade inherits the
  /// previous users' unscoped blocks and reports; this is accepted and one-time.
  static Future<void> adoptLegacyRecords(String key) {
    final owner = key.trim();
    if (owner.isEmpty) return Future<void>.value();
    return _legacyAdoption ??= _adoptLegacyRecords(owner);
  }

  static Future<void> _adoptLegacyRecords(String owner) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final legacyBlocked = prefs.getString(blockedWalletsKey);
      if (legacyBlocked != null) {
        final target = scopedKey(blockedWalletsKey, accountKey: owner)!;
        final merged = <String>{
          ...decodeWalletList(prefs.getString(target)),
          ...decodeWalletList(legacyBlocked),
        };
        await prefs.setString(target, jsonEncode(merged.toList()));
        await prefs.remove(blockedWalletsKey);
      }

      final legacyReported = prefs.getStringList(reportedPostsKey);
      if (legacyReported != null) {
        final target = scopedKey(reportedPostsKey, accountKey: owner)!;
        final merged = <String>[...?prefs.getStringList(target)];
        for (final report in legacyReported) {
          if (!merged.contains(report)) merged.add(report);
        }
        await prefs.setStringList(target, merged);
        await prefs.remove(reportedPostsKey);
      }
    } catch (e) {
      // Leave the legacy records in place and let a later call retry.
      _legacyAdoption = null;
      if (kDebugMode) {
        debugPrint('AccountIdentity: legacy adoption failed: $e');
      }
    }
  }

  /// Reads a stored per-account block set: a JSON list of wallet addresses.
  static Set<String> decodeWalletList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<String>()
          .map((e) => WalletUtils.canonical(e))
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Announces an identity change. Listeners run now; the returned future
  /// completes once the device-level account keys are purged.
  static Future<void> notifyChanged() async {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      try {
        listener();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('AccountIdentity: listener failed: $e');
        }
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _purgedKeys) {
        await prefs.remove(key);
      }
      for (final key in prefs.getKeys().toList(growable: false)) {
        if (_purgedKeyPrefixes.any(key.startsWith)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountIdentity: purge failed: $e');
      }
    }
  }

  /// Clears the account and the one-time adoption. Tests only.
  @visibleForTesting
  static void resetForTesting() {
    _accountKey = '';
    _legacyAdoption = null;
  }
}
