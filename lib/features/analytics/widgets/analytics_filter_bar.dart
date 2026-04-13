import 'package:flutter/material.dart';

import '../../../providers/analytics_filters_provider.dart';
import '../../../utils/design_tokens.dart';
import '../analytics_metric_registry.dart';

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
    final compact = MediaQuery.sizeOf(context).width < 720;
    final selectedMetric =
        metrics.any((metric) => metric.id == selectedMetricId)
            ? selectedMetricId
            : (metrics.isNotEmpty ? metrics.first.id : '');

    final timeframeChips = AnalyticsFiltersProvider.allowedTimeframes.map((tf) {
      return ChoiceChip(
        selected: timeframe == tf,
        label: Text(tf.toUpperCase()),
        visualDensity: compact ? VisualDensity.compact : null,
        onSelected: (_) => onTimeframeChanged(tf),
      );
    }).toList(growable: false);

    final metricSelector = DropdownButtonFormField<String>(
      initialValue: selectedMetric.isEmpty ? null : selectedMetric,
      isDense: compact,
      decoration: InputDecoration(
        labelText: 'Metric',
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KubusRadius.md),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: compact ? KubusSpacing.sm : KubusSpacing.md,
        ),
      ),
      items: metrics.map((metric) {
        return DropdownMenuItem<String>(
          value: metric.id,
          child: Text(
            metric.label,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(growable: false),
      onChanged: (value) {
        if (value != null && value.isNotEmpty) onMetricChanged(value);
      },
    );

    return Container(
      color: scheme.surface.withValues(alpha: 0.88),
      padding: EdgeInsets.fromLTRB(
        compact ? KubusSpacing.md : KubusSpacing.xl,
        KubusSpacing.sm,
        compact ? KubusSpacing.md : KubusSpacing.xl,
        KubusSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.sm),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < timeframeChips.length; i++) ...[
                            if (i > 0) const SizedBox(width: KubusSpacing.sm),
                            timeframeChips[i],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    metricSelector,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: KubusSpacing.sm,
                        runSpacing: KubusSpacing.sm,
                        children: timeframeChips,
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.md),
                    SizedBox(width: 300, child: metricSelector),
                  ],
                ),
        ),
      ),
    );
  }
}
