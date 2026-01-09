import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'charts/stats_interactive_bar_chart.dart';
import 'charts/stats_interactive_line_chart.dart';

class EnhancedStatsChart extends StatelessWidget {
  final String title;
  final List<double> data;
  final Color accentColor;
  final List<String>? labels;

  const EnhancedStatsChart({
    super.key,
    required this.title,
    required this.data,
    required this.accentColor,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final xLabels = (labels != null && labels!.length == data.length)
        ? labels!
        : List<String>.generate(data.length, (i) => '${i + 1}d', growable: false);

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          StatsInteractiveLineChart(
            series: [
              StatsLineSeries(
                label: title,
                values: data,
                color: accentColor,
                showArea: true,
              ),
            ],
            xLabels: xLabels,
            height: 180,
            gridColor: scheme.onSurface.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

// Bar chart variant
class EnhancedBarChart extends StatelessWidget {
  final String title;
  final List<double> data;
  final Color accentColor;
  final List<String>? labels;

  const EnhancedBarChart({
    super.key,
    required this.title,
    required this.data,
    required this.accentColor,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final xLabels = (labels != null && labels!.length == data.length)
        ? labels!
        : List<String>.generate(data.length, (i) => '${i + 1}d', growable: false);

    final now = DateTime.now();
    final entries = List<StatsBarEntry>.generate(
      data.length,
      (i) {
        final dayOffset = data.length - 1 - i;
        return StatsBarEntry(
          bucketStart: now.subtract(Duration(days: dayOffset)),
          value: data[i].round(),
        );
      },
      growable: false,
    );

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          StatsInteractiveBarChart(
            entries: entries,
            xLabels: xLabels,
            barColor: accentColor,
            gridColor: scheme.onSurface.withValues(alpha: 0.12),
            height: 140,
          ),
        ],
      ),
    );
  }
}
