import 'package:flutter/foundation.dart';

import '../models/stats/stats_models.dart';
import 'backend_api_service.dart';

class StatsApiService {
  final BackendApiService _api;

  StatsApiService({BackendApiService? api}) : _api = api ?? BackendApiService();

  Future<StatsSnapshot> fetchSnapshot({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
  }) async {
    final data = await _api.getStatsSnapshot(
      entityType: entityType,
      entityId: entityId,
      metrics: metrics,
      scope: scope,
      groupBy: groupBy,
    );
    return StatsSnapshot.fromJson(data);
  }

  Future<StatsSeries> fetchSeries({
    required String entityType,
    required String entityId,
    required String metric,
    String bucket = 'day',
    String timeframe = '30d',
    String? from,
    String? to,
    String? groupBy,
    String scope = 'public',
  }) async {
    final data = await _api.getStatsSeries(
      entityType: entityType,
      entityId: entityId,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: from,
      to: to,
      groupBy: groupBy,
      scope: scope,
    );
    return StatsSeries.fromJson(data);
  }

  static List<double> toChartSeries(StatsSeries? series, {int? maxPoints}) {
    if (series == null) return const [];
    final points = series.series;
    if (points.isEmpty) return const [];
    final trimmed = (maxPoints != null && maxPoints > 0 && points.length > maxPoints)
        ? points.sublist(points.length - maxPoints)
        : points;
    return trimmed.map((p) => p.v.toDouble()).toList(growable: false);
  }

  static String timeframeFromLabel(String label) {
    final raw = label.trim().toLowerCase();
    switch (raw) {
      case '1d':
      case '24h':
      case '1 day':
      case 'today':
        return '24h';
      case '7d':
      case '7 days':
      case 'this week':
      case 'last 7 days':
        return '7d';
      case '30d':
      case '30 days':
      case 'this month':
      case 'last 30 days':
        return '30d';
      case '90d':
      case '90 days':
      case '3 months':
      case 'this quarter':
      case 'last 90 days':
        return '90d';
      case '1y':
      case '1 year':
      case 'last year':
      case 'this year':
        return '1y';
      case 'all':
      case 'all time':
        return '1y';
      default:
        return '30d';
    }
  }

  static String metricFromUiStatType(String statType) {
    final raw = statType.trim().toLowerCase();
    switch (raw) {
      case 'followers':
        return 'followers';
      case 'views':
      case 'visitors':
        return 'viewsReceived';
      case 'artworks':
        return 'artworks';
      case 'engagement':
        return 'engagement';
      default:
        return statType;
    }
  }

  static String entityTypeFromContext({required String entityType}) {
    return entityType.trim();
  }

  static bool shouldFetchAnalytics({
    required bool analyticsFeatureEnabled,
    required bool analyticsPreferenceEnabled,
  }) {
    if (!analyticsFeatureEnabled) return false;
    return analyticsPreferenceEnabled;
  }

  static void debugLog(String message) {
    if (kDebugMode) {
      debugPrint('StatsApiService: $message');
    }
  }
}

