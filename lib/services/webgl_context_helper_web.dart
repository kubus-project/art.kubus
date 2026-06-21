import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Whether the WebGL/CanvasKit context is currently healthy.
///
/// Updated by JS interop event listeners. The [GlassCapabilitiesProvider]
/// listens to this notifier to decide whether blur effects are safe, and
/// [ArtMapView] uses it to drive its (non-covering) recovery indicator.
final ValueNotifier<bool> webGLContextHealthy = ValueNotifier<bool>(true);

// Throttle toggles to avoid rapid duplicate flips from multiple canvas events.
int _lastWebGLToggleMs = 0;
const int _webGLToggleDebounceMs = 200;

/// After a critical/crash health drop we optimistically restore health if no
/// further critical event arrives within this window.
///
/// A single transient `webglcontextlost` is NOT treated as unhealthy at all
/// (MapLibre restores its own context and the resize-recovery path handles the
/// repaint), so blur/recovery UI never flickers on routine browser blips. Only
/// *excessive* loss (`kubus:webgl-critical`) or a CanvasKit crash flips health
/// — and even then the app keeps running (the error was caught), so we must not
/// leave the map/glass chrome wedged in the degraded fallback forever. This
/// self-heal guarantees the UI returns to normal instead of getting stuck.
Timer? _autoRestoreTimer;
const Duration _autoRestoreDelay = Duration(seconds: 4);

void _scheduleHealthAutoRestore() {
  _autoRestoreTimer?.cancel();
  _autoRestoreTimer = Timer(_autoRestoreDelay, () {
    _autoRestoreTimer = null;
    if (!webGLContextHealthy.value) {
      webGLContextHealthy.value = true;
      _lastWebGLToggleMs = DateTime.now().millisecondsSinceEpoch;
    }
  });
}

void _markWebGLUnhealthy() {
  final now = DateTime.now().millisecondsSinceEpoch;
  if (!webGLContextHealthy.value &&
      now - _lastWebGLToggleMs < _webGLToggleDebounceMs) {
    // Already unhealthy; just extend the self-heal window for the new event.
    _scheduleHealthAutoRestore();
    return;
  }
  webGLContextHealthy.value = false;
  _lastWebGLToggleMs = now;
  _scheduleHealthAutoRestore();
}

bool isWebGLDebugEnabled() {
  try {
    final params = web.URLSearchParams(web.window.location.search.toJS);
    return params.get('debug_webgl') == '1' || params.get('debug_map') == '1';
  } catch (_) {
    return false;
  }
}

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
/// When the JS layer dispatches `kubus:webgl-lost`, `kubus:webgl-critical`, or
/// `kubus:canvaskit-crash`, this helper sets [webGLContextHealthy] to false
/// so that glass surfaces can switch to a tinted fallback.
void initWebGLContextHelper() {
  // Listen for the custom events dispatched by webgl_context_handler.js
  web.window.addEventListener(
    'kubus:webgl-lost',
    _onWebGLLost.toJS,
  );
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

  if (kDebugMode && isWebGLDebugEnabled()) {
    // Keep logs opt-in to avoid noisy debug output.
    // (The primary detailed diagnostics live in webgl_context_handler.js.)
    // ignore: avoid_print
    print(
      'webgl_context_helper: initialized (context-loss listeners active)',
    );
  }
}

void _onWebGLCritical(web.Event event) {
  // Excessive, repeated context loss: degrade to the safe tint fallback.
  _markWebGLUnhealthy();
}

void _onWebGLLost(web.Event event) {
  // A single/transient WebGL context loss is expected on the web (memory
  // pressure, tab backgrounding, GPU resets) and MapLibre recovers it on its
  // own via `webglcontextrestored`. Treating it as "unhealthy" here was what
  // made a routine browser blip flip blur to the tint fallback AND trigger the
  // map recovery overlay. Intentionally a no-op for health: let MapLibre + the
  // resize-recovery path handle it without degrading app chrome.
}

void _onCanvasKitCrash(web.Event event) {
  _markWebGLUnhealthy();
}

void _onWebGLRestored(web.Event event) {
  final now = DateTime.now().millisecondsSinceEpoch;
  _autoRestoreTimer?.cancel();
  _autoRestoreTimer = null;
  if (webGLContextHealthy.value &&
      now - _lastWebGLToggleMs < _webGLToggleDebounceMs) {
    return;
  }
  webGLContextHealthy.value = true;
  _lastWebGLToggleMs = now;
}
