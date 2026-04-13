import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../../widgets/charts/stats_interactive_line_chart.dart';
import '../../../widgets/inline_loading.dart';
import '../analytics_metric_registry.dart';
import '../analytics_time.dart';
import 'analytics_state_widgets.dart';

class AnalyticsTrendPanel extends StatelessWidget {
  const AnalyticsTrendPanel({
    super.key,
    required this.metric,
    required this.summary,
    required this.labels,
    required this.timeframe,
    required this.isLoading,
    required this.error,
  });

  final AnalyticsMetricDefinition metric;
  final AnalyticsSeriesSummary summary;
  final List<String> labels;
  final String timeframe;
  final bool isLoading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final height = compact ? 260.0 : 360.0;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${metric.label} trend',
                      style: KubusTypography.inter(
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      '${timeframe.toUpperCase()} compared with the previous period',
                      style: KubusTypography.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              _TrendValue(metric: metric, summary: summary),
            ],
          ),
          const SizedBox(height: KubusSpacing.lg),
          SizedBox(
            height: height,
            child: _buildChart(context, height),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, double height) {
    final scheme = Theme.of(context).colorScheme;
    if (error != null && summary.values.every((value) => value == 0)) {
      return const AnalyticsInlineEmptyState(
        title: 'Unable to load trend',
        description: 'Try a different metric or timeframe.',
      );
    }
    if (isLoading && !summary.hasData) {
      return Center(
        child: InlineLoading(tileSize: 10, color: scheme.primary),
      );
    }
    if (!summary.hasData) {
      return const AnalyticsInlineEmptyState(
        title: 'No trend data yet',
        description: 'Activity will appear here as it is recorded.',
      );
    }
    return StatsInteractiveLineChart(
      series: <StatsLineSeries>[
        StatsLineSeries(
          label: 'Current',
          values: summary.values,
          color: scheme.primary,
          showArea: true,
        ),
        StatsLineSeries(
          label: 'Previous',
          values: summary.previousValues,
          color: scheme.secondary.withValues(alpha: 0.72),
        ),
      ],
      xLabels: labels,
      height: height,
      gridColor: scheme.onSurface.withValues(alpha: 0.12),
    );
  }
}

class _TrendValue extends StatelessWidget {
  const _TrendValue({
    required this.metric,
    required this.summary,
  });

  final AnalyticsMetricDefinition metric;
  final AnalyticsSeriesSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = summary.changePercent;
    final changeLabel = change == null
        ? 'N/A'
        : '${change >= 0 ? '+' : '-'}${change.abs().toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          metric.formatValue(summary.currentTotal),
          style: KubusTypography.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          changeLabel,
          style: KubusTypography.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: change == null
                ? scheme.onSurface.withValues(alpha: 0.62)
                : change >= 0
                    ? scheme.primary
                    : scheme.error,
          ),
        ),
      ],
    );
  }
}
