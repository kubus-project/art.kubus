import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import 'chart_scale.dart';
import 'stats_chart_shared.dart';

@immutable
class StatsLineSeries {
  final String label;
  final List<double> values;
  final Color color;
  final bool showArea;

  const StatsLineSeries({
    required this.label,
    required this.values,
    required this.color,
    this.showArea = false,
  });
}

class StatsInteractiveLineChart extends StatelessWidget {
  final List<StatsLineSeries> series;
  final List<String> xLabels;
  final double height;
  final Color gridColor;
  final EdgeInsetsGeometry padding;
  final String Function(num value)? valueFormatter;

  /// Shown on the baseline when there is nothing to plot. Localized by the
  /// caller.
  final String emptyLabel;

  const StatsInteractiveLineChart({
    super.key,
    required this.series,
    required this.xLabels,
    this.height = 200,
    required this.gridColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    this.valueFormatter,
    required this.emptyLabel,
  });

  static const double _bottomReserved = 34;
  static const double _minYReserved = 52;
  static const double _baseMinWidth = 84;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pointCount = xLabels.length;

    if (series.isEmpty || pointCount == 0) {
      return StatsChartEmptyState(
        height: height,
        gridColor: gridColor,
        label: emptyLabel,
      );
    }

    final locale = Localizations.localeOf(context).languageCode;
    final formatValue = valueFormatter ?? ((value) => value.round().toString());
    final padded = series
        .map((s) => _padOrTrim(ChartScale.sanitize(s.values), pointCount))
        .toList(growable: false);
    final allValues = padded.expand((values) => values);

    final edge = padding.resolve(Directionality.of(context));
    final bottomLabelStyle = KubusTextStyles.navMetaLabel.copyWith(
      fontSize: math.max(KubusChromeMetrics.navMetaLabel - 1, 11),
      color: scheme.onSurface.withValues(alpha: 0.55),
    );
    final bottomLabelWidth =
        statsChartWidestLabel(context, xLabels, bottomLabelStyle);
    // Lines never scroll sideways. The label stride already thins the x labels
    // to whatever fits, so a longer series only gets denser, not wider. A
    // per-point minimum would scroll 52-week and 90-day series on phones.
    const minWidth = _baseMinWidth;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final domain = ChartScale.domain(
            allValues,
            targetTicks: ChartScale.ticksFor(available),
            minStep: 1,
            padFlat: true,
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
          final plotWidth = math.max(
            0.0,
            width - yReserved - edge.horizontal,
          );
          final stride = ChartScale.labelStride(
            count: pointCount,
            pointSpacing: pointCount > 1 ? plotWidth / (pointCount - 1) : 0,
            labelWidth: bottomLabelWidth,
          );
          final singlePoint = pointCount == 1;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: padding,
                child: LineChart(
                  LineChartData(
                    // A single point sits at the centre of a short x range
                    // instead of on the axis, so it still reads as a point.
                    minX: singlePoint ? -0.5 : 0,
                    maxX: singlePoint ? 0.5 : (pointCount - 1).toDouble(),
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
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchSpotThreshold: 28,
                      mouseCursorResolver: (_, __) =>
                          SystemMouseCursors.precise,
                      getTouchedSpotIndicator: (
                        LineChartBarData barData,
                        List<int> spotIndexes,
                      ) {
                        return spotIndexes.map((_) {
                          return TouchedSpotIndicatorData(
                            FlLine(
                              color: barData.color ??
                                  scheme.primary.withValues(alpha: 0.75),
                              strokeWidth: 1.6,
                              dashArray: [4, 4],
                            ),
                            FlDotData(
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                radius: 4,
                                color: barData.color ?? scheme.primary,
                                strokeWidth: 2,
                                strokeColor: scheme.surface,
                              ),
                            ),
                          );
                        }).toList(growable: false);
                      },
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.surfaceContainerHighest,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) {
                          if (spots.isEmpty) return const [];
                          final x = spots.first.x
                              .round()
                              .clamp(0, xLabels.length - 1);
                          final header = xLabels[x];

                          final items = <LineTooltipItem>[
                            LineTooltipItem(
                              '$header\n',
                              KubusTextStyles.navMetaLabel.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ];

                          for (final spot in spots) {
                            final index = spot.barIndex;
                            final label = index >= 0 && index < series.length
                                ? series[index].label
                                : 'Series';
                            // Tooltips show the true value, even when the
                            // drawn point was clipped to the domain top.
                            final trueValue =
                                index >= 0 && index < padded.length
                                    ? padded[index][x]
                                    : spot.y;
                            items.add(
                              LineTooltipItem(
                                '$label: ${formatValue(trueValue)}\n',
                                KubusTextStyles.navMetaLabel.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: spot.bar.color ?? scheme.primary,
                                ),
                              ),
                            );
                          }

                          return items;
                        },
                      ),
                    ),
                    lineBarsData: List<LineChartBarData>.generate(
                      series.length,
                      (seriesIndex) {
                        final s = series[seriesIndex];
                        final raw = padded[seriesIndex];
                        final spots = List<FlSpot>.generate(
                          pointCount,
                          (i) => FlSpot(
                            singlePoint ? 0 : i.toDouble(),
                            domain.plot(raw[i]),
                          ),
                          growable: false,
                        );
                        bool isMarked(int index) =>
                            singlePoint || domain.isClippedValue(raw[index]);

                        return LineChartBarData(
                          spots: spots,
                          isCurved: !singlePoint,
                          curveSmoothness: 0.22,
                          preventCurveOverShooting: true,
                          color: s.color,
                          barWidth: 2.8,
                          isStrokeCapRound: true,
                          // Dots only where the line cannot show the point:
                          // a single value, or a value clipped at the top.
                          dotData: FlDotData(
                            show: singlePoint || raw.any(domain.isClippedValue),
                            checkToShowDot: (spot, _) => isMarked(spot.x
                                .round()
                                .clamp(0, pointCount - 1)
                                .toInt()),
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                              radius: singlePoint ? 4.5 : 3.5,
                              color: s.color,
                              strokeWidth: 2,
                              strokeColor: scheme.surface,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: s.showArea,
                            color: s.color.withValues(alpha: 0.12),
                          ),
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

  static List<double> _padOrTrim(List<double> values, int length) {
    if (values.length == length) return values;
    if (values.isEmpty) return List<double>.filled(length, 0);
    if (values.length > length) return values.sublist(values.length - length);
    final out = List<double>.filled(length, 0);
    final offset = length - values.length;
    for (var i = 0; i < values.length; i++) {
      out[offset + i] = values[i];
    }
    return out;
  }
}
