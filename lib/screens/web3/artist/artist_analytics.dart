import 'package:flutter/material.dart';

import '../../../features/analytics/analytics_presets.dart';
import '../../../features/analytics/unified_analytics_screen.dart';

class ArtistAnalytics extends StatelessWidget {
  const ArtistAnalytics({super.key, this.embedded = true});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return UnifiedAnalyticsScreen(
      presetKind: AnalyticsPresetKind.artist,
      embedded: embedded,
    );
  }
}
