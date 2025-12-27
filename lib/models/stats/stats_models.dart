import 'package:flutter/foundation.dart';

@immutable
class StatsSnapshot {
  final String entityType;
  final String entityId;
  final String scope;
  final List<String> metrics;
  final Map<String, int> counters;
  final DateTime? generatedAt;

  const StatsSnapshot({
    required this.entityType,
    required this.entityId,
    required this.scope,
    required this.metrics,
    required this.counters,
    required this.generatedAt,
  });

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  static Map<String, int> _parseCounters(dynamic value) {
    if (value is! Map) return const {};
    final out = <String, int>{};
    value.forEach((k, v) {
      if (k == null) return;
      final key = k.toString();
      if (key.isEmpty) return;
      out[key] = _toInt(v);
    });
    return out;
  }

  static List<String> _parseMetrics(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return const [];
  }

  factory StatsSnapshot.fromJson(Map<String, dynamic> json) {
    final generatedRaw = json['generatedAt'] ?? json['generated_at'];
    DateTime? generatedAt;
    if (generatedRaw != null) {
      generatedAt = DateTime.tryParse(generatedRaw.toString());
    }
    return StatsSnapshot(
      entityType: (json['entityType'] ?? json['entity_type'] ?? '').toString(),
      entityId: (json['entityId'] ?? json['entity_id'] ?? '').toString(),
      scope: (json['scope'] ?? 'public').toString(),
      metrics: _parseMetrics(json['metrics']),
      counters: _parseCounters(json['counters']),
      generatedAt: generatedAt,
    );
  }
}

@immutable
class StatsSeriesPoint {
  final DateTime t;
  final int v;
  final String? g;

  const StatsSeriesPoint({
    required this.t,
    required this.v,
    required this.g,
  });

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  factory StatsSeriesPoint.fromJson(Map<String, dynamic> json) {
    final tRaw = json['t'] ?? json['bucket'] ?? json['timestamp'];
    final parsedT = tRaw != null ? DateTime.tryParse(tRaw.toString()) : null;
    return StatsSeriesPoint(
      t: parsedT ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      v: _toInt(json['v'] ?? json['value']),
      g: (json['g'] ?? json['group'] ?? json['group_key'])?.toString(),
    );
  }
}

@immutable
class StatsSeries {
  final String entityType;
  final String entityId;
  final String scope;
  final String metric;
  final String bucket;
  final DateTime? from;
  final DateTime? to;
  final String? groupBy;
  final List<StatsSeriesPoint> series;
  final DateTime? generatedAt;

  const StatsSeries({
    required this.entityType,
    required this.entityId,
    required this.scope,
    required this.metric,
    required this.bucket,
    required this.from,
    required this.to,
    required this.groupBy,
    required this.series,
    required this.generatedAt,
  });

  static List<StatsSeriesPoint> _parseSeries(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => StatsSeriesPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory StatsSeries.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) => raw == null ? null : DateTime.tryParse(raw.toString());
    return StatsSeries(
      entityType: (json['entityType'] ?? json['entity_type'] ?? '').toString(),
      entityId: (json['entityId'] ?? json['entity_id'] ?? '').toString(),
      scope: (json['scope'] ?? 'public').toString(),
      metric: (json['metric'] ?? '').toString(),
      bucket: (json['bucket'] ?? 'day').toString(),
      from: parseDate(json['from']),
      to: parseDate(json['to']),
      groupBy: (json['groupBy'] ?? json['group_by'])?.toString(),
      series: _parseSeries(json['series']),
      generatedAt: parseDate(json['generatedAt'] ?? json['generated_at']),
    );
  }
}

