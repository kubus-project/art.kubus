import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/analytics_filters_provider.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_button.dart';
import '../analytics_metric_colors.dart';
import '../analytics_metric_registry.dart';

/// Localized long-form label for an analytics timeframe token.
String analyticsTimeframeLabel(AppLocalizations l10n, String timeframe) {
  switch (timeframe) {
    case '24h':
      return l10n.analyticsTimeframeLabel24h;
    case '7d':
      return l10n.analyticsTimeframeLabel7d;
    case '30d':
      return l10n.analyticsTimeframeLabel30d;
    case '90d':
      return l10n.analyticsTimeframeLabel90d;
    case '1y':
      return l10n.analyticsTimeframeLabel1y;
  }
  return timeframe.toUpperCase();
}

/// Opens the canonical liquid-glass sheet with the full metric list and
/// timeframe options. Selections apply immediately through the provided
/// callbacks (which persist via [AnalyticsFiltersProvider]), so closing the
/// sheet never loses state.
Future<void> showAnalyticsFilterSheet({
  required BuildContext context,
  required List<AnalyticsMetricDefinition> metrics,
  required String selectedMetricId,
  required String timeframe,
  required ValueChanged<String> onMetricChanged,
  required ValueChanged<String> onTimeframeChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _AnalyticsFilterSheet(
        metrics: metrics,
        initialMetricId: selectedMetricId,
        initialTimeframe: timeframe,
        onMetricChanged: onMetricChanged,
        onTimeframeChanged: onTimeframeChanged,
      );
    },
  );
}

class _AnalyticsFilterSheet extends StatefulWidget {
  const _AnalyticsFilterSheet({
    required this.metrics,
    required this.initialMetricId,
    required this.initialTimeframe,
    required this.onMetricChanged,
    required this.onTimeframeChanged,
  });

  final List<AnalyticsMetricDefinition> metrics;
  final String initialMetricId;
  final String initialTimeframe;
  final ValueChanged<String> onMetricChanged;
  final ValueChanged<String> onTimeframeChanged;

  @override
  State<_AnalyticsFilterSheet> createState() => _AnalyticsFilterSheetState();
}

class _AnalyticsFilterSheetState extends State<_AnalyticsFilterSheet> {
  late String _metricId = widget.initialMetricId;
  late String _timeframe = widget.initialTimeframe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // Bound the content column inside the glass sheet so the metric list can
    // flex-scroll; the sheet itself stays as tall as its content needs.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return BackdropGlassSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.analyticsFilterSheetTitle,
              style: KubusTypography.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            // One scroll area for every control, so no viewport height or
            // text scale can overflow the sheet; title and Done stay fixed.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    l10n.analyticsFilterTimeframeSectionTitle,
                    style: KubusTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  Wrap(
                    spacing: KubusSpacing.sm,
                    runSpacing: KubusSpacing.sm,
                    children: [
                      for (final tf
                          in AnalyticsFiltersProvider.allowedTimeframes)
                        ChoiceChip(
                          selected: _timeframe == tf,
                          label: Text(analyticsTimeframeLabel(l10n, tf)),
                          onSelected: (_) {
                            setState(() => _timeframe = tf);
                            widget.onTimeframeChanged(tf);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: KubusSpacing.lg),
                  Text(
                    l10n.analyticsMetricLabel,
                    style: KubusTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  for (var index = 0;
                      index < widget.metrics.length;
                      index++) ...[
                    if (index > 0) const SizedBox(height: KubusSpacing.xs),
                    _buildMetricRow(context, widget.metrics[index]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: KubusSpacing.lg),
            KubusButton(
              label: l10n.commonDone,
              isFullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    AnalyticsMetricDefinition metric,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final selected = metric.id == _metricId;
    final accent = AnalyticsMetricColors.resolve(context, metric.id);
    return Semantics(
      button: true,
      selected: selected,
      label: metric.localizedLabel(l10n),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          onTap: () {
            setState(() => _metricId = metric.id);
            widget.onMetricChanged(metric.id);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.md,
              vertical: KubusSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(KubusRadius.sm),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.45)
                    : scheme.outline.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  metric.icon,
                  size: 20,
                  color: selected
                      ? accent
                      : scheme.onSurface.withValues(alpha: 0.62),
                ),
                const SizedBox(width: KubusSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.localizedLabel(l10n),
                        style: KubusTypography.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        metric.localizedDescription(l10n),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTypography.inter(
                          fontSize: 12,
                          height: 1.3,
                          color: scheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: KubusSpacing.sm),
                  Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
