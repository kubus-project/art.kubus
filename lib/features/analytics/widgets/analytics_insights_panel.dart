import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../analytics_view_models.dart';
import 'analytics_section_panel.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return AnalyticsSectionPanel(
      title: l10n.analyticsSectionInsights,
      child: insights.isEmpty
          ? AnalyticsInlineEmptyState(
              title: l10n.analyticsNotEnoughDataTitle,
              description: l10n.analyticsInsightsEmptyDescription,
              icon: Icons.lightbulb_outline,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // One quiet icon treatment for every insight: the old
                // index-modulo accent rotation carried no meaning and read as
                // dashboard decoration.
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
                            color: scheme.onSurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(KubusRadius.sm),
                            border: Border.all(
                              color: scheme.outline.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            insight.icon,
                            size: 18,
                            color: scheme.onSurface.withValues(alpha: 0.66),
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
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.68),
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
