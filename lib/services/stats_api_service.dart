import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/stats/stats_models.dart';
import 'backend_api_service.dart';

class StatsApiService {
  final BackendApiService _api;

  // Cross-provider cache/dedupe: multiple surfaces still call StatsApiService
  // directly (ProfileProvider/WalletProvider/Web3Provider). Keeping a small
  // static cache avoids duplicate network calls and reduces UI jitter.
  static const Duration _snapshotTtl = Duration(seconds: 60);
  static const Duration _seriesTtl = Duration(seconds: 120);
  static const int _maxSnapshotCacheEntries = 400;
  static const int _maxSeriesCacheEntries = 250;

  static final Map<String, _CacheEntry<StatsSnapshot>> _snapshotCache = <String, _CacheEntry<StatsSnapshot>>{};
  static final Map<String, _CacheEntry<StatsSeries>> _seriesCache = <String, _CacheEntry<StatsSeries>>{};

  static final Map<String, Future<StatsSnapshot>> _inFlightSnapshots = <String, Future<StatsSnapshot>>{};
  static final Map<String, Future<StatsSeries>> _inFlightSeries = <String, Future<StatsSeries>>{};

  StatsApiService({BackendApiService? api}) : _api = api ?? BackendApiService();

  static String _snapshotKey({
    required String entityType,
    required String entityId,
    required List<String> metrics,
    required String scope,
    required String? groupBy,
  }) {
    final normalizedEntityType = entityType.trim().toLowerCase();
    final normalizedEntityId = entityId.trim();
    final normalizedScope = scope.trim().toLowerCase();
    final sortedMetrics = metrics.map((m) => m.trim()).where((m) => m.isNotEmpty).toList()..sort();
    final group = (groupBy ?? '').trim().toLowerCase();
    return 'snapshot|$normalizedEntityType|$normalizedEntityId|$normalizedScope|${sortedMetrics.join(",")}|$group';
  }

  static String _seriesKey({
    required String entityType,
    required String entityId,
    required String metric,
    required String bucket,
    required String timeframe,
    required String? from,
    required String? to,
    required String? groupBy,
    required String scope,
  }) {
    final normalizedEntityType = entityType.trim().toLowerCase();
    final normalizedEntityId = entityId.trim();
    final normalizedMetric = metric.trim();
    final normalizedBucket = bucket.trim().toLowerCase();
    final normalizedScope = scope.trim().toLowerCase();
    final normalizedTimeframe = timeframe.trim().toLowerCase();
    final normalizedFrom = (from ?? '').trim();
    final normalizedTo = (to ?? '').trim();
    final group = (groupBy ?? '').trim().toLowerCase();
    return 'series|$normalizedEntityType|$normalizedEntityId|$normalizedScope|$normalizedMetric|$normalizedBucket|$normalizedTimeframe|$normalizedFrom|$normalizedTo|$group';
  }

  static bool _isFresh(DateTime fetchedAt, Duration ttl) {
    if (fetchedAt.millisecondsSinceEpoch <= 0) return false;
    return DateTime.now().difference(fetchedAt) <= ttl;
  }

  static void _pruneCacheIfNeeded<T>(Map<String, _CacheEntry<T>> cache, int maxEntries) {
    if (cache.length <= maxEntries) return;
    // Remove the oldest ~25% to keep overhead low.
    final target = (maxEntries * 0.75).floor();
    final entries = cache.entries.toList(growable: false)
      ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));
    final removeCount = cache.length - target;
    for (var i = 0; i < removeCount && i < entries.length; i++) {
      cache.remove(entries[i].key);
    }
  }

  Future<StatsSnapshot> fetchSnapshot({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
    bool forceRefresh = false,
  }) async {
    final key = _snapshotKey(
      entityType: entityType,
      entityId: entityId,
      metrics: metrics,
      scope: scope,
      groupBy: groupBy,
    );

    final cached = _snapshotCache[key];
    if (!forceRefresh && cached != null && _isFresh(cached.fetchedAt, _snapshotTtl)) {
      return cached.value;
    }

    final inFlight = _inFlightSnapshots[key];
    if (!forceRefresh && inFlight != null) {
      return inFlight;
    }

    final future = () async {
      final data = await _api.getStatsSnapshot(
        entityType: entityType,
        entityId: entityId,
        metrics: metrics,
        scope: scope,
        groupBy: groupBy,
      );
      final snapshot = StatsSnapshot.fromJson(data);
      _snapshotCache[key] = _CacheEntry(snapshot, DateTime.now());
      _pruneCacheIfNeeded(_snapshotCache, _maxSnapshotCacheEntries);
      return snapshot;
    }();

    _inFlightSnapshots[key] = future;
    try {
      return await future;
    } finally {
      _inFlightSnapshots.remove(key);
    }
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
    bool forceRefresh = false,
  }) async {
    final key = _seriesKey(
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

    final cached = _seriesCache[key];
    if (!forceRefresh && cached != null && _isFresh(cached.fetchedAt, _seriesTtl)) {
      return cached.value;
    }

    final inFlight = _inFlightSeries[key];
    if (!forceRefresh && inFlight != null) {
      return inFlight;
    }

    final future = () async {
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
      final series = StatsSeries.fromJson(data);
      _seriesCache[key] = _CacheEntry(series, DateTime.now());
      _pruneCacheIfNeeded(_seriesCache, _maxSeriesCacheEntries);
      return series;
    }();

    _inFlightSeries[key] = future;
    try {
      return await future;
    } finally {
      _inFlightSeries.remove(key);
    }
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

class _CacheEntry<T> {
  final T value;
  final DateTime fetchedAt;

  const _CacheEntry(this.value, this.fetchedAt);
}

