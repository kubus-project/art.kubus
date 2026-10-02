import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/common/kubus_atmosphere.dart';
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
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = columnsFor(constraints.maxWidth);
              // Rows are measured, not aspect-ratio cells: each row is as
              // tall as its tallest tile at the ambient text scale, so 200 %
              // text grows the row instead of clipping the value.
              return Column(
                key: const ValueKey<String>('analytics_supporting_metrics'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var row = 0;
                      row * columns < supporting.length;
                      row++) ...[
                    if (row > 0) const SizedBox(height: KubusSpacing.md),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var col = 0; col < columns; col++) ...[
                            if (col > 0) const SizedBox(width: KubusSpacing.md),
                            Expanded(
                              child: row * columns + col < supporting.length
                                  ? _AnalyticsSupportingCard(
                                      data: supporting[row * columns + col],
                                      isLoading: isLoading,
                                      onTap: () => onMetricSelected(
                                        supporting[row * columns + col]
                                            .metricId,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  /// Supporting columns for the space the overview actually gets (not the
  /// window): three on a wide workspace, two on a medium one, one on a phone.
  static int columnsFor(double width) => width >= 840
      ? 3
      : width >= 520
          ? 2
          : 1;
}

/// Trend direction and period, shared by the lead and supporting cards. The
/// arrow is the direction (state), the label the magnitude: neither repeats
/// the metric's identity.
class _AnalyticsTrend extends StatelessWidget {
  const _AnalyticsTrend({
    required this.data,
    required this.fontSize,
    this.showSubtitle = false,
  });

  final AnalyticsOverviewCardData data;
  final double fontSize;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final trendColor = data.isPositive == null
        ? scheme.onSurface.withValues(alpha: 0.62)
        : data.isPositive!
            ? roles.positiveAction
            : roles.negativeAction;
    return Wrap(
      spacing: KubusSpacing.sm,
      runSpacing: KubusSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (data.changeLabel != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.isPositive != null) ...[
                Icon(
                  data.isPositive!
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  // Tracks the label it qualifies at any text scale.
                  size: MediaQuery.textScalerOf(context).scale(fontSize + 1),
                  color: trendColor,
                ),
                const SizedBox(width: KubusSpacing.xxs),
              ],
              Text(
                data.changeLabel!,
                style: KubusTypography.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: trendColor,
                ),
              ),
            ],
          ),
        if (showSubtitle && data.subtitle != null)
          Text(
            data.subtitle!,
            style: KubusTypography.inter(
              fontSize: fontSize - 1,
              color: scheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
      ],
    );
  }
}

/// The selected metric. Its identity is expressed once, as the metric's
/// glyph cropped into the trailing corner; the accent border marks the
/// selection. Label, value and trend stack in normal flow, clear of the
/// glyph corner, so a long label or 200 % text grows the card instead of
/// pushing the value out.
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
    final accent = AnalyticsMetricColors.resolve(context, data.metricId);
    final hasTrend = data.changeLabel != null || data.subtitle != null;

    final label = Text(
      data.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: KubusTypography.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface.withValues(alpha: 0.72),
      ),
    );
    // A number is never ellipsised: wider than the card, it scales down.
    final value = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        isLoading ? '…' : data.value,
        maxLines: 1,
        style: KubusTypography.inter(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
    );
    final trend = hasTrend
        ? _AnalyticsTrend(data: data, fontSize: 13, showSubtitle: true)
        : null;

    return Semantics(
      button: true,
      selected: true,
      label: AppLocalizations.of(context)!.analyticsCardSemanticsLabel(
        data.title,
      ),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.66),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.md),
          side: BorderSide(color: accent.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: KubusGhostGlyph(
                  key: const ValueKey<String>('analytics_lead_glyph'),
                  icon: data.icon,
                  color: accent,
                  alignment: Alignment.bottomRight,
                  extent: 120,
                  bleed: 0.34,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                // One reading order at every width: label, value, trend.
                // The trailing corner belongs to the glyph.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: KubusSpacing.xs),
                    value,
                    if (trend != null) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      trend,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A metric that can be promoted to the lead. Its colour appears once, as
/// the legend key before the label (the colour of its chart series); there
/// is no icon tile. Hover answers with the border only.
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

  static const double _labelSize = 12;
  static const double _labelHeight = 1.3;
  static const double _keySize = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AnalyticsMetricColors.resolve(context, widget.data.metricId);
    final scaler = MediaQuery.textScalerOf(context);

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
              constraints: const BoxConstraints(minHeight: 44),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Centred on the label's first line at any text scale.
                      Padding(
                        padding: EdgeInsets.only(
                          top: (scaler.scale(_labelSize) * _labelHeight -
                                  _keySize) /
                              2,
                        ),
                        child: Container(
                          key: const ValueKey<String>('analytics_metric_key'),
                          width: _keySize,
                          height: _keySize,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.data.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KubusTypography.inter(
                            fontSize: _labelSize,
                            height: _labelHeight,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            widget.isLoading ? '…' : widget.data.value,
                            maxLines: 1,
                            style: KubusTypography.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (widget.data.changeLabel != null) ...[
                        const SizedBox(width: KubusSpacing.sm),
                        _AnalyticsTrend(data: widget.data, fontSize: 11),
                      ],
                    ],
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
