import '../../models/stats/stats_models.dart';

class AnalyticsTimeWindow {
  const AnalyticsTimeWindow({
    required this.timeframe,
    required this.bucket,
    required this.currentFrom,
    required this.currentTo,
    required this.previousFrom,
    required this.previousTo,
    required this.expectedPoints,
    required this.step,
  });

  final String timeframe;
  final String bucket;
  final DateTime currentFrom;
  final DateTime currentTo;
  final DateTime previousFrom;
  final DateTime previousTo;
  final int expectedPoints;
  final Duration step;

  static AnalyticsTimeWindow resolve({
    required String timeframe,
    DateTime? now,
  }) {
    final normalized = normalizeTimeframe(timeframe);
    final bucket = bucketForTimeframe(normalized);
    final step = stepForBucket(bucket);
    final duration = durationForTimeframe(normalized);
    final resolvedNow = (now ?? DateTime.now()).toUtc();
    final currentTo = bucketStartUtc(resolvedNow, bucket).add(step);
    final currentFrom = currentTo.subtract(duration);
    final previousTo = currentFrom;
    final previousFrom = previousTo.subtract(duration);
    return AnalyticsTimeWindow(
      timeframe: normalized,
      bucket: bucket,
      currentFrom: currentFrom,
      currentTo: currentTo,
      previousFrom: previousFrom,
      previousTo: previousTo,
      expectedPoints: expectedPointsFor(normalized, bucket),
      step: step,
    );
  }

  static String normalizeTimeframe(String timeframe) {
    final normalized = timeframe.trim().toLowerCase();
    switch (normalized) {
      case '24h':
      case '7d':
      case '30d':
      case '90d':
      case '1y':
        return normalized;
      default:
        return '30d';
    }
  }

  static String bucketForTimeframe(String timeframe) {
    if (timeframe == '24h') return 'hour';
    if (timeframe == '1y') return 'week';
    return 'day';
  }

  static Duration durationForTimeframe(String timeframe) {
    switch (timeframe) {
      case '24h':
        return const Duration(hours: 24);
      case '7d':
        return const Duration(days: 7);
      case '30d':
        return const Duration(days: 30);
      case '90d':
        return const Duration(days: 90);
      case '1y':
        return const Duration(days: 365);
      default:
        return const Duration(days: 30);
    }
  }

  static int expectedPointsFor(String timeframe, String bucket) {
    if (bucket == 'hour') return 24;
    if (bucket == 'week') return 52;
    switch (timeframe) {
      case '7d':
        return 7;
      case '90d':
        return 90;
      case '30d':
      default:
        return 30;
    }
  }

  static Duration stepForBucket(String bucket) {
    if (bucket == 'hour') return const Duration(hours: 1);
    if (bucket == 'week') return const Duration(days: 7);
    return const Duration(days: 1);
  }

  static DateTime bucketStartUtc(DateTime dateTime, String bucket) {
    final utc = dateTime.toUtc();
    if (bucket == 'hour') {
      return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    }
    if (bucket == 'week') {
      final day = DateTime.utc(utc.year, utc.month, utc.day);
      return day.subtract(Duration(days: day.weekday - 1));
    }
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  List<String> labels() {
    final endBucket = bucketStartUtc(
      currentTo.subtract(const Duration(microseconds: 1)),
      bucket,
    );
    final startBucket = endBucket.subtract(step * (expectedPoints - 1));
    return List<String>.generate(expectedPoints, (index) {
      final local = startBucket.add(step * index).toLocal();
      if (bucket == 'hour') return '${local.hour.toString().padLeft(2, '0')}h';
      if (bucket == 'day' && timeframe == '7d') {
        const days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[(local.weekday - 1).clamp(0, 6)];
      }
      return '${local.month}/${local.day}';
    }, growable: false);
  }
}

class AnalyticsSeriesSummary {
  const AnalyticsSeriesSummary({
    required this.values,
    required this.previousValues,
    required this.currentTotal,
    required this.previousTotal,
    required this.average,
    required this.previousAverage,
    required this.peak,
    required this.consistency,
    required this.changePercent,
    required this.groupTotals,
  });

  final List<double> values;
  final List<double> previousValues;
  final double currentTotal;
  final double previousTotal;
  final double average;
  final double previousAverage;
  final double peak;
  final double consistency;
  final double? changePercent;
  final Map<String, int> groupTotals;

  bool get hasData => values.any((value) => value > 0);
}

class AnalyticsSeriesTools {
  const AnalyticsSeriesTools._();

  static AnalyticsSeriesSummary summarize({
    required StatsSeries? current,
    required StatsSeries? previous,
    required AnalyticsTimeWindow window,
  }) {
    final values = fillValues(
      current,
      windowEnd: window.currentTo,
      expected: window.expectedPoints,
      bucket: window.bucket,
      step: window.step,
    );
    final previousValues = fillValues(
      previous,
      windowEnd: window.previousTo,
      expected: window.expectedPoints,
      bucket: window.bucket,
      step: window.step,
    );
    final currentTotal = sum(values);
    final previousTotal = sum(previousValues);
    final average = values.isEmpty ? 0.0 : currentTotal / values.length;
    final previousAverage =
        previousValues.isEmpty ? 0.0 : previousTotal / previousValues.length;
    final peak = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b).toDouble();
    final activeBuckets = values.where((value) => value > 0).length;
    final consistency = values.isEmpty ? 0.0 : activeBuckets / values.length;
    final changePercent = _changePercent(currentTotal, previousTotal);
    return AnalyticsSeriesSummary(
      values: values,
      previousValues: previousValues,
      currentTotal: currentTotal,
      previousTotal: previousTotal,
      average: average,
      previousAverage: previousAverage,
      peak: peak,
      consistency: consistency,
      changePercent: changePercent,
      groupTotals: groupTotals(current),
    );
  }

  static List<double> fillValues(
    StatsSeries? series, {
    required DateTime windowEnd,
    required int expected,
    required String bucket,
    required Duration step,
  }) {
    if (expected <= 0) return const <double>[];
    final endBucket = AnalyticsTimeWindow.bucketStartUtc(
      windowEnd.subtract(const Duration(microseconds: 1)),
      bucket,
    );
    final startBucket = endBucket.subtract(step * (expected - 1));
    final valuesByBucket = <int, int>{};

    for (final point in series?.series ?? const <StatsSeriesPoint>[]) {
      final key = AnalyticsTimeWindow.bucketStartUtc(point.t, bucket)
          .millisecondsSinceEpoch;
      valuesByBucket[key] = (valuesByBucket[key] ?? 0) + point.v;
    }

    return List<double>.generate(expected, (index) {
      final bucketStart = startBucket.add(step * index);
      return (valuesByBucket[bucketStart.millisecondsSinceEpoch] ?? 0)
          .toDouble();
    }, growable: false);
  }

  static Map<String, int> groupTotals(StatsSeries? series) {
    final out = <String, int>{};
    for (final point in series?.series ?? const <StatsSeriesPoint>[]) {
      final group = (point.g ?? '').trim();
      if (group.isEmpty) continue;
      out[group] = (out[group] ?? 0) + point.v;
    }
    final entries = out.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, int>.fromEntries(entries);
  }

  static double sum(List<double> values) {
    return values.fold<double>(0, (sum, value) => sum + value);
  }

  static double? _changePercent(double current, double previous) {
    if (previous > 0) return ((current - previous) / previous) * 100;
    if (current == 0) return 0;
    return null;
  }
}
