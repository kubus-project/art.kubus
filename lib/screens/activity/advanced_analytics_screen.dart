import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/topbar_icon.dart';
import '../../widgets/empty_state_card.dart';
import '../../utils/app_animations.dart';
import '../../utils/app_color_utils.dart';
import '../../models/stats/stats_models.dart';
import '../../services/stats_api_service.dart';
import '../../providers/profile_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/web3provider.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  final String statType;
  
  const AdvancedAnalyticsScreen({super.key, required this.statType});

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;
  bool _didPlayEntrance = false;
  
  String _selectedPeriod = '7D';
  final List<String> _periods = ['1D', '7D', '30D', '90D', '1Y'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimationTheme.defaults.long,
      vsync: this,
    );
    _configureAnimations(AppAnimationTheme.defaults);
    _tabController = TabController(length: 4, vsync: this);
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final web3Provider = context.watch<Web3Provider>();
    final statsProvider = context.watch<StatsProvider>();
    final wallet = (profileProvider.currentUser?.walletAddress ??
            web3Provider.walletAddress)
        .trim();
    final analytics = _buildAnalyticsContext(
      statsProvider: statsProvider,
      walletAddress: wallet,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '${widget.statType} Analytics',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            TopBarIcon(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () => unawaited(_shareAnalytics(analytics)),
              tooltip: 'Share',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildTabBar(),
            Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                  _buildOverviewTab(analytics),
                  _buildTrendsTab(analytics),
                  _buildInsightsTab(analytics),
                  _buildComparisonsTab(analytics),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColorUtils.amberAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColorUtils.amberAccent,
      unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
      indicatorColor: AppColorUtils.amberAccent,
      labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Trends'),
        Tab(text: 'Insights'),
        Tab(text: 'Compare'),
      ],
    );
  }

  Widget _buildOverviewTab(_AnalyticsContext analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsSummary(analytics),
          const SizedBox(height: 24),
          _buildAdvancedChart(analytics),
          const SizedBox(height: 24),
          _buildKeyMetrics(analytics),
          const SizedBox(height: 24),
          _buildGoalProgress(analytics),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(_AnalyticsContext analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrendAnalysis(analytics),
          const SizedBox(height: 24),
          _buildSeasonalityChart(analytics),
          const SizedBox(height: 24),
          _buildGrowthProjections(analytics),
        ],
      ),
    );
  }

  Widget _buildInsightsTab(_AnalyticsContext analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIInsights(analytics),
          const SizedBox(height: 24),
          _buildPerformanceBreakdown(analytics),
          const SizedBox(height: 24),
          _buildRecommendations(analytics),
        ],
      ),
    );
  }

  Widget _buildComparisonsTab(_AnalyticsContext analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBenchmarkComparison(analytics),
          const SizedBox(height: 24),
          _buildPeerAnalysis(analytics),
          const SizedBox(height: 24),
          _buildMarketPosition(analytics),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(_AnalyticsContext analytics) {
    final scheme = Theme.of(context).colorScheme;
    if (!analytics.hasWallet) {
      return EmptyStateCard(
        icon: Icons.analytics_outlined,
        title: 'Connect your wallet',
        description: 'Analytics are available after signing in.',
        showAction: false,
      );
    }

    if (!analytics.analyticsEnabled) {
      return EmptyStateCard(
        icon: Icons.analytics_outlined,
        title: 'Analytics disabled',
        description: 'Enable analytics in privacy settings to view charts.',
        showAction: false,
      );
    }

    final currentValue = analytics.currentTotal;
    final change = analytics.changePct;
    final isPositive = (change ?? 0) >= 0;
    final changeLabel = change == null ? 'N/A' : '${change.abs().toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.tertiary.withValues(alpha: 0.1),
            scheme.tertiary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.tertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This period',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatValue(currentValue),
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              if (analytics.isLoading && analytics.chartData.isEmpty)
                InlineLoading(
                  width: 26,
                  height: 12,
                  tileSize: 4.0,
                  color: scheme.tertiary,
                  borderRadius: BorderRadius.circular(10),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: isPositive ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        changeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'vs previous $_selectedPeriod',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedChart(_AnalyticsContext analytics) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.statType} Over Time',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: analytics.isLoading && analytics.chartData.isEmpty
                ? Center(
                    child: InlineLoading(
                      tileSize: 10.0,
                      color: scheme.tertiary,
                    ),
                  )
                : analytics.chartData.isEmpty
                    ? Center(
                        child: Text(
                          'No data available',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : CustomPaint(
                        painter: AdvancedChartPainter(
                          data: analytics.chartData,
                          accentColor: scheme.tertiary,
                        ),
                        size: Size.infinite,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(_AnalyticsContext analytics) {
    final metrics = analytics.keyMetrics;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    metric['icon'] as IconData,
                    color: metric['color'] as Color,
                    size: 24,
                  ),
                  const Spacer(),
                  Text(
                    metric['value'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    metric['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGoalProgress(_AnalyticsContext analytics) {
    final progress = analytics.goalProgress;
    final animationTheme = context.animationTheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal Progress',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: InlineLoading(
                progress: progress,
                tileSize: 8.0,
                color: AppColorUtils.greenAccent,
                duration: animationTheme.medium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'Target: ${analytics.goalTargetLabel}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysis(_AnalyticsContext analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend Analysis',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildTrendItem(
            'Overall Trend',
            analytics.trendLabel,
            analytics.trendIcon,
            analytics.trendColor,
          ),
          _buildTrendItem(
            'Growth Rate',
            analytics.changePctLabel,
            Icons.speed,
            analytics.trendColor,
          ),
          _buildTrendItem(
            'Volatility',
            analytics.volatilityLabel,
            Icons.show_chart,
            Colors.orange,
          ),
          _buildTrendItem(
            'Momentum',
            analytics.momentumLabel,
            Icons.rocket_launch,
            Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonalityChart(_AnalyticsContext analytics) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seasonality Pattern',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: analytics.seasonalityData.isEmpty
                ? const Center(
                    child: EmptyStateCard(
                      icon: Icons.insights,
                      title: 'Not enough data',
                      description:
                          'Seasonality becomes available after more activity is recorded.',
                      showAction: false,
                    ),
                  )
                : CustomPaint(
                    painter: SeasonalityChartPainter(
                      accentColor: scheme.tertiary,
                      data: analytics.seasonalityData,
                    ),
                    size: Size.infinite,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthProjections(_AnalyticsContext analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Projections',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (analytics.projections.isEmpty)
            const EmptyStateCard(
              icon: Icons.trending_up,
              title: 'Not available',
              description:
                  'Projections require enough historical data in the selected range.',
              showAction: false,
            )
          else
            ...analytics.projections.map(
              (p) => _buildProjectionItem(p.label, p.value, p.color),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectionItem(String period, String growth, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            period,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              growth,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsights(_AnalyticsContext analytics) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.10),
            scheme.secondary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Icon(Icons.psychology, color: scheme.primary, size: 24),
               const SizedBox(width: 8),
               Text(
                'Insights',
                 style: GoogleFonts.inter(
                   fontSize: 18,
                   fontWeight: FontWeight.bold,
                   color: Colors.white,
                 ),
               ),
             ],
           ),
           const SizedBox(height: 16),
          if (analytics.insights.isEmpty)
            const EmptyStateCard(
              icon: Icons.insights,
              title: 'No insights yet',
              description: 'Interact with the platform to start generating analytics.',
              showAction: false,
            )
          else
            ...analytics.insights
                .map((i) => _buildInsightItem(i.text, i.icon, i.color)),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBreakdown(_AnalyticsContext analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Breakdown',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...analytics.performanceBars.map(
            (bar) => _buildPerformanceBar(bar.label, bar.value, bar.color),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBar(String label, double value, Color color) {
    final animationTheme = context.animationTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 8,
              child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: InlineLoading(
                progress: value,
                tileSize: 6.0,
                color: color,
                duration: animationTheme.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(_AnalyticsContext analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommendations',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (analytics.recommendations.isEmpty)
            const EmptyStateCard(
              icon: Icons.lightbulb_outline,
              title: 'Not available',
              description: 'Recommendations appear once enough analytics data is available.',
              showAction: false,
            )
          else
            ...analytics.recommendations.map(
              (rec) => _buildRecommendationItem(
                rec.title,
                rec.description,
                rec.icon,
                rec.color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarkComparison(_AnalyticsContext analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Period Comparison',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (analytics.comparisons.isEmpty)
            const EmptyStateCard(
              icon: Icons.compare_arrows,
              title: 'Not available',
              description: 'Comparisons require enough analytics data.',
              showAction: false,
            )
          else
            ...analytics.comparisons.map(
              (c) => _buildComparisonItem(
                c.metric,
                c.currentValue,
                c.previousValue,
                c.isGood,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(String metric, String yourValue, String benchmarkValue, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              metric,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              yourValue,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isGood ? Colors.green : Colors.red,
              ),
            ),
          ),
          Expanded(
            child: Text(
              benchmarkValue,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          Icon(
            isGood ? Icons.trending_up : Icons.trending_down,
            color: isGood ? Colors.green : Colors.red,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildPeerAnalysis(_AnalyticsContext analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peer Analysis',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const EmptyStateCard(
            icon: Icons.people_outline,
            title: 'Not available',
            description: 'Peer benchmarking requires aggregate platform data.',
            showAction: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMarketPosition(_AnalyticsContext analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market Position',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const EmptyStateCard(
            icon: Icons.public,
            title: 'Not available',
            description: 'Market position insights require aggregate platform data.',
            showAction: false,
          ),
        ],
      ),
    );
  }

  _AnalyticsContext _buildAnalyticsContext({
    required StatsProvider statsProvider,
    required String walletAddress,
  }) {
    final hasWallet = walletAddress.trim().isNotEmpty;
    final analyticsEnabled = statsProvider.analyticsEnabled;

    final resolvedMetricRaw = StatsApiService.metricFromUiStatType(widget.statType);
    final metric = resolvedMetricRaw.trim().isNotEmpty ? resolvedMetricRaw.trim() : 'engagement';

    final timeframe = StatsApiService.timeframeFromLabel(_selectedPeriod);
    final bucket = timeframe == '24h' ? 'hour' : 'day';

    final now = DateTime.now().toUtc();
    final duration = _durationForTimeframe(timeframe);
    final prevFrom = now.subtract(Duration(seconds: duration.inSeconds * 2));
    final prevTo = now.subtract(duration);

    if (hasWallet && analyticsEnabled) {
      unawaited(statsProvider.ensureSeries(
        entityType: 'user',
        entityId: walletAddress,
        metric: metric,
        bucket: bucket,
        timeframe: timeframe,
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
      scope: 'private',
    );
    final previousSeries = statsProvider.getSeries(
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
      scope: 'private',
    );
    final error = statsProvider.seriesError(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      scope: 'private',
    );

    final prevLoading = statsProvider.isSeriesLoading(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: prevFrom.toIso8601String(),
      to: prevTo.toIso8601String(),
      scope: 'private',
    );
    final prevError = statsProvider.seriesError(
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
      final points = (s?.series ?? const []).toList()
        ..sort((a, b) => a.t.compareTo(b.t));
      return points.map((p) => p.v.toDouble()).toList(growable: false);
    }

    List<double> filledValues(StatsSeries? s, {required DateTime windowEnd}) {
      final raw = (s?.series ?? const []).toList();
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
      for (final point in raw) {
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

    final chartData = filledValues(series, windowEnd: now);
    final previousChartData = filledValues(previousSeries, windowEnd: prevTo);

    double sumSeries(StatsSeries? s) =>
        (s?.series ?? const []).fold<double>(0, (sum, p) => sum + p.v.toDouble());

    final currentTotal = sumSeries(series);
    final previousTotal = sumSeries(previousSeries);

    double? changePct;
    if (previousTotal > 0) {
      changePct = ((currentTotal - previousTotal) / previousTotal) * 100.0;
    } else if (currentTotal == 0) {
      changePct = 0.0;
    } else {
      changePct = null;
    }

    final changePctLabel = changePct == null
        ? 'N/A'
        : '${changePct >= 0 ? '+' : '-'}${changePct.abs().toStringAsFixed(1)}%';

    final scheme = Theme.of(context).colorScheme;
    final trendColor = changePct == null
        ? scheme.secondary
        : (changePct >= 0 ? Colors.green : Colors.red);
    final trendIcon = changePct == null
        ? Icons.trending_flat
        : (changePct >= 0 ? Icons.trending_up : Icons.trending_down);
    final trendLabel = changePct == null
        ? 'N/A'
        : (changePct.abs() < 0.1 ? 'Stable' : (changePct >= 0 ? 'Upward' : 'Downward'));

    double mean(List<double> values) =>
        values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

    double stdev(List<double> values) {
      if (values.length < 2) return 0.0;
      final m = mean(values);
      final variance = values
              .map((v) => (v - m) * (v - m))
              .reduce((a, b) => a + b) /
          values.length;
      return variance <= 0 ? 0.0 : math.sqrt(variance);
    }

    double? volatilityScore;
    final avg = mean(chartData);
    if (avg > 0) {
      final sd = stdev(chartData);
      volatilityScore = sd > 0 ? (sd / avg) : 0.0;
    } else {
      volatilityScore = null;
    }

    final volatilityLabel = volatilityScore == null
        ? 'N/A'
        : volatilityScore < 0.35
            ? 'Low'
            : volatilityScore < 0.75
                ? 'Medium'
                : 'High';

    final totalBuckets = chartData.isEmpty ? 0 : chartData.length;
    final nonZeroBuckets = chartData.where((v) => v > 0).length;
    final consistency = totalBuckets == 0 ? 0.0 : nonZeroBuckets / totalBuckets;
    final peak = chartData.isEmpty ? 0.0 : chartData.reduce((a, b) => a > b ? a : b);

    String momentumLabel = 'N/A';
    if (chartData.length >= 6) {
      final split = (chartData.length / 3).floor();
      final head = chartData.take(split).toList();
      final tail = chartData.skip(chartData.length - split).toList();
      final headAvg = mean(head);
      final tailAvg = mean(tail);
      if (headAvg == 0 && tailAvg == 0) {
        momentumLabel = 'Stable';
      } else if (tailAvg > headAvg * 1.1) {
        momentumLabel = 'Strong';
      } else if (tailAvg < headAvg * 0.9) {
        momentumLabel = 'Weak';
      } else {
        momentumLabel = 'Stable';
      }
    }

    final keyMetrics = <Map<String, dynamic>>[
      {
        'label': bucket == 'hour' ? 'Hourly Avg' : 'Daily Avg',
        'value': _formatValue(avg),
        'icon': Icons.today,
        'color': scheme.primary,
      },
      {
        'label': bucket == 'hour' ? 'Peak Hour' : 'Peak',
        'value': chartData.isEmpty ? '0' : chartData.reduce((a, b) => a > b ? a : b).toInt().toString(),
        'icon': Icons.trending_up,
        'color': scheme.secondary,
      },
      {
        'label': 'Growth Rate',
        'value': changePctLabel,
        'icon': Icons.speed,
        'color': scheme.primary.withValues(alpha: 0.85),
      },
      {
        'label': 'Consistency',
        'value': '${(consistency * 100).toStringAsFixed(0)}%',
        'icon': Icons.check_circle,
        'color': scheme.primary,
      },
    ];

    final goalTargetLabel = previousTotal > 0 ? _formatValue(previousTotal) : 'N/A';
    final goalProgress = previousTotal > 0
        ? (currentTotal / previousTotal).clamp(0.0, 1.0)
        : 0.0;

    List<double> seasonalityData = const [];
    if (bucket == 'day' && series != null && series.series.isNotEmpty) {
      final totals = List<double>.filled(7, 0.0);
      for (final point in series.series) {
        final w = point.t.toUtc().weekday;
        if (w >= 1 && w <= 7) {
          totals[w - 1] += point.v.toDouble();
        }
      }
      final max = totals.reduce((a, b) => a > b ? a : b);
      if (max > 0) {
        seasonalityData = totals.map((v) => (v / max).clamp(0.0, 1.0)).toList(growable: false);
      }
    }

    final projections = <_AnalyticsProjection>[];
    if (chartData.isNotEmpty && avg > 0) {
      projections.add(_AnalyticsProjection('Next 7 days', '~${_formatValue(avg * 7)}', Colors.green));
      projections.add(_AnalyticsProjection('Next 30 days', '~${_formatValue(avg * 30)}', scheme.tertiary));
    }

    final insights = <_AnalyticsInsight>[];
    if (chartData.isNotEmpty) {
      insights.add(_AnalyticsInsight('Peak bucket: ${peak.toInt()}', Icons.trending_up, Colors.green));
      insights.add(_AnalyticsInsight('Average per ${bucket == 'hour' ? 'hour' : 'day'}: ${_formatValue(avg)}', Icons.timeline, scheme.secondary));
      insights.add(_AnalyticsInsight('Consistency: ${(consistency * 100).toStringAsFixed(0)}%', Icons.check_circle, scheme.primary));
    }

    final performanceBars = <_AnalyticsPerformanceBar>[
      _AnalyticsPerformanceBar('Consistency', consistency.clamp(0.0, 1.0), scheme.primary),
      _AnalyticsPerformanceBar(
        'Stability',
        volatilityScore == null ? 0.0 : (1 / (1 + volatilityScore)).clamp(0.0, 1.0),
        Colors.green,
      ),
      _AnalyticsPerformanceBar(
        'Growth',
        changePct == null ? 0.0 : (((changePct.clamp(-100.0, 100.0)) + 100.0) / 200.0),
        scheme.tertiary,
      ),
      _AnalyticsPerformanceBar(
        'Activity',
        chartData.isEmpty ? 0.0 : (avg / (peak == 0 ? 1 : peak)).clamp(0.0, 1.0),
        scheme.secondary,
      ),
    ];

    final recommendations = <_AnalyticsRecommendation>[];
    if (chartData.isNotEmpty) {
      if (consistency < 0.4) {
        recommendations.add(_AnalyticsRecommendation(
          'Improve consistency',
          'Activity was recorded on $nonZeroBuckets of $totalBuckets buckets.',
          Icons.calendar_today,
          scheme.primary,
        ));
      }
      if (changePct != null && changePct < 0) {
        recommendations.add(_AnalyticsRecommendation(
          'Reverse the decline',
          'This period is down vs the previous period.',
          Icons.trending_down,
          Colors.red,
        ));
      } else if (changePct != null && changePct > 0) {
        recommendations.add(_AnalyticsRecommendation(
          'Maintain momentum',
          'This period is up vs the previous period.',
          Icons.trending_up,
          Colors.green,
        ));
      }
    }

    final comparisons = <_AnalyticsComparison>[];
    if (currentTotal > 0 || previousTotal > 0) {
      comparisons.add(_AnalyticsComparison(
        'Total',
        _formatValue(currentTotal),
        _formatValue(previousTotal),
        currentTotal >= previousTotal,
      ));
      comparisons.add(_AnalyticsComparison(
        bucket == 'hour' ? 'Avg / hour' : 'Avg / day',
        _formatValue(avg),
        previousChartData.isEmpty ? '0' : _formatValue(mean(previousChartData)),
        avg >= mean(previousChartData),
      ));
    }

    return _AnalyticsContext(
      walletAddress: walletAddress,
      metric: metric,
      timeframe: timeframe,
      bucket: bucket,
      hasWallet: hasWallet,
      analyticsEnabled: analyticsEnabled,
      isLoading: isLoading || prevLoading,
      error: error ?? prevError,
      chartData: chartData,
      previousChartData: previousChartData,
      currentTotal: currentTotal,
      previousTotal: previousTotal,
      changePct: changePct,
      changePctLabel: changePctLabel,
      trendLabel: trendLabel,
      trendIcon: trendIcon,
      trendColor: trendColor,
      volatilityLabel: volatilityLabel,
      momentumLabel: momentumLabel,
      keyMetrics: keyMetrics,
      goalProgress: goalProgress,
      goalTargetLabel: goalTargetLabel,
      seasonalityData: seasonalityData,
      projections: projections,
      insights: insights,
      performanceBars: performanceBars,
      recommendations: recommendations,
      comparisons: comparisons,
    );
  }

  String _formatValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toInt().toString();
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

  Future<void> _shareAnalytics(_AnalyticsContext analytics) async {
    if (!analytics.hasWallet) return;
    if (!analytics.analyticsEnabled) return;

    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final title = widget.statType.trim().isEmpty ? 'Analytics' : '${widget.statType} Analytics';
    final periodLabel = _selectedPeriod;
    final summary = StringBuffer()
      ..writeln(title)
      ..writeln('Period: $periodLabel')
      ..writeln('Total: ${_formatValue(analytics.currentTotal)}')
      ..writeln('Change: ${analytics.changePctLabel}')
      ..writeln('Trend: ${analytics.trendLabel}');

    try {
      await SharePlus.instance.share(
        ShareParams(text: summary.toString(), subject: title),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Unable to share analytics on this device.'),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _AnalyticsContext {
  final String walletAddress;
  final String metric;
  final String timeframe;
  final String bucket;
  final bool hasWallet;
  final bool analyticsEnabled;
  final bool isLoading;
  final Object? error;

  final List<double> chartData;
  final List<double> previousChartData;
  final double currentTotal;
  final double previousTotal;
  final double? changePct;
  final String changePctLabel;

  final String trendLabel;
  final IconData trendIcon;
  final Color trendColor;
  final String volatilityLabel;
  final String momentumLabel;

  final List<Map<String, dynamic>> keyMetrics;
  final double goalProgress;
  final String goalTargetLabel;

  final List<double> seasonalityData;
  final List<_AnalyticsProjection> projections;
  final List<_AnalyticsInsight> insights;
  final List<_AnalyticsPerformanceBar> performanceBars;
  final List<_AnalyticsRecommendation> recommendations;
  final List<_AnalyticsComparison> comparisons;

  const _AnalyticsContext({
    required this.walletAddress,
    required this.metric,
    required this.timeframe,
    required this.bucket,
    required this.hasWallet,
    required this.analyticsEnabled,
    required this.isLoading,
    required this.error,
    required this.chartData,
    required this.previousChartData,
    required this.currentTotal,
    required this.previousTotal,
    required this.changePct,
    required this.changePctLabel,
    required this.trendLabel,
    required this.trendIcon,
    required this.trendColor,
    required this.volatilityLabel,
    required this.momentumLabel,
    required this.keyMetrics,
    required this.goalProgress,
    required this.goalTargetLabel,
    required this.seasonalityData,
    required this.projections,
    required this.insights,
    required this.performanceBars,
    required this.recommendations,
    required this.comparisons,
  });
}

class _AnalyticsProjection {
  final String label;
  final String value;
  final Color color;

  const _AnalyticsProjection(this.label, this.value, this.color);
}

class _AnalyticsInsight {
  final String text;
  final IconData icon;
  final Color color;

  const _AnalyticsInsight(this.text, this.icon, this.color);
}

class _AnalyticsPerformanceBar {
  final String label;
  final double value;
  final Color color;

  const _AnalyticsPerformanceBar(this.label, this.value, this.color);
}

class _AnalyticsRecommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _AnalyticsRecommendation(this.title, this.description, this.icon, this.color);
}

class _AnalyticsComparison {
  final String metric;
  final String currentValue;
  final String previousValue;
  final bool isGood;

  const _AnalyticsComparison(this.metric, this.currentValue, this.previousValue, this.isGood);
}

// Custom chart painter for advanced analytics
class AdvancedChartPainter extends CustomPainter {
  final List<double> data;
  final Color accentColor;

  AdvancedChartPainter({required this.data, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    // Draw grid lines
    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i <= 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    if (data.isEmpty) return;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    if (range == 0) return;

    final path = Path();
    final fillPath = Path();
    
    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final normalizedValue = (data[i] - minValue) / range;
      final y = size.height * (1 - normalizedValue);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final normalizedValue = (data[i] - minValue) / range;
      final y = size.height * (1 - normalizedValue);
      
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Seasonality chart painter
class SeasonalityChartPainter extends CustomPainter {
  final Color accentColor;
  final List<double> data;

  SeasonalityChartPainter({required this.accentColor, required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final barWidth = size.width / data.length * 0.8;
    final spacing = size.width / data.length * 0.2;

    for (int i = 0; i < data.length; i++) {
      final x = i * (barWidth + spacing) + spacing / 2;
      final value = data[i].clamp(0.0, 1.0);
      final height = size.height * value;
      final y = size.height - height;

      final paint = Paint()
        ..color = accentColor.withValues(alpha: 0.6 + 0.4 * value)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromLTRBR(x, y, x + barWidth, size.height, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
