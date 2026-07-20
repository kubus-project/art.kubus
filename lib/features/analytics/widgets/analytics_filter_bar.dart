import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/analytics_filters_provider.dart';
import '../../../utils/design_tokens.dart';
import '../analytics_metric_registry.dart';
import 'analytics_filter_sheet.dart';

/// Desktop analytics filter toolbar.
///
/// Intrinsic height (no pinned extent contract): timeframe chips wrap freely
/// for long localized labels and large text scales, and the metric selector
/// keeps a bounded width. Keyboard focus is native to the chips and the
/// dropdown.
class AnalyticsFilterBar extends StatelessWidget {
  const AnalyticsFilterBar({
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final selectedMetric =
        metrics.any((metric) => metric.id == selectedMetricId)
            ? selectedMetricId
            : (metrics.isNotEmpty ? metrics.first.id : '');

    final timeframeChips = AnalyticsFiltersProvider.allowedTimeframes.map((tf) {
      return Tooltip(
        message: analyticsTimeframeLabel(l10n, tf),
        child: ChoiceChip(
          selected: timeframe == tf,
          label: Text(tf.toUpperCase()),
          onSelected: (_) => onTimeframeChanged(tf),
        ),
      );
    }).toList(growable: false);

    final metricSelector = DropdownButtonFormField<String>(
      initialValue: selectedMetric.isEmpty ? null : selectedMetric,
      decoration: InputDecoration(
        labelText: l10n.analyticsMetricLabel,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KubusRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.md,
        ),
      ),
      items: metrics.map((metric) {
        return DropdownMenuItem<String>(
          value: metric.id,
          child: Text(
            metric.localizedLabel(l10n),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(growable: false),
      onChanged: (value) {
        if (value != null && value.isNotEmpty) onMetricChanged(value);
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.xl,
        KubusSpacing.xs,
        KubusSpacing.xl,
        KubusSpacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: timeframeChips,
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
                child: metricSelector,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
