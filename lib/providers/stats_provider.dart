import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/stats/stats_models.dart';
import '../services/stats_api_service.dart';
import 'app_refresh_provider.dart';
import 'config_provider.dart';

class StatsProvider extends ChangeNotifier {
  static const Duration _snapshotTtl = Duration(seconds: 60);
  static const Duration _seriesTtl = Duration(seconds: 120);
  static const Duration _errorBackoff = Duration(seconds: 12);

  final StatsApiService _api;

  AppRefreshProvider? _refreshProvider;
  ConfigProvider? _configProvider;
  VoidCallback? _configListener;

  int _lastGlobalVersion = 0;
  int _lastProfileVersion = 0;
  int _lastCommunityVersion = 0;

  final Map<String, _SnapshotEntry> _snapshots = <String, _SnapshotEntry>{};
  final Map<String, _SeriesEntry> _series = <String, _SeriesEntry>{};

  final Map<String, Future<void>> _inFlightSnapshotFetches = <String, Future<void>>{};
  final Map<String, Future<void>> _inFlightSeriesFetches = <String, Future<void>>{};

  bool _initialized = false;

  StatsProvider({StatsApiService? api}) : _api = api ?? StatsApiService();

  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  void bindToRefresh(AppRefreshProvider refreshProvider) {
    if (identical(_refreshProvider, refreshProvider)) return;
    _refreshProvider = refreshProvider;
    _lastGlobalVersion = refreshProvider.globalVersion;
    _lastProfileVersion = refreshProvider.profileVersion;
    _lastCommunityVersion = refreshProvider.communityVersion;

    refreshProvider.addListener(() {
      try {
        final nextGlobal = refreshProvider.globalVersion;
        final nextProfile = refreshProvider.profileVersion;
        final nextCommunity = refreshProvider.communityVersion;
        final changed = nextGlobal != _lastGlobalVersion ||
            nextProfile != _lastProfileVersion ||
            nextCommunity != _lastCommunityVersion;
        _lastGlobalVersion = nextGlobal;
        _lastProfileVersion = nextProfile;
        _lastCommunityVersion = nextCommunity;

        if (changed) {
          _markAllStale();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('StatsProvider: refresh listener error: $e');
        }
      }
    });
  }

  void bindConfigProvider(ConfigProvider configProvider) {
    if (identical(_configProvider, configProvider)) return;

    if (_configProvider != null && _configListener != null) {
      try {
        _configProvider!.removeListener(_configListener!);
      } catch (_) {}
    }

    _configProvider = configProvider;
    _configListener = () {
      // Analytics preference changes may affect whether we fetch series. Keep existing cache,
      // but notify so screens can hide/show charts immediately.
      notifyListeners();
    };
    configProvider.addListener(_configListener!);
  }

  bool get analyticsEnabled =>
      AppConfig.isFeatureEnabled('analytics') && (_configProvider?.enableAnalytics ?? true);

  void _markAllStale() {
    final staleAt = DateTime.fromMillisecondsSinceEpoch(0);
    for (final entry in _snapshots.values) {
      entry.fetchedAt = staleAt;
    }
    for (final entry in _series.values) {
      entry.fetchedAt = staleAt;
    }
    notifyListeners();
  }

  String _snapshotKey({
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

  String _seriesKey({
    required String entityType,
    required String entityId,
    required String metric,
    required String bucket,
    required String timeframe,
    required String? from,
    required String? to,
    required String scope,
    required String? groupBy,
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

  StatsSnapshot? getSnapshot({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
  }) {
    final key = _snapshotKey(
      entityType: entityType,
      entityId: entityId,
      metrics: metrics,
      scope: scope,
      groupBy: groupBy,
    );
    return _snapshots[key]?.snapshot;
  }

  bool isSnapshotLoading({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
  }) {
    final key = _snapshotKey(
      entityType: entityType,
      entityId: entityId,
      metrics: metrics,
      scope: scope,
      groupBy: groupBy,
    );
    return _snapshots[key]?.isLoading ?? false;
  }

  Object? snapshotError({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
  }) {
    final key = _snapshotKey(
      entityType: entityType,
      entityId: entityId,
      metrics: metrics,
      scope: scope,
      groupBy: groupBy,
    );
    return _snapshots[key]?.error;
  }

  StatsSeries? getSeries({
    required String entityType,
    required String entityId,
    required String metric,
    String bucket = 'day',
    String timeframe = '30d',
    String? from,
    String? to,
    String scope = 'public',
    String? groupBy,
  }) {
    final key = _seriesKey(
      entityType: entityType,
      entityId: entityId,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: from,
      to: to,
      scope: scope,
      groupBy: groupBy,
    );
    return _series[key]?.series;
  }

  bool isSeriesLoading({
    required String entityType,
    required String entityId,
    required String metric,
    String bucket = 'day',
    String timeframe = '30d',
    String? from,
    String? to,
    String scope = 'public',
    String? groupBy,
  }) {
    final key = _seriesKey(
      entityType: entityType,
      entityId: entityId,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: from,
      to: to,
      scope: scope,
      groupBy: groupBy,
    );
    return _series[key]?.isLoading ?? false;
  }

  Object? seriesError({
    required String entityType,
    required String entityId,
    required String metric,
    String bucket = 'day',
    String timeframe = '30d',
    String? from,
    String? to,
    String scope = 'public',
    String? groupBy,
  }) {
    final key = _seriesKey(
      entityType: entityType,
      entityId: entityId,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: from,
      to: to,
      scope: scope,
      groupBy: groupBy,
    );
    return _series[key]?.error;
  }

  _SnapshotEntry _snapshotEntry(String key) =>
      _snapshots.putIfAbsent(key, () => _SnapshotEntry());

  _SeriesEntry _seriesEntry(String key) =>
      _series.putIfAbsent(key, () => _SeriesEntry());

  bool _isStale(DateTime fetchedAt, Duration ttl) {
    if (fetchedAt.millisecondsSinceEpoch <= 0) return true;
    return DateTime.now().difference(fetchedAt) > ttl;
  }

  bool _shouldRetryError(DateTime? errorAt) {
    if (errorAt == null) return true;
    return DateTime.now().difference(errorAt) > _errorBackoff;
  }

  Future<StatsSnapshot?> ensureSnapshot({
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

    final entry = _snapshotEntry(key);
    if (!forceRefresh &&
        entry.snapshot != null &&
        !_isStale(entry.fetchedAt, _snapshotTtl)) {
      return entry.snapshot;
    }

    if (!forceRefresh && entry.errorAt != null && !_shouldRetryError(entry.errorAt)) {
      return entry.snapshot;
    }

    final inFlight = _inFlightSnapshotFetches[key];
    if (inFlight != null) {
      await inFlight;
      return entry.snapshot;
    }

    entry.isLoading = true;
    entry.error = null;
    notifyListeners();

    final future = () async {
      try {
        final snapshot = await _api.fetchSnapshot(
          entityType: entityType,
          entityId: entityId,
          metrics: metrics,
          scope: scope,
          groupBy: groupBy,
        );
        entry.snapshot = snapshot;
        entry.fetchedAt = DateTime.now();
        entry.error = null;
        entry.errorAt = null;
      } catch (e) {
        entry.error = e;
        entry.errorAt = DateTime.now();
      } finally {
        entry.isLoading = false;
        _inFlightSnapshotFetches.remove(key);
        notifyListeners();
      }
    }();

    _inFlightSnapshotFetches[key] = future;
    await future;
    return entry.snapshot;
  }

  Future<StatsSeries?> ensureSeries({
    required String entityType,
    required String entityId,
    required String metric,
    String bucket = 'day',
    String timeframe = '30d',
    String? from,
    String? to,
    String scope = 'public',
    String? groupBy,
    bool forceRefresh = false,
  }) async {
    if (!analyticsEnabled) {
      return getSeries(
        entityType: entityType,
        entityId: entityId,
        metric: metric,
        bucket: bucket,
        timeframe: timeframe,
        from: from,
        to: to,
        scope: scope,
        groupBy: groupBy,
      );
    }

    final key = _seriesKey(
      entityType: entityType,
      entityId: entityId,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: from,
      to: to,
      scope: scope,
      groupBy: groupBy,
    );

    final entry = _seriesEntry(key);
    if (!forceRefresh && entry.series != null && !_isStale(entry.fetchedAt, _seriesTtl)) {
      return entry.series;
    }

    if (!forceRefresh && entry.errorAt != null && !_shouldRetryError(entry.errorAt)) {
      return entry.series;
    }

    final inFlight = _inFlightSeriesFetches[key];
    if (inFlight != null) {
      await inFlight;
      return entry.series;
    }

    entry.isLoading = true;
    entry.error = null;
    notifyListeners();

    final future = () async {
      try {
        final series = await _api.fetchSeries(
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
        entry.series = series;
        entry.fetchedAt = DateTime.now();
        entry.error = null;
        entry.errorAt = null;
      } catch (e) {
        entry.error = e;
        entry.errorAt = DateTime.now();
      } finally {
        entry.isLoading = false;
        _inFlightSeriesFetches.remove(key);
        notifyListeners();
      }
    }();

    _inFlightSeriesFetches[key] = future;
    await future;
    return entry.series;
  }

  void invalidateEntity({required String entityType, required String entityId}) {
    final prefix = '|${entityType.trim().toLowerCase()}|${entityId.trim()}|';
    for (final key in _snapshots.keys.toList(growable: false)) {
      if (key.contains(prefix)) {
        _snapshots[key]?.fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    for (final key in _series.keys.toList(growable: false)) {
      if (key.contains(prefix)) {
        _series[key]?.fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    notifyListeners();
  }
}

class _SnapshotEntry {
  StatsSnapshot? snapshot;
  DateTime fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool isLoading = false;
  Object? error;
  DateTime? errorAt;
}

class _SeriesEntry {
  StatsSeries? series;
  DateTime fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool isLoading = false;
  Object? error;
  DateTime? errorAt;
}
