import 'package:flutter/material.dart';

import '../../features/analytics/analytics_presets.dart';
import '../../features/analytics/unified_analytics_screen.dart';
import '../../services/stats_api_service.dart';

class AdvancedStatsScreen extends StatelessWidget {
  final String statType;

  const AdvancedStatsScreen({super.key, required this.statType});

  @override
  Widget build(BuildContext context) {
    return UnifiedAnalyticsScreen(
      presetKind: AnalyticsPresetKind.profile,
      initialMetricId: StatsApiService.metricFromUiStatType(statType),
    );
  }
}
