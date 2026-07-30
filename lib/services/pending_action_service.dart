import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_action_intent.dart';

/// Durable single-slot storage for the action a visitor attempted before they
/// had an account.
///
/// A single slot is intentional: the funnel only ever needs the most recent
/// attempt, and keeping one record means a stale intent can never accumulate.
/// Every read validates and expires the stored value, so a corrupted or
/// tampered preference degrades to "no pending action" instead of driving
/// navigation or a mutation.
///
/// All methods are defensive and never throw — the activation funnel must never
/// break public browsing.
class PendingActionService {
  const PendingActionService();

  static const String storageKey = 'kubus_pending_action_v1';

  /// Marks intents whose action already ran, so a refresh or a second
  /// confirmation tap cannot execute the same mutation twice.
  static const String completedKeyPrefix = 'kubus_pending_action_done_';

  Future<SharedPreferences> _prefs(SharedPreferences? prefs) async =>
      prefs ?? await SharedPreferences.getInstance();

  /// Persists [intent], replacing any earlier one. Invalid intents are ignored.
  Future<bool> save(
    PendingActionIntent intent, {
    SharedPreferences? prefs,
  }) async {
    if (!intent.isValid) return false;
    try {
      final p = await _prefs(prefs);
      await p.setString(storageKey, intent.encode());
      await p.remove('$completedKeyPrefix${intent.identityKey}');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reads the stored intent, dropping it when it is malformed or expired.
  Future<PendingActionIntent?> read({
    SharedPreferences? prefs,
    DateTime? nowUtc,
  }) async {
    try {
      final p = await _prefs(prefs);
      final intent = PendingActionIntent.decode(p.getString(storageKey));
      if (intent == null) {
        await p.remove(storageKey);
        return null;
      }
      if (!intent.isValid ||
          intent.isExpiredAt(nowUtc ?? DateTime.now().toUtc())) {
        await clear(prefs: p);
        return null;
      }
      return intent;
    } catch (_) {
      return null;
    }
  }

  /// True when the intent was already executed and must not run again.
  Future<bool> isCompleted(
    PendingActionIntent intent, {
    SharedPreferences? prefs,
  }) async {
    try {
      final p = await _prefs(prefs);
      return p.getBool('$completedKeyPrefix${intent.identityKey}') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Records that [intent] ran and removes it from the pending slot.
  Future<void> markCompleted(
    PendingActionIntent intent, {
    SharedPreferences? prefs,
  }) async {
    try {
      final p = await _prefs(prefs);
      await p.setBool('$completedKeyPrefix${intent.identityKey}', true);
      await p.remove(storageKey);
    } catch (_) {
      // Best effort: the in-memory guard in PendingActionProvider still holds.
    }
  }

  Future<void> clear({SharedPreferences? prefs}) async {
    try {
      final p = await _prefs(prefs);
      await p.remove(storageKey);
    } catch (_) {
      // Ignored.
    }
  }

  /// Drops the exactly-once marker so the same target can be actioned again in
  /// a later, deliberately re-captured intent.
  Future<void> clearCompletedMarker(
    PendingActionIntent intent, {
    SharedPreferences? prefs,
  }) async {
    try {
      final p = await _prefs(prefs);
      await p.remove('$completedKeyPrefix${intent.identityKey}');
    } catch (_) {
      // Ignored.
    }
  }
}
