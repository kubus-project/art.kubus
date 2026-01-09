import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  const StatsInteractiveLineChart({
    super.key,
    required this.series,
    required this.xLabels,
    this.height = 200,
    required this.gridColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (series.isEmpty || xLabels.isEmpty) {
      return SizedBox(height: height);
    }

    final pointCount = xLabels.length;
    final normalizedSeries = series
        .map(
          (s) => StatsLineSeries(
            label: s.label,
            color: s.color,
            showArea: s.showArea,
            values: _padOrTrim(s.values, pointCount),
          ),
        )
        .toList(growable: false);

    final yMax = _computeMaxY(normalizedSeries);
    final yTop = yMax <= 0 ? 1.0 : (yMax * 1.15);

    final chartWidth = math.max(0, pointCount - 1) * 28.0 + 56;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, chartWidth);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: padding,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (pointCount - 1).toDouble(),
                    minY: 0,
                    maxY: yTop,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _niceInterval(yTop),
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
                        right: BorderSide(color: gridColor.withValues(alpha: 0.35)),
                        top: BorderSide(color: gridColor.withValues(alpha: 0.35)),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _niceInterval(yTop),
                          reservedSize: 44,
                          getTitlesWidget: (value, meta) {
                            if (value < 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                value.round().toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: scheme.onSurface.withValues(alpha: 0.65),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: _bottomInterval(pointCount),
                          getTitlesWidget: (value, meta) {
                            final idx = value.round();
                            if (idx < 0 || idx >= xLabels.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                xLabels[idx],
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: scheme.onSurface.withValues(alpha: 0.55),
                                ),
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
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.surfaceContainerHighest,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) {
                          if (spots.isEmpty) return const [];
                          final x = spots.first.x.round().clamp(0, xLabels.length - 1);
                          final header = xLabels[x];

                          final items = <LineTooltipItem>[
                            LineTooltipItem(
                              '$header\n',
                              GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ];

                          for (final spot in spots) {
                            final label = spot.barIndex >= 0 && spot.barIndex < normalizedSeries.length
                                ? normalizedSeries[spot.barIndex].label
                                : 'Series';
                            items.add(
                              LineTooltipItem(
                                '$label: ${spot.y.round()}\n',
                                GoogleFonts.inter(
                                  fontSize: 11,
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
                    lineBarsData: normalizedSeries.map((s) {
                      final spots = List<FlSpot>.generate(
                        pointCount,
                        (i) => FlSpot(i.toDouble(), s.values[i]),
                        growable: false,
                      );

                      return LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.25,
                        preventCurveOverShooting: true,
                        color: s.color,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: s.showArea,
                          color: s.color.withValues(alpha: 0.12),
                        ),
                      );
                    }).toList(growable: false),
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

  static double _computeMaxY(List<StatsLineSeries> series) {
    var maxY = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > maxY) maxY = v;
      }
    }
    return maxY;
  }

  static double _niceInterval(double maxY) {
    if (maxY <= 0) return 1;
    final rough = maxY / 4;
    final power = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final scaled = rough / power;
    final base = scaled <= 1
        ? 1
        : scaled <= 2
            ? 2
            : scaled <= 5
                ? 5
                : 10;
    return base * power;
  }

  static double _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return (count / 6).ceilToDouble();
  }
}
