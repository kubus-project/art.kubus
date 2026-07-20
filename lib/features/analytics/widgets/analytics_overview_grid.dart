import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../analytics_metric_colors.dart';
import '../analytics_view_models.dart';

/// Overview with a real hierarchy instead of a wall of equal tiles: the
/// selected metric renders as a full-width lead card with the large value,
/// and the remaining metrics follow as smaller supporting tiles. Tapping a
/// supporting tile selects it, which promotes it to the lead position.
class AnalyticsOverviewGrid extends StatelessWidget {
  const AnalyticsOverviewGrid({
    super.key,
    required this.cards,
    required this.isLoading,
    required this.selectedMetricId,
    required this.onMetricSelected,
  });

  final List<AnalyticsOverviewCardData> cards;
  final bool isLoading;
  final String selectedMetricId;
  final ValueChanged<String> onMetricSelected;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final leadIndex =
        cards.indexWhere((card) => card.metricId == selectedMetricId);
    final resolvedLeadIndex = leadIndex < 0 ? 0 : leadIndex;
    final lead = cards[resolvedLeadIndex];
    final supporting = <AnalyticsOverviewCardData>[
      for (var i = 0; i < cards.length; i++)
        if (i != resolvedLeadIndex) cards[i],
    ];

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1200
        ? 3
        : width >= 760
            ? 2
            : 1;
    final aspectRatio = width >= 1200
        ? 3.1
        : width >= 760
            ? 3.2
            : 4.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnalyticsLeadCard(
          data: lead,
          isLoading: isLoading,
          onTap: () => onMetricSelected(lead.metricId),
        ),
        if (supporting.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: supporting.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: KubusSpacing.md,
              mainAxisSpacing: KubusSpacing.md,
              childAspectRatio: aspectRatio,
            ),
            itemBuilder: (context, index) {
              return _AnalyticsSupportingCard(
                data: supporting[index],
                isLoading: isLoading,
                onTap: () => onMetricSelected(supporting[index].metricId),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _AnalyticsLeadCard extends StatelessWidget {
  const _AnalyticsLeadCard({
    required this.data,
    required this.isLoading,
    required this.onTap,
  });

  final AnalyticsOverviewCardData data;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final accent = AnalyticsMetricColors.resolve(context, data.metricId);
    final trendColor = data.isPositive == null
        ? scheme.onSurface.withValues(alpha: 0.62)
        : data.isPositive!
            ? roles.positiveAction
            : roles.negativeAction;

    return Semantics(
      button: true,
      selected: true,
      label: AppLocalizations.of(context)!.analyticsCardSemanticsLabel(
        data.title,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: Container(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(KubusRadius.sm),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Icon(data.icon, color: accent, size: 26),
                ),
                const SizedBox(width: KubusSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTypography.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        isLoading ? '…' : data.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTypography.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.changeLabel != null || data.subtitle != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (data.changeLabel != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (data.isPositive != null)
                              Icon(
                                data.isPositive!
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 14,
                                color: trendColor,
                              ),
                            const SizedBox(width: KubusSpacing.xxs),
                            Text(
                              data.changeLabel!,
                              style: KubusTypography.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      if (data.subtitle != null) ...[
                        const SizedBox(height: KubusSpacing.xxs),
                        Text(
                          data.subtitle!,
                          style: KubusTypography.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsSupportingCard extends StatefulWidget {
  const _AnalyticsSupportingCard({
    required this.data,
    required this.isLoading,
    required this.onTap,
  });

  final AnalyticsOverviewCardData data;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  State<_AnalyticsSupportingCard> createState() =>
      _AnalyticsSupportingCardState();
}

class _AnalyticsSupportingCardState extends State<_AnalyticsSupportingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final trendColor = widget.data.isPositive == null
        ? scheme.onSurface.withValues(alpha: 0.62)
        : widget.data.isPositive!
            ? roles.positiveAction
            : roles.negativeAction;
    final accent = AnalyticsMetricColors.resolve(context, widget.data.metricId);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        selected: false,
        label: AppLocalizations.of(context)!.analyticsCardSemanticsLabel(
          widget.data.title,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.md,
                vertical: KubusSpacing.sm + KubusSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(
                  alpha: _hovered ? 0.62 : 0.46,
                ),
                borderRadius: BorderRadius.circular(KubusRadius.sm),
                border: Border.all(
                  color: _hovered
                      ? accent.withValues(alpha: 0.45)
                      : scheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(KubusRadius.sm),
                    ),
                    child: Icon(widget.data.icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: KubusSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KubusTypography.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isLoading ? '…' : widget.data.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KubusTypography.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.data.changeLabel != null)
                    Text(
                      widget.data.changeLabel!,
                      maxLines: 1,
                      style: KubusTypography.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: trendColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
