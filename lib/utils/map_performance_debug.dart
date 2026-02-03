import 'package:flutter/foundation.dart';

import '../config/config.dart';

/// Debug-only toggle for map performance instrumentation.
///
/// This is intentionally runtime-togglable (debug builds only) so we can
/// validate performance improvements without shipping noisy logs.
class MapPerformanceDebug {
  MapPerformanceDebug._();

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static bool get isEnabled => kDebugMode && enabled.value;

  static void setEnabled(bool value) {
    if (!kDebugMode) return;
    if (enabled.value == value) return;
    enabled.value = value;
    AppConfig.debugPrint('MapPerformanceDebug: enabled=$value');
  }

  static void toggle() => setEnabled(!enabled.value);
}
