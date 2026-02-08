import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Whether the WebGL/CanvasKit context is currently healthy.
///
/// Updated by JS interop event listeners. The [GlassCapabilitiesProvider]
/// listens to this notifier to decide whether blur effects are safe.
final ValueNotifier<bool> webGLContextHealthy = ValueNotifier<bool>(true);

/// Returns `true` when the platform signals `prefers-reduced-motion: reduce`.
bool prefersReducedMotion() {
  try {
    final mql = web.window.matchMedia('(prefers-reduced-motion: reduce)');
    return mql.matches;
  } catch (_) {
    return false;
  }
}

/// Initializes event listeners for WebGL context loss detection.
///
/// When the JS layer dispatches `kubus:webgl-critical` or
/// `kubus:canvaskit-crash`, this helper sets [webGLContextHealthy] to false
/// so that glass surfaces can switch to a tinted fallback.
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

  if (kDebugMode) {
    print('webgl_context_helper: initialized (context-loss listeners active)');
  }
}

void _onWebGLCritical(web.Event event) {
  webGLContextHealthy.value = false;
}

void _onCanvasKitCrash(web.Event event) {
  webGLContextHealthy.value = false;
}

void _onWebGLRestored(web.Event event) {
  webGLContextHealthy.value = true;
}
