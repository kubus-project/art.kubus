import 'dart:js_interop';
import 'package:web/web.dart' as web;

import '../widgets/glass_components.dart';

/// Initializes event listeners for WebGL context loss detection.
///
/// When the JS layer dispatches 'kubus:webgl-critical' or 'kubus:canvaskit-crash',
/// this helper sets [kubusDisableBackdropFilter] to true, causing all
/// [LiquidGlassPanel] and [showKubusDialog] calls to skip BackdropFilter
/// (which requires a healthy WebGL context).
void initWebGLContextHelper() {
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
