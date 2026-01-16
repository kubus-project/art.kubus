import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/institution.dart';
import '../../../providers/institution_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/analytics_filters_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/stats/stats_models.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/charts/stats_interactive_bar_chart.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../utils/app_animations.dart';

class InstitutionAnalytics extends StatefulWidget {
  const InstitutionAnalytics({super.key});

  @override
  State<InstitutionAnalytics> createState() => _InstitutionAnalyticsState();
}

class _InstitutionAnalyticsState extends State<InstitutionAnalytics>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _didPlayEntrance = false;

  String _resolveWalletAddress({bool listen = false}) {
    final profileProvider =
        listen ? context.watch<ProfileProvider>() : context.read<ProfileProvider>();
    final web3Provider =
        listen ? context.watch<Web3Provider>() : context.read<Web3Provider>();
    return WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
  }

  String _bucketForTimeframe(String timeframe) {
    if (timeframe == '24h') return 'hour';
    if (timeframe == '1y') return 'week';
    return 'day';
  }

  Duration _durationForTimeframe(String timeframe) {
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

  DateTime _bucketStartUtc(DateTime dt, String bucket) {
    final utc = dt.toUtc();
    if (bucket == 'hour') return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    if (bucket == 'week') {
      final startOfDay = DateTime.utc(utc.year, utc.month, utc.day);
      return startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
    }
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  Duration _bucketStep(String bucket) {
    if (bucket == 'hour') return const Duration(hours: 1);
    if (bucket == 'week') return const Duration(days: 7);
    return const Duration(days: 1);
  }

  int _sumGroups(StatsSeries? series, Set<String> groups) {
    if (series == null) return 0;
    var total = 0;
    for (final point in series.series) {
      final g = (point.g ?? '').trim().toLowerCase();
      if (g.isEmpty) continue;
      if (!groups.contains(g)) continue;
      total += point.v;
    }
    return total;
  }

  String _formatPercentChange({required int current, required int previous}) {
    if (previous <= 0) {
      return current <= 0 ? '0%' : '\u2014';
    }
    final pct = ((current - previous) / previous) * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(0)}%';
  }

  List<_BucketStat> _fillGroupBuckets({
    required StatsSeries? series,
    required DateTime fromInclusive,
    required DateTime toExclusive,
    required String bucket,
    required Set<String> groups,
  }) {
    final valuesByBucket = <int, int>{};
    for (final point in series?.series ?? const <StatsSeriesPoint>[]) {
      final g = (point.g ?? '').trim().toLowerCase();
      if (!groups.contains(g)) continue;
      final key = _bucketStartUtc(point.t, bucket).millisecondsSinceEpoch;
      valuesByBucket[key] = (valuesByBucket[key] ?? 0) + point.v;
    }

    final step = _bucketStep(bucket);
    final out = <_BucketStat>[];
    for (var dt = fromInclusive; dt.isBefore(toExclusive); dt = dt.add(step)) {
      final bucketStart = _bucketStartUtc(dt, bucket);
      final key = bucketStart.millisecondsSinceEpoch;
      out.add(_BucketStat(bucketStart, valuesByBucket[key] ?? 0));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimationTheme.defaults.long,
      vsync: this,
    );
    _configureAnimations(AppAnimationTheme.defaults);
  }

  void _configureAnimations(AppAnimationTheme animationTheme) {
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: animationTheme.fadeCurve,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationTheme = context.animationTheme;
    if (_animationController.duration != animationTheme.long) {
      _animationController.duration = animationTheme.long;
    }
    _configureAnimations(animationTheme);
    if (!_didPlayEntrance) {
      _didPlayEntrance = true;
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              _buildStatsOverview(),
              const SizedBox(height: 16),
              _buildVisitorAnalytics(),
              const SizedBox(height: 16),
              _buildEventPerformance(),
              const SizedBox(height: 16),
              _buildRevenueAnalytics(),
              const SizedBox(height: 16),
              _buildArtworkAnalytics(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Institution Analytics',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your institution\'s performance and engagement',
          style: GoogleFonts.inter(
            fontSize: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () => _showExportDialog(),
              icon: Icon(Icons.download,
                  color: Theme.of(context).colorScheme.onSurface, size: 20),
            ),
            IconButton(
              onPressed: () => _showSettingsDialog(),
              icon: Icon(Icons.settings,
                  color: Theme.of(context).colorScheme.onSurface, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) return const SizedBox.shrink();

    const labels = <String, String>{
      '7d': 'This Week',
      '30d': 'This Month',
      '90d': 'This Quarter',
      '1y': 'This Year',
    };

    final filters = context.watch<AnalyticsFiltersProvider>();
    final selectedTimeframe = labels.containsKey(filters.institutionTimeframe) ? filters.institutionTimeframe : '30d';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Period',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.2)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedTimeframe,
                isExpanded: true,
                dropdownColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                items: labels.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  context.read<AnalyticsFiltersProvider>().setInstitutionTimeframe(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Consumer2<InstitutionProvider, StatsProvider>(
      builder: (context, institutionProvider, statsProvider, child) {
        final scheme = Theme.of(context).colorScheme;
        final walletAddress = _resolveWalletAddress(listen: true);
        final analyticsEnabled = statsProvider.analyticsEnabled;

        if (walletAddress.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: EmptyStateCard(
                  icon: Icons.analytics_outlined,
                  title: 'Connect your wallet',
                  description: 'Connect a wallet to see institution analytics.',
                ),
              ),
            ],
          );
        }

        if (!analyticsEnabled) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: EmptyStateCard(
                  icon: Icons.analytics_outlined,
                  title: 'Analytics disabled',
                  description: 'Enable analytics in Settings to view charts and insights.',
                ),
              ),
            ],
          );
        }

        final timeframe = context.watch<AnalyticsFiltersProvider>().institutionTimeframe;
        final bucket = _bucketForTimeframe(timeframe);
        final duration = _durationForTimeframe(timeframe);
        final now = DateTime.now().toUtc();
        final currentTo = _bucketStartUtc(now, bucket);
        final currentFrom = currentTo.subtract(duration);
        final prevTo = currentFrom;
        final prevFrom = prevTo.subtract(duration);

        unawaited(statsProvider.ensureSeries(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: currentFrom.toIso8601String(),
          to: currentTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        ));
        unawaited(statsProvider.ensureSeries(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: prevFrom.toIso8601String(),
          to: prevTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        ));

        final series = statsProvider.getSeries(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: currentFrom.toIso8601String(),
          to: currentTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        );
        final prevSeries = statsProvider.getSeries(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: prevFrom.toIso8601String(),
          to: prevTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        );

        final currentError = statsProvider.seriesError(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: currentFrom.toIso8601String(),
          to: currentTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        );
        final prevError = statsProvider.seriesError(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: prevFrom.toIso8601String(),
          to: prevTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        );

        final currentLoading = series == null &&
            statsProvider.isSeriesLoading(
              entityType: 'user',
              entityId: walletAddress,
              metric: 'viewsReceived',
              bucket: bucket,
              timeframe: timeframe,
              from: currentFrom.toIso8601String(),
              to: currentTo.toIso8601String(),
              groupBy: 'targetType',
              scope: 'private',
            );
        final prevLoading = prevSeries == null &&
            statsProvider.isSeriesLoading(
              entityType: 'user',
              entityId: walletAddress,
              metric: 'viewsReceived',
              bucket: bucket,
              timeframe: timeframe,
              from: prevFrom.toIso8601String(),
              to: prevTo.toIso8601String(),
              groupBy: 'targetType',
              scope: 'private',
            );
        final isLoading = currentLoading || prevLoading;
        final hasError = !isLoading &&
            ((currentError != null && series == null) || (prevError != null && prevSeries == null));

        final visitorGroups = <String>{'event', 'exhibition'};
        final artworkGroups = <String>{'artwork'};

        final visitorsThis = _sumGroups(series, visitorGroups);
        final visitorsPrev = _sumGroups(prevSeries, visitorGroups);
        final artworkViewsThis = _sumGroups(series, artworkGroups);
        final artworkViewsPrev = _sumGroups(prevSeries, artworkGroups);

        final visitorValue = hasError
            ? '\u2014'
            : isLoading
                ? '\u2026'
                : visitorsThis.toString();
        final artworkValue = hasError
            ? '\u2014'
            : isLoading
                ? '\u2026'
                : _formatNumber(artworkViewsThis);
        final visitorChange = (isLoading || hasError)
            ? '\u2014'
            : _formatPercentChange(current: visitorsThis, previous: visitorsPrev);
        final artworkChange = (isLoading || hasError)
            ? '\u2014'
            : _formatPercentChange(current: artworkViewsThis, previous: artworkViewsPrev);

        final institution = institutionProvider.institutions.isNotEmpty ? institutionProvider.institutions.first : null;
        final events = institution != null
            ? institutionProvider.getEventsByInstitution(institution.id)
            : const <Event>[];

        final activeEvents = events.where((e) => e.isActive).length;
        var totalRevenue = 0.0;
        for (final event in events) {
          final price = event.price ?? 0;
          if (price <= 0) continue;
          totalRevenue += price * event.currentAttendees;
        }

        final stats = [
          {
            'title': 'Total Visitors',
            'value': visitorValue,
            'change': visitorChange,
            'positive': visitorsThis >= visitorsPrev,
          },
          {
            'title': 'Active Events',
            'value': activeEvents.toString(),
            'change': '\u2014',
            'positive': true,
          },
          {
            'title': 'Artwork Views',
            'value': artworkValue,
            'change': artworkChange,
            'positive': artworkViewsThis >= artworkViewsPrev,
          },
          {
            'title': 'Revenue',
            'value': '\$${_formatRevenue(totalRevenue)}',
            'change': '\u2014',
            'positive': true,
          },
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (hasError) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Unable to load analytics right now.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        unawaited(statsProvider.ensureSeries(
                          entityType: 'user',
                          entityId: walletAddress,
                          metric: 'viewsReceived',
                          bucket: bucket,
                          timeframe: timeframe,
                          from: currentFrom.toIso8601String(),
                          to: currentTo.toIso8601String(),
                          groupBy: 'targetType',
                          scope: 'private',
                          forceRefresh: true,
                        ));
                        unawaited(statsProvider.ensureSeries(
                          entityType: 'user',
                          entityId: walletAddress,
                          metric: 'viewsReceived',
                          bucket: bucket,
                          timeframe: timeframe,
                          from: prevFrom.toIso8601String(),
                          to: prevTo.toIso8601String(),
                          groupBy: 'targetType',
                          scope: 'private',
                          forceRefresh: true,
                        ));
                      },
                      child: Text(
                        'Retry',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.3,
              children: stats.map((stat) => _buildStatCard(stat)).toList(),
            ),
          ],
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  String _formatRevenue(double revenue) {
    if (revenue >= 1000) {
      return '${(revenue / 1000).toStringAsFixed(1)}k';
    }
    return revenue.toStringAsFixed(0);
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              stat['title'],
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              stat['value'],
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Row(
              children: [
                Icon(
                  stat['positive'] ? Icons.trending_up : Icons.trending_down,
                  color: stat['positive']
                      ? KubusColorRoles.of(context).positiveAction
                      : KubusColorRoles.of(context).negativeAction,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    stat['change'],
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: stat['positive']
                          ? KubusColorRoles.of(context).positiveAction
                          : KubusColorRoles.of(context).negativeAction,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorAnalytics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visitor Analytics',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildVisitorChart(),
          const SizedBox(height: 16),
          _buildVisitorMetrics(),
        ],
      ),
    );
  }

  Widget _buildVisitorChart() {
    return Consumer<StatsProvider>(
      builder: (context, statsProvider, child) {
        final scheme = Theme.of(context).colorScheme;
        final roles = KubusColorRoles.of(context);
        final walletAddress = _resolveWalletAddress(listen: true);

        if (walletAddress.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: EmptyStateCard(
                icon: Icons.analytics_outlined,
                title: 'Connect your wallet',
                description: 'Connect a wallet to see visitor analytics.',
                showAction: false,
              ),
            ),
          );
        }

        if (!statsProvider.analyticsEnabled) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: EmptyStateCard(
                icon: Icons.analytics_outlined,
                title: 'Analytics disabled',
                description: 'Enable analytics in Settings to view charts and insights.',
                showAction: false,
              ),
            ),
          );
        }

        final timeframe = context.watch<AnalyticsFiltersProvider>().institutionTimeframe;
        final bucket = _bucketForTimeframe(timeframe);
        final duration = _durationForTimeframe(timeframe);
        final now = DateTime.now().toUtc();
        final currentTo = _bucketStartUtc(now, bucket);
        final currentFrom = currentTo.subtract(duration);

        unawaited(statsProvider.ensureSeries(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: currentFrom.toIso8601String(),
          to: currentTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        ));

        final series = statsProvider.getSeries(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: currentFrom.toIso8601String(),
          to: currentTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        );

        final isLoading = series == null &&
            statsProvider.isSeriesLoading(
              entityType: 'user',
              entityId: walletAddress,
              metric: 'viewsReceived',
              bucket: bucket,
              timeframe: timeframe,
              from: currentFrom.toIso8601String(),
              to: currentTo.toIso8601String(),
              groupBy: 'targetType',
              scope: 'private',
            );
        final error = statsProvider.seriesError(
          entityType: 'user',
          entityId: walletAddress,
          metric: 'viewsReceived',
          bucket: bucket,
          timeframe: timeframe,
          from: currentFrom.toIso8601String(),
          to: currentTo.toIso8601String(),
          groupBy: 'targetType',
          scope: 'private',
        );
        final hasError = !isLoading && error != null && series == null;

        final buckets = _fillGroupBuckets(
          series: series,
          fromInclusive: currentFrom,
          toExclusive: currentTo,
          bucket: bucket,
          groups: const <String>{'event', 'exhibition'},
        );
        final hasData = buckets.any((entry) => entry.value > 0);

        if (isLoading) {
          return SizedBox(
            height: 120,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: roles.web3InstitutionAccent,
                ),
              ),
            ),
          );
        }

        if (hasError) {
          return SizedBox(
            height: 120,
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  unawaited(statsProvider.ensureSeries(
                    entityType: 'user',
                    entityId: walletAddress,
                    metric: 'viewsReceived',
                    bucket: bucket,
                    timeframe: timeframe,
                    from: currentFrom.toIso8601String(),
                    to: currentTo.toIso8601String(),
                    groupBy: 'targetType',
                    scope: 'private',
                    forceRefresh: true,
                  ));
                },
                icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                label: Text(
                  'Retry loading visitors',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        }

        if (!hasData) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: EmptyStateCard(
                icon: Icons.people_outline,
                title: 'No visitors yet',
                description: 'Views will appear once people visit your events and exhibitions.',
                showAction: false,
              ),
            ),
          );
        }

        String labelFor(DateTime bucketStart) {
          final d = bucketStart.toLocal();
          if (bucket == 'day' && timeframe == '7d') {
            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            return days[(d.weekday - 1).clamp(0, 6)];
          }
          final mm = d.month.toString().padLeft(2, '0');
          final dd = d.day.toString().padLeft(2, '0');
          return '$mm/$dd';
        }

        return StatsInteractiveBarChart(
          height: 120,
          barColor: roles.web3InstitutionAccent,
          gridColor: scheme.onPrimary.withValues(alpha: 0.1),
          entries: buckets
              .map((e) => StatsBarEntry(bucketStart: e.bucketStart, value: e.value))
              .toList(growable: false),
          xLabels: buckets.map((e) => labelFor(e.bucketStart)).toList(growable: false),
        );
      },
    );
  }

  Widget _buildVisitorMetrics() {
    return Consumer<InstitutionProvider>(
      builder: (context, institutionProvider, child) {
        final institution =
            institutionProvider.institutions.isNotEmpty ? institutionProvider.institutions.first : null;

        final events = institution != null
            ? institutionProvider.getEventsByInstitution(institution.id)
            : const <Event>[];

        double? avgDurationMinutes;
        if (events.isNotEmpty) {
          final minutes = events
              .map((e) => e.endDate.difference(e.startDate).inMinutes)
              .fold<int>(0, (sum, value) => sum + value);
          avgDurationMinutes = minutes / events.length;
        }
        final avgDurationLabel = avgDurationMinutes == null
            ? '—'
            : avgDurationMinutes >= 60
                ? '${(avgDurationMinutes / 60).toStringAsFixed(1)} h'
                : '${avgDurationMinutes.round()} min';

        double? avgFill;
        final fillValues = events
            .where((e) => (e.capacity ?? 0) > 0)
            .map((e) => e.currentAttendees / e.capacity!)
            .toList();
        if (fillValues.isNotEmpty) {
          avgFill = fillValues.fold<double>(0, (sum, v) => sum + v) / fillValues.length;
        }
        final avgFillLabel = avgFill == null ? '—' : '${(avgFill * 100).toStringAsFixed(0)}%';

        final metrics = [
          {'label': 'Avg. Event Duration', 'value': avgDurationLabel},
          {'label': 'Avg. Event Fill', 'value': avgFillLabel},
          {'label': 'Return Visitors', 'value': '—'},
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: metrics
                      .map(
                        (metric) => Flexible(
                          child: Column(
                            children: [
                              Text(
                                metric['value']!,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                metric['label']!,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventPerformance() {
    return Consumer<InstitutionProvider>(
      builder: (context, institutionProvider, child) {
        final institution = institutionProvider.institutions.isNotEmpty
            ? institutionProvider.institutions.first
            : null;

        final institutionEvents = institution != null
            ? List<Event>.from(
                institutionProvider.getEventsByInstitution(institution.id))
            : <Event>[];
        institutionEvents
            .sort((a, b) => b.currentAttendees.compareTo(a.currentAttendees));
        final topEvents = institutionEvents.take(3).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Event Performance',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              if (topEvents.isEmpty)
                EmptyStateCard(
                  icon: Icons.event_busy,
                  title: 'No events yet',
                  description:
                      'Create your first event to see performance analytics.',
                  showAction: false,
                )
              else
                ...topEvents.map((event) {
                  final capacity = event.capacity ?? 0;
                  final fillPct =
                      capacity > 0 ? (event.currentAttendees / capacity) : null;
                  final fillText = fillPct == null
                      ? 'No capacity'
                      : '${(fillPct * 100).toStringAsFixed(0)}% full';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${event.currentAttendees} attendees',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                    .withValues(alpha: 0.14)),
                          ),
                          child: Text(
                            fillText,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueAnalytics() {
    return Consumer<InstitutionProvider>(
      builder: (context, institutionProvider, child) {
        final institution = institutionProvider.institutions.isNotEmpty
            ? institutionProvider.institutions.first
            : null;

        final events = institution != null
            ? institutionProvider.getEventsByInstitution(institution.id)
            : const <Event>[];
        final revenueByType = <String, double>{};
        var totalRevenue = 0.0;

        for (final event in events) {
          final price = event.price ?? 0;
          if (price <= 0) continue;
          final revenue = price * event.currentAttendees;
          if (revenue <= 0) continue;
          totalRevenue += revenue;
          final typeLabel =
              event.type.name.replaceAll(RegExp(r'([A-Z])'), r' $1');
          final normalizedTypeLabel = typeLabel.isNotEmpty
              ? '${typeLabel[0].toUpperCase()}${typeLabel.substring(1)}'
              : 'Event';
          revenueByType[normalizedTypeLabel] =
              (revenueByType[normalizedTypeLabel] ?? 0) + revenue;
        }

        final sorted = revenueByType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue Analytics',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              if (totalRevenue <= 0)
                EmptyStateCard(
                  icon: Icons.payments_outlined,
                  title: 'No revenue data yet',
                  description:
                      'Revenue will appear after paid events collect attendees.',
                  showAction: false,
                )
              else ...[
                ...sorted.take(4).map((entry) {
                  final pct =
                      totalRevenue > 0 ? entry.value / totalRevenue : 0.0;
                  return _buildRevenueItem(
                      entry.key, '\$${entry.value.toStringAsFixed(0)}', pct);
                }),
                const SizedBox(height: 4),
                Text(
                  'Total: \$${totalRevenue.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueItem(String category, String amount, double percentage) {
    final animationTheme = context.animationTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: InlineLoading(
                progress: percentage,
                tileSize: 6.0,
                color: KubusColorRoles.of(context).web3InstitutionAccent,
                duration: animationTheme.medium,
                animate: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkAnalytics() {
    return Consumer2<InstitutionProvider, ArtworkProvider>(
      builder: (context, institutionProvider, artworkProvider, child) {
        // Get artworks from institution or all artworks
        final artworks = artworkProvider.artworks.toList()
          ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));

        final topArtworks = artworks.take(3).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Artworks',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              if (topArtworks.isEmpty)
                _buildArtworkItem('No artworks yet', '0 views', '0 likes')
              else
                ...topArtworks.map((artwork) => _buildArtworkItem(
                      artwork.title,
                      '${_formatNumber(artwork.viewsCount)} views',
                      '${artwork.likesCount} likes',
                    )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtworkItem(String title, String views, String rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KubusColorRoles.of(context)
                  .web3InstitutionAccent
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.image,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  '$views • $rating',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Export Analytics',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Export your analytics data as CSV.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(() async {
                try {
                  await _exportAnalyticsCsv();
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text('Unable to export analytics.'),
                      backgroundColor: scheme.error,
                    ),
                  );
                }
              }());
            },
            child: const Text('Export CSV'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAnalyticsCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final statsProvider = context.read<StatsProvider>();
    final walletAddress = _resolveWalletAddress(listen: false);

    if (walletAddress.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Connect your wallet to export analytics.'),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    if (!statsProvider.analyticsEnabled) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Analytics is disabled. Enable it in Settings to export.'),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    final timeframe = context.read<AnalyticsFiltersProvider>().institutionTimeframe;
    final periodLabel = switch (timeframe) {
      '7d' => 'This Week',
      '30d' => 'This Month',
      '90d' => 'This Quarter',
      '1y' => 'This Year',
      _ => 'This Month',
    };
    final bucket = _bucketForTimeframe(timeframe);
    final duration = _durationForTimeframe(timeframe);
    final now = DateTime.now().toUtc();
    final currentTo = _bucketStartUtc(now, bucket);
    final currentFrom = currentTo.subtract(duration);

    final series = await statsProvider.ensureSeries(
      entityType: 'user',
      entityId: walletAddress,
      metric: 'viewsReceived',
      bucket: bucket,
      timeframe: timeframe,
      from: currentFrom.toIso8601String(),
      to: currentTo.toIso8601String(),
      groupBy: 'targetType',
      scope: 'private',
      forceRefresh: true,
    );
    if (!mounted) return;

    final points = (series?.series ?? const <StatsSeriesPoint>[]).toList();
    if (points.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('No analytics data available to export.'),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    final visitorBuckets = _fillGroupBuckets(
      series: series,
      fromInclusive: currentFrom,
      toExclusive: currentTo,
      bucket: bucket,
      groups: const <String>{'event', 'exhibition'},
    );
    final artworkBuckets = _fillGroupBuckets(
      series: series,
      fromInclusive: currentFrom,
      toExclusive: currentTo,
      bucket: bucket,
      groups: const <String>{'artwork'},
    );

    final totalVisitors = visitorBuckets.fold<int>(0, (sum, b) => sum + b.value);
    final artworkViews = artworkBuckets.fold<int>(0, (sum, b) => sum + b.value);

    final buffer = StringBuffer()
      ..writeln('key,value')
      ..writeln('period,${periodLabel.replaceAll(",", " ")}')
      ..writeln('timeframe,$timeframe')
      ..writeln('bucket,$bucket')
      ..writeln('from,${currentFrom.toIso8601String()}')
      ..writeln('to,${currentTo.toIso8601String()}')
      ..writeln('totalVisitors,$totalVisitors')
      ..writeln('artworkViews,$artworkViews')
      ..writeln('')
      ..writeln('bucketStartUtc,visitors,artworkViews');

    final rowCount = visitorBuckets.length < artworkBuckets.length ? visitorBuckets.length : artworkBuckets.length;
    for (var i = 0; i < rowCount; i += 1) {
      buffer.writeln(
        '${visitorBuckets[i].bucketStart.toIso8601String()},${visitorBuckets[i].value},${artworkBuckets[i].value}',
      );
    }

    final dir = await getTemporaryDirectory();
    if (!mounted) return;
    final filename =
        'institution_analytics_${timeframe}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Institution analytics',
        text: 'Exported institution analytics (${periodLabel.trim()}).',
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Analytics Settings',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Configure your analytics tracking preferences.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonClose),
          ),
        ],
      ),
    );
  }
}

class _BucketStat {
  final DateTime bucketStart;
  final int value;

  const _BucketStat(this.bucketStart, this.value);
}
