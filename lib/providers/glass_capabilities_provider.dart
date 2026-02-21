import 'dart:async';

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
  static const String _autoReduceEffectsOptOutKey =
      'kubus_reduce_effects_auto_opt_out';
  static const String _reduceEffectsUserTouchedKey =
      'kubus_reduce_effects_user_touched';

  GlassMode _mode = GlassMode.blur;
  bool _reduceEffectsUser = false;
  bool _reduceEffectsUserTouched = false;
  bool _autoReduceEffectsOptOut = false;
  bool _heuristicTriggered = false;
  bool _isInitialized = false;
  Timer? _perfProbeStartTimer;

  GlassMode get mode => _mode;

  /// Canonical policy: whether blur is currently allowed.
  bool get allowBlur => _mode == GlassMode.blur;

  /// Compatibility alias. Prefer [allowBlur].
  bool get isBlurEnabled => allowBlur;

  /// The effective "reduce effects" state, whether user-set or auto-detected.
  bool get reduceEffects =>
      _reduceEffectsUser || (_heuristicTriggered && !_autoReduceEffectsOptOut);

  /// Whether the heuristic auto-detected a constrained device.
  bool get heuristicTriggered => _heuristicTriggered;

  /// Whether automatic heuristic-based reduce-effects is currently active.
  bool get autoReduceEffectsApplied =>
      _heuristicTriggered && !_reduceEffectsUser && !_autoReduceEffectsOptOut;

  /// Whether the user explicitly toggled "Reduce effects".
  bool get reduceEffectsUserOverride => _reduceEffectsUser;

  /// Whether the user explicitly changed the Reduce Effects toggle.
  bool get reduceEffectsUserTouched => _reduceEffectsUserTouched;

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
      _reduceEffectsUserTouched =
          prefs.getBool(_reduceEffectsUserTouchedKey) ?? false;
      _autoReduceEffectsOptOut =
          prefs.getBool(_autoReduceEffectsOptOutKey) ?? false;
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

    // 4. Schedule a lightweight perf probe after initial loading settles.
    if (!_reduceEffectsUser &&
        !_heuristicTriggered &&
        !_autoReduceEffectsOptOut &&
        _shouldRunRuntimePerfProbe()) {
      _schedulePerfProbe();
    }
  }

  bool _shouldRunRuntimePerfProbe() {
    // Desktop map startup can cause temporary frame spikes (shader/style warmup)
    // that are not representative of sustained capability. Running the
    // automatic jank probe on desktop can therefore incorrectly disable blur
    // globally for the session. Keep auto-probing on web/mobile, where we
    // primarily need this safeguard.
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
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
    final nextUserSetting = value;
    final nextAutoOptOut = !value && _heuristicTriggered;

    if (_reduceEffectsUser == nextUserSetting &&
        _autoReduceEffectsOptOut == nextAutoOptOut) {
      return;
    }

    _reduceEffectsUser = nextUserSetting;
    _reduceEffectsUserTouched = true;
    _autoReduceEffectsOptOut = nextAutoOptOut;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reduceEffectsKey, _reduceEffectsUser);
      await prefs.setBool(
          _reduceEffectsUserTouchedKey, _reduceEffectsUserTouched);
      await prefs.setBool(
          _autoReduceEffectsOptOutKey, _autoReduceEffectsOptOut);
    } catch (_) {}
    _recomputeMode();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Mode computation
  // ---------------------------------------------------------------------------

  void _recomputeMode() {
    final healthy = webGLContextHealthy.value;
    final heuristicActive = _heuristicTriggered && !_autoReduceEffectsOptOut;

    // If the user explicitly turned Reduce Effects OFF, honor that preference
    // on desktop-class environments and keep blur enabled. This avoids cases
    // where safety heuristics/context health flags keep blur disabled even
    // after the user opted into full effects.
    final explicitOffForcesBlur = _reduceEffectsUserTouched &&
        !_reduceEffectsUser &&
        _isDesktopClassEnvironment();

    if (_reduceEffectsUser) {
      _mode = GlassMode.tintedFallback;
      return;
    }

    if (explicitOffForcesBlur) {
      _mode = GlassMode.blur;
      return;
    }

    if (!healthy || heuristicActive) {
      _mode = GlassMode.tintedFallback;
    } else {
      _mode = GlassMode.blur;
    }
  }

  bool _isDesktopClassEnvironment() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return false;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Capability heuristic (browser-agnostic)
  // ---------------------------------------------------------------------------

  bool _evaluateHeuristic() {
    try {
      final view = PlatformDispatcher.instance.implicitView;
      if (view == null) return false;

      final dpr = view.devicePixelRatio;
      final logicalSize = view.physicalSize / dpr;
      final logicalArea = logicalSize.width * logicalSize.height;

      // Very small logical area with high DPR: likely a constrained device.
      // This applies to both web and native mobile.
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

  static const Duration _perfProbeWarmupDelay = Duration(seconds: 8);
  int _probeFrameCount = 0;
  int _jankFrameCount = 0;
  static const int _probeFrameLimit = 36;
  static const Duration _jankThreshold = Duration(milliseconds: 48);

  void _schedulePerfProbe() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _perfProbeStartTimer?.cancel();
      _perfProbeStartTimer = Timer(_perfProbeWarmupDelay, _runPerfProbe);
    });
  }

  void _runPerfProbe() {
    if (_reduceEffectsUser || _autoReduceEffectsOptOut || _heuristicTriggered) {
      return;
    }
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
        final severeJank = _jankFrameCount >= (_probeFrameLimit * 2 ~/ 3);
        if (severeJank && !_autoReduceEffectsOptOut && !_reduceEffectsUser) {
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

  /// Read the current blur policy without rebuilding.
  ///
  /// Falls back to [GlassMode.blur] if the provider is not in the tree.
  static bool allowBlurEnabled(BuildContext context) {
    try {
      return context.read<GlassCapabilitiesProvider>().allowBlur;
    } catch (_) {
      return true;
    }
  }

  /// Compatibility alias. Prefer [allowBlurEnabled].
  static bool blurEnabled(BuildContext context) => allowBlurEnabled(context);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _perfProbeStartTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    webGLContextHealthy.removeListener(_onWebGLHealthChanged);
    super.dispose();
  }
}
