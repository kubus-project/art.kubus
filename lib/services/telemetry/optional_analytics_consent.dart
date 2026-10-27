import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AnalyticsPreferencesGetter = Future<SharedPreferences> Function();

/// The sole authority for optional analytics permission.
///
/// Legacy preferences never imply consent. A grant becomes effective only after
/// successful persistence; withdrawal invalidates in-flight work synchronously.
class OptionalAnalyticsConsent extends ChangeNotifier {
  OptionalAnalyticsConsent._({AnalyticsPreferencesGetter? preferencesGetter})
      : _preferencesGetter = preferencesGetter ?? SharedPreferences.getInstance;

  @visibleForTesting
  OptionalAnalyticsConsent.forTesting({
    required AnalyticsPreferencesGetter preferencesGetter,
  }) : this._(preferencesGetter: preferencesGetter);

  static final OptionalAnalyticsConsent instance = OptionalAnalyticsConsent._();
  static const String prefsKey = 'optional_analytics_consent_v2';

  AnalyticsPreferencesGetter _preferencesGetter;
  Future<void> _pending = Future<void>.value();
  bool _granted = false;
  int _generation = 0;
  // A failed denial must not be undone by re-reading the old durable grant.
  bool _unpersistedWithdrawal = false;

  bool get granted => _granted;
  int get generation => _generation;

  void _apply(bool value) {
    if (_granted == value) return;
    _granted = value;
    _generation += 1;
    notifyListeners();
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    // Keep the chain usable after a failed platform operation.
    _pending = next.catchError((Object _) {});
    return _pending;
  }

  /// Reloads durable state, including changes from another browser tab.
  /// Pending writes and generation checks prevent stale reads reviving consent.
  Future<bool> refresh() async {
    final expectedGeneration = _generation;
    await _serialize(() async {
      try {
        final prefs = await _preferencesGetter();
        await prefs.reload();
        final value = prefs.get(prefsKey) == true;
        if (_generation == expectedGeneration) {
          _apply(value && !_unpersistedWithdrawal);
        }
      } catch (_) {
        if (_generation == expectedGeneration) _apply(false);
      }
    });
    return _granted;
  }

  Future<void> setGranted(bool value) {
    final operationGeneration = ++_generation;
    if (!value) _unpersistedWithdrawal = true;
    // Granting also waits in the denied state until the write succeeds.
    _granted = false;
    notifyListeners();
    return _serialize(() async {
      try {
        final prefs = await _preferencesGetter();
        final saved = await prefs.setBool(prefsKey, value);
        if (!saved) throw StateError('Analytics choice was not persisted');
        if (_generation == operationGeneration) {
          _unpersistedWithdrawal = false;
          _apply(value);
        }
        // Compatibility only: this key is never read as a permission grant.
        try {
          await prefs.setBool('enableAnalytics', value);
        } catch (_) {}
      } catch (_) {
        if (_generation == operationGeneration) _apply(false);
      }
    });
  }

  @visibleForTesting
  Future<void> resetForTesting({
    AnalyticsPreferencesGetter? preferencesGetter,
  }) async {
    await _pending;
    _preferencesGetter = preferencesGetter ?? SharedPreferences.getInstance;
    _granted = false;
    _generation = 0;
    _unpersistedWithdrawal = false;
    notifyListeners();
  }
}
