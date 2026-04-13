import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../analytics_view_models.dart';
import 'analytics_state_widgets.dart';

class AnalyticsInsightsPanel extends StatelessWidget {
  const AnalyticsInsightsPanel({
    super.key,
    required this.insights,
  });

  final List<AnalyticsInsightData> insights;

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
            'Insights',
            style: KubusTypography.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          if (insights.isEmpty)
            const AnalyticsInlineEmptyState(
              title: 'Not enough data',
              description:
                  'More activity is needed before insights are useful.',
              icon: Icons.lightbulb_outline,
            )
          else
            ...insights.map((insight) {
              return Padding(
                padding: const EdgeInsets.only(bottom: KubusSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                      ),
                      child: Icon(
                        insight.icon,
                        size: 18,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: KubusTypography.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.description,
                            style: KubusTypography.inter(
                              fontSize: 12,
                              height: 1.35,
                              color: scheme.onSurface.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
