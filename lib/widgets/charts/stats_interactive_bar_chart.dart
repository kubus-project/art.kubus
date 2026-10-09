import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import 'chart_scale.dart';
import 'stats_chart_shared.dart';

@immutable
class StatsBarEntry {
  final DateTime bucketStart;
  final int value;

  const StatsBarEntry({required this.bucketStart, required this.value});
}

class StatsInteractiveBarChart extends StatelessWidget {
  final List<StatsBarEntry> entries;
  final List<String> xLabels;
  final Color barColor;
  final double height;
  final Color gridColor;

  /// Shown on the baseline when every entry is zero. Localized by the caller.
  final String emptyLabel;

  const StatsInteractiveBarChart({
    super.key,
    required this.entries,
    required this.xLabels,
    required this.barColor,
    required this.gridColor,
    required this.emptyLabel,
    this.height = 140,
  }) : assert(entries.length == xLabels.length);

  static const double _bottomReserved = 34;
  static const double _minYReserved = 52;
  static const double _edgePadding = 20;
  static const double _slotMinWidth = 22;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pointCount = entries.length;

    if (pointCount == 0) {
      return StatsChartEmptyState(
        height: height,
        gridColor: gridColor,
        label: emptyLabel,
      );
    }

    final locale = Localizations.localeOf(context).languageCode;
    final values =
        entries.map((e) => e.value.toDouble()).toList(growable: false);
    final bottomLabelStyle = KubusTextStyles.navMetaLabel.copyWith(
      fontSize: math.max(KubusChromeMetrics.navMetaLabel - 1, 11),
      color: scheme.onSurface.withValues(alpha: 0.55),
    );
    final bottomLabelWidth =
        statsChartWidestLabel(context, xLabels, bottomLabelStyle);
    final minWidth = 52 + pointCount * _slotMinWidth;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final domain = ChartScale.domain(
            values,
            targetTicks: ChartScale.ticksFor(available),
            minStep: 1,
            padFlat: false,
            clipOutliers: true,
          );
          if (!domain.hasData) {
            return StatsChartEmptyState(
              height: height,
              gridColor: gridColor,
              label: emptyLabel,
            );
          }

          final yLabels = domain.ticks
              .map((tick) => ChartScale.compactLabel(tick, locale: locale))
              .toList(growable: false);
          final yReserved = math.max(
            _minYReserved,
            statsChartWidestLabel(
                    context, yLabels, KubusTextStyles.navMetaLabel) +
                10,
          );
          final width = ChartScale.contentWidth(
            available: available,
            minWidth: minWidth,
          );
          final plotWidth = math.max(0.0, width - yReserved - _edgePadding);
          final rodWidth = ChartScale.barWidth(plotWidth, pointCount);
          final stride = ChartScale.labelStride(
            count: pointCount,
            pointSpacing: plotWidth / pointCount,
            labelWidth: bottomLabelWidth,
          );

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: BarChart(
                  BarChartData(
                    minY: domain.min,
                    maxY: domain.max,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: domain.step,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: gridColor,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: gridColor),
                        left: BorderSide(color: gridColor),
                        right: BorderSide(
                            color: gridColor.withValues(alpha: 0.35)),
                        top: BorderSide(
                            color: gridColor.withValues(alpha: 0.35)),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: domain.step,
                          reservedSize: yReserved,
                          getTitlesWidget: (value, meta) {
                            if (value < domain.min || value > domain.max) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                ChartScale.compactLabel(value, locale: locale),
                                style: KubusTextStyles.navMetaLabel.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.65),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: _bottomReserved,
                          interval: stride.toDouble(),
                          getTitlesWidget: (value, meta) {
                            final idx = value.round();
                            // Only the stride grid is labelled. fl_chart also
                            // reports the last x value, which would collide
                            // with the grid label next to it.
                            if (idx < 0 ||
                                idx >= xLabels.length ||
                                idx % stride != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                xLabels[idx],
                                style: bottomLabelStyle,
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => scheme.surfaceContainerHighest,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final inRange =
                              groupIndex >= 0 && groupIndex < xLabels.length;
                          final label = inRange ? xLabels[groupIndex] : '';
                          // The rod may be clipped to the domain top; the
                          // tooltip always reports the true entry value.
                          final value = inRange
                              ? entries[groupIndex].value
                              : rod.toY.round();
                          return BarTooltipItem(
                            '$label\n$value',
                            KubusTextStyles.navMetaLabel.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: List<BarChartGroupData>.generate(
                      pointCount,
                      (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: domain.plot(values[i]),
                              color: barColor,
                              width: rodWidth,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      },
                      growable: false,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
