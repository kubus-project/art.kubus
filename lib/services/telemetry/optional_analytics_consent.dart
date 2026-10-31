import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'family_consent_context.dart';

typedef AnalyticsPreferencesGetter = Future<SharedPreferences> Function();

/// The sole authority for optional analytics permission.
///
/// Legacy preferences never imply consent. A grant becomes effective only after
/// successful persistence; withdrawal invalidates in-flight work synchronously.
class OptionalAnalyticsConsent extends ChangeNotifier {
  OptionalAnalyticsConsent._(
      {AnalyticsPreferencesGetter? preferencesGetter,
      String? Function()? familyContextGetter})
      : _preferencesGetter = preferencesGetter ?? SharedPreferences.getInstance,
        _familyContextGetter = familyContextGetter ?? readFamilyConsentContext;

  @visibleForTesting
  OptionalAnalyticsConsent.forTesting({
    required AnalyticsPreferencesGetter preferencesGetter,
    String? Function()? familyContextGetter,
  }) : this._(
            preferencesGetter: preferencesGetter,
            familyContextGetter: familyContextGetter);

  static final OptionalAnalyticsConsent instance = OptionalAnalyticsConsent._();
  static const String prefsKey = 'optional_analytics_consent_v2';

  AnalyticsPreferencesGetter _preferencesGetter;
  final String? Function() _familyContextGetter;
  String? _familyContext;
  void Function()? _stopFamilyObserver;
  Future<void>? _pending;
  bool _granted = false;
  String? _revision;
  String? get revision => _revision;
  int _generation = 0;
  // A failed denial must not be undone by re-reading the old durable grant.
  bool _unpersistedWithdrawal = false;

  bool get granted =>
      _granted &&
      _familyContextGetter() != '!unavailable' &&
      _familyContextGetter() == _familyContext;
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
    _stopFamilyObserver ??=
        observeFamilyConsentContext(() => unawaited(refresh()));
    final expectedGeneration = _generation;
    await _serialize(() async {
      try {
        final prefs = await _preferencesGetter();
        await prefs.reload();
        final family = _familyContextGetter();
        final receipt = _readReceipt(prefs, familyContext: family);
        if (_generation == expectedGeneration) {
          _familyContext = family;
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
    return granted;
  }

  Future<void> setGranted(bool value) {
    final family = _familyContextGetter();
    final operationGeneration = ++_generation;
    final revision =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
    if (!value) _unpersistedWithdrawal = true;
    // Granting also waits in the denied state until the write succeeds.
    _granted = false;
    notifyListeners();
    return _serialize(() async {
      try {
        final prefs = await _preferencesGetter();
        if (value && family == '!unavailable') {
          throw StateError('Family preferences unavailable');
        }
        final saved = await prefs.setString(
            prefsKey,
            jsonEncode({
              'v': 2,
              'granted': value,
              'revision': revision,
              if (family != null) 'familyContext': family,
            }));
        if (!saved) throw StateError('Analytics choice was not persisted');
        if (_generation == operationGeneration) {
          _unpersistedWithdrawal = false;
          _revision = revision;
          _familyContext = family;
          _apply(value && family == _familyContextGetter());
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

  static Map<String, dynamic>? _readReceipt(SharedPreferences prefs,
      {String? familyContext}) {
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
      if (familyContext != null &&
          (familyContext == '!unavailable' ||
              value['familyContext'] != familyContext)) {
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
      _readReceipt(prefs,
          familyContext: readFamilyConsentContext())?['granted'] ==
      true;

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
    _familyContext = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopFamilyObserver?.call();
    super.dispose();
  }
}
