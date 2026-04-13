import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../analytics_metric_colors.dart';
import '../analytics_view_models.dart';

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
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1200
        ? 4
        : width >= 760
            ? 2
            : 1;
    final aspectRatio = width >= 1200
        ? 2.55
        : width >= 760
            ? 2.8
            : 3.25;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: KubusSpacing.md,
        mainAxisSpacing: KubusSpacing.md,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, index) {
        return _AnalyticsOverviewCard(
          data: cards[index],
          isLoading: isLoading,
          isSelected: cards[index].metricId == selectedMetricId,
          onTap: () => onMetricSelected(cards[index].metricId),
        );
      },
    );
  }
}

class _AnalyticsOverviewCard extends StatefulWidget {
  const _AnalyticsOverviewCard({
    required this.data,
    required this.isLoading,
    required this.isSelected,
    required this.onTap,
  });

  final AnalyticsOverviewCardData data;
  final bool isLoading;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_AnalyticsOverviewCard> createState() => _AnalyticsOverviewCardState();
}

class _AnalyticsOverviewCardState extends State<_AnalyticsOverviewCard> {
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
    final active = _hovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        selected: widget.isSelected,
        label: '${widget.data.title} analytics',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
              padding: const EdgeInsets.all(KubusSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: active ? 0.22 : 0.12),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                  ],
                ),
                borderRadius: BorderRadius.circular(KubusRadius.sm),
                border: Border.all(
                  color: active
                      ? accent.withValues(alpha: 0.55)
                      : scheme.outline.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  if (_hovered)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: active ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(KubusRadius.sm),
                      border: Border.all(
                        color: accent.withValues(alpha: active ? 0.40 : 0.22),
                      ),
                    ),
                    child: Icon(
                      widget.data.icon,
                      color: accent,
                      size: 22,
                    ),
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
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface.withValues(alpha: 0.76),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isLoading ? '...' : widget.data.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KubusTypography.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: active ? accent : scheme.onSurface,
                          ),
                        ),
                        if (widget.data.changeLabel != null ||
                            widget.data.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.data.changeLabel ?? widget.data.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KubusTypography.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.data.changeLabel != null
                                  ? trendColor
                                  : scheme.onSurface.withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ],
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
