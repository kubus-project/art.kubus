import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../analytics_view_models.dart';

class AnalyticsOverviewGrid extends StatelessWidget {
  const AnalyticsOverviewGrid({
    super.key,
    required this.cards,
    required this.isLoading,
  });

  final List<AnalyticsOverviewCardData> cards;
  final bool isLoading;

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
        );
      },
    );
  }
}

class _AnalyticsOverviewCard extends StatefulWidget {
  const _AnalyticsOverviewCard({
    required this.data,
    required this.isLoading,
  });

  final AnalyticsOverviewCardData data;
  final bool isLoading;

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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(
            color: _hovered
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.10),
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
                color: scheme.primaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              child: Icon(
                widget.data.icon,
                color: scheme.onPrimaryContainer,
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
                      color: scheme.onSurface.withValues(alpha: 0.70),
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
                      color: scheme.onSurface,
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
                            : scheme.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
