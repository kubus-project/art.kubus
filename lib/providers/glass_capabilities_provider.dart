
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/webgl_context_helper.dart';

/// Whether glass surfaces use real blur or a solid tinted fallback.
enum GlassMode { blur, tintedFallback }

/// Browser-agnostic provider that decides whether glass surfaces should use
/// real [BackdropFilter] blur or degrade to a tinted-surface fallback.
///
/// Decision inputs (no user-agent sniffing):
/// - User "Reduce effects" override (persisted to SharedPreferences).
/// - WebGL context health (web-only; set by [initWebGLContextHelper]).
/// - Capability heuristic: device-pixel ratio, logical screen area, and the
///   platform's `prefers-reduced-motion` media query.
/// - Optional lightweight runtime perf probe that measures frame timings.
class GlassCapabilitiesProvider with ChangeNotifier {
  static const String _reduceEffectsKey = 'kubus_reduce_effects';

  GlassMode _mode = GlassMode.blur;
  bool _reduceEffectsUser = false;
  bool _heuristicTriggered = false;
  bool _isInitialized = false;

  GlassMode get mode => _mode;

  /// Whether blur is currently enabled.
  bool get isBlurEnabled => _mode == GlassMode.blur;

  /// The effective "reduce effects" state, whether user-set or auto-detected.
  bool get reduceEffects => _reduceEffectsUser || _heuristicTriggered;

  /// Whether the heuristic auto-detected a constrained device.
  bool get heuristicTriggered => _heuristicTriggered;

  /// Whether the user explicitly toggled "Reduce effects".
  bool get reduceEffectsUserOverride => _reduceEffectsUser;

  bool get isInitialized => _isInitialized;

  GlassCapabilitiesProvider() {
    _initialize();
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    // 1. Load persisted user preference.
    try {
      final prefs = await SharedPreferences.getInstance();
      _reduceEffectsUser = prefs.getBool(_reduceEffectsKey) ?? false;
    } catch (_) {
      // Default: effects enabled.
    }

    // 2. Listen to WebGL context health changes (web only; no-op otherwise).
    webGLContextHealthy.addListener(_onWebGLHealthChanged);

    // 3. Run platform capability heuristic.
    _heuristicTriggered = _evaluateHeuristic();

    _recomputeMode();
    _isInitialized = true;
    notifyListeners();

    // 4. Schedule a lightweight perf probe after first frame.
    if (kIsWeb && !_reduceEffectsUser && !_heuristicTriggered) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _runPerfProbe());
    }
  }

  // ---------------------------------------------------------------------------
  // WebGL context health
  // ---------------------------------------------------------------------------

  void _onWebGLHealthChanged() {
    _recomputeMode();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // User setting
  // ---------------------------------------------------------------------------

  /// Toggle the user "Reduce effects" preference.
  Future<void> setReduceEffects(bool value) async {
    if (_reduceEffectsUser == value) return;
    _reduceEffectsUser = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reduceEffectsKey, value);
    } catch (_) {}
    _recomputeMode();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Mode computation
  // ---------------------------------------------------------------------------

  void _recomputeMode() {
    final healthy = webGLContextHealthy.value;
    if (_reduceEffectsUser || !healthy || _heuristicTriggered) {
      _mode = GlassMode.tintedFallback;
    } else {
      _mode = GlassMode.blur;
    }
  }

  // ---------------------------------------------------------------------------
  // Capability heuristic (browser-agnostic)
  // ---------------------------------------------------------------------------

  bool _evaluateHeuristic() {
    // On native platforms blur is handled efficiently by the GPU compositor.
    if (!kIsWeb) return false;

    try {
      final view = PlatformDispatcher.instance.implicitView;
      if (view == null) return false;

      final dpr = view.devicePixelRatio;
      final logicalSize = view.physicalSize / dpr;
      final logicalArea = logicalSize.width * logicalSize.height;

      // Very small logical area with high DPR: likely a constrained mobile web.
      if (dpr >= 3.5 && logicalArea < 200000) return true;

      // Check platform "prefers-reduced-motion".
      if (prefersReducedMotion()) return true;
    } catch (_) {
      // Best-effort; don't degrade on error.
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Perf probe: measure frame timings and degrade if severe jank detected
  // ---------------------------------------------------------------------------

  int _probeFrameCount = 0;
  int _jankFrameCount = 0;
  static const int _probeFrameLimit = 10;
  static const Duration _jankThreshold = Duration(milliseconds: 32);

  void _runPerfProbe() {
    _probeFrameCount = 0;
    _jankFrameCount = 0;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
  }

  void _timingsCallback(List<FrameTiming> timings) {
    for (final timing in timings) {
      _probeFrameCount++;
      if (timing.totalSpan > _jankThreshold) {
        _jankFrameCount++;
      }
      if (_probeFrameCount >= _probeFrameLimit) {
        SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
        if (_jankFrameCount > _probeFrameLimit ~/ 2) {
          _heuristicTriggered = true;
          _recomputeMode();
          notifyListeners();
        }
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Static helper for places that cannot use context.watch
  // ---------------------------------------------------------------------------

  /// Read the current blur state without rebuilding.
  ///
  /// Falls back to [GlassMode.blur] if the provider is not in the tree.
  static bool blurEnabled(BuildContext context) {
    try {
      return context.read<GlassCapabilitiesProvider>().isBlurEnabled;
    } catch (_) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    webGLContextHealthy.removeListener(_onWebGLHealthChanged);
    super.dispose();
  }
}
