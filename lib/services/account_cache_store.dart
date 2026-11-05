import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Captured before an asynchronous lookup, never inferred from its response.
final class AccountCacheScope {
  AccountCacheScope.capture()
      : account = AccountCacheStore.owner,
        generation = AccountCacheStore.generation;

  final String account;
  final int generation;
  bool get isCurrent =>
      account == AccountCacheStore.owner &&
      generation == AccountCacheStore.generation;
}

/// Disposable account caches. Envelopes never adopt another account's bytes.
abstract final class AccountCacheStore {
  static const _prefix = 'account_cache_v1.';
  static const _pendingKey = 'account_cache_purge_pending_v1';
  static const legacyKeys = <String>{
    'cache_provider_avatars_v1',
    'cache_provider_display_names_v1',
    'user_cache_v1',
    'profile_critical_cache_v3',
    'profile_package_cache_v1',
    'in_app_notifications',
    'following_users',
    'username',
    'user_profile',
    'user_id',
    'private_profile',
    'allow_messages',
    'show_activity_status',
    'show_achievements',
    'showAchievements',
    'share_last_visited_location',
    'show_collection',
  };
  static int _generation = 0;
  static bool _disabled = false;
  static bool _legacyCleaned = false;
  static Future<void>? _tail;

  static String _owner = '';

  /// Called exclusively by the canonical AccountIdentity setter.
  static void bindAccount(String account) => _owner = account;

  static String get owner => _owner;
  static int get generation => _generation;

  static Future<T> _serialized<T>(Future<T> Function() operation) {
    final previous = _tail;
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<dynamic> read(String key) {
    final account = owner;
    final epoch = _generation;
    return _serialized(() async {
      if (_disabled || epoch != _generation || account != owner) {
        return null;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(_pendingKey) == true) {
          return null;
        }
        // Legacy entries have no trustworthy owner, so never hydrate them.
        if (!_legacyCleaned) {
          for (final legacy in prefs.getKeys().toList()) {
            if (legacy == 'cache_provider_avatars_v1' ||
                legacy == 'cache_provider_display_names_v1' ||
                legacy == 'user_cache_v1' ||
                legacy == 'profile_critical_cache_v3' ||
                legacy == 'profile_package_cache_v1' ||
                legacy == 'in_app_notifications' ||
                legacy == 'following_users' ||
                legacy.startsWith('following_users_')) {
              if (!await prefs.remove(legacy)) {
                _disabled = true;
                return null;
              }
            }
          }
          _legacyCleaned = true;
        }
        for (final legacy in <String>[
          key,
          if (key == 'profile_critical_cache_v3') 'profile_package_cache_v1',
        ]) {
          if ((legacyKeys.contains(legacy) ||
                  legacy.startsWith('following_users_')) &&
              prefs.containsKey(legacy) &&
              !await prefs.remove(legacy)) {
            _disabled = true;
            return null;
          }
        }
        final raw = prefs.getString('$_prefix$key');
        if (raw == null) {
          return null;
        }
        final record = jsonDecode(raw);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (record is! Map ||
            record['owner'] != account ||
            record['expiresAt'] is! int ||
            record['expiresAt'] <= now) {
          await prefs.remove('$_prefix$key');
          return null;
        }
        if (epoch != _generation || account != owner) {
          return null;
        }
        return record['data'];
      } catch (_) {
        _disabled = true;
        return null;
      }
    });
  }

  static Future<void> write(String key, dynamic data,
      {required String account,
      required int generation,
      Duration ttl = const Duration(hours: 24)}) {
    // Encode now: callers may mutate their maps while this write is queued.
    final encoded = jsonEncode(<String, dynamic>{
      'owner': account,
      'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
      'data': data,
    });
    return _serialized(() async {
      if (_disabled || generation != _generation || account != owner) {
        return;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        if (generation != _generation ||
            account != owner ||
            prefs.getBool(_pendingKey) == true) {
          return;
        }
        if (!await prefs.setString('$_prefix$key', encoded)) {
          _disabled = true;
        }
      } catch (_) {
        _disabled = true;
      }
    });
  }

  /// Invalidates queued reads/writes immediately, then removes disk copies.
  /// A durable intent rejects restoration if any deletion failed.
  static Future<void> purge() {
    _generation++;
    _disabled = true;
    return _serialized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        var complete = await prefs.setBool(_pendingKey, true);
        for (final key in prefs.getKeys().toList()) {
          if (!key.startsWith(_prefix) &&
              !key.startsWith('following_users_') &&
              !legacyKeys.contains(key)) {
            continue;
          }
          try {
            if (!await prefs.remove(key)) complete = false;
          } catch (_) {
            complete = false;
          }
        }
        if (complete && await prefs.remove(_pendingKey)) {
          _disabled = false;
        }
      } catch (_) {
        // No storage result is interpreted as successful erasure.
      }
    });
  }

  static Future<void> remove(String key) {
    final account = owner;
    final epoch = _generation;
    return _serialized(() async {
      if (account != owner || epoch != _generation) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.remove('$_prefix$key')) _disabled = true;
      } catch (_) {
        _disabled = true;
      }
    });
  }

  /// Starts a test with an empty queue. A widget test can end with a cache
  /// operation still in flight; its zone is gone, so it never completes and
  /// would hold every later [read] and [write] of the isolate behind it.
  @visibleForTesting
  static void discardQueueForTesting() {
    _tail = null;
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await _tail;
    _generation++;
    _disabled = false;
    _legacyCleaned = false;
  }
}
