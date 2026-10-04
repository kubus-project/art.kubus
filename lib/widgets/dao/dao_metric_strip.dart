import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_stat_card.dart';

/// One governance metric for [DaoMetricStrip].
@immutable
class DaoMetric {
  const DaoMetric({
    required this.title,
    required this.value,
    required this.icon,
    this.semanticsLabel,
    this.onTap,
  });

  final String title;
  final String value;

  /// The metric's own symbol: it becomes the oversized ghost glyph.
  final IconData icon;
  final String? semanticsLabel;
  final VoidCallback? onTap;
}

/// The governance metric strip (voting power, active proposals, delegates)
/// in the same expressive [KubusStatCard] language as the Home and profile
/// statistics: a large value, the DAO accent as one contextual field rising
/// from the trailing corner, the metric's glyph oversized and cropped there,
/// and the shared hover response when the tile is interactive.
///
/// Layout follows the available width, never a fixed utility row:
/// * wide (>= [rowBreakpoint]): every metric in one balanced row;
/// * narrower: two columns, and with an odd count the first metric (the
///   visitor's own voting power when present) takes the full width, so no
///   tile is squeezed and nothing overflows horizontally.
///
/// Tiles are as tall as their value plus a two-line label at the ambient text
/// scale (floored at [minTileHeight]), so 200 % text grows the strip instead
/// of clipping it. The strip stays secondary to the proposals: one band, no
/// heading of its own.
class DaoMetricStrip extends StatelessWidget {
  const DaoMetricStrip({super.key, required this.metrics});

  final List<DaoMetric> metrics;

  static const double rowBreakpoint = 600;
  static const double minTileHeight = 104;
  static const double gap = KubusSpacing.sm;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    final accent = KubusColorRoles.of(context).web3DaoAccent;
    final height = math.max(
      minTileHeight,
      KubusStatCard.centeredExtent(context, titleLines: 2),
    );

    Widget tile(DaoMetric metric) => SizedBox(
          height: height,
          child: KubusStatCard(
            title: metric.title,
            value: metric.value,
            icon: metric.icon,
            accent: accent,
            layout: KubusStatCardLayout.centered,
            expressive: true,
            titleMaxLines: 2,
            minHeight: height,
            semanticsLabel: metric.semanticsLabel,
            onTap: metric.onTap,
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= rowBreakpoint || metrics.length == 1) {
          return Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: tile(metrics[i])),
              ],
            ],
          );
        }
        final rows = <Widget>[];
        var start = 0;
        if (metrics.length.isOdd) {
          rows.add(tile(metrics.first));
          start = 1;
        }
        for (var i = start; i < metrics.length; i += 2) {
          rows.add(
            Row(
              children: [
                Expanded(child: tile(metrics[i])),
                const SizedBox(width: gap),
                Expanded(
                  child: i + 1 < metrics.length
                      ? tile(metrics[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}
