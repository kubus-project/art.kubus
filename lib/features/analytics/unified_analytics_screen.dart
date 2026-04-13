import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/stats/stats_models.dart';
import '../../providers/analytics_filters_provider.dart';
import '../../providers/dao_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/web3provider.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/kubus_snackbar.dart';
import 'analytics_capability_resolver.dart';
import 'analytics_entity_registry.dart';
import 'analytics_metric_registry.dart';
import 'analytics_presets.dart';
import 'analytics_time.dart';
import 'analytics_view_models.dart';
import 'widgets/analytics_compare_panel.dart';
import 'widgets/analytics_filter_bar.dart';
import 'widgets/analytics_header.dart';
import 'widgets/analytics_insights_panel.dart';
import 'widgets/analytics_overview_grid.dart';
import 'widgets/analytics_shell_scaffold.dart';
import 'widgets/analytics_state_widgets.dart';
import 'widgets/analytics_trend_panel.dart';

class UnifiedAnalyticsScreen extends StatefulWidget {
  const UnifiedAnalyticsScreen({
    super.key,
    required this.presetKind,
    this.entityId,
    this.initialMetricId,
    this.availablePresetKinds,
    this.embedded = false,
  });

  final AnalyticsPresetKind presetKind;
  final String? entityId;
  final String? initialMetricId;
  final List<AnalyticsPresetKind>? availablePresetKinds;
  final bool embedded;

  @override
  State<UnifiedAnalyticsScreen> createState() => _UnifiedAnalyticsScreenState();
}

class _UnifiedAnalyticsScreenState extends State<UnifiedAnalyticsScreen> {
  late AnalyticsPresetKind _activePresetKind;
  String _lastReviewWallet = '';
  bool _reviewRequestScheduled = false;
  String? _seededInitialMetricKey;

  @override
  void initState() {
    super.initState();
    _activePresetKind = widget.presetKind;
  }

  @override
  void didUpdateWidget(covariant UnifiedAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presetKind != widget.presetKind) {
      _activePresetKind = widget.presetKind;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleRoleReviewLoad();
  }

  @override
  Widget build(BuildContext context) {
    final preset = AnalyticsPresets.byKind(_activePresetKind);
    final availablePresets = _availablePresets();
    final statsProvider = context.watch<StatsProvider>();
    final filtersProvider = context.watch<AnalyticsFiltersProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final web3Provider = context.watch<Web3Provider>();
    final daoProvider = context.watch<DAOProvider>();

    final viewerWallet = _resolveViewerWallet(profileProvider, web3Provider);
    final subjectId = _resolveSubjectId(preset, viewerWallet);
    final currentProfile = profileProvider.currentUser;
    final isOwner = WalletUtils.equals(viewerWallet, subjectId);
    final review =
        subjectId.isEmpty ? null : daoProvider.findReviewForWallet(subjectId);
    final capabilities = AnalyticsCapabilityResolver.resolve(
      preset: preset,
      viewer: AnalyticsViewerContext(
        viewerWallet: viewerWallet,
        subjectId: subjectId,
        persona: profileProvider.userPersona,
        daoReview: review,
        profileIsArtist: isOwner && (currentProfile?.isArtist ?? false),
        profileIsInstitution:
            isOwner && (currentProfile?.isInstitution ?? false),
        isAdmin: false,
        analyticsEnabled: statsProvider.analyticsEnabled,
      ),
    );

    if (!capabilities.canView) {
      final permissionState = AnalyticsPermissionState(
        title: capabilities.blockedTitle ?? 'Analytics unavailable',
        description: capabilities.blockedDescription ??
            'This analytics surface is not available for this wallet.',
      );
      if (widget.embedded) return permissionState;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: permissionState),
      );
    }

    final metrics = capabilities.allowedMetrics;
    if (metrics.isEmpty) {
      const empty = AnalyticsPermissionState(
        title: 'No supported metrics',
        description:
            'This analytics preset has no metrics for the current scope.',
      );
      if (widget.embedded) return empty;
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: empty),
      );
    }

    final selectedMetric = _selectedMetric(
      preset: preset,
      metrics: metrics,
      filtersProvider: filtersProvider,
    );
    final timeframe = AnalyticsTimeWindow.normalizeTimeframe(
      filtersProvider.timeframeFor(preset.contextKey),
    );
    final window = AnalyticsTimeWindow.resolve(timeframe: timeframe);
    final groupBy = _groupByFor(preset, selectedMetric);
    final scope = capabilities.scope;
    final scopeValue = scope.apiValue;
    final entityType = preset.entityType.apiValue;

    final overviewMetrics = capabilities.allowedOverviewMetrics;
    final overviewMetricIds = overviewMetrics.map((m) => m.id).toList();
    final snapshotMetricIds = <String>[
      ...overviewMetricIds,
      if (!overviewMetricIds.contains(selectedMetric.id)) selectedMetric.id,
    ];
    if (subjectId.isNotEmpty) {
      unawaited(statsProvider.ensureSnapshot(
        entityType: entityType,
        entityId: subjectId,
        metrics: snapshotMetricIds,
        scope: scopeValue,
      ));
    }

    final snapshot = subjectId.isEmpty
        ? null
        : statsProvider.getSnapshot(
            entityType: entityType,
            entityId: subjectId,
            metrics: snapshotMetricIds,
            scope: scopeValue,
          );
    final snapshotLoading = subjectId.isNotEmpty &&
        statsProvider.isSnapshotLoading(
          entityType: entityType,
          entityId: subjectId,
          metrics: snapshotMetricIds,
          scope: scopeValue,
        ) &&
        snapshot == null;

    final canLoadSeries = selectedMetric.seriesSupported &&
        selectedMetric.supportsScope(scope) &&
        subjectId.isNotEmpty;
    if (canLoadSeries) {
      unawaited(statsProvider.ensureSeries(
        entityType: entityType,
        entityId: subjectId,
        metric: selectedMetric.id,
        bucket: window.bucket,
        timeframe: window.timeframe,
        from: window.currentFrom.toIso8601String(),
        to: window.currentTo.toIso8601String(),
        groupBy: groupBy?.apiValue,
        scope: scopeValue,
      ));
      unawaited(statsProvider.ensureSeries(
        entityType: entityType,
        entityId: subjectId,
        metric: selectedMetric.id,
        bucket: window.bucket,
        timeframe: window.timeframe,
        from: window.previousFrom.toIso8601String(),
        to: window.previousTo.toIso8601String(),
        groupBy: groupBy?.apiValue,
        scope: scopeValue,
      ));
    }

    final series = canLoadSeries
        ? statsProvider.getSeries(
            entityType: entityType,
            entityId: subjectId,
            metric: selectedMetric.id,
            bucket: window.bucket,
            timeframe: window.timeframe,
            from: window.currentFrom.toIso8601String(),
            to: window.currentTo.toIso8601String(),
            groupBy: groupBy?.apiValue,
            scope: scopeValue,
          )
        : null;
    final previousSeries = canLoadSeries
        ? statsProvider.getSeries(
            entityType: entityType,
            entityId: subjectId,
            metric: selectedMetric.id,
            bucket: window.bucket,
            timeframe: window.timeframe,
            from: window.previousFrom.toIso8601String(),
            to: window.previousTo.toIso8601String(),
            groupBy: groupBy?.apiValue,
            scope: scopeValue,
          )
        : null;
    final seriesLoading = canLoadSeries &&
        (statsProvider.isSeriesLoading(
              entityType: entityType,
              entityId: subjectId,
              metric: selectedMetric.id,
              bucket: window.bucket,
              timeframe: window.timeframe,
              from: window.currentFrom.toIso8601String(),
              to: window.currentTo.toIso8601String(),
              groupBy: groupBy?.apiValue,
              scope: scopeValue,
            ) ||
            statsProvider.isSeriesLoading(
              entityType: entityType,
              entityId: subjectId,
              metric: selectedMetric.id,
              bucket: window.bucket,
              timeframe: window.timeframe,
              from: window.previousFrom.toIso8601String(),
              to: window.previousTo.toIso8601String(),
              groupBy: groupBy?.apiValue,
              scope: scopeValue,
            ));
    final seriesError = canLoadSeries
        ? statsProvider.seriesError(
              entityType: entityType,
              entityId: subjectId,
              metric: selectedMetric.id,
              bucket: window.bucket,
              timeframe: window.timeframe,
              from: window.currentFrom.toIso8601String(),
              to: window.currentTo.toIso8601String(),
              groupBy: groupBy?.apiValue,
              scope: scopeValue,
            ) ??
            statsProvider.seriesError(
              entityType: entityType,
              entityId: subjectId,
              metric: selectedMetric.id,
              bucket: window.bucket,
              timeframe: window.timeframe,
              from: window.previousFrom.toIso8601String(),
              to: window.previousTo.toIso8601String(),
              groupBy: groupBy?.apiValue,
              scope: scopeValue,
            )
        : null;

    final summary = AnalyticsSeriesTools.summarize(
      current: series,
      previous: previousSeries,
      window: window,
    );

    final overviewCards = _overviewCards(
      snapshot: snapshot,
      overviewMetrics: overviewMetrics,
      selectedMetric: selectedMetric,
      summary: summary,
    );
    final insights = _insights(selectedMetric, summary, timeframe);
    final comparisons = _comparisons(selectedMetric, summary);

    return AnalyticsShellScaffold(
      embedded: widget.embedded,
      header: AnalyticsHeader(
        title: preset.title,
        subtitle: preset.subtitle,
        scopeLabel: preset.scopeLabel,
        icon: preset.icon,
        scopeBadge: capabilities.scope.label,
        availablePresets: availablePresets,
        activePreset: preset,
        onPresetSelected: (kind) {
          setState(() => _activePresetKind = kind);
          _scheduleRoleReviewLoad();
        },
        canExport: capabilities.canExport,
        onExport: () => unawaited(_exportAnalytics(
          preset: preset,
          metric: selectedMetric,
          summary: summary,
          window: window,
        )),
        onShare: () => unawaited(_shareAnalytics(
          preset: preset,
          metric: selectedMetric,
          summary: summary,
          timeframe: timeframe,
        )),
      ),
      filterBar: AnalyticsFilterBar(
        metrics: metrics,
        selectedMetricId: selectedMetric.id,
        timeframe: timeframe,
        onMetricChanged: (metricId) {
          filtersProvider.setMetricFor(
            preset.contextKey,
            metricId,
            allowedMetrics: metrics.map((metric) => metric.id),
          );
        },
        onTimeframeChanged: (next) {
          filtersProvider.setTimeframeFor(preset.contextKey, next);
        },
      ),
      overview: AnalyticsOverviewGrid(
        cards: overviewCards,
        isLoading: snapshotLoading,
        selectedMetricId: selectedMetric.id,
        onMetricSelected: (metricId) {
          filtersProvider.setMetricFor(
            preset.contextKey,
            metricId,
            allowedMetrics: metrics.map((metric) => metric.id),
          );
        },
      ),
      trend: canLoadSeries
          ? AnalyticsTrendPanel(
              metric: selectedMetric,
              summary: summary,
              labels: window.labels(),
              timeframe: timeframe,
              isLoading: seriesLoading,
              error: seriesError,
            )
          : const AnalyticsInlineEmptyState(
              title: 'Series unavailable',
              description: 'This metric is available as a snapshot only.',
            ),
      insights: AnalyticsInsightsPanel(insights: insights),
      comparison: AnalyticsComparePanel(
        comparisons: comparisons,
        groupTotals: summary.groupTotals,
      ),
    );
  }

  List<AnalyticsPreset> _availablePresets() {
    final kinds =
        widget.availablePresetKinds ?? <AnalyticsPresetKind>[widget.presetKind];
    return kinds.map(AnalyticsPresets.byKind).toList(growable: false);
  }

  AnalyticsMetricDefinition _selectedMetric({
    required AnalyticsPreset preset,
    required List<AnalyticsMetricDefinition> metrics,
    required AnalyticsFiltersProvider filtersProvider,
  }) {
    final initialMetricId = widget.initialMetricId?.trim();
    final fallback = initialMetricId?.isNotEmpty == true
        ? initialMetricId!
        : preset.defaultMetric.id;
    final initialMetric = initialMetricId?.isNotEmpty == true
        ? _metricById(metrics, initialMetricId!)
        : null;
    if (initialMetric != null) {
      final seedKey = '${preset.contextKey}:${initialMetric.id}';
      if (_seededInitialMetricKey != seedKey) {
        _seededInitialMetricKey = seedKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          filtersProvider.setMetricFor(
            preset.contextKey,
            initialMetric.id,
            allowedMetrics: metrics.map((metric) => metric.id),
          );
        });
        return initialMetric;
      }
    }

    final stored = filtersProvider.metricFor(
      preset.contextKey,
      fallback: fallback,
    );
    for (final metric in metrics) {
      if (metric.id == stored) return metric;
    }
    for (final metric in metrics) {
      if (metric.id == fallback) return metric;
    }
    return metrics.first;
  }

  AnalyticsMetricDefinition? _metricById(
    List<AnalyticsMetricDefinition> metrics,
    String metricId,
  ) {
    for (final metric in metrics) {
      if (metric.id == metricId) return metric;
    }
    return null;
  }

  AnalyticsGroupBy? _groupByFor(
    AnalyticsPreset preset,
    AnalyticsMetricDefinition metric,
  ) {
    final preferred = preset.defaultGroupBy ?? metric.defaultGroupBy;
    if (preferred != null && metric.supportedGroupBys.contains(preferred)) {
      return preferred;
    }
    return null;
  }

  String _resolveViewerWallet(
    ProfileProvider profileProvider,
    Web3Provider web3Provider,
  ) {
    return WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
  }

  String _resolveSubjectId(AnalyticsPreset preset, String viewerWallet) {
    if (preset.entityType == AnalyticsEntityType.platform) return 'global';
    final explicit = widget.entityId?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    return viewerWallet.trim();
  }

  void _scheduleRoleReviewLoad() {
    if (_reviewRequestScheduled) return;
    final preset = AnalyticsPresets.byKind(_activePresetKind);
    if (preset.roleRequirement != AnalyticsRoleRequirement.artist &&
        preset.roleRequirement != AnalyticsRoleRequirement.institution) {
      return;
    }
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    final wallet = _resolveSubjectId(
      preset,
      _resolveViewerWallet(profileProvider, web3Provider),
    );
    if (wallet.isEmpty || wallet == _lastReviewWallet) return;
    _reviewRequestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reviewRequestScheduled = false;
      _lastReviewWallet = wallet;
      unawaited(context.read<DAOProvider>().loadReviewForWallet(wallet));
    });
  }

  List<AnalyticsOverviewCardData> _overviewCards({
    required StatsSnapshot? snapshot,
    required List<AnalyticsMetricDefinition> overviewMetrics,
    required AnalyticsMetricDefinition selectedMetric,
    required AnalyticsSeriesSummary summary,
  }) {
    final counters = snapshot?.counters ?? const <String, int>{};
    final cards = <AnalyticsOverviewCardData>[];
    for (final metric in overviewMetrics.take(4)) {
      final raw = counters[metric.id];
      cards.add(
        AnalyticsOverviewCardData(
          metricId: metric.id,
          title: metric.label,
          value: metric.formatValue(raw ?? 0),
          icon: metric.icon,
          subtitle: metric.description,
        ),
      );
    }
    final selectedAlreadyShown =
        overviewMetrics.take(4).any((metric) => metric.id == selectedMetric.id);
    if (!selectedAlreadyShown) {
      final raw = counters[selectedMetric.id];
      cards.add(
        AnalyticsOverviewCardData(
          metricId: selectedMetric.id,
          title: selectedMetric.label,
          value: selectedMetric.formatValue(
            raw ?? (summary.hasData ? summary.currentTotal : 0),
          ),
          icon: selectedMetric.icon,
          subtitle: selectedMetric.description,
          changeLabel:
              summary.hasData ? _formatChange(summary.changePercent) : null,
          isPositive: summary.changePercent == null
              ? null
              : summary.changePercent! >= 0,
        ),
      );
    }
    return cards;
  }

  List<AnalyticsInsightData> _insights(
    AnalyticsMetricDefinition metric,
    AnalyticsSeriesSummary summary,
    String timeframe,
  ) {
    if (!summary.hasData) return const <AnalyticsInsightData>[];
    final activeBuckets = summary.values.where((value) => value > 0).length;
    final totalBuckets = summary.values.length;
    final trend = summary.changePercent;
    final insights = <AnalyticsInsightData>[
      AnalyticsInsightData(
        title: 'Active ${timeframe.toUpperCase()} pattern',
        description:
            '$activeBuckets of $totalBuckets buckets recorded ${metric.label.toLowerCase()}.',
        icon: Icons.calendar_today_outlined,
      ),
      AnalyticsInsightData(
        title: 'Peak bucket',
        description:
            'The strongest bucket reached ${metric.formatValue(summary.peak)}.',
        icon: Icons.trending_up_outlined,
      ),
    ];
    if (trend != null) {
      insights.add(
        AnalyticsInsightData(
          title: trend >= 0 ? 'Momentum improved' : 'Momentum softened',
          description:
              '${metric.label} is ${_formatChange(trend)} versus the previous period.',
          icon: trend >= 0
              ? Icons.arrow_upward_outlined
              : Icons.arrow_downward_outlined,
        ),
      );
    }
    return insights;
  }

  List<AnalyticsComparisonData> _comparisons(
    AnalyticsMetricDefinition metric,
    AnalyticsSeriesSummary summary,
  ) {
    if (summary.values.isEmpty && summary.previousValues.isEmpty) {
      return const <AnalyticsComparisonData>[];
    }
    return <AnalyticsComparisonData>[
      AnalyticsComparisonData(
        label: 'Total',
        currentValue: metric.formatValue(summary.currentTotal),
        previousValue: metric.formatValue(summary.previousTotal),
        isPositive: summary.currentTotal >= summary.previousTotal,
      ),
      AnalyticsComparisonData(
        label: 'Average bucket',
        currentValue: metric.formatValue(summary.average),
        previousValue: metric.formatValue(summary.previousAverage),
        isPositive: summary.average >= summary.previousAverage,
      ),
      AnalyticsComparisonData(
        label: 'Consistency',
        currentValue: '${(summary.consistency * 100).toStringAsFixed(0)}%',
        previousValue: 'Activity coverage',
        isPositive: summary.consistency >= 0.5,
      ),
    ];
  }

  String _formatChange(double? value) {
    if (value == null) return 'N/A';
    return '${value >= 0 ? '+' : '-'}${value.abs().toStringAsFixed(1)}%';
  }

  Future<void> _shareAnalytics({
    required AnalyticsPreset preset,
    required AnalyticsMetricDefinition metric,
    required AnalyticsSeriesSummary summary,
    required String timeframe,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = StringBuffer()
      ..writeln(preset.title)
      ..writeln('Metric: ${metric.label}')
      ..writeln('Period: ${timeframe.toUpperCase()}')
      ..writeln('Total: ${metric.formatValue(summary.currentTotal)}')
      ..writeln('Change: ${_formatChange(summary.changePercent)}');

    try {
      await SharePlus.instance.share(
        ShareParams(text: text.toString(), subject: preset.title),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: const Text('Unable to share analytics on this device.'),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  Future<void> _exportAnalytics({
    required AnalyticsPreset preset,
    required AnalyticsMetricDefinition metric,
    required AnalyticsSeriesSummary summary,
    required AnalyticsTimeWindow window,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (!summary.hasData) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: const Text('No analytics data available to export.'),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    final labels = window.labels();
    final buffer = StringBuffer()
      ..writeln('bucket,value,previous')
      ..writeAll(
        List<String>.generate(summary.values.length, (index) {
          final current = summary.values[index].toStringAsFixed(0);
          final previous = index < summary.previousValues.length
              ? summary.previousValues[index].toStringAsFixed(0)
              : '0';
          final label =
              index < labels.length ? labels[index] : index.toString();
          return '$label,$current,$previous\n';
        }),
      );

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: '${preset.title} ${metric.label} export',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: const Text('Unable to export analytics.'),
          backgroundColor: scheme.error,
        ),
      );
    }
  }
}
