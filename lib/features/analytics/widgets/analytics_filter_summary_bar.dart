import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/common/kubus_glass_chip.dart';
import '../analytics_metric_registry.dart';
import 'analytics_filter_sheet.dart';

/// Compact pinned filter summary for narrow layouts.
///
/// Keeps the current metric and time period readable while scrolled, and
/// opens the canonical filter sheet for the full controls — no cramped
/// horizontal chip rows. Sticky elevated chrome, so the chips use the
/// canonical glass stack.
class AnalyticsFilterSummaryBar extends StatelessWidget {
  const AnalyticsFilterSummaryBar({
    super.key,
    required this.metrics,
    required this.selectedMetricId,
    required this.timeframe,
    required this.onMetricChanged,
    required this.onTimeframeChanged,
  });

  final List<AnalyticsMetricDefinition> metrics;
  final String selectedMetricId;
  final String timeframe;
  final ValueChanged<String> onMetricChanged;
  final ValueChanged<String> onTimeframeChanged;

  /// Deterministic pinned extent: chip line height at the current text scale
  /// plus fixed chrome. Min == max so scrolling never animates a resize.
  static double extentFor(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(18);
    return (scaled + 44).clamp(56.0, 120.0).toDouble();
  }

  AnalyticsMetricDefinition? get _selectedMetric {
    for (final metric in metrics) {
      if (metric.id == selectedMetricId) return metric;
    }
    return metrics.isEmpty ? null : metrics.first;
  }

  void _openSheet(BuildContext context) {
    showAnalyticsFilterSheet(
      context: context,
      metrics: metrics,
      selectedMetricId: selectedMetricId,
      timeframe: timeframe,
      onMetricChanged: onMetricChanged,
      onTimeframeChanged: onTimeframeChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final metric = _selectedMetric;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      child: Row(
        children: [
          if (metric != null)
            Expanded(
              child: Semantics(
                button: true,
                tooltip: l10n.analyticsFilterSummaryTooltip,
                child: KubusGlassChip(
                  label: metric.localizedLabel(l10n),
                  icon: metric.icon,
                  active: true,
                  fullWidth: true,
                  minHeight: 40,
                  onPressed: () => _openSheet(context),
                ),
              ),
            ),
          const SizedBox(width: KubusSpacing.sm),
          Semantics(
            button: true,
            tooltip: l10n.analyticsFilterSummaryTooltip,
            child: KubusGlassChip(
              label: analyticsTimeframeLabel(l10n, timeframe),
              icon: Icons.schedule_outlined,
              active: false,
              minHeight: 40,
              onPressed: () => _openSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}
