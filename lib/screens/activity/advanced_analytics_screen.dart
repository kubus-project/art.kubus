import 'dart:async';
import 'dart:math' as math;

import 'package:art_kubus/config/config.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/topbar_icon.dart';
import '../../widgets/empty_state_card.dart';
import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../models/stats/stats_models.dart';
import '../../services/stats_api_service.dart';
import '../../widgets/charts/stats_interactive_line_chart.dart';
import '../../widgets/charts/stats_interactive_bar_chart.dart';
import '../../providers/analytics_filters_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/web3provider.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

enum AnalyticsExperienceContext { home, profile, community }

class AdvancedAnalyticsScreen extends StatefulWidget {
  final String statType;
  final String? walletAddress;
  final AnalyticsExperienceContext initialContext;
  final List<AnalyticsExperienceContext> contexts;

  const AdvancedAnalyticsScreen({
    super.key,
    required this.statType,
    this.walletAddress,
    this.initialContext = AnalyticsExperienceContext.home,
    this.contexts = const <AnalyticsExperienceContext>[
      AnalyticsExperienceContext.home,
    ],
  });

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;
  bool _didPlayEntrance = false;
  late AnalyticsExperienceContext _activeContext;

  @override
  void initState() {
    super.initState();
    _activeContext = widget.initialContext;
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final profileProvider = context.watch<ProfileProvider>();
    final web3Provider = context.watch<Web3Provider>();
    final statsProvider = context.watch<StatsProvider>();
    final filtersProvider = context.watch<AnalyticsFiltersProvider>();
    final configProvider = context.watch<ConfigProvider>();
    final viewerWallet = (profileProvider.currentUser?.walletAddress ??
            web3Provider.walletAddress)
        .trim();
    final targetWallet = (widget.walletAddress?.trim().isNotEmpty ?? false)
        ? widget.walletAddress!.trim()
        : viewerWallet;
    final isOwner = viewerWallet.isNotEmpty &&
        targetWallet.isNotEmpty &&
        viewerWallet.toLowerCase() == targetWallet.toLowerCase();
    final definition = _buildDefinition(
      l10n: l10n,
      scheme: scheme,
      roles: roles,
      contextType: _activeContext,
      isOwner: isOwner,
    );
    final timeframe = filtersProvider.timeframeFor(definition.storageKey);
    final selectedMetricId = _resolveSelectedMetricId(
      definition: definition,
      storedMetricId: filtersProvider.metricFor(
        definition.storageKey,
        fallback: _defaultMetricForDefinition(definition),
      ),
      hasExplicitMetricSelection: filtersProvider.hasExplicitMetricFor(
        definition.storageKey,
      ),
      statType: widget.statType,
    );
    final analytics = _buildAnalyticsContext(
      statsProvider: statsProvider,
      walletAddress: targetWallet,
      definition: definition,
      timeframe: timeframe,
      selectedMetricId: selectedMetricId,
      canFetch: StatsApiService.shouldFetchAnalytics(
        analyticsFeatureEnabled: AppConfig.isFeatureEnabled('analytics'),
        analyticsPreferenceEnabled: configProvider.enableAnalytics,
      ),
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: scheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            definition.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          actions: [
            TopBarIcon(
              icon: Icon(Icons.share, color: scheme.onSurface),
              onPressed: () => unawaited(_shareAnalytics(analytics)),
              tooltip: 'Share',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildHeaderControls(
              definition: definition,
              selectedMetricId: selectedMetricId,
              timeframe: timeframe,
            ),
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

  Widget _buildHeaderControls({
    required _AnalyticsDefinition definition,
    required String selectedMetricId,
    required String timeframe,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            definition.scopeLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            definition.subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.35,
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          if (widget.contexts.length > 1) ...[
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: widget.contexts.map((contextType) {
                final selected = contextType == _activeContext;
                return ChoiceChip(
                  selected: selected,
                  label: Text(_contextLabel(l10n, contextType)),
                  avatar: Icon(_contextIcon(contextType), size: 16),
                  onSelected: (_) {
                    if (selected) return;
                    setState(() => _activeContext = contextType);
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: KubusSpacing.md),
          ],
          Wrap(
            spacing: KubusSpacing.md,
            runSpacing: KubusSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: KubusSpacing.sm,
                runSpacing: KubusSpacing.sm,
                children: AnalyticsFiltersProvider.allowedTimeframes.map((value) {
                  return ChoiceChip(
                    selected: timeframe == value,
                    label: Text(value.toUpperCase()),
                    onSelected: (_) {
                      context
                          .read<AnalyticsFiltersProvider>()
                          .setTimeframeFor(definition.storageKey, value);
                    },
                  );
                }).toList(growable: false),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedMetricId,
                  items: definition.metrics
                      .map(
                        (metric) => DropdownMenuItem<String>(
                          value: metric.id,
                          child: Text(metric.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null || value.trim().isEmpty) return;
                    context.read<AnalyticsFiltersProvider>().setMetricFor(
                          definition.storageKey,
                          value.trim(),
                          allowedMetrics: definition.metrics.map((metric) => metric.id),
                        );
                  },
                  decoration: InputDecoration(
                    labelText: l10n.analyticsMetricLabel,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _AnalyticsDefinition _buildDefinition({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required KubusColorRoles roles,
    required AnalyticsExperienceContext contextType,
    required bool isOwner,
  }) {
    final metrics = <String, _AnalyticsMetricDefinition>{
      'followers': _AnalyticsMetricDefinition(
        id: 'followers',
        label: l10n.userProfileFollowersStatLabel,
        icon: Icons.people_outline,
        color: scheme.primary,
      ),
      'posts': _AnalyticsMetricDefinition(
        id: 'posts',
        label: l10n.userProfilePostsStatLabel,
        icon: Icons.forum_outlined,
        color: scheme.secondary,
      ),
      'artworks': _AnalyticsMetricDefinition(
        id: 'artworks',
        label: l10n.userProfileArtworksTitle,
        icon: Icons.palette_outlined,
        color: roles.positiveAction,
      ),
      'viewsReceived': _AnalyticsMetricDefinition(
        id: 'viewsReceived',
        label: l10n.analyticsMetricViewsReceivedLabel,
        icon: Icons.visibility_outlined,
        color: scheme.tertiary,
      ),
      'likesReceived': _AnalyticsMetricDefinition(
        id: 'likesReceived',
        label: l10n.analyticsMetricLikesReceivedLabel,
        icon: Icons.favorite_border,
        color: roles.negativeAction,
      ),
      'engagement': _AnalyticsMetricDefinition(
        id: 'engagement',
        label: l10n.analyticsMetricEngagementLabel,
        icon: Icons.insights_outlined,
        color: scheme.primary,
        privateOnly: true,
      ),
      'viewsGiven': _AnalyticsMetricDefinition(
        id: 'viewsGiven',
        label: l10n.analyticsMetricViewsGivenLabel,
        icon: Icons.travel_explore_outlined,
        color: scheme.secondary,
        privateOnly: true,
      ),
    };

    switch (contextType) {
      case AnalyticsExperienceContext.home:
        return _AnalyticsDefinition(
          contextType: contextType,
          storageKey: AnalyticsFiltersProvider.homeContextKey,
          title: 'Analytics',
          subtitle:
              'Unified personal analytics for reach, activity, and momentum across the app.',
          scopeLabel: l10n.analyticsYourAnalyticsTitle,
          icon: Icons.analytics_outlined,
          accentColor: scheme.primary,
          metrics: <_AnalyticsMetricDefinition>[
            metrics['engagement']!,
            metrics['viewsReceived']!,
            metrics['followers']!,
            metrics['artworks']!,
          ],
        );
      case AnalyticsExperienceContext.profile:
        return _AnalyticsDefinition(
          contextType: contextType,
          storageKey: AnalyticsFiltersProvider.profileContextKey,
          title: l10n.profileAnalyticsProfileTitle,
          subtitle:
              'A single profile-focused analytics surface with public and owner-aware metrics.',
          scopeLabel:
              isOwner ? l10n.analyticsYourAnalyticsTitle : l10n.analyticsPublicAnalyticsTitle,
          icon: Icons.person_outline,
          accentColor: scheme.primary,
          metrics: <_AnalyticsMetricDefinition>[
            metrics['viewsReceived']!,
            metrics['followers']!,
            metrics['posts']!,
            metrics['artworks']!,
            metrics['likesReceived']!,
            if (isOwner) metrics['engagement']!,
            if (isOwner) metrics['viewsGiven']!,
          ],
        );
      case AnalyticsExperienceContext.community:
        return _AnalyticsDefinition(
          contextType: contextType,
          storageKey: AnalyticsFiltersProvider.communityContextKey,
          title: l10n.profileAnalyticsCommunityTitle,
          subtitle:
              'The same analytics system, configured around community posting and response signals.',
          scopeLabel:
              isOwner ? l10n.analyticsYourAnalyticsTitle : l10n.analyticsPublicAnalyticsTitle,
          icon: Icons.forum_outlined,
          accentColor: scheme.secondary,
          metrics: <_AnalyticsMetricDefinition>[
            metrics['posts']!,
            metrics['likesReceived']!,
            if (isOwner) metrics['engagement']!,
          ],
        );
    }
  }

  String _defaultMetricForDefinition(_AnalyticsDefinition definition) {
    switch (definition.contextType) {
      case AnalyticsExperienceContext.home:
        return 'engagement';
      case AnalyticsExperienceContext.profile:
        return 'viewsReceived';
      case AnalyticsExperienceContext.community:
        return 'posts';
    }
  }

  String _resolveSelectedMetricId({
    required _AnalyticsDefinition definition,
    required String storedMetricId,
    required bool hasExplicitMetricSelection,
    required String statType,
  }) {
    final statMetric = StatsApiService.metricFromUiStatType(statType).trim();
    final candidates = definition.contextType == AnalyticsExperienceContext.home &&
            statMetric.isNotEmpty &&
            !hasExplicitMetricSelection
        ? <String>[
            statMetric,
            storedMetricId.trim(),
            _defaultMetricForDefinition(definition),
          ]
        : <String>[
            storedMetricId.trim(),
            statMetric,
            _defaultMetricForDefinition(definition),
          ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      if (definition.metricById(candidate) != null) return candidate;
    }
    return definition.metrics.first.id;
  }

  String _contextLabel(AppLocalizations l10n, AnalyticsExperienceContext contextType) {
    switch (contextType) {
      case AnalyticsExperienceContext.home:
        return 'Home';
      case AnalyticsExperienceContext.profile:
        return l10n.profileAnalyticsProfileTitle;
      case AnalyticsExperienceContext.community:
        return l10n.profileAnalyticsCommunityTitle;
    }
  }

  IconData _contextIcon(AnalyticsExperienceContext contextType) {
    switch (contextType) {
      case AnalyticsExperienceContext.home:
        return Icons.home_outlined;
      case AnalyticsExperienceContext.profile:
        return Icons.person_outline;
      case AnalyticsExperienceContext.community:
        return Icons.forum_outlined;
    }
  }

  Widget _buildTabBar() {
    final scheme = Theme.of(context).colorScheme;
    return TabBar(
      controller: _tabController,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.6),
      indicatorColor: scheme.primary,
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
            'vs previous ${analytics.periodLabel}',
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

    List<String> buildLabels() {
      final now = DateTime.now().toUtc();
      final bucket = analytics.bucket;
      final timeframe = analytics.timeframe;
      final count = analytics.chartData.length;
      if (count <= 0) return const [];

      DateTime startOfDayUtc(DateTime dt) {
        final utc = dt.toUtc();
        return DateTime.utc(utc.year, utc.month, utc.day);
      }

      DateTime startOfHourUtc(DateTime dt) {
        final utc = dt.toUtc();
        return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
      }

      if (bucket == 'hour') {
        final endBucket = startOfHourUtc(now);
        final startBucket = endBucket.subtract(const Duration(hours: 1) * (count - 1));
        return List<String>.generate(
          count,
          (i) {
            final t = startBucket.add(const Duration(hours: 1) * i);
            return t.hour.toString();
          },
          growable: false,
        );
      }

      final endBucket = startOfDayUtc(now);
      final startBucket = endBucket.subtract(const Duration(days: 1) * (count - 1));
      return List<String>.generate(
        count,
        (i) {
          final t = startBucket.add(const Duration(days: 1) * i);
          if (timeframe == '7d') {
            return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday - 1];
          }
          return '${t.month}/${t.day}';
        },
        growable: false,
      );
    }

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
            '${analytics.metricLabel} Over Time',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
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
                    : StatsInteractiveLineChart(
                        series: [
                          StatsLineSeries(
                            label: analytics.metricLabel,
                            values: analytics.chartData,
                            color: scheme.tertiary,
                            showArea: true,
                          ),
                        ],
                        xLabels: buildLabels(),
                        height: 220,
                        gridColor: scheme.onSurface.withValues(alpha: 0.18),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
    final scheme = Theme.of(context).colorScheme;
    
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
                color: scheme.primary,
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
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seasonality Pattern',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
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
                : _buildSeasonalityInteractiveBarChart(analytics, scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonalityInteractiveBarChart(
    _AnalyticsContext analytics,
    ColorScheme scheme,
  ) {
    final data = analytics.seasonalityData;
    if (data.isEmpty) return const SizedBox.shrink();

    final labels = data.length == 7
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : List<String>.generate(data.length, (i) => '${i + 1}', growable: false);

    final now = DateTime.now();
    final entries = List<StatsBarEntry>.generate(
      data.length,
      (i) {
        final dayOffset = data.length - 1 - i;
        return StatsBarEntry(
          bucketStart: now.subtract(Duration(days: dayOffset)),
          value: (data[i] * 100).round(),
        );
      },
      growable: false,
    );

    return StatsInteractiveBarChart(
      entries: entries,
      xLabels: labels,
      barColor: scheme.tertiary,
      gridColor: scheme.onSurface.withValues(alpha: 0.12),
      height: 140,
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
    required _AnalyticsDefinition definition,
    required String timeframe,
    required String selectedMetricId,
    required bool canFetch,
  }) {
    final hasWallet = walletAddress.trim().isNotEmpty;
    final analyticsEnabled = canFetch;
    final metricDefinition = definition.metricById(selectedMetricId) ??
        definition.metricById(_defaultMetricForDefinition(definition))!;
    final metric = metricDefinition.id;
    final bucket = timeframe == '24h' ? 'hour' : 'day';
    final scope = definition.scopeFor(metricDefinition);

    final now = DateTime.now().toUtc();
    final duration = _durationForTimeframe(timeframe);

    DateTime bucketStartUtc(DateTime dt) {
      final utc = dt.toUtc();
      if (bucket == 'hour') return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
      return DateTime.utc(utc.year, utc.month, utc.day);
    }

    final step = bucket == 'hour' ? const Duration(hours: 1) : const Duration(days: 1);
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
        scope: scope,
      ));
      unawaited(statsProvider.ensureSeries(
        entityType: 'user',
        entityId: walletAddress,
        metric: metric,
        bucket: bucket,
        timeframe: timeframe,
        from: prevFrom.toIso8601String(),
        to: prevTo.toIso8601String(),
        scope: scope,
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
      scope: scope,
    );
    final previousSeries = statsProvider.getSeries(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: prevFrom.toIso8601String(),
      to: prevTo.toIso8601String(),
      scope: scope,
    );

    final isLoading = statsProvider.isSeriesLoading(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: currentFrom.toIso8601String(),
      to: currentTo.toIso8601String(),
      scope: scope,
    );
    final error = statsProvider.seriesError(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: currentFrom.toIso8601String(),
      to: currentTo.toIso8601String(),
      scope: scope,
    );

    final prevLoading = statsProvider.isSeriesLoading(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: prevFrom.toIso8601String(),
      to: prevTo.toIso8601String(),
      scope: scope,
    );
    final prevError = statsProvider.seriesError(
      entityType: 'user',
      entityId: walletAddress,
      metric: metric,
      bucket: bucket,
      timeframe: timeframe,
      from: prevFrom.toIso8601String(),
      to: prevTo.toIso8601String(),
      scope: scope,
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

    final chartData =
        filledValues(series, windowEnd: currentTo.subtract(const Duration(milliseconds: 1)));
    final previousChartData =
        filledValues(previousSeries, windowEnd: prevTo.subtract(const Duration(milliseconds: 1)));

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
    final roles = KubusColorRoles.of(context);
    final trendColor = changePct == null
        ? scheme.secondary
        : (changePct >= 0 ? roles.positiveAction : roles.negativeAction);
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
      insights.add(_AnalyticsInsight('Average ${metricDefinition.label.toLowerCase()} per ${bucket == 'hour' ? 'hour' : 'day'}: ${_formatValue(avg)}', Icons.timeline, scheme.secondary));
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
      title: definition.title,
      subtitle: definition.subtitle,
      metricLabel: metricDefinition.label,
      periodLabel: timeframe.toUpperCase(),
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

    final title = analytics.title;
    final periodLabel = analytics.periodLabel;
    final summary = StringBuffer()
      ..writeln(title)
      ..writeln('Period: $periodLabel')
      ..writeln('${analytics.metricLabel}: ${_formatValue(analytics.currentTotal)}')
      ..writeln('Change: ${analytics.changePctLabel}')
      ..writeln('Trend: ${analytics.trendLabel}');

    try {
      await SharePlus.instance.share(
        ShareParams(text: summary.toString(), subject: title),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
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
  final String title;
  final String subtitle;
  final String metricLabel;
  final String periodLabel;
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
    required this.title,
    required this.subtitle,
    required this.metricLabel,
    required this.periodLabel,
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

class _AnalyticsDefinition {
  const _AnalyticsDefinition({
    required this.contextType,
    required this.storageKey,
    required this.title,
    required this.subtitle,
    required this.scopeLabel,
    required this.icon,
    required this.accentColor,
    required this.metrics,
  });

  final AnalyticsExperienceContext contextType;
  final String storageKey;
  final String title;
  final String subtitle;
  final String scopeLabel;
  final IconData icon;
  final Color accentColor;
  final List<_AnalyticsMetricDefinition> metrics;

  _AnalyticsMetricDefinition? metricById(String metricId) {
    for (final metric in metrics) {
      if (metric.id == metricId) return metric;
    }
    return null;
  }

  String scopeFor(_AnalyticsMetricDefinition metricDefinition) {
    if (contextType == AnalyticsExperienceContext.home) return 'private';
    if (metricDefinition.privateOnly) return 'private';
    return 'public';
  }
}

class _AnalyticsMetricDefinition {
  const _AnalyticsMetricDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.privateOnly = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool privateOnly;
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

