import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/backend_api_service.dart';
import 'telemetry_config.dart';
import 'telemetry_event.dart';

class TelemetrySendResult {
  const TelemetrySendResult._({
    required this.ok,
    required this.shouldDrop,
    this.retryAfter,
    this.statusCode,
  });

  final bool ok;
  final bool shouldDrop;
  final Duration? retryAfter;
  final int? statusCode;

  factory TelemetrySendResult.ok() => const TelemetrySendResult._(ok: true, shouldDrop: false);

  factory TelemetrySendResult.retry({Duration? retryAfter, int? statusCode}) =>
      TelemetrySendResult._(ok: false, shouldDrop: false, retryAfter: retryAfter, statusCode: statusCode);

  factory TelemetrySendResult.drop({int? statusCode}) =>
      TelemetrySendResult._(ok: false, shouldDrop: true, statusCode: statusCode);
}

abstract class TelemetrySender {
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events);
}

class BackendTelemetrySender implements TelemetrySender {
  BackendTelemetrySender({BackendApiService? backend}) : _backend = backend ?? BackendApiService();

  final BackendApiService _backend;

  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async {
    if (events.isEmpty) return TelemetrySendResult.ok();

    try {
      final payload = jsonEncode({
        'property': AppTelemetryConfig.property,
        'events': events.map((e) => e.toJson()).toList(growable: false),
      });

      final res = await _backend.postAppTelemetry(payload);
      if (res == null) return TelemetrySendResult.retry();

      if (res.statusCode == 204 || (res.statusCode >= 200 && res.statusCode < 300)) {
        return TelemetrySendResult.ok();
      }

      if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        return TelemetrySendResult.drop(statusCode: res.statusCode);
      }

      if (res.statusCode == 413) {
        return TelemetrySendResult.drop(statusCode: res.statusCode);
      }

      if (res.statusCode == 429) {
        final retryAfter = _parseRetryAfter(res);
        return TelemetrySendResult.retry(retryAfter: retryAfter, statusCode: res.statusCode);
      }

      if (res.statusCode >= 500) {
        return TelemetrySendResult.retry(statusCode: res.statusCode);
      }

      return TelemetrySendResult.drop(statusCode: res.statusCode);
    } catch (_) {
      return TelemetrySendResult.retry();
    }
  }

  Duration? _parseRetryAfter(http.Response res) {
    final raw = res.headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    return null;
  }
}
