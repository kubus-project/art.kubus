import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../widgets/glass_components.dart';

/// Initializes event listeners for WebGL context loss detection.
///
/// When the JS layer dispatches 'kubus:webgl-critical' or 'kubus:canvaskit-crash',
/// this helper sets [kubusDisableBackdropFilter] to true, causing all
/// [LiquidGlassPanel] and [showKubusDialog] calls to skip BackdropFilter
/// (which requires a healthy WebGL context).
void initWebGLContextHelper() {
  // Firefox (especially on Android) is prone to WebGL/CanvasKit composition
  // quirks when BackdropFilter is layered above other WebGL content (MapLibre).
  // This can manifest as “burned-in”/ghosted UI on the map surface.
  //
  // Disable BackdropFilter preemptively on Firefox to keep rendering stable.
  try {
    final ua = web.window.navigator.userAgent;
    if (_isFirefoxUserAgent(ua)) {
      kubusDisableBackdropFilter = true;
      if (kDebugMode) {
        // Intentionally quiet in release; this is an environment workaround.
        // ignore: avoid_print
        print('webgl_context_helper: Firefox detected; disabling BackdropFilter');
      }
    }
  } catch (_) {
    // Best-effort: userAgent access can fail in some hardened contexts.
  }

  // Listen for the custom events dispatched by webgl_context_handler.js
  web.window.addEventListener(
    'kubus:webgl-critical',
    _onWebGLCritical.toJS,
  );
  web.window.addEventListener(
    'kubus:canvaskit-crash',
    _onCanvasKitCrash.toJS,
  );
  web.window.addEventListener(
    'kubus:webgl-restored',
    _onWebGLRestored.toJS,
  );
}

bool _isFirefoxUserAgent(String? userAgent) {
  final ua = (userAgent ?? '').toLowerCase();
  if (ua.isEmpty) return false;
  // Android: contains "Firefox/.."
  // iOS: contains "FxiOS/.."
  return ua.contains('firefox') || ua.contains('fxios');
}

void _onWebGLCritical(web.Event event) {
  // Disable BackdropFilter to prevent further crashes
  kubusDisableBackdropFilter = true;
}

void _onCanvasKitCrash(web.Event event) {
  // Disable BackdropFilter to prevent further crashes
  kubusDisableBackdropFilter = true;
}

void _onWebGLRestored(web.Event event) {
  // Re-enable BackdropFilter if context is restored successfully
  // Note: we leave it disabled for now to be safe; can be changed if needed
  // kubusDisableBackdropFilter = false;
}
