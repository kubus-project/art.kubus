import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

/// Pieces the analytics line and bar charts share: the empty state and the
/// text measurement that sizes axis labels.

/// Empty state for the analytics charts: a baseline at zero with a localized
/// message above it. Used when there is no data, or every value is zero.
class StatsChartEmptyState extends StatelessWidget {
  const StatsChartEmptyState({
    super.key,
    required this.height,
    required this.gridColor,
    required this.label,
  });

  final double height;
  final Color gridColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: KubusTextStyles.navMetaLabel.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          ),
          Container(height: 1, color: gridColor),
        ],
      ),
    );
  }
}

/// Width of the widest of [labels] in [style], at the current text scale.
double statsChartWidestLabel(
  BuildContext context,
  List<String> labels,
  TextStyle style,
) {
  final direction = Directionality.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  var widest = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  return widest;
}
