import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_api_service.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  static const String _queueKey = 'telemetry_queue_v1';

  /// Log an event. Attempts to send immediately; on failure caches locally.
  Future<void> logEvent(String eventName, {Map<String, dynamic>? params}) async {
    final backend = BackendApiService();
    final payload = <String, dynamic>{
      'event': eventName,
      'params': params ?? {},
    };

    try {
      // Ensure auth token loaded if available
      try {
        await backend.loadAuthToken();
      } catch (_) {}

      await backend.sendTelemetryEvent(eventName, payload['params']);
    } catch (e) {
      debugPrint('Telemetry: failed to send event, caching locally: $e');
      await _cacheEvent(payload);
    }
  }

  Future<void> _cacheEvent(Map<String, dynamic> event) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList(_queueKey) ?? <String>[];
    queueJson.add(jsonEncode({
      'event': event['event'],
      'params': event['params'],
      'timestamp': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_queueKey, queueJson);
  }

  /// Attempt to flush queued telemetry events
  Future<void> flushQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList(_queueKey) ?? <String>[];
    if (queueJson.isEmpty) return;

    final backend = BackendApiService();
    try {
      try {
        await backend.loadAuthToken();
      } catch (_) {}

      final remaining = <String>[];
      for (final item in queueJson) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          final event = decoded['event'] as String? ?? 'unknown';
          final params = decoded['params'] as Map<String, dynamic>? ?? {};
          await backend.sendTelemetryEvent(event, params);
        } catch (e) {
          debugPrint('Telemetry flush: failed to send queued event: $e');
          remaining.add(item);
        }
      }

      if (remaining.isEmpty) {
        await prefs.remove(_queueKey);
      } else {
        await prefs.setStringList(_queueKey, remaining);
      }
    } catch (e) {
      debugPrint('Telemetry flush error: $e');
    }
  }
}
