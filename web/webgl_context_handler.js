/**
 * WebGL Context Loss Handler for art.kubus
 * 
 * Firefox is prone to WebGL context loss under memory pressure, which cascades
 * into CanvasKit crashes ("RuntimeError: unreachable executed"). This script:
 * 
 * 1. Adds global handlers for WebGL context lost/restored events
 * 2. Intercepts MapLibre map instances to add recovery logic
 * 3. Prevents the crash cascade by catching CanvasKit errors early
 * 4. Provides a recovery mechanism by triggering Flutter to recreate the map
 * 
 * The script works alongside MapLibre's built-in context handlers which:
 * - Call preventDefault() on webglcontextlost
 * - Re-setup the painter on webglcontextrestored
 */
(function () {
  'use strict';

  // Skip if not in a browser context
  if (typeof window === 'undefined') return;

  var isFirefox = navigator.userAgent.toLowerCase().indexOf('firefox') > -1;
  var contextLostCount = 0;
  var lastContextLoss = 0;
  var MAX_RECOVERY_ATTEMPTS = 3;
  var RECOVERY_COOLDOWN_MS = 5000;

  // Track active MapLibre maps for recovery
  var activeMaps = new WeakSet();
  var mapCanvases = new WeakMap();
  var canvasToMap = new WeakMap();
  var mapIdSeq = 0;

  /**
   * Log with prefix for debugging (only in development or with debug flag)
   */
  function debugLog(level, message, data) {
    try {
      var params = new URLSearchParams(location.search || '');
      var debugMode = params.get('debug_webgl') === '1' ||
        params.get('debug_map') === '1' ||
        params.get('debug_stack') === '1' ||
        location.hostname === 'localhost' ||
        location.hostname === '127.0.0.1';

      if (!debugMode) return;

      var prefix = '[kubus webgl]';
      if (level === 'warn') {
        console.warn(prefix, message, data || '');
      } else if (level === 'error') {
        console.error(prefix, message, data || '');
      } else {
        console.info(prefix, message, data || '');
      }
    } catch (_) { }
  }

  function currentRoute() {
    try {
      return location.pathname + location.search + location.hash;
    } catch (_) {
      return '';
    }
  }

  function snapshotCanvases() {
    try {
      var all = document.querySelectorAll('canvas');
      var mapCanvasesNow = document.querySelectorAll('.maplibregl-canvas');
      return {
        total: all.length,
        maplibre: mapCanvasesNow.length,
        other: Math.max(0, all.length - mapCanvasesNow.length)
      };
    } catch (_) {
      return { total: 0, maplibre: 0, other: 0 };
    }
  }

  function logCanvasSnapshot(label, extra) {
    var payload = {
      ts: new Date().toISOString(),
      route: currentRoute(),
      canvases: snapshotCanvases()
    };
    if (extra) {
      try {
        for (var k in extra) payload[k] = extra[k];
      } catch (_) { }
    }
    debugLog('info', label, payload);
  }

  function mapStateForLog(map) {
    try {
      if (!map) return null;
      var center = map.getCenter && map.getCenter();
      return {
        zoom: map.getZoom ? map.getZoom() : null,
        bearing: map.getBearing ? map.getBearing() : null,
        pitch: map.getPitch ? map.getPitch() : null,
        center: center ? { lng: center.lng, lat: center.lat } : null
      };
    } catch (_) {
      return null;
    }
  }

  /**
   * Handle WebGL context lost event
   */
  function handleContextLost(event) {
    var now = Date.now();
    var canvas = event.target;

    // Always prevent default to allow potential recovery
    event.preventDefault();

    debugLog('warn', 'WebGL context lost', {
      canvas: canvas,
      firefoxDetected: isFirefox,
      lossCount: contextLostCount + 1,
      ts: new Date(now).toISOString(),
      route: currentRoute(),
      mapState: mapStateForLog(canvasToMap.get(canvas))
    });

    // Track loss frequency for crash detection
    if (now - lastContextLoss < RECOVERY_COOLDOWN_MS) {
      contextLostCount++;
    } else {
      contextLostCount = 1;
    }
    lastContextLoss = now;

    // If we're losing context too frequently, something is seriously wrong
    if (contextLostCount > MAX_RECOVERY_ATTEMPTS) {
      debugLog('error', 'Excessive WebGL context losses - possible memory issue', {
        lossCount: contextLostCount
      });

      // Dispatch custom event that Flutter can listen for via JS interop
      try {
        window.dispatchEvent(new CustomEvent('kubus:webgl-critical', {
          detail: {
            type: 'excessive_context_loss',
            count: contextLostCount,
            timestamp: now
          }
        }));
      } catch (_) { }
    }

    // Mark canvas as recovering
    if (canvas) {
      canvas.dataset.webglRecovering = 'true';
    }
  }

  /**
   * Handle WebGL context restored event
   */
  function handleContextRestored(event) {
    var canvas = event.target;

    debugLog('info', 'WebGL context restored', {
      canvas: canvas,
      ts: new Date().toISOString(),
      route: currentRoute(),
      mapState: mapStateForLog(canvasToMap.get(canvas))
    });

    // Clear recovering flag
    if (canvas) {
      delete canvas.dataset.webglRecovering;
    }

    // Reset loss counter on successful recovery
    contextLostCount = Math.max(0, contextLostCount - 1);

    // Dispatch recovery event
    try {
      window.dispatchEvent(new CustomEvent('kubus:webgl-restored', {
        detail: {
          canvas: canvas,
          timestamp: Date.now()
        }
      }));
    } catch (_) { }

    // Try to trigger MapLibre resize/repaint if the map is available
    tryMapRecovery(canvas);
  }

  /**
   * Attempt to recover the MapLibre map after context restoration
   */
  function tryMapRecovery(canvas) {
    if (!canvas || !window.maplibregl) return;

    // Find the map container (MapLibre adds .maplibregl-map class to container)
    var container = canvas.closest('.maplibregl-map');
    if (!container) return;

    debugLog('info', 'Attempting MapLibre map recovery');

    // Trigger a resize which forces MapLibre to recalculate and repaint
    // This is done after a small delay to let the context fully initialize
    setTimeout(function () {
      try {
        // Dispatch resize event to trigger any resize observers
        window.dispatchEvent(new Event('resize'));

        // Also dispatch our custom event for Flutter handling
        window.dispatchEvent(new CustomEvent('kubus:map-recovery-requested', {
          detail: { container: container }
        }));
      } catch (e) {
        debugLog('error', 'Map recovery failed', e);
      }
    }, 100);
  }

  /**
   * Add context handlers to a canvas element
   */
  function addCanvasHandlers(canvas, source) {
    if (!canvas || canvas.dataset.kubusWebglHandled) return;

    canvas.addEventListener('webglcontextlost', handleContextLost, false);
    canvas.addEventListener('webglcontextrestored', handleContextRestored, false);
    canvas.dataset.kubusWebglHandled = 'true';
    if (source) {
      canvas.dataset.kubusWebglSource = source;
    }

    debugLog('info', 'Added WebGL handlers to canvas', {
      canvas: canvas,
      source: source || 'unknown',
      ts: new Date().toISOString(),
      route: currentRoute()
    });
  }

  /**
   * Watch for new MapLibre canvas elements via MutationObserver
   */
  function setupCanvasWatcher() {
    // Handle any existing MapLibre canvases
    document.querySelectorAll('canvas').forEach(function (canvas) {
      var isMapLibre = canvas.classList && canvas.classList.contains('maplibregl-canvas');
      addCanvasHandlers(canvas, isMapLibre ? 'maplibre' : 'generic');
    });

    logCanvasSnapshot('Canvas watcher initial scan');

    // Watch for new canvases being added (e.g., when map is recreated)
    var observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (mutation) {
        mutation.addedNodes.forEach(function (node) {
          if (node.nodeType !== Node.ELEMENT_NODE) return;

          // Direct MapLibre canvas
          if (node.classList && node.classList.contains('maplibregl-canvas')) {
            addCanvasHandlers(node, 'maplibre');
          }

          // Canvas within added subtree
          if (node.querySelectorAll) {
            node.querySelectorAll('canvas').forEach(function (canvas) {
              var isMapLibre = canvas.classList && canvas.classList.contains('maplibregl-canvas');
              addCanvasHandlers(canvas, isMapLibre ? 'maplibre' : 'generic');
            });
          }
        });

        mutation.removedNodes.forEach(function (node) {
          if (node.nodeType !== Node.ELEMENT_NODE) return;
          var removedCanvases = [];
          if (node.tagName && node.tagName.toLowerCase() === 'canvas') {
            removedCanvases.push(node);
          }
          if (node.querySelectorAll) {
            node.querySelectorAll('canvas').forEach(function (canvas) {
              removedCanvases.push(canvas);
            });
          }
          if (removedCanvases.length > 0) {
            setTimeout(function () {
              logCanvasSnapshot('Canvas removed', { removedCount: removedCanvases.length });
            }, 0);
          }
        });
      });
    });

    observer.observe(document.documentElement, {
      childList: true,
      subtree: true
    });

    debugLog('info', 'Canvas watcher initialized');
  }

  function installMapLibreHooks() {
    if (!window.maplibregl || !window.maplibregl.Map) return false;
    if (window.maplibregl.__kubusWebglHooks) return true;

    var OriginalMap = window.maplibregl.Map;

    function WrappedMap(options) {
      var before = snapshotCanvases();
      var map = new OriginalMap(options);
      try {
        map.__kubusMapId = ++mapIdSeq;
        activeMaps.add(map);
        if (map.getCanvas) {
          var canvas = map.getCanvas();
          if (canvas) {
            mapCanvases.set(map, canvas);
            canvasToMap.set(canvas, map);
            addCanvasHandlers(canvas, 'maplibre');
          }
        }
      } catch (_) { }

      // Map controls (zoom, compass/bearing reset) are handled entirely by
      // Flutter UI widgets. No MapLibre JS NavigationControl is added.

      debugLog('info', 'MapLibre map created', {
        mapId: map.__kubusMapId,
        route: currentRoute(),
        ts: new Date().toISOString(),
        canvasesBefore: before,
        canvasesAfter: snapshotCanvases(),
        mapState: mapStateForLog(map)
      });

      return map;
    }

    WrappedMap.prototype = OriginalMap.prototype;
    try {
      Object.setPrototypeOf(WrappedMap, OriginalMap);
    } catch (_) { }

    try {
      Object.keys(OriginalMap).forEach(function (key) {
        try {
          WrappedMap[key] = OriginalMap[key];
        } catch (_) { }
      });
    } catch (_) { }

    if (OriginalMap.prototype && OriginalMap.prototype.remove) {
      var originalRemove = OriginalMap.prototype.remove;
      OriginalMap.prototype.remove = function () {
        var before = snapshotCanvases();
        var canvas = null;
        try {
          canvas = this.getCanvas ? this.getCanvas() : null;
        } catch (_) { }

        debugLog('info', 'MapLibre map remove() called', {
          mapId: this.__kubusMapId,
          ts: new Date().toISOString(),
          route: currentRoute(),
          mapState: mapStateForLog(this),
          canvasesBefore: before
        });

        var result = originalRemove.apply(this, arguments);

        setTimeout(function () {
          var mapRef = canvas ? canvasToMap.get(canvas) : null;
          debugLog('info', 'MapLibre map remove() completed', {
            mapId: mapRef ? mapRef.__kubusMapId : null,
            ts: new Date().toISOString(),
            route: currentRoute(),
            canvasesAfter: snapshotCanvases(),
            canvasConnected: canvas ? !!canvas.isConnected : null
          });
        }, 0);

        return result;
      };
    }

    window.maplibregl.Map = WrappedMap;
    window.maplibregl.__kubusWebglHooks = true;
    debugLog('info', 'MapLibre hooks installed');
    return true;
  }

  /**
   * Install a global error handler to catch CanvasKit unreachable errors
   * and prevent them from crashing the entire app
   */
  function installGlobalErrorHandler() {
    var originalOnError = window.onerror;
    var params = new URLSearchParams(location.search || '');
    var debugStacks = params.get('debug_stack') === '1' ||
      params.get('debug_webgl') === '1';

    window.onerror = function (message, source, lineno, colno, error) {
      // Check for CanvasKit crash patterns
      var isCanvasKitCrash =
        (message && (
          message.indexOf('unreachable') > -1 ||
          message.indexOf('RuntimeError') > -1 ||
          message.indexOf('CanvasKit') > -1
        )) ||
        (error && error.message && (
          error.message.indexOf('unreachable') > -1 ||
          error.message.indexOf('RuntimeError') > -1
        ));

      if (isCanvasKitCrash) {
        debugLog('error', 'CanvasKit crash detected - likely WebGL context issue', {
          message: message,
          source: source,
          error: error
        });

        // Dispatch event for Flutter to handle
        try {
          window.dispatchEvent(new CustomEvent('kubus:canvaskit-crash', {
            detail: {
              message: message,
              source: source,
              timestamp: Date.now(),
              firefoxDetected: isFirefox
            }
          }));
        } catch (_) { }

        // On Firefox, if this is related to WebGL, don't let it propagate
        // This prevents the error from being reported multiple times
        if (isFirefox) {
          debugLog('warn', 'Suppressing CanvasKit error propagation on Firefox');
          return true; // Prevent default error handling
        }
      }

      if (debugStacks && error && error.stack) {
        try {
          console.error('[kubus webgl] window.onerror stack', error.stack);
        } catch (_) { }
      }

      // Call original handler for other errors
      if (originalOnError) {
        return originalOnError.call(window, message, source, lineno, colno, error);
      }
      return false;
    };

    // Also handle unhandled promise rejections
    window.addEventListener('unhandledrejection', function (event) {
      var reason = event.reason;
      if (reason && (
        (typeof reason === 'string' && reason.indexOf('unreachable') > -1) ||
        (reason.message && reason.message.indexOf('unreachable') > -1)
      )) {
        debugLog('error', 'Unhandled CanvasKit rejection', reason);

        // On Firefox, prevent the rejection from crashing everything
        if (isFirefox) {
          event.preventDefault();
          window.dispatchEvent(new CustomEvent('kubus:canvaskit-crash', {
            detail: {
              message: reason.message || reason,
              timestamp: Date.now(),
              isPromiseRejection: true
            }
          }));
        }
      }

      if (debugStacks) {
        try {
          var stack = reason && reason.stack ? reason.stack : null;
          if (stack) {
            console.error('[kubus webgl] unhandledrejection stack', stack);
          }
        } catch (_) { }
      }
    });

    debugLog('info', 'Global error handlers installed');
  }

  /**
   * Firefox-specific memory pressure handling
   */
  function setupFirefoxOptimizations() {
    if (!isFirefox) return;

    debugLog('info', 'Firefox detected - applying WebGL optimizations');

    // Reduce memory pressure by limiting concurrent image decoding
    // This can help prevent context loss during heavy rendering
    try {
      if (window.maplibregl && window.maplibregl.prewarm) {
        // Don't prewarm workers on Firefox as it can increase memory pressure
        debugLog('info', 'Skipping MapLibre worker prewarm on Firefox');
      }
    } catch (_) { }

    // Listen for visibility changes to help manage resources
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) {
        debugLog('info', 'Page hidden - Firefox may reclaim WebGL resources');
      } else {
        debugLog('info', 'Page visible - checking WebGL context health');
        // Check if any canvas is in recovering state
        document.querySelectorAll('.maplibregl-canvas[data-webgl-recovering]')
          .forEach(function (canvas) {
            debugLog('warn', 'Found canvas still recovering after visibility change');
            tryMapRecovery(canvas);
          });
      }
    });
  }

  /**
   * Initialize all handlers
   */
  function init() {
    debugLog('info', 'Initializing WebGL context handler', {
      firefox: isFirefox,
      userAgent: navigator.userAgent
    });

    installGlobalErrorHandler();
    setupFirefoxOptimizations();

    // Setup canvas watcher once DOM is ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', setupCanvasWatcher);
    } else {
      setupCanvasWatcher();
    }

    // Try to hook MapLibre immediately; retry after Flutter boot
    installMapLibreHooks();

    // Also run after Flutter loads (it may create maps later)
    window.addEventListener('flutter-first-frame', function () {
      debugLog('info', 'Flutter first frame - re-checking for MapLibre canvases');
      setTimeout(setupCanvasWatcher, 500);
      setTimeout(installMapLibreHooks, 500);
    });
  }

  // Initialize
  init();
})();
