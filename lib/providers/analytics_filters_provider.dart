import 'package:flutter/foundation.dart';

class AnalyticsFiltersProvider extends ChangeNotifier {
  static const List<String> allowedTimeframes = <String>[
    '24h',
    '7d',
    '30d',
    '90d',
    '1y',
  ];

  static const String homeContextKey = 'home';
  static const String profileContextKey = 'profile';
  static const String communityContextKey = 'community';
  static const String artistContextKey = 'artist';
  static const String institutionContextKey = 'institution';

  final Map<String, String> _timeframes = <String, String>{
    homeContextKey: '30d',
    profileContextKey: '30d',
    communityContextKey: '30d',
    artistContextKey: '30d',
    institutionContextKey: '30d',
  };

  final Map<String, String> _selectedMetrics = <String, String>{
    homeContextKey: 'engagement',
    profileContextKey: 'viewsReceived',
    communityContextKey: 'posts',
  };
  final Set<String> _explicitMetricContexts = <String>{};

  String get artistTimeframe => timeframeFor(artistContextKey);
  String get institutionTimeframe => timeframeFor(institutionContextKey);

  String timeframeFor(String contextKey) =>
      _timeframes[contextKey.trim().toLowerCase()] ?? '30d';

  String metricFor(String contextKey, {String fallback = ''}) {
    final normalized = contextKey.trim().toLowerCase();
    final metric = _selectedMetrics[normalized];
    if (metric == null || metric.isEmpty) {
      return fallback;
    }
    return metric;
  }

  bool hasExplicitMetricFor(String contextKey) =>
      _explicitMetricContexts.contains(contextKey.trim().toLowerCase());

  void setTimeframeFor(String contextKey, String timeframe) {
    final normalizedContext = contextKey.trim().toLowerCase();
    final normalizedTimeframe = timeframe.trim().toLowerCase();
    if (!allowedTimeframes.contains(normalizedTimeframe)) return;
    if ((_timeframes[normalizedContext] ?? '30d') == normalizedTimeframe) return;
    _timeframes[normalizedContext] = normalizedTimeframe;
    notifyListeners();
  }

  void setMetricFor(
    String contextKey,
    String metric, {
    Iterable<String>? allowedMetrics,
  }) {
    final normalizedContext = contextKey.trim().toLowerCase();
    final normalizedMetric = metric.trim();
    if (normalizedMetric.isEmpty) return;

    if (allowedMetrics != null) {
      final allowed = allowedMetrics
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
      if (!allowed.contains(normalizedMetric)) return;
    }

    final metricChanged = _selectedMetrics[normalizedContext] != normalizedMetric;
    final selectionChanged = !hasExplicitMetricFor(normalizedContext);
    if (!metricChanged && !selectionChanged) return;

    _selectedMetrics[normalizedContext] = normalizedMetric;
    _explicitMetricContexts.add(normalizedContext);
    notifyListeners();
  }

  void setArtistTimeframe(String timeframe) {
    setTimeframeFor(artistContextKey, timeframe);
  }

  void setInstitutionTimeframe(String timeframe) {
    setTimeframeFor(institutionContextKey, timeframe);
  }
}
