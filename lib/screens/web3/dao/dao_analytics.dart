import 'package:flutter/material.dart';

import '../../../features/analytics/analytics_presets.dart';
import '../../../features/analytics/unified_analytics_screen.dart';

class DAOAnalytics extends StatelessWidget {
  const DAOAnalytics({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return UnifiedAnalyticsScreen(
      presetKind: AnalyticsPresetKind.dao,
      embedded: embedded,
    );
  }
}
