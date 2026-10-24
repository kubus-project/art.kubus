import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one place that announces the signed-in identity changed: a session was
/// cleared (sign-out, a token for another wallet, a suspended or deleted
/// account), a wallet was disconnected, or a token for another account was set.
///
/// Listeners run synchronously when [notifyChanged] is called, before its first
/// await, so account-scoped caches are dropped at the change itself and never
/// depend on the sign-out flow reaching them. The device-level keys that hold
/// the previous account's local data are purged afterwards.
abstract final class AccountIdentity {
  static final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Preference keys that hold account-scoped data on this device.
  static const List<String> _purgedKeys = <String>[
    // Artwork view history: what the previous account browsed.
    'artwork_view_history_v1',
    // Blocked wallets and reported posts are local to the device.
    'blocked_wallets_v1',
    'reported_posts',
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

  @visibleForTesting
  static int get listenerCount => _listeners.length;

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
}
