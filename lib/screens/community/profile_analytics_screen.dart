import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../models/stats/stats_models.dart';
import '../../providers/config_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/web3provider.dart';
import '../../services/stats_api_service.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/charts/stats_interactive_line_chart.dart';
import '../../widgets/empty_state_card.dart';

class ProfileAnalyticsScreen extends StatefulWidget {
  final String walletAddress;
  final String? title;

  const ProfileAnalyticsScreen({
    super.key,
    required this.walletAddress,
    this.title,
  });

  @override
  State<ProfileAnalyticsScreen> createState() => _ProfileAnalyticsScreenState();
}

class _ProfileAnalyticsScreenState extends State<ProfileAnalyticsScreen> {
  String _timeframe = '30d';
  String _metric = 'viewsReceived';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    final web3Wallet = context.watch<Web3Provider>().walletAddress.trim();
    final targetWallet = widget.walletAddress.trim();

    final isOwner = web3Wallet.isNotEmpty && web3Wallet.toLowerCase() == targetWallet.toLowerCase();
    final analyticsFeatureEnabled = AppConfig.isFeatureEnabled('analytics');
    final analyticsPreferenceEnabled = context.watch<ConfigProvider>().enableAnalytics;

    final allowedMetrics = <String, String>{
      'followers': 'Followers',
      'posts': 'Posts',
      'artworks': 'Artworks',
      'viewsReceived': 'Views received',
      'likesReceived': 'Likes received',
      if (isOwner) 'engagement': 'Engagement',
      if (isOwner) 'viewsGiven': 'Views given',
    };

    if (!allowedMetrics.containsKey(_metric)) {
      _metric = allowedMetrics.keys.first;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title ?? 'Profile analytics',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: !analyticsFeatureEnabled
                ? null
                : () {
                    final statsProvider = context.read<StatsProvider>();
                    unawaited(_refresh(statsProvider, force: true));
                  },
            icon: Icon(Icons.refresh, color: scheme.onSurface.withValues(alpha: 0.85)),
          ),
        ],
      ),
      body: !analyticsFeatureEnabled
          ? const Center(
              child: EmptyStateCard(
                icon: Icons.analytics_outlined,
                title: 'Analytics disabled',
                description: 'This feature is currently turned off.',
                showAction: false,
              ),
            )
          : Consumer<StatsProvider>(
              builder: (context, statsProvider, child) {
                final canFetch = StatsApiService.shouldFetchAnalytics(
                  analyticsFeatureEnabled: analyticsFeatureEnabled,
                  analyticsPreferenceEnabled: analyticsPreferenceEnabled,
                );

                if (targetWallet.isEmpty) {
                  return const Center(
                    child: EmptyStateCard(
                      icon: Icons.person_outline,
                      title: 'No profile selected',
                      description: 'Missing wallet address.',
                      showAction: false,
                    ),
                  );
                }

                final bucket = _bucketForTimeframe(_timeframe);
                final duration = _durationForTimeframe(_timeframe);
                final now = DateTime.now().toUtc();
                final currentTo = _bucketStartUtc(now, bucket);
                final currentFrom = currentTo.subtract(duration);

                final scope = (isOwner && _isPrivateMetric(_metric)) ? 'private' : 'public';

                if (canFetch) {
                  unawaited(statsProvider.ensureSeries(
                    entityType: 'user',
                    entityId: targetWallet,
                    metric: _metric,
                    bucket: bucket,
                    timeframe: _timeframe,
                    from: currentFrom.toIso8601String(),
                    to: currentTo.toIso8601String(),
                    scope: scope,
                  ));
                }

                final series = statsProvider.getSeries(
                  entityType: 'user',
                  entityId: targetWallet,
                  metric: _metric,
                  bucket: bucket,
                  timeframe: _timeframe,
                  from: currentFrom.toIso8601String(),
                  to: currentTo.toIso8601String(),
                  scope: scope,
                );

                final isLoading = canFetch &&
                    series == null &&
                    statsProvider.isSeriesLoading(
                      entityType: 'user',
                      entityId: targetWallet,
                      metric: _metric,
                      bucket: bucket,
                      timeframe: _timeframe,
                      from: currentFrom.toIso8601String(),
                      to: currentTo.toIso8601String(),
                      scope: scope,
                    );

                final error = statsProvider.seriesError(
                  entityType: 'user',
                  entityId: targetWallet,
                  metric: _metric,
                  bucket: bucket,
                  timeframe: _timeframe,
                  from: currentFrom.toIso8601String(),
                  to: currentTo.toIso8601String(),
                  scope: scope,
                );

                final values = _filledValues(
                  series,
                  windowEnd: currentTo,
                  timeframe: _timeframe,
                  bucket: bucket,
                );

                final labels = _buildBucketLabels(
                  windowEnd: currentTo,
                  timeframe: _timeframe,
                  bucket: bucket,
                  count: values.length,
                );

                final hasData = values.any((v) => v > 0);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _controlsCard(
                      context,
                      accent: themeProvider.accentColor,
                      scheme: scheme,
                      roles: roles,
                      allowedMetrics: allowedMetrics,
                      isOwner: isOwner,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.show_chart, color: themeProvider.accentColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  allowedMetrics[_metric] ?? _metric,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                _timeframe,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!analyticsPreferenceEnabled)
                            const EmptyStateCard(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Analytics paused',
                              description: 'Enable analytics in Settings to load charts.',
                              showAction: false,
                            )
                          else if (isLoading)
                            SizedBox(
                              height: 200,
                              child: Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: themeProvider.accentColor,
                                  ),
                                ),
                              ),
                            )
                          else if (error != null && series == null)
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  unawaited(_refresh(statsProvider, force: true));
                                },
                                icon: Icon(Icons.refresh, color: scheme.primary),
                                label: Text(
                                  'Retry',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            )
                          else if (!hasData)
                            const SizedBox(
                              height: 200,
                              child: Center(
                                child: EmptyStateCard(
                                  icon: Icons.insights_outlined,
                                  title: 'No data yet',
                                  description: 'This chart will populate as activity happens.',
                                  showAction: false,
                                ),
                              ),
                            )
                          else
                            StatsInteractiveLineChart(
                              height: 200,
                              gridColor: scheme.onPrimary.withValues(alpha: 0.1),
                              xLabels: labels,
                              series: [
                                StatsLineSeries(
                                  label: allowedMetrics[_metric] ?? _metric,
                                  values: values,
                                  color: themeProvider.accentColor,
                                  showArea: true,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _refresh(StatsProvider statsProvider, {required bool force}) async {
    final targetWallet = widget.walletAddress.trim();
    if (targetWallet.isEmpty) return;

    final web3Wallet = context.read<Web3Provider>().walletAddress.trim();
    final isOwner = web3Wallet.isNotEmpty && web3Wallet.toLowerCase() == targetWallet.toLowerCase();

    final bucket = _bucketForTimeframe(_timeframe);
    final duration = _durationForTimeframe(_timeframe);
    final now = DateTime.now().toUtc();
    final currentTo = _bucketStartUtc(now, bucket);
    final currentFrom = currentTo.subtract(duration);

    final scope = (isOwner && _isPrivateMetric(_metric)) ? 'private' : 'public';

    await statsProvider.ensureSeries(
      entityType: 'user',
      entityId: targetWallet,
      metric: _metric,
      bucket: bucket,
      timeframe: _timeframe,
      from: currentFrom.toIso8601String(),
      to: currentTo.toIso8601String(),
      scope: scope,
      forceRefresh: force,
    );
  }

  bool _isPrivateMetric(String metric) {
    switch (metric) {
      case 'engagement':
      case 'viewsGiven':
      case 'artworksDiscovered':
        return true;
      default:
        return false;
    }
  }

  String _bucketForTimeframe(String timeframe) {
    switch (timeframe) {
      case '24h':
        return 'hour';
      case '7d':
      case '30d':
      case '90d':
      case '1y':
      default:
        return 'day';
    }
  }

  Duration _durationForTimeframe(String timeframe) {
    switch (timeframe) {
      case '24h':
        return const Duration(hours: 24);
      case '7d':
        return const Duration(days: 7);
      case '90d':
        return const Duration(days: 90);
      case '1y':
        return const Duration(days: 365);
      case '30d':
      default:
        return const Duration(days: 30);
    }
  }

  DateTime _bucketStartUtc(DateTime dt, String bucket) {
    final utc = dt.toUtc();
    if (bucket == 'hour') return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    if (bucket == 'week') {
      final startOfDay = DateTime.utc(utc.year, utc.month, utc.day);
      return startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
    }
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  List<double> _filledValues(
    StatsSeries? series, {
    required DateTime windowEnd,
    required String timeframe,
    required String bucket,
  }) {
    final points = (series?.series ?? const <StatsSeriesPoint>[]).toList()
      ..sort((a, b) => a.t.compareTo(b.t));

    int expectedPoints() {
      if (bucket == 'hour') return 24;
      if (bucket == 'day') {
        switch (timeframe) {
          case '7d':
            return 7;
          case '30d':
            return 30;
          case '90d':
            return 90;
          default:
            return 30;
        }
      }
      if (bucket == 'week') return 52;
      return points.length;
    }

    final expected = expectedPoints();
    if (expected <= 0) return const <double>[];

    DateTime bucketStart(DateTime dt) {
      final utc = dt.toUtc();
      if (bucket == 'hour') return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
      if (bucket == 'week') {
        final startOfDay = DateTime.utc(utc.year, utc.month, utc.day);
        return startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
      }
      return DateTime.utc(utc.year, utc.month, utc.day);
    }

    final step = bucket == 'hour'
        ? const Duration(hours: 1)
        : bucket == 'week'
            ? const Duration(days: 7)
            : const Duration(days: 1);

    final endBucket = bucketStart(windowEnd.subtract(const Duration(microseconds: 1)));
    final startBucket = endBucket.subtract(step * (expected - 1));

    final valuesByBucket = <int, int>{};
    for (final point in points) {
      final key = bucketStart(point.t).millisecondsSinceEpoch;
      valuesByBucket[key] = (valuesByBucket[key] ?? 0) + point.v;
    }

    final out = <double>[];
    for (var i = 0; i < expected; i += 1) {
      final key = startBucket.add(step * i).millisecondsSinceEpoch;
      out.add((valuesByBucket[key] ?? 0).toDouble());
    }
    return out;
  }

  List<String> _buildBucketLabels({
    required DateTime windowEnd,
    required String timeframe,
    required String bucket,
    required int count,
  }) {
    if (count <= 0) return const <String>[];

    DateTime bucketStart(DateTime dt) {
      final utc = dt.toUtc();
      if (bucket == 'hour') return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
      if (bucket == 'week') {
        final startOfDay = DateTime.utc(utc.year, utc.month, utc.day);
        return startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
      }
      return DateTime.utc(utc.year, utc.month, utc.day);
    }

    final step = bucket == 'hour'
        ? const Duration(hours: 1)
        : bucket == 'week'
            ? const Duration(days: 7)
            : const Duration(days: 1);

    final endBucket = bucketStart(windowEnd.subtract(const Duration(microseconds: 1)));
    final startBucket = endBucket.subtract(step * (count - 1));

    String labelFor(DateTime bucketStartUtc) {
      final local = bucketStartUtc.toLocal();
      if (bucket == 'hour') {
        return '${local.hour.toString().padLeft(2, '0')}h';
      }
      if (bucket == 'day' && timeframe == '7d') {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[(local.weekday - 1).clamp(0, 6)];
      }
      final mm = local.month.toString().padLeft(2, '0');
      final dd = local.day.toString().padLeft(2, '0');
      return '$mm/$dd';
    }

    return List<String>.generate(
      count,
      (i) => labelFor(startBucket.add(step * i)),
      growable: false,
    );
  }

  Widget _controlsCard(
    BuildContext context, {
    required Color accent,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required Map<String, String> allowedMetrics,
    required bool isOwner,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: scheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOwner ? 'Your analytics' : 'Public analytics',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _metric,
                  items: allowedMetrics.entries
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _metric = value);
                  },
                  decoration: InputDecoration(
                    labelText: 'Metric',
                    labelStyle: GoogleFonts.inter(fontSize: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _timeframe,
                  items: const [
                    DropdownMenuItem(value: '7d', child: Text('7d')),
                    DropdownMenuItem(value: '30d', child: Text('30d')),
                    DropdownMenuItem(value: '90d', child: Text('90d')),
                    DropdownMenuItem(value: '1y', child: Text('1y')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _timeframe = value);
                  },
                  decoration: InputDecoration(
                    labelText: 'Timeframe',
                    labelStyle: GoogleFonts.inter(fontSize: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
