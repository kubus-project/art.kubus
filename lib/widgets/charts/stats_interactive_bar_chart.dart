import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  const StatsInteractiveBarChart({
    super.key,
    required this.entries,
    required this.xLabels,
    required this.barColor,
    required this.gridColor,
    this.height = 140,
  }) : assert(entries.length == xLabels.length);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return SizedBox(height: height);
    }

    final maxY = entries.fold<int>(0, (max, e) => e.value > max ? e.value : max);
    final yTop = maxY <= 0 ? 1.0 : maxY.toDouble() * 1.2;

    final pointCount = entries.length;
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: BarChart(
                  BarChartData(
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
                    barTouchData: BarTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => scheme.surfaceContainerHighest,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final label = groupIndex >= 0 && groupIndex < xLabels.length ? xLabels[groupIndex] : '';
                          final value = rod.toY.round();
                          return BarTooltipItem(
                            '$label\n$value',
                            GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: List<BarChartGroupData>.generate(
                      entries.length,
                      (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: entries[i].value.toDouble(),
                              color: barColor,
                              width: 14,
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
