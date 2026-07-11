import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../config/config.dart';
import '../backend_api_service.dart';
import '../telemetry/kubus_client_context.dart';
import '../telemetry/telemetry_uuid.dart';

class DiagnosticsClient {
  DiagnosticsClient._();

  static final DiagnosticsClient instance = DiagnosticsClient._();

  static const int _maxPayloadBytes = 16 * 1024;
  static const Duration _dedupeWindow = Duration(seconds: 15);
  static const int _warningSampleModulo = 10;

  final Map<String, DateTime> _lastSentBySignature = {};
  int _warningCounter = 0;

  Future<void> captureError(
    Object error,
    StackTrace stack, {
    required String source,
    String severity = 'error',
    Map<String, dynamic>? metadata,
  }) async {
    if (!_enabled) return;
    final normalizedSeverity = _normalizeSeverity(severity);
    if (normalizedSeverity == 'warning' && !_shouldSendWarning()) return;

    final message = _redact(error.toString());
    final stackText = _redact(stack.toString());
    // Signature deliberately excludes source AND severity: the same
    // exception is delivered to both the FlutterError handler ('error')
    // and the Zone handler ('fatal'); reporting it twice halves the
    // signal-to-noise of the diagnostics feed.
    final signature = '$message|${stackText.split('\n').firstOrNull ?? ''}';
    final now = DateTime.now();
    final last = _lastSentBySignature[signature];
    if (last != null && now.difference(last) < _dedupeWindow) return;
    _lastSentBySignature[signature] = now;

    await _send({
      'eventId': TelemetryUuid.v4(),
      'source': source,
      'severity': normalizedSeverity,
      'message': message,
      'stack': stackText,
      'clientVersion': AppInfo.fullVersion,
      'platform': defaultTargetPlatform.name,
      'metadata': _sanitizeMetadata(metadata ?? const <String, dynamic>{}),
    });
  }

  Future<void> captureHttpFailure({
    required String method,
    required Uri uri,
    required int statusCode,
    required String responseBody,
    String? requestId,
  }) async {
    if (!_enabled) return;
    if (uri.path == '/api/diagnostics/error') return;
    if (statusCode < 500 && statusCode != 401 && statusCode != 403) return;

    await _send({
      'eventId': TelemetryUuid.v4(),
      'source': 'flutter_http',
      'severity': statusCode >= 500 ? 'error' : 'warning',
      'message': 'HTTP $statusCode $method ${uri.path}',
      'screenRoute': uri.path,
      'clientVersion': AppInfo.fullVersion,
      'platform': defaultTargetPlatform.name,
      'requestId': requestId,
      'metadata': _sanitizeMetadata({
        'method': method,
        'path': uri.path,
        'status_code': statusCode,
        'response_preview': responseBody.length > 300
            ? responseBody.substring(0, 300)
            : responseBody,
      }),
    });
  }

  bool get _enabled =>
      AppConfig.enableCrashReporting ||
      AppConfig.enableAnalytics ||
      kDebugMode;

  bool _shouldSendWarning() {
    _warningCounter += 1;
    return _warningCounter % _warningSampleModulo == 0;
  }

  Future<void> _send(Map<String, dynamic> payload) async {
    try {
      final context = KubusClientContext.instance.snapshot;
      final enriched = <String, dynamic>{
        ...payload,
        if (context != null) ...{
          'sessionId': context.sessionId,
          'screenName': context.screenName,
          'screenRoute': payload['screenRoute'] ?? context.screenRoute,
          'flowStage': context.flowStage,
        },
        'buildNumber': AppInfo.buildNumber,
        'metadata': _sanitizeMetadata({
          ...(payload['metadata'] is Map
              ? Map<String, dynamic>.from(payload['metadata'] as Map)
              : const <String, dynamic>{}),
          'last_request_id': BackendApiService().lastRequestId,
        }),
      };

      var jsonBody = jsonEncode(enriched);
      if (utf8.encode(jsonBody).length > _maxPayloadBytes) {
        enriched['metadata'] = {'truncated': true};
        enriched['stack'] = (enriched['stack'] ?? '').toString().take(1200);
        jsonBody = jsonEncode(enriched);
      }
      if (utf8.encode(jsonBody).length > _maxPayloadBytes) return;
      await BackendApiService().postClientDiagnostics(jsonBody);
    } catch (_) {
      // Diagnostics must never affect the app flow.
    }
  }

  String _normalizeSeverity(String severity) {
    final raw = severity.trim().toLowerCase();
    if (raw == 'fatal' || raw == 'error' || raw == 'warning' || raw == 'info') {
      return raw;
    }
    return 'error';
  }

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> input) {
    final output = <String, dynamic>{};
    input.forEach((key, value) {
      if (_isSecretKey(key)) {
        output[key] = '[redacted]';
      } else if (value is String) {
        output[key] = _redact(value);
      } else if (value is Map) {
        output[key] = _sanitizeMetadata(Map<String, dynamic>.from(value));
      } else if (value is List) {
        output[key] = value.take(25).map((item) {
          if (item is String) return _redact(item);
          if (item is Map) return _sanitizeMetadata(Map<String, dynamic>.from(item));
          return item;
        }).toList(growable: false);
      } else {
        output[key] = value;
      }
    });
    return output;
  }

  bool _isSecretKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('authorization') ||
        lower.contains('cookie') ||
        lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains('private') ||
        lower.contains('seed') ||
        lower.contains('mnemonic') ||
        lower.contains('backup');
  }

  String _redact(String value) {
    var out = value;
    out = out.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false), 'Bearer [redacted]');
    out = out.replaceAll(RegExp(r'(token|password|secret|private[_-]?key)=([^&\s]+)', caseSensitive: false), r'$1=[redacted]');
    out = out.replaceAll(RegExp(r'postgres(?:ql)?://[^\s]+', caseSensitive: false), 'postgres://[redacted]');
    out = out.replaceAll(RegExp(r'redis(?:s)?://[^\s]+', caseSensitive: false), 'redis://[redacted]');
    if (out.length > 2000) out = out.substring(0, 2000);
    return out;
  }
}

extension _StringTake on String {
  String take(int max) => length <= max ? this : substring(0, max);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
