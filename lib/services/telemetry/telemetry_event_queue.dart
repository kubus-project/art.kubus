import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'telemetry_config.dart';
import 'optional_analytics_consent.dart';
import 'telemetry_event.dart';

abstract class TelemetryEventQueue {
  Future<void> init();
  Future<int> count();
  Future<void> enqueue(AppTelemetryEvent event);
  Future<List<AppTelemetryEvent>> peekBatch(int maxEvents);
  Future<void> removeFirst(int n);
  Future<void> clear();
}

class InMemoryTelemetryEventQueue implements TelemetryEventQueue {
  InMemoryTelemetryEventQueue(
      {this.maxLength = AppTelemetryConfig.maxQueueLength});

  final int maxLength;
  final List<AppTelemetryEvent> _events = [];

  @override
  Future<void> init() async {}

  @override
  Future<int> count() async => _events.length;

  @override
  Future<void> enqueue(AppTelemetryEvent event) async {
    _events.add(event);
    if (_events.length > maxLength) {
      _events.removeRange(0, _events.length - maxLength);
    }
  }

  @override
  Future<List<AppTelemetryEvent>> peekBatch(int maxEvents) async {
    if (_events.isEmpty) return const [];
    final n = maxEvents.clamp(0, _events.length);
    return List<AppTelemetryEvent>.unmodifiable(_events.take(n));
  }

  @override
  Future<void> removeFirst(int n) async {
    if (n <= 0) return;
    final countToRemove = n.clamp(0, _events.length);
    _events.removeRange(0, countToRemove);
  }

  @override
  Future<void> clear() async {
    _events.clear();
  }
}

class SharedPreferencesTelemetryEventQueue implements TelemetryEventQueue {
  SharedPreferencesTelemetryEventQueue({
    this.maxLength = AppTelemetryConfig.maxQueueLength,
    this.queueKey = AppTelemetryConfig.queuePrefsKey,
    this.droppedCountKey = AppTelemetryConfig.droppedCountPrefsKey,
  });

  final int maxLength;
  final String queueKey;
  final String droppedCountKey;

  bool _initialized = false;
  SharedPreferences? _prefs;
  final List<String> _encoded = [];
  int _dropped = 0;
  String? _scope;
  String _currentScope(SharedPreferences prefs) =>
      '${prefs.getString('user_id') ?? 'guest'}:${prefs.getString(OptionalAnalyticsConsent.prefsKey)}';
  Future<void> _op = Future.value();
  Timer? _persistTimer;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    await prefs.remove('app_telemetry_queue_v2');
    _encoded.clear();
    if (OptionalAnalyticsConsent.hasStoredPermission(prefs)) {
      final stored = prefs.getStringList(queueKey) ?? const <String>[];
      final scope = _currentScope(prefs);
      _scope = scope;
      if (prefs.getString('${queueKey}_scope') == scope) {
        _encoded.addAll(stored.where(_fresh));
      }
      await prefs.setString('${queueKey}_scope', scope);
      await prefs.setStringList(queueKey, List<String>.from(_encoded));
    } else {
      await prefs.remove(queueKey);
      await prefs.remove('${queueKey}_scope');
    }
    _dropped = prefs.getInt(droppedCountKey) ?? 0;
    _initialized = true;
  }

  @override
  Future<int> count() => _withLock(() async {
        await init();
        return _encoded.length;
      });

  @override
  Future<void> enqueue(AppTelemetryEvent event) => _withLock(() async {
        await init();
        if (!OptionalAnalyticsConsent.hasStoredPermission(_prefs!)) return;
        final scope = _currentScope(_prefs!);
        if (_scope != scope) {
          _encoded.clear();
          _scope = scope;
        }
        final actor = _prefs!.getString('user_id');
        if (event.actorUserId != actor) return;
        _encoded.add(event.toJsonString());
        if (_encoded.length > maxLength) {
          final overflow = _encoded.length - maxLength;
          _encoded.removeRange(0, overflow);
          _dropped += overflow;
        }
        _schedulePersist();
      });

  @override
  Future<List<AppTelemetryEvent>> peekBatch(int maxEvents) =>
      _withLock(() async {
        await init();
        _encoded.removeWhere((raw) => !_fresh(raw));
        if (_encoded.isEmpty) return const [];
        final n = maxEvents.clamp(0, _encoded.length);
        final batch = <AppTelemetryEvent>[];
        for (final raw in _encoded.take(n)) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map) {
              batch.add(
                AppTelemetryEvent.fromJson(
                    decoded.map((k, v) => MapEntry(k.toString(), v))),
              );
            }
          } catch (_) {
            _dropped += 1;
          }
        }
        return batch;
      });

  @override
  Future<void> removeFirst(int n) => _withLock(() async {
        await init();
        if (n <= 0 || _encoded.isEmpty) return;
        final countToRemove = n.clamp(0, _encoded.length);
        _encoded.removeRange(0, countToRemove);
        _schedulePersist();
      });

  @override
  Future<void> clear() => _withLock(() async {
        await init();
        _persistTimer?.cancel();
        _persistTimer = null;
        _encoded.clear();
        _scope = null;
        final prefs = _prefs!;
        await prefs.remove(queueKey);
        await prefs.remove('${queueKey}_scope');
        await prefs.remove('app_telemetry_queue_v2');
      });

  bool _fresh(String raw) {
    try {
      final event = jsonDecode(raw) as Map;
      final at = DateTime.tryParse(event['event_time']?.toString() ?? '');
      final now = DateTime.now().toUtc();
      return at != null &&
          !at.isAfter(now) &&
          now.difference(at) <= AppTelemetryConfig.maxQueueAge;
    } catch (_) {
      return false;
    }
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), () {
      _persistTimer = null;
      unawaited(_persist().catchError((Object _) {}));
    });
  }

  Future<void> _persist() => _withLock(() async {
        final prefs = _prefs;
        if (!_initialized || prefs == null) return;
        if (!OptionalAnalyticsConsent.hasStoredPermission(prefs)) {
          _encoded.clear();
          await prefs.remove(queueKey);
          await prefs.remove('${queueKey}_scope');
          return;
        }
        if (_scope != _currentScope(prefs)) {
          _encoded.clear();
          await prefs.remove(queueKey);
          await prefs.remove('${queueKey}_scope');
          return;
        }
        await prefs.setString('${queueKey}_scope', _scope!);
        await prefs.setStringList(queueKey, List<String>.from(_encoded));
        await prefs.setInt(droppedCountKey, _dropped);
      });

  Future<T> _withLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _op = _op.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
