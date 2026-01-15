import 'dart:convert';

import 'telemetry_config.dart';

class AppTelemetryEvent {
  AppTelemetryEvent({
    required this.eventId,
    required this.eventTimeUtc,
    required this.eventType,
    required this.sessionId,
    required this.metadata,
    this.actorUserId,
  });

  final String eventId;
  final DateTime eventTimeUtc;
  final String eventType;
  final String sessionId;
  final String? actorUserId;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return {
      'event_id': eventId,
      'event_time': eventTimeUtc.toIso8601String(),
      'event_type': eventType,
      'event_category': AppTelemetryConfig.eventCategory,
      'actor_user_id': actorUserId,
      'session_id': sessionId,
      'metadata': metadata,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static AppTelemetryEvent fromJson(Map<String, Object?> json) {
    final eventId = (json['event_id'] ?? '').toString();
    final eventTime = (json['event_time'] ?? '').toString();
    final eventType = (json['event_type'] ?? '').toString();
    final sessionId = (json['session_id'] ?? '').toString();
    final actorUserId = json['actor_user_id']?.toString();
    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map
        ? metadataRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, Object?>{};
    return AppTelemetryEvent(
      eventId: eventId,
      eventTimeUtc: DateTime.tryParse(eventTime)?.toUtc() ?? DateTime.now().toUtc(),
      eventType: eventType,
      sessionId: sessionId,
      actorUserId: actorUserId?.trim().isEmpty == true ? null : actorUserId,
      metadata: metadata,
    );
  }
}

