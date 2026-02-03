import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import 'map_performance_debug.dart';

class MapPerfTracker {
  MapPerfTracker(this.label) : _uptime = Stopwatch()..start();

  final String label;
  final Stopwatch _uptime;

  final Set<String> _activeTimers = <String>{};
  final Set<String> _activeSubscriptions = <String>{};
  final Set<String> _activeControllers = <String>{};
  final Map<String, int> _fetchCounts = <String, int>{};
  final Map<String, int> _setStateCounts = <String, int>{};

  int _buildCount = 0;
  int _lastBuildLogAt = 0;

  bool get enabled => MapPerformanceDebug.isEnabled;

  void recordBuild() {
    if (!enabled) return;
    _buildCount += 1;
    if (_buildCount - _lastBuildLogAt >= 120) {
      _lastBuildLogAt = _buildCount;
      _log(
        'builds=$_buildCount timers=${_activeTimers.length} subs=${_activeSubscriptions.length} ctrls=${_activeControllers.length}',
      );
    }
  }

  void recordSetState(String reason) {
    if (!enabled) return;
    _setStateCounts.update(reason, (value) => value + 1, ifAbsent: () => 1);
  }

  void recordFetch(String key) {
    if (!enabled) return;
    _fetchCounts.update(key, (value) => value + 1, ifAbsent: () => 1);
  }

  void timerStarted(String name) {
    if (!enabled) return;
    _activeTimers.add(name);
  }

  void timerStopped(String name) {
    if (!enabled) return;
    _activeTimers.remove(name);
  }

  void subscriptionStarted(String name) {
    if (!enabled) return;
    _activeSubscriptions.add(name);
  }

  void subscriptionStopped(String name) {
    if (!enabled) return;
    _activeSubscriptions.remove(name);
  }

  void controllerCreated(String name) {
    if (!enabled) return;
    _activeControllers.add(name);
  }

  void controllerDisposed(String name) {
    if (!enabled) return;
    _activeControllers.remove(name);
  }

  void logEvent(
    String event, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    if (!enabled) return;

    final buffer = StringBuffer()
      ..write(event)
      ..write(' t=${_uptime.elapsedMilliseconds}ms')
      ..write(' timers=${_activeTimers.length}')
      ..write(' subs=${_activeSubscriptions.length}')
      ..write(' ctrls=${_activeControllers.length}');

    extra.forEach((key, value) {
      if (value == null) return;
      buffer
        ..write(' ')
        ..write(key)
        ..write('=')
        ..write(value);
    });

    _log(buffer.toString());
  }

  void logSummary(
    String event, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    if (!enabled) return;
    _log('$event t=${_uptime.elapsedMilliseconds}ms');
    _log(
        'active timers=${_activeTimers.length} -> ${_activeTimers.toList()..sort()}');
    _log(
        'active subs=${_activeSubscriptions.length} -> ${_activeSubscriptions.toList()..sort()}');
    _log(
        'active ctrls=${_activeControllers.length} -> ${_activeControllers.toList()..sort()}');
    if (_fetchCounts.isNotEmpty) {
      _log('fetchCounts=${_formatCounts(_fetchCounts)}');
    }
    if (_setStateCounts.isNotEmpty) {
      _log('setState=${_formatCounts(_setStateCounts)}');
    }
    if (extra.isNotEmpty) {
      final sorted = SplayTreeMap<String, Object?>.from(extra);
      _log('extra=$sorted');
    }
  }

  void _log(String message) {
    if (!kDebugMode) return;
    AppConfig.debugPrint('$label: $message');
  }

  static String _formatCounts(Map<String, int> counts) {
    final sortedKeys = counts.keys.toList()..sort();
    return '{${sortedKeys.map((k) => '$k:${counts[k]}').join(', ')}}';
  }
}
