import 'package:flutter/material.dart';

import '../../features/analytics/analytics_presets.dart';
import '../../features/analytics/unified_analytics_screen.dart';
import '../../services/stats_api_service.dart';

enum AnalyticsExperienceContext { home, profile, community }

class AdvancedAnalyticsScreen extends StatelessWidget {
  final String statType;
  final String? walletAddress;
  final AnalyticsExperienceContext initialContext;
  final List<AnalyticsExperienceContext> contexts;
  final bool embedded;

  const AdvancedAnalyticsScreen({
    super.key,
    required this.statType,
    this.walletAddress,
    this.embedded = false,
    this.initialContext = AnalyticsExperienceContext.home,
    this.contexts = const <AnalyticsExperienceContext>[
      AnalyticsExperienceContext.home,
    ],
  });

  @override
  Widget build(BuildContext context) {
    final presetKind = _presetFor(initialContext);
    final available = contexts.map(_presetFor).toSet().toList(growable: false);
    if (!available.contains(presetKind)) {
      available.insert(0, presetKind);
    }

    return UnifiedAnalyticsScreen(
      presetKind: presetKind,
      entityId: walletAddress,
      initialMetricId: StatsApiService.metricFromUiStatType(statType),
      availablePresetKinds: available,
      embedded: embedded,
    );
  }

  AnalyticsPresetKind _presetFor(AnalyticsExperienceContext contextType) {
    switch (contextType) {
      case AnalyticsExperienceContext.home:
      case AnalyticsExperienceContext.profile:
        return AnalyticsPresetKind.profile;
      case AnalyticsExperienceContext.community:
        return AnalyticsPresetKind.community;
    }
  }
}
