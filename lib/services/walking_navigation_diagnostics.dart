import 'package:flutter/foundation.dart';

import '../config/config.dart';

/// Bounded, coordinate-free walking-navigation diagnostics.
class WalkingNavigationDiagnostics {
  const WalkingNavigationDiagnostics._();

  static void record(
    String event, {
    String? reason,
  }) {
    if (!kDebugMode) return;
    final safeEvent = event.trim().take(64);
    final safeReason = reason?.trim().take(64);
    AppConfig.debugPrint(
      'WalkingNavigation: event=$safeEvent'
      '${safeReason == null || safeReason.isEmpty ? '' : ' reason=$safeReason'}',
    );
  }
}

extension on String {
  String take(int maximum) => length <= maximum ? this : substring(0, maximum);
}
