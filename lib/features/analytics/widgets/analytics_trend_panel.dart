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
    final scheme = Theme.of(context).colorScheme;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            child: _buildChart(context, height),
          ),
          if (summary.hasData) ...[
            const SizedBox(height: KubusSpacing.sm),
            // The chart draws two lines. Without a key nothing says which
            // one is this period and which one is the previous period.
            _TrendLegend(
              entries: <_TrendLegendEntry>[
                _TrendLegendEntry(
                  label: l10n.analyticsSeriesCurrentLabel,
                  color: AnalyticsMetricColors.resolve(context, metric.id),
                ),
                _TrendLegendEntry(
                  label: l10n.analyticsSeriesPreviousLabel,
                  color: _previousColor(scheme),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color _previousColor(ColorScheme scheme) =>
      scheme.secondary.withValues(alpha: 0.72);

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
          color: _previousColor(scheme),
        ),
      ],
      xLabels: labels,
      height: height,
      gridColor: scheme.onSurface.withValues(alpha: 0.12),
      valueFormatter: metric.formatValue,
      emptyLabel: l10n.analyticsNoDataYetTitle,
    );
  }
}

class _TrendLegendEntry {
  const _TrendLegendEntry({required this.label, required this.color});

  final String label;
  final Color color;
}

/// Key for the two trend lines: a short swatch in the series colour and its
/// label. Quiet, like the rest of the report; no box or chip.
class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.entries});

  final List<_TrendLegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: KubusSpacing.md,
      runSpacing: KubusSpacing.xs,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: entry.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: KubusSpacing.xs),
              Text(
                entry.label,
                style: KubusTextStyles.navMetaLabel.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
      ],
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
    // A flat period (0 %) is neither a gain nor a loss: no arrow, no sign,
    // neutral colour. Showing "+0.0 %" in green read as growth.
    final isFlat = change == 0;
    final changeLabel = change == null
        ? l10n.commonNotAvailableShort
        : isFlat
            ? '0.0%'
            : '${change >= 0 ? '+' : '-'}${change.abs().toStringAsFixed(1)}%';
    final neutral = change == null || isFlat;

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
            if (!neutral)
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
                color: neutral
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
