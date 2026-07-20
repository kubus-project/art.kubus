import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/charts/stats_interactive_line_chart.dart';
import '../../../widgets/inline_loading.dart';
import '../analytics_metric_colors.dart';
import '../analytics_metric_registry.dart';
import '../analytics_time.dart';
import 'analytics_section_panel.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final height = compact ? 260.0 : 360.0;

    return AnalyticsSectionPanel(
      title: l10n.analyticsTrendTitle(metric.localizedLabel(l10n)),
      subtitle: l10n.analyticsTrendComparedSubtitle(timeframe.toUpperCase()),
      trailing: _TrendValue(metric: metric, summary: summary),
      // A refresh with previous data keeps the chart in place; only the
      // small kit loader signals the update.
      isRefreshing: isLoading && summary.hasData,
      child: SizedBox(
        height: height,
        child: _buildChart(context, height),
      ),
    );
  }

  Widget _buildChart(BuildContext context, double height) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (error != null && summary.values.every((value) => value == 0)) {
      return AnalyticsInlineEmptyState(
        title: l10n.analyticsTrendErrorTitle,
        description: l10n.analyticsTrendErrorDescription,
        kind: AnalyticsInlineStateKind.error,
      );
    }
    if (isLoading && !summary.hasData) {
      return Center(
        child: InlineLoading(tileSize: 10, color: scheme.primary),
      );
    }
    if (!summary.hasData) {
      return AnalyticsInlineEmptyState(
        title: l10n.analyticsNoDataYetTitle,
        description: l10n.analyticsNoDataYetDescription,
      );
    }
    final accent = AnalyticsMetricColors.resolve(context, metric.id);
    return StatsInteractiveLineChart(
      series: <StatsLineSeries>[
        StatsLineSeries(
          label: l10n.analyticsSeriesCurrentLabel,
          values: summary.values,
          color: accent,
          showArea: true,
        ),
        StatsLineSeries(
          label: l10n.analyticsSeriesPreviousLabel,
          values: summary.previousValues,
          color: scheme.secondary.withValues(alpha: 0.72),
        ),
      ],
      xLabels: labels,
      height: height,
      gridColor: scheme.onSurface.withValues(alpha: 0.12),
      valueFormatter: metric.formatValue,
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
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final change = summary.changePercent;
    final changeLabel = change == null
        ? l10n.commonNotAvailableShort
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (change != null)
              Icon(
                change >= 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 13,
                // Judgment colors come from the shared roles so deltas read
                // the same here as in the overview cards and compare rows.
                color:
                    change >= 0 ? roles.positiveAction : roles.negativeAction,
              ),
            Text(
              changeLabel,
              style: KubusTypography.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: change == null
                    ? scheme.onSurface.withValues(alpha: 0.62)
                    : change >= 0
                        ? roles.positiveAction
                        : roles.negativeAction,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
