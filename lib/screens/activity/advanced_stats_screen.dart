import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/topbar_icon.dart';
import '../../widgets/empty_state_card.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/kubus_color_roles.dart';
import '../../models/stats/stats_models.dart';
import '../../providers/profile_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/web3provider.dart';
import '../../services/stats_api_service.dart';
import '../../widgets/charts/stats_interactive_line_chart.dart';

class AdvancedStatsScreen extends StatefulWidget {
  final String statType;
  
  const AdvancedStatsScreen({super.key, required this.statType});

  @override
  State<AdvancedStatsScreen> createState() => _AdvancedStatsScreenState();
}

class _AdvancedStatsScreenState extends State<AdvancedStatsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedTimeframe = '7 days';
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  List<String> _buildChartLabels(_StatsContext stats) {
    final now = DateTime.now().toUtc();

    DateTime startOfDayUtc(DateTime dt) {
      final utc = dt.toUtc();
      return DateTime.utc(utc.year, utc.month, utc.day);
    }

    DateTime startOfWeekUtc(DateTime dt) {
      final dayStart = startOfDayUtc(dt);
      return dayStart.subtract(Duration(days: dayStart.weekday - 1));
    }

    DateTime startOfHourUtc(DateTime dt) {
      final utc = dt.toUtc();
      return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    }

    final bucket = stats.bucket;
    final timeframe = stats.timeframe;

    final expected = stats.chartData.length;
    if (expected <= 0) return const [];

    if (bucket == 'hour') {
      final endBucket = startOfHourUtc(now);
      final startBucket = endBucket.subtract(const Duration(hours: 1) * (expected - 1));
      return List<String>.generate(
        expected,
        (i) {
          final t = startBucket.add(const Duration(hours: 1) * i);
          return t.hour.toString();
        },
        growable: false,
      );
    }

    if (bucket == 'week') {
      final endBucket = startOfWeekUtc(now);
      final startBucket = endBucket.subtract(const Duration(days: 7) * (expected - 1));
      return List<String>.generate(
        expected,
        (i) {
          final t = startBucket.add(const Duration(days: 7) * i);
          return '${t.month}/${t.day}';
        },
        growable: false,
      );
    }

    // Default: daily buckets
    final endBucket = startOfDayUtc(now);
    final startBucket = endBucket.subtract(const Duration(days: 1) * (expected - 1));
    return List<String>.generate(
      expected,
      (i) {
        final t = startBucket.add(const Duration(days: 1) * i);
        if (timeframe == '7d') {
          // Shorter labels when space is tight.
          return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday - 1];
        }
        return '${t.month}/${t.day}';
      },
      growable: false,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final web3Provider = context.watch<Web3Provider>();
    final statsProvider = context.watch<StatsProvider>();
    final wallet = (profileProvider.currentUser?.walletAddress ?? web3Provider.walletAddress).trim();
    final stats = _buildStatsContext(statsProvider: statsProvider, walletAddress: wallet);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.statType} Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TopBarIcon(
            icon: const Icon(Icons.download),
            onPressed: () => _showExportDialog(stats),
            tooltip: 'Export',
          ),
          TopBarIcon(
            icon: const Icon(Icons.share),
            onPressed: () => _showShareDialog(stats),
            tooltip: 'Share',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeframeSelectorCard(),
              const SizedBox(height: 20),
              _buildAdvancedChart(stats),
              const SizedBox(height: 20),
              _buildDetailedMetrics(stats),
              const SizedBox(height: 20),
              _buildComparativeAnalysis(stats),
              const SizedBox(height: 20),
              _buildInsightsCard(stats),
              const SizedBox(height: 20),
              _buildGoalsCard(stats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeSelectorCard() {
    final timeframes = ['7 days', '30 days', '3 months', '1 year', 'All time'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Range',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: timeframes.map((timeframe) {
                final isSelected = _selectedTimeframe == timeframe;
                return FilterChip(
                  selected: isSelected,
                  label: Text(timeframe),
                  onSelected: (selected) {
                    setState(() {
                      _selectedTimeframe = timeframe;
                    });
                  },
                  selectedColor: AppColorUtils.amberAccent.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedChart(_StatsContext stats) {
    final scheme = Theme.of(context).colorScheme;

    if (!stats.hasWallet) {
      return const EmptyStateCard(
        icon: Icons.analytics_outlined,
        title: 'Connect your wallet',
        description: 'Analytics are available after signing in.',
        showAction: false,
      );
    }

    if (!stats.analyticsEnabled) {
      return const EmptyStateCard(
        icon: Icons.analytics_outlined,
        title: 'Analytics disabled',
        description: 'Enable analytics in privacy settings to view charts.',
        showAction: false,
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.statType} Over Time',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _selectedTimeframe,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: stats.isLoading && stats.chartData.isEmpty
                  ? Center(
                      child: InlineLoading(
                        tileSize: 10.0,
                        color: scheme.tertiary,
                      ),
                    )
                  : stats.chartData.isEmpty
                      ? Center(
                          child: Text(
                            'No data available',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      : StatsInteractiveLineChart(
                          series: [
                            StatsLineSeries(
                              label: widget.statType,
                              values: stats.chartData,
                              color: scheme.tertiary,
                              showArea: true,
                            ),
                          ],
                          xLabels: _buildChartLabels(stats),
                          height: 250,
                          gridColor: scheme.onSurface.withValues(alpha: 0.12),
                        ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(_StatsContext stats) {
    final currentValue = stats.currentValueLabel;
    final change = stats.changePct;
    final isPositive = (change ?? 0) >= 0;
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Value',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                currentValue,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change ($_selectedTimeframe)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Row(
                children: [
                  Icon(
                    change == null
                        ? Icons.trending_flat
                        : (isPositive ? Icons.trending_up : Icons.trending_down),
                    color: change == null
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                        : (isPositive
                            ? KubusColorRoles.of(context).positiveAction
                            : KubusColorRoles.of(context).negativeAction),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    stats.changePctLabel,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: change == null
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                          : (isPositive
                              ? KubusColorRoles.of(context).positiveAction
                              : KubusColorRoles.of(context).negativeAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMetrics(_StatsContext stats) {
    final metrics = stats.detailedMetrics;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Metrics',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.isEmpty)
              const EmptyStateCard(
                icon: Icons.analytics_outlined,
                title: 'Not enough data',
                description: 'More activity is required to compute detailed metrics.',
                showAction: false,
              )
            else
              ...metrics.map((metric) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          metric['title'] ?? '',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        Text(
                          metric['value'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildComparativeAnalysis(_StatsContext stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comparative Analysis',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildComparisonItem(
              'vs. Last Period',
              stats.changePctLabel,
              stats.changePct == null ? null : (stats.changePct! >= 0),
            ),
            _buildComparisonItem('vs. Average User', 'N/A', null),
            _buildComparisonItem(
              'vs. Your Best Bucket',
              stats.vsBestBucketLabel,
              stats.vsBestBucketIsPositive,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(String label, String value, bool? isPositive) {
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = isPositive == null
        ? scheme.onSurface.withValues(alpha: 0.6)
        : (isPositive ? roles.positiveAction : roles.negativeAction);
    final resolvedIcon = isPositive == null
        ? Icons.remove
        : (isPositive ? Icons.arrow_upward : Icons.arrow_downward);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14),
          ),
          Row(
            children: [
              Icon(
                resolvedIcon,
                color: resolvedColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: resolvedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(_StatsContext stats) {
    final insights = stats.insights;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: AppColorUtils.purpleAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Insights',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (insights.isEmpty)
              const EmptyStateCard(
                icon: Icons.lightbulb_outline,
                title: 'Not enough data',
                description: 'Interact with the platform to generate insights.',
                showAction: false,
              )
            else
              ...insights.map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: AppColorUtils.purpleAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            insight,
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsCard(_StatsContext stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goals & Milestones',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildGoalItem('Next Milestone', stats.nextMilestoneLabel, stats.nextMilestoneProgress),
            const SizedBox(height: 12),
            _buildGoalItem('Monthly Goal (projection)', stats.monthGoalLabel, stats.monthGoalProgress),
            const SizedBox(height: 12),
            _buildGoalItem('Annual Goal (projection)', stats.yearGoalLabel, stats.yearGoalProgress),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(String title, String target, double progress) {
    final scheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            Text(
              target,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: InlineLoading(
              progress: progress,
              tileSize: 6.0,
              color: AppColorUtils.greenAccent,
              duration: const Duration(milliseconds: 700),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}% complete',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  void _showExportDialog(_StatsContext stats) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Export your stats data as CSV.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        unawaited(_exportCsv(stats));
      }
    });
  }

  void _showShareDialog(_StatsContext stats) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Stats'),
        content: const Text('Share a summary of this analytics view.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        unawaited(_share(stats));
      }
    });
  }

  Future<void> _exportCsv(_StatsContext stats) async {
    if (!stats.hasWallet) return;
    if (!stats.analyticsEnabled) return;

    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final statsProvider = context.read<StatsProvider>();
    final metricLabel = widget.statType.trim().isEmpty ? 'Metric' : widget.statType.trim();
    final title = '$metricLabel analytics';

    try {
      final series = await statsProvider.ensureSeries(
        entityType: 'user',
        entityId: stats.walletAddress,
        metric: stats.metric,
        bucket: stats.bucket,
        timeframe: stats.timeframe,
        scope: 'private',
      );
      if (!mounted) return;

      final points = (series?.series ?? const <StatsSeriesPoint>[]).toList()
        ..sort((a, b) => a.t.compareTo(b.t));
      if (points.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('No analytics data available to export.'),
            backgroundColor: scheme.error,
          ),
        );
        return;
      }

      final buffer = StringBuffer('timestamp,value\n');
      for (final p in points) {
        buffer.writeln('${p.t.toUtc().toIso8601String()},${p.v}');
      }

      final dir = await getTemporaryDirectory();
      if (!mounted) return;

      final filename =
          'analytics_${stats.metric}_${stats.timeframe}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}${Platform.pathSeparator}$filename');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: title,
          text: 'Exported $metricLabel analytics (${stats.timeframeLabel}).',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Unable to export analytics.'),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  Future<void> _share(_StatsContext stats) async {
    if (!stats.hasWallet) return;
    if (!stats.analyticsEnabled) return;

    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final metricLabel =
        widget.statType.trim().isEmpty ? 'Analytics' : '${widget.statType} Analytics';
    final summary = StringBuffer()
      ..writeln(metricLabel)
      ..writeln('Period: ${stats.timeframeLabel}')
      ..writeln('Total: ${stats.currentValueLabel}')
      ..writeln('Change: ${stats.changePctLabel}');

    try {
      await SharePlus.instance.share(
        ShareParams(text: summary.toString(), subject: metricLabel),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Unable to share analytics on this device.'),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  _StatsContext _buildStatsContext({
    required StatsProvider statsProvider,
    required String walletAddress,
  }) {
    final hasWallet = walletAddress.trim().isNotEmpty;
    final analyticsEnabled = statsProvider.analyticsEnabled;

    final metricRaw = StatsApiService.metricFromUiStatType(widget.statType);
    final metric = metricRaw.trim().isNotEmpty ? metricRaw.trim() : 'engagement';

    final timeframe = StatsApiService.timeframeFromLabel(_selectedTimeframe);
    final bucket = timeframe == '24h'
        ? 'hour'
        : timeframe == '1y'
            ? 'week'
            : 'day';

    final now = DateTime.now().toUtc();
    final duration = _durationForTimeframe(timeframe);

    DateTime bucketStartUtc(DateTime dt) {
      final utc = dt.toUtc();
      if (bucket == 'hour') return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
      if (bucket == 'week') {
        final startOfDay = DateTime.utc(utc.year, utc.month, utc.day);
        return startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
      }
      return DateTime.utc(utc.year, utc.month, utc.day);
    }

    Duration bucketStep() {
      if (bucket == 'hour') return const Duration(hours: 1);
      if (bucket == 'week') return const Duration(days: 7);
      return const Duration(days: 1);
    }

    final step = bucketStep();
    final currentTo = bucketStartUtc(now).add(step);
    final currentFrom = currentTo.subtract(duration);
    final prevTo = currentFrom;
    final prevFrom = prevTo.subtract(duration);

    if (hasWallet && analyticsEnabled) {
      unawaited(statsProvider.ensureSeries(
        entityType: 'user',
        entityId: walletAddress,
        metric: metric,
        bucket: bucket,
        timeframe: timeframe,
        from: currentFrom.toIso8601String(),
        to: currentTo.toIso8601String(),
        scope: 'private',
      ));
      unawaited(statsProvider.ensureSeries(
        entityType: 'user',
        entityId: walletAddress,
        metric: metric,
        bucket: bucket,
        timeframe: timeframe,
        from: prevFrom.toIso8601String(),
        to: prevTo.toIso8601String(),
        scope: 'private',
      ));
    }

    final series = statsProvider.getSeries(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: currentFrom.toIso8601String(),
      to: currentTo.toIso8601String(),
      scope: 'private',
    );
    final prevSeries = statsProvider.getSeries(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: prevFrom.toIso8601String(),
      to: prevTo.toIso8601String(),
      scope: 'private',
    );

    final isLoading = statsProvider.isSeriesLoading(
          entityType: 'user',
          entityId: walletAddress,
          metric: metric,
          bucket: bucket,
          timeframe: timeframe,
          from: currentFrom.toIso8601String(),
          to: currentTo.toIso8601String(),
          scope: 'private',
        ) ||
        statsProvider.isSeriesLoading(
          entityType: 'user',
          entityId: walletAddress,
          metric: metric,
          bucket: bucket,
          timeframe: timeframe,
          from: prevFrom.toIso8601String(),
          to: prevTo.toIso8601String(),
          scope: 'private',
        );

    List<double> toValues(StatsSeries? s) {
      final points = (s?.series ?? const <StatsSeriesPoint>[]).toList()
        ..sort((a, b) => a.t.compareTo(b.t));
      return points.map((p) => p.v.toDouble()).toList(growable: false);
    }

    List<double> filledValues(StatsSeries? s, {required DateTime windowEnd}) {
      if (bucket != 'day' && bucket != 'hour') return toValues(s);
      final expected = timeframe == '24h'
          ? 24
          : timeframe == '7d'
              ? 7
              : timeframe == '30d'
                  ? 30
                  : timeframe == '90d'
                      ? 90
                      : 30;

      final endBucket = bucket == 'hour'
          ? DateTime.utc(windowEnd.year, windowEnd.month, windowEnd.day, windowEnd.hour)
          : DateTime.utc(windowEnd.year, windowEnd.month, windowEnd.day);
      final step = bucket == 'hour' ? const Duration(hours: 1) : const Duration(days: 1);
      final startBucket = endBucket.subtract(step * (expected - 1));

      final valuesByBucket = <int, int>{};
      for (final point in (s?.series ?? const <StatsSeriesPoint>[])) {
        final dt = point.t.toUtc();
        final key = bucket == 'hour'
            ? DateTime.utc(dt.year, dt.month, dt.day, dt.hour).millisecondsSinceEpoch
            : DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
        valuesByBucket[key] = (valuesByBucket[key] ?? 0) + point.v;
      }

      return List<double>.generate(expected, (i) {
        final t = startBucket.add(step * i);
        final key = t.millisecondsSinceEpoch;
        return (valuesByBucket[key] ?? 0).toDouble();
      }, growable: false);
    }

    List<double> cumulative(List<double> values) {
      var running = 0.0;
      return values.map((v) {
        running += v;
        return running;
      }).toList(growable: false);
    }

    final rawValues = filledValues(series, windowEnd: currentTo.subtract(const Duration(milliseconds: 1)));
    final prevRawValues = filledValues(prevSeries, windowEnd: prevTo.subtract(const Duration(milliseconds: 1)));
    final chartData = cumulative(rawValues);

    double sum(List<double> values) => values.fold(0.0, (a, b) => a + b);
    final total = sum(rawValues);
    final prevTotal = sum(prevRawValues);

    double? changePct;
    if (prevTotal > 0) {
      changePct = ((total - prevTotal) / prevTotal) * 100.0;
    } else if (total == 0) {
      changePct = 0.0;
    } else {
      changePct = null;
    }
    final changePctLabel = changePct == null
        ? 'N/A'
        : '${changePct >= 0 ? '+' : '-'}${changePct.abs().toStringAsFixed(1)}%';

    final currentValueLabel = _formatValue(chartData.isEmpty ? 0.0 : chartData.last);

    final detailedMetrics = <Map<String, String>>[];
    if (rawValues.isNotEmpty) {
      final avg = total / rawValues.length;
      detailedMetrics.add({
        'title': bucket == 'hour' ? 'Average per hour' : 'Average per day',
        'value': _formatValue(avg),
      });
      detailedMetrics.add({
        'title': bucket == 'hour' ? 'Peak hour' : 'Peak day',
        'value': rawValues.reduce((a, b) => a > b ? a : b).toInt().toString(),
      });
      detailedMetrics.add({
        'title': 'Active buckets',
        'value': rawValues.where((v) => v > 0).length.toString(),
      });
      detailedMetrics.add({
        'title': 'Total',
        'value': _formatValue(total),
      });
    }

    final insights = <String>[];
    if (rawValues.isNotEmpty) {
      final nonZero = rawValues.where((v) => v > 0).length;
      insights.add('Activity recorded in $nonZero of ${rawValues.length} buckets.');
      if (changePct != null && changePct.abs() >= 0.1) {
        insights.add('This period is ${changePct >= 0 ? 'up' : 'down'} vs the previous period.');
      }
      final peakBucket = rawValues.reduce((a, b) => a > b ? a : b);
      insights.add('Peak bucket value: ${peakBucket.toInt()}.');
    }

    final peakBucket = rawValues.isEmpty ? 0.0 : rawValues.reduce((a, b) => a > b ? a : b);
    final lastBucket = rawValues.isEmpty ? 0.0 : rawValues.last;
    final vsBestBucketPct = peakBucket > 0 ? ((lastBucket - peakBucket) / peakBucket) * 100.0 : null;
    final vsBestBucketLabel = vsBestBucketPct == null
        ? 'N/A'
        : '${vsBestBucketPct >= 0 ? '+' : '-'}${vsBestBucketPct.abs().toStringAsFixed(1)}%';

    double nextMilestone(double value) {
      if (value <= 0) return 10;
      if (value < 50) return 50;
      if (value < 100) return 100;
      if (value < 500) return (value / 100).ceil() * 100;
      if (value < 1000) return 1000;
      return (value / 500).ceil() * 500;
    }

    final next = nextMilestone(total);
    final avgPerBucket = rawValues.isEmpty ? 0.0 : (total / rawValues.length);
    final monthMultiplier = bucket == 'hour'
        ? 24 * 30
        : bucket == 'week'
            ? 4
            : 30;
    final yearMultiplier = bucket == 'hour'
        ? 24 * 365
        : bucket == 'week'
            ? 52
            : 365;
    final monthGoal = avgPerBucket > 0 ? avgPerBucket * monthMultiplier : 0.0;
    final yearGoal = avgPerBucket > 0 ? avgPerBucket * yearMultiplier : 0.0;

    return _StatsContext(
      walletAddress: walletAddress,
      metric: metric,
      timeframe: timeframe,
      timeframeLabel: _selectedTimeframe,
      bucket: bucket,
      hasWallet: hasWallet,
      analyticsEnabled: analyticsEnabled,
      isLoading: isLoading,
      chartData: chartData,
      currentValueLabel: currentValueLabel,
      changePct: changePct,
      changePctLabel: changePctLabel,
      detailedMetrics: detailedMetrics,
      insights: insights,
      vsBestBucketLabel: vsBestBucketLabel,
      vsBestBucketIsPositive: vsBestBucketPct == null ? null : (vsBestBucketPct >= 0),
      nextMilestoneLabel: _formatValue(next),
      nextMilestoneProgress: next <= 0 ? 0.0 : (total / next).clamp(0.0, 1.0),
      monthGoalLabel: monthGoal <= 0 ? 'N/A' : _formatValue(monthGoal),
      monthGoalProgress: monthGoal <= 0 ? 0.0 : (total / monthGoal).clamp(0.0, 1.0),
      yearGoalLabel: yearGoal <= 0 ? 'N/A' : _formatValue(yearGoal),
      yearGoalProgress: yearGoal <= 0 ? 0.0 : (total / yearGoal).clamp(0.0, 1.0),
    );
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

  String _formatValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toInt().toString();
  }
}

class _StatsContext {
  final String walletAddress;
  final String metric;
  final String timeframe;
  final String timeframeLabel;
  final String bucket;
  final bool hasWallet;
  final bool analyticsEnabled;
  final bool isLoading;

  final List<double> chartData;
  final String currentValueLabel;
  final double? changePct;
  final String changePctLabel;
  final List<Map<String, String>> detailedMetrics;
  final List<String> insights;

  final String vsBestBucketLabel;
  final bool? vsBestBucketIsPositive;

  final String nextMilestoneLabel;
  final double nextMilestoneProgress;
  final String monthGoalLabel;
  final double monthGoalProgress;
  final String yearGoalLabel;
  final double yearGoalProgress;

  const _StatsContext({
    required this.walletAddress,
    required this.metric,
    required this.timeframe,
    required this.timeframeLabel,
    required this.bucket,
    required this.hasWallet,
    required this.analyticsEnabled,
    required this.isLoading,
    required this.chartData,
    required this.currentValueLabel,
    required this.changePct,
    required this.changePctLabel,
    required this.detailedMetrics,
    required this.insights,
    required this.vsBestBucketLabel,
    required this.vsBestBucketIsPositive,
    required this.nextMilestoneLabel,
    required this.nextMilestoneProgress,
    required this.monthGoalLabel,
    required this.monthGoalProgress,
    required this.yearGoalLabel,
    required this.yearGoalProgress,
  });
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color accentColor;
  final Color backgroundColor;
  
  LineChartPainter({
    required this.data,
    required this.accentColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    if (data.isEmpty) return;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    final safeRange = range == 0 ? 1.0 : range;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = data.length == 1 ? size.width / 2 : (i / (data.length - 1)) * size.width;
      final normalizedValue = range == 0 ? 0.5 : ((data[i] - minValue) / safeRange);
      final y = size.height - normalizedValue * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = data.length == 1 ? size.width / 2 : (i / (data.length - 1)) * size.width;
      final normalizedValue = range == 0 ? 0.5 : ((data[i] - minValue) / safeRange);
      final y = size.height - normalizedValue * size.height;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
