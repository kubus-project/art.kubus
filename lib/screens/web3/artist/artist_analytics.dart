import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/artwork.dart';
import '../../../models/stats/stats_models.dart';
import '../../../services/stats_api_service.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/rarity_ui.dart';

class ArtistAnalytics extends StatefulWidget {
  const ArtistAnalytics({super.key});

  @override
  State<ArtistAnalytics> createState() => _ArtistAnalyticsState();
}

class _ArtistAnalyticsState extends State<ArtistAnalytics> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _didPlayEntrance = false;
  
  String _selectedPeriod = 'Last 30 Days';
  int _currentChartIndex = 0;
  int _nftsSold = 0;
  bool _loadingNFTs = true;

  @override
  void initState() {
    super.initState();
    _loadNFTData();
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

  Future<void> _loadNFTData() async {
    final web3 = Provider.of<Web3Provider>(context, listen: false);
    final walletAddress = web3.walletAddress;
    if (!web3.isConnected || walletAddress.isEmpty) {
      setState(() {
        _loadingNFTs = false;
        _nftsSold = 0;
      });
      return;
    }

    try {
      final collectiblesProvider = Provider.of<CollectiblesProvider>(context, listen: false);
      if (!collectiblesProvider.isLoading &&
          collectiblesProvider.allSeries.isEmpty &&
          collectiblesProvider.allCollectibles.isEmpty) {
        await collectiblesProvider.initialize();
      }
      if (!mounted) return;
      final nfts = collectiblesProvider.getCollectiblesByOwner(walletAddress);
      setState(() {
        _nftsSold = nfts.length;
        _loadingNFTs = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ArtistAnalytics: _loadNFTData failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _loadingNFTs = false;
        _nftsSold = 0;
      });
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
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildOverviewCards(),
              const SizedBox(height: 16),
              _buildChartSection(),
              const SizedBox(height: 16),
              _buildDetailedMetrics(),
              const SizedBox(height: 16),
              _buildTopArtworks(),
              const SizedBox(height: 16),
              _buildRecentActivity(),
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
          'Analytics Dashboard',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your artwork performance',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        _buildPeriodSelector(),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
      ),
      child: DropdownButton<String>(
        value: _selectedPeriod,
        underline: const SizedBox(),
        isExpanded: true,
        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface, size: 20),
        items: ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last Year'].map((period) {
          return DropdownMenuItem<String>(
            value: period,
            child: Text(period),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedPeriod = value!;
          });
        },
      ),
    );
  }

  String _timeframeForSelectedPeriod() => StatsApiService.timeframeFromLabel(_selectedPeriod);

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

  int _totalFromSeries(StatsSeries? series) {
    return (series?.series ?? const <StatsSeriesPoint>[])
        .fold<int>(0, (sum, point) => sum + point.v);
  }

  String _formatPercentChange({required int current, required int previous}) {
    if (previous <= 0) {
      return current <= 0 ? '0%' : '\u2014';
    }
    final pct = ((current - previous) / previous) * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(0)}%';
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

  Widget _buildOverviewCards() {
    return Consumer2<ArtworkProvider, StatsProvider>(
      builder: (context, artworkProvider, statsProvider, child) {
        final themeProvider = context.watch<ThemeProvider>();
        final web3 = context.watch<Web3Provider>();
        final walletAddress = web3.walletAddress.trim();

        const snapshotMetrics = <String>[
          'viewsReceived',
          'arEnabledArtworks',
        ];

        if (walletAddress.isNotEmpty) {
          unawaited(statsProvider.ensureSnapshot(
            entityType: 'user',
            entityId: walletAddress,
            metrics: snapshotMetrics,
            scope: 'public',
          ));
        }

        final snapshot = walletAddress.isEmpty
            ? null
            : statsProvider.getSnapshot(
                entityType: 'user',
                entityId: walletAddress,
                metrics: snapshotMetrics,
                scope: 'public',
              );
        final snapshotCounters = snapshot?.counters ?? const <String, int>{};

        final artworks = artworkProvider.userArtworks;
        final estimatedRewards = artworks.fold<int>(0, (sum, a) => sum + a.actualRewards);
        final kub8Balance = web3.kub8Balance;
        final totalRevenueKub8 = kub8Balance + estimatedRewards.toDouble();

        final fallbackViews = artworks.fold<int>(0, (sum, a) => sum + a.viewsCount);
        final totalVisitors = snapshotCounters['viewsReceived'] ?? fallbackViews;
        final fallbackMarkers = artworks.where((a) => a.arEnabled).length;
        final activeMarkers = snapshotCounters['arEnabledArtworks'] ?? fallbackMarkers;

        final timeframe = _timeframeForSelectedPeriod();
        final bucket = _bucketForTimeframe(timeframe);
        final duration = _durationForTimeframe(timeframe);
        final now = DateTime.now().toUtc();
        final currentTo = _bucketStartUtc(now, bucket);
        final currentFrom = currentTo.subtract(duration);
        final prevTo = currentFrom;
        final prevFrom = prevTo.subtract(duration);

        if (walletAddress.isNotEmpty && statsProvider.analyticsEnabled) {
          unawaited(statsProvider.ensureSeries(
            entityType: 'user',
            entityId: walletAddress,
            metric: 'viewsReceived',
            bucket: bucket,
            timeframe: timeframe,
            from: currentFrom.toIso8601String(),
            to: currentTo.toIso8601String(),
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
            scope: 'private',
          ));

          unawaited(statsProvider.ensureSeries(
            entityType: 'user',
            entityId: walletAddress,
            metric: 'achievementTokensTotal',
            bucket: bucket,
            timeframe: timeframe,
            from: currentFrom.toIso8601String(),
            to: currentTo.toIso8601String(),
            scope: 'private',
          ));
          unawaited(statsProvider.ensureSeries(
            entityType: 'user',
            entityId: walletAddress,
            metric: 'achievementTokensTotal',
            bucket: bucket,
            timeframe: timeframe,
            from: prevFrom.toIso8601String(),
            to: prevTo.toIso8601String(),
            scope: 'private',
          ));
        }

        final viewsSeries = walletAddress.isEmpty
            ? null
            : statsProvider.getSeries(
                entityType: 'user',
                entityId: walletAddress,
                metric: 'viewsReceived',
                bucket: bucket,
                timeframe: timeframe,
                from: currentFrom.toIso8601String(),
                to: currentTo.toIso8601String(),
                scope: 'private',
              );
        final prevViewsSeries = walletAddress.isEmpty
            ? null
            : statsProvider.getSeries(
                entityType: 'user',
                entityId: walletAddress,
                metric: 'viewsReceived',
                bucket: bucket,
                timeframe: timeframe,
                from: prevFrom.toIso8601String(),
                to: prevTo.toIso8601String(),
                scope: 'private',
              );

        final earningsSeries = walletAddress.isEmpty
            ? null
            : statsProvider.getSeries(
                entityType: 'user',
                entityId: walletAddress,
                metric: 'achievementTokensTotal',
                bucket: bucket,
                timeframe: timeframe,
                from: currentFrom.toIso8601String(),
                to: currentTo.toIso8601String(),
                scope: 'private',
              );
        final prevEarningsSeries = walletAddress.isEmpty
            ? null
            : statsProvider.getSeries(
                entityType: 'user',
                entityId: walletAddress,
                metric: 'achievementTokensTotal',
                bucket: bucket,
                timeframe: timeframe,
                from: prevFrom.toIso8601String(),
                to: prevTo.toIso8601String(),
                scope: 'private',
              );

        final viewsThis = _totalFromSeries(viewsSeries);
        final viewsPrev = _totalFromSeries(prevViewsSeries);
        final viewsChange = statsProvider.analyticsEnabled
            ? _formatPercentChange(current: viewsThis, previous: viewsPrev)
            : '\u2014';
        final viewsPositive = viewsThis >= viewsPrev;

        final earningsThis = _totalFromSeries(earningsSeries);
        final earningsPrev = _totalFromSeries(prevEarningsSeries);
        final earningsChange = statsProvider.analyticsEnabled
            ? _formatPercentChange(current: earningsThis, previous: earningsPrev)
            : '\u2014';
        final earningsPositive = earningsThis >= earningsPrev;

        final inactiveChange = '\u2014';

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildMetricCard(
              'Total Revenue',
              '${totalRevenueKub8.toStringAsFixed(1)} KUB8',
              'Wallet: ${kub8Balance.toStringAsFixed(1)} KUB8',
              Icons.account_balance_wallet,
              themeProvider.accentColor,
              earningsChange,
              earningsPositive,
            ),
            _buildMetricCard(
              'Active Markers',
              activeMarkers.toString(),
              'AR-enabled artworks',
              Icons.location_on,
              Theme.of(context).colorScheme.primary,
              inactiveChange,
              true,
            ),
            _buildMetricCard(
              'Total Visitors',
              totalVisitors.toString(),
              'All-time views',
              Icons.people,
              Theme.of(context).colorScheme.tertiary,
              viewsChange,
              viewsPositive,
            ),
            _buildMetricCard(
              'NFTs Sold',
              _loadingNFTs ? '\u2026' : _nftsSold.toString(),
              _loadingNFTs
                  ? 'Loading...'
                  : (web3.isConnected
                      ? (_nftsSold > 0 ? '$_nftsSold minted' : 'No sales yet')
                      : 'Connect wallet'),
              Icons.token,
              Theme.of(context).colorScheme.secondary,
              inactiveChange,
              true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    String change,
    bool isPositive,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);

    final isNeutral = change.trim() == '\u2014';
    final chipColor = isNeutral
        ? scheme.onSurface.withValues(alpha: 0.6)
        : isPositive
            ? roles.positiveAction
            : scheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Consumer2<StatsProvider, Web3Provider>(
      builder: (context, statsProvider, web3, child) {
        final scheme = Theme.of(context).colorScheme;
        final themeProvider = context.watch<ThemeProvider>();

        final walletAddress = web3.walletAddress.trim();
        final timeframe = _timeframeForSelectedPeriod();
        final bucket = _bucketForTimeframe(timeframe);
        final duration = _durationForTimeframe(timeframe);
        final now = DateTime.now().toUtc();
        final currentTo = _bucketStartUtc(now, bucket);
        final currentFrom = currentTo.subtract(duration);
        final prevTo = currentFrom;
        final prevFrom = prevTo.subtract(duration);

        final metric = _currentChartIndex == 0
            ? 'achievementTokensTotal'
            : _currentChartIndex == 1
                ? 'viewsReceived'
                : 'engagement';

        if (walletAddress.isNotEmpty && statsProvider.analyticsEnabled) {
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

        final series = walletAddress.isEmpty
            ? null
            : statsProvider.getSeries(
                entityType: 'user',
                entityId: walletAddress,
                metric: metric,
                bucket: bucket,
                timeframe: timeframe,
                from: currentFrom.toIso8601String(),
                to: currentTo.toIso8601String(),
                scope: 'private',
              );
        final prevSeries = walletAddress.isEmpty
            ? null
            : statsProvider.getSeries(
                entityType: 'user',
                entityId: walletAddress,
                metric: metric,
                bucket: bucket,
                timeframe: timeframe,
                from: prevFrom.toIso8601String(),
                to: prevTo.toIso8601String(),
                scope: 'private',
              );

        final values = _filledValues(
          series,
          windowEnd: currentTo,
          timeframe: timeframe,
          bucket: bucket,
        );
        final previousValues = _filledValues(
          prevSeries,
          windowEnd: prevTo,
          timeframe: timeframe,
          bucket: bucket,
        );

        final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
        final averageValues = values.isEmpty ? const <double>[] : List<double>.filled(values.length, avg);

        final hasSeries = values.any((v) => v > 0) || previousValues.any((v) => v > 0);
        final isLoading = walletAddress.isNotEmpty &&
            statsProvider.analyticsEnabled &&
            ((series == null &&
                    statsProvider.isSeriesLoading(
                      entityType: 'user',
                      entityId: walletAddress,
                      metric: metric,
                      bucket: bucket,
                      timeframe: timeframe,
                      from: currentFrom.toIso8601String(),
                      to: currentTo.toIso8601String(),
                      scope: 'private',
                    )) ||
                (prevSeries == null &&
                    statsProvider.isSeriesLoading(
                      entityType: 'user',
                      entityId: walletAddress,
                      metric: metric,
                      bucket: bucket,
                      timeframe: timeframe,
                      from: prevFrom.toIso8601String(),
                      to: prevTo.toIso8601String(),
                      scope: 'private',
                    )));

        final currentLineColor = themeProvider.accentColor;
        final previousLineColor = scheme.secondary;
        final averageLineColor = scheme.tertiary;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 400;
                  
                  if (isSmallScreen) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance Overview',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildChartSelector(),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Text(
                          'Performance Overview',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        _buildChartSelector(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: walletAddress.isEmpty
                    ? Center(
                        child: Text(
                          'Connect wallet to view analytics.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : !statsProvider.analyticsEnabled
                        ? Center(
                            child: Text(
                              'Analytics is disabled in settings.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : isLoading
                            ? Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: themeProvider.accentColor,
                                  ),
                                ),
                              )
                            : !hasSeries
                            ? Center(
                                child: Text(
                                  'No analytics data yet.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: scheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : CustomPaint(
                                painter: LineChartPainter(
                                  current: values,
                                  previous: previousValues,
                                  average: averageValues,
                                  currentColor: currentLineColor,
                                  previousColor: previousLineColor,
                                  averageColor: averageLineColor,
                                  gridColor: scheme.onPrimary.withValues(alpha: 0.1),
                                ),
                                size: const Size(double.infinity, 200),
                              ),
              ),
              const SizedBox(height: 16),
              _buildChartLegend(
                currentColor: currentLineColor,
                previousColor: previousLineColor,
                averageColor: averageLineColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartSelector() {
    final options = ['Revenue', 'Views', 'Engagement'];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        if (isSmallScreen) {
          // Use Wrap for small screens to prevent overflow
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _currentChartIndex == index;
              
              return GestureDetector(
                onTap: () => setState(() => _currentChartIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Provider.of<ThemeProvider>(context).accentColor 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? Provider.of<ThemeProvider>(context).accentColor 
                          : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    option,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        } else {
          // Use Row for larger screens
          return Row(
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _currentChartIndex == index;
              
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _currentChartIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Provider.of<ThemeProvider>(context).accentColor 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected 
                            ? Provider.of<ThemeProvider>(context).accentColor 
                            : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildChartLegend({
    required Color currentColor,
    required Color previousColor,
    required Color averageColor,
  }) {
    final colors = [currentColor, previousColor, averageColor];
    final labels = ['This Period', 'Previous Period', 'Average'];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 350;
        
        if (isSmallScreen) {
          // Use Wrap for very small screens to prevent overflow
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: labels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors[index],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            }).toList(),
          );
        } else {
          // Use Row for larger screens
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: labels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colors[index],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildDetailedMetrics() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final artworks = artworkProvider.userArtworks;
        final totalViews = artworks.fold<int>(0, (sum, a) => sum + a.viewsCount);
        final totalLikes = artworks.fold<int>(0, (sum, a) => sum + a.likesCount);
        final totalComments = artworks.fold<int>(0, (sum, a) => sum + a.commentsCount);
        final favoritesCount = artworks.where((a) => a.isFavorite || a.isFavoriteByCurrentUser).length;

        final engagementRate = totalViews > 0 ? ((totalLikes + totalComments) / totalViews * 100) : 0.0;
        final conversionRate = totalViews > 0 ? (favoritesCount / totalViews * 100) : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Metrics',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
              Row(
                children: [
                Expanded(child: _buildMetricItem('Avg. View Time', '\u2014', Icons.schedule)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricItem('Engagement Rate', '${engagementRate.toStringAsFixed(1)}%', Icons.thumb_up)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricItem('Conversion Rate', '${conversionRate.toStringAsFixed(1)}%', Icons.trending_up)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricItem('Return Visitors', '\u2014', Icons.refresh)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopArtworks() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        // Top performing artworks by views
        final sorted = List<Artwork>.from(artworkProvider.artworks)
          ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        final topArtworks = sorted.take(4).map((artwork) {
          final viewsText = artwork.viewsCount.toString();
          final revenueText = '${artwork.actualRewards} KUB8';

          return {
            'title': artwork.title,
            'views': viewsText,
            'revenue': revenueText,
            'artwork': artwork,
          };
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Artworks',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...topArtworks.asMap().entries.map((entry) {
              final index = entry.key;
              final artworkData = entry.value;
              final artwork = artworkData['artwork'] as Artwork;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: RarityUi.artworkColor(context, artwork.rarity),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artworkData['title'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${artworkData['views']} views',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      artworkData['revenue'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Provider.of<ThemeProvider>(context).accentColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
  }

  Widget _buildRecentActivity() {
    return Consumer2<ArtworkProvider, ThemeProvider>(
      builder: (context, artworkProvider, themeProvider, child) {
        final activities = <Map<String, dynamic>>[];
        final artworks = artworkProvider.artworks;

        for (final a in artworks) {
          if (a.discoveredAt != null) {
            activities.add({
              'time': a.discoveredAt!,
              'icon': Icons.visibility,
              'action': 'Artwork "${a.title}" discovered',
            });
          }
          // Creation event
          activities.add({
            'time': a.createdAt,
            'icon': Icons.add,
            'action': 'New artwork "${a.title}" added',
          });
          // Latest comment event if available
          final comments = artworkProvider.getComments(a.id);
          if (comments.isNotEmpty) {
            comments.sort((c1, c2) => c2.createdAt.compareTo(c1.createdAt));
            activities.add({
              'time': comments.first.createdAt,
              'icon': Icons.comment,
              'action': 'New comment on "${a.title}"',
            });
          }
        }

        activities.sort((x, y) => (y['time'] as DateTime).compareTo(x['time'] as DateTime));
        final recent = activities.take(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: recent.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No recent activity',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      ]
                    : recent.map((activity) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeProvider.accentColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  activity['icon'] as IconData,
                                  color: themeProvider.accentColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity['action'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      _relativeTime(activity['time'] as DateTime),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    return weeks <= 1 ? '1w ago' : '${weeks}w ago';
  }

class LineChartPainter extends CustomPainter {
  final List<double> current;
  final List<double> previous;
  final List<double> average;
  final Color currentColor;
  final Color previousColor;
  final Color averageColor;
  final Color gridColor;

  LineChartPainter({
    required this.current,
    required this.previous,
    required this.average,
    required this.currentColor,
    required this.previousColor,
    required this.averageColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i <= 7; i++) {
      final x = size.width * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    double maxValue = 0;
    for (final v in current) {
      if (v > maxValue) maxValue = v;
    }
    for (final v in previous) {
      if (v > maxValue) maxValue = v;
    }
    for (final v in average) {
      if (v > maxValue) maxValue = v;
    }
    if (maxValue <= 0) maxValue = 1;

    void drawSeries(List<double> values, Color color, double strokeWidth) {
      if (values.isEmpty) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      final offsets = _toOffsets(values, size, maxValue);
      if (offsets.isEmpty) return;
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (var i = 1; i < offsets.length; i += 1) {
        path.lineTo(offsets[i].dx, offsets[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    drawSeries(previous, previousColor.withValues(alpha: 0.7), 1.5);
    drawSeries(average, averageColor.withValues(alpha: 0.6), 1.0);
    drawSeries(current, currentColor, 2.0);

    if (current.isNotEmpty) {
      final pointPaint = Paint()
        ..color = currentColor
        ..style = PaintingStyle.fill;

      for (final offset in _toOffsets(current, size, maxValue)) {
        canvas.drawCircle(offset, 2.5, pointPaint);
      }
    }
  }

  List<Offset> _toOffsets(List<double> values, Size size, double maxValue) {
    final points = <Offset>[];
    if (values.isEmpty) return points;
    if (values.length == 1) {
      final y = size.height * (1 - (values.first / maxValue));
      points.add(Offset(0, y));
      return points;
    }

    for (var i = 0; i < values.length; i += 1) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * (1 - (values[i] / maxValue));
      points.add(Offset(x, y));
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return !listEquals(oldDelegate.current, current) ||
        !listEquals(oldDelegate.previous, previous) ||
        !listEquals(oldDelegate.average, average) ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.previousColor != previousColor ||
        oldDelegate.averageColor != averageColor ||
        oldDelegate.gridColor != gridColor;
  }
}



