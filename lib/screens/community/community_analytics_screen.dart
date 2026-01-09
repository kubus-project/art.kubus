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

class CommunityAnalyticsScreen extends StatefulWidget {
  final String walletAddress;
  final String? title;

  const CommunityAnalyticsScreen({
    super.key,
    required this.walletAddress,
    this.title,
  });

  @override
  State<CommunityAnalyticsScreen> createState() => _CommunityAnalyticsScreenState();
}

class _CommunityAnalyticsScreenState extends State<CommunityAnalyticsScreen> {
  String _timeframe = '30d';

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title ?? 'Community analytics',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
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

                final postScope = 'public';
                final likesScope = 'public';
                final engagementScope = isOwner ? 'private' : 'public';

                if (canFetch) {
                  unawaited(statsProvider.ensureSeries(
                    entityType: 'user',
                    entityId: targetWallet,
                    metric: 'posts',
                    bucket: bucket,
                    timeframe: _timeframe,
                    from: currentFrom.toIso8601String(),
                    to: currentTo.toIso8601String(),
                    scope: postScope,
                  ));
                  unawaited(statsProvider.ensureSeries(
                    entityType: 'user',
                    entityId: targetWallet,
                    metric: 'likesReceived',
                    bucket: bucket,
                    timeframe: _timeframe,
                    from: currentFrom.toIso8601String(),
                    to: currentTo.toIso8601String(),
                    scope: likesScope,
                  ));
                  if (isOwner) {
                    unawaited(statsProvider.ensureSeries(
                      entityType: 'user',
                      entityId: targetWallet,
                      metric: 'engagement',
                      bucket: bucket,
                      timeframe: _timeframe,
                      from: currentFrom.toIso8601String(),
                      to: currentTo.toIso8601String(),
                      scope: engagementScope,
                    ));
                  }
                }

                final postsSeries = statsProvider.getSeries(
                  entityType: 'user',
                  entityId: targetWallet,
                  metric: 'posts',
                  bucket: bucket,
                  timeframe: _timeframe,
                  from: currentFrom.toIso8601String(),
                  to: currentTo.toIso8601String(),
                  scope: postScope,
                );
                final likesSeries = statsProvider.getSeries(
                  entityType: 'user',
                  entityId: targetWallet,
                  metric: 'likesReceived',
                  bucket: bucket,
                  timeframe: _timeframe,
                  from: currentFrom.toIso8601String(),
                  to: currentTo.toIso8601String(),
                  scope: likesScope,
                );
                final engagementSeries = isOwner
                    ? statsProvider.getSeries(
                        entityType: 'user',
                        entityId: targetWallet,
                        metric: 'engagement',
                        bucket: bucket,
                        timeframe: _timeframe,
                        from: currentFrom.toIso8601String(),
                        to: currentTo.toIso8601String(),
                        scope: engagementScope,
                      )
                    : null;

                final postsValues = _filledValues(postsSeries, windowEnd: currentTo, timeframe: _timeframe, bucket: bucket);
                final likesValues = _filledValues(likesSeries, windowEnd: currentTo, timeframe: _timeframe, bucket: bucket);
                final engagementValues = isOwner
                    ? _filledValues(engagementSeries, windowEnd: currentTo, timeframe: _timeframe, bucket: bucket)
                    : const <double>[];

                final labels = _buildBucketLabels(
                  windowEnd: currentTo,
                  timeframe: _timeframe,
                  bucket: bucket,
                  count: postsValues.isNotEmpty ? postsValues.length : (likesValues.isNotEmpty ? likesValues.length : 0),
                );

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _timeframeSelector(context, roles: roles, scheme: scheme),
                    const SizedBox(height: 16),
                    _chartCard(
                      context,
                      title: 'Posts created',
                      accent: themeProvider.accentColor,
                      values: postsValues,
                      labels: labels,
                    ),
                    const SizedBox(height: 16),
                    _chartCard(
                      context,
                      title: 'Likes received',
                      accent: scheme.secondary,
                      values: likesValues,
                      labels: labels,
                    ),
                    if (isOwner) ...[
                      const SizedBox(height: 16),
                      _chartCard(
                        context,
                        title: 'Engagement',
                        accent: scheme.tertiary,
                        values: engagementValues,
                        labels: labels,
                      ),
                    ],
                    if (!analyticsPreferenceEnabled)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: EmptyStateCard(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Analytics paused',
                          description: 'Enable analytics in Settings to load charts.',
                          showAction: false,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _timeframeSelector(
    BuildContext context, {
    required KubusColorRoles roles,
    required ColorScheme scheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.timeline, color: scheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Timeframe',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          DropdownButton<String>(
            value: _timeframe,
            underline: const SizedBox.shrink(),
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
          ),
        ],
      ),
    );
  }

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required Color accent,
    required List<double> values,
    required List<String> labels,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final hasData = values.any((v) => v > 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasData)
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
                  label: title,
                  values: values,
                  color: accent,
                  showArea: true,
                ),
              ],
            ),
        ],
      ),
    );
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
}
