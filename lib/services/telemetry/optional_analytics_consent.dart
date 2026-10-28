import 'dart:convert';
import 'dart:math';

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
  Future<void>? _pending;
  bool _granted = false;
  String? _revision;
  String? get revision => _revision;
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
    final previous = _pending;
    final next = previous == null
        ? Future<void>.sync(operation)
        : previous.then((_) => operation());
    // Keep the chain usable after a failed platform operation.
    _pending = next.catchError((Object _) {});
    return _pending!;
  }

  /// Reloads durable state, including changes from another browser tab.
  /// Pending writes and generation checks prevent stale reads reviving consent.
  Future<bool> refresh() async {
    final expectedGeneration = _generation;
    await _serialize(() async {
      try {
        final prefs = await _preferencesGetter();
        await prefs.reload();
        final receipt = _readReceipt(prefs);
        if (_generation == expectedGeneration) {
          final revision = receipt?['revision'] as String?;
          final changed = revision != _revision;
          _revision = revision;
          if (changed) {
            _generation += 1;
          }
          final old = _granted;
          _apply(receipt?['granted'] == true && !_unpersistedWithdrawal);
          if (changed && old == _granted) notifyListeners();
        }
      } catch (_) {
        if (_generation == expectedGeneration) _apply(false);
      }
    });
    return _granted;
  }

  Future<void> setGranted(bool value) {
    final operationGeneration = ++_generation;
    final revision =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    if (!value) _unpersistedWithdrawal = true;
    // Granting also waits in the denied state until the write succeeds.
    _granted = false;
    notifyListeners();
    return _serialize(() async {
      try {
        final prefs = await _preferencesGetter();
        final saved = await prefs.setString(prefsKey,
            jsonEncode({'v': 2, 'granted': value, 'revision': revision}));
        if (!saved) throw StateError('Analytics choice was not persisted');
        if (_generation == operationGeneration) {
          _unpersistedWithdrawal = false;
          _revision = revision;
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

  static Map<String, dynamic>? _readReceipt(SharedPreferences prefs) {
    try {
      final raw = prefs.get(prefsKey);
      if (raw is! String) return null;
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['v'] != 2 ||
          value['granted'] is! bool ||
          value['revision'] is! String ||
          (value['revision'] as String).isEmpty) {
        return null;
      }
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }

  static String? storedRevision(SharedPreferences prefs) =>
      _readReceipt(prefs)?['revision'] as String?;

  static bool hasStoredPermission(SharedPreferences prefs) =>
      _readReceipt(prefs)?['granted'] == true;

  @visibleForTesting
  Future<void> resetForTesting({
    AnalyticsPreferencesGetter? preferencesGetter,
  }) async {
    await _pending;
    _pending = null;
    _preferencesGetter = preferencesGetter ?? SharedPreferences.getInstance;
    _granted = false;
    _revision = null;
    _generation = 0;
    _unpersistedWithdrawal = false;
    notifyListeners();
  }
}
