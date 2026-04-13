import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../analytics_metric_registry.dart';
import '../analytics_view_models.dart';
import 'analytics_state_widgets.dart';

class AnalyticsComparePanel extends StatelessWidget {
  const AnalyticsComparePanel({
    super.key,
    required this.comparisons,
    required this.groupTotals,
  });

  final List<AnalyticsComparisonData> comparisons;
  final Map<String, int> groupTotals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparison',
            style: KubusTypography.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          if (comparisons.isEmpty)
            const AnalyticsInlineEmptyState(
              title: 'No comparison yet',
              description:
                  'Comparison data appears after the first trend load.',
              icon: Icons.compare_arrows_outlined,
            )
          else
            ...comparisons.map((item) => _ComparisonRow(item: item)),
          if (groupTotals.isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.lg),
            Text(
              'Breakdown',
              style: KubusTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            ...groupTotals.entries.take(5).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _humanizeGroup(entry.key),
                        overflow: TextOverflow.ellipsis,
                        style: KubusTypography.inter(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    Text(
                      AnalyticsMetricRegistry.formatCompact(entry.value),
                      style: KubusTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _humanizeGroup(String group) {
    final raw = group.trim();
    if (raw.isEmpty) return 'Unknown';
    final spaced = raw.replaceAll('_', ' ').replaceAll('-', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.item});

  final AnalyticsComparisonData item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final color = item.isPositive == null
        ? scheme.onSurface.withValues(alpha: 0.6)
        : item.isPositive!
            ? roles.positiveAction
            : roles.negativeAction;

    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: KubusTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Previous: ${item.previousValue}',
                  style: KubusTypography.inter(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.currentValue,
            style: KubusTypography.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
