import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../config/config.dart';
import '../services/map_style_service.dart';
import 'kubus_snackbar.dart';

/// Shared MapLibre layer used by both mobile and desktop map screens.
///
/// UI overlays (filters, marker cards, discovery progress, etc.) remain
/// Flutter widgets layered above this view.
///
/// The native MapLibre compass is enabled by default on mobile platforms
/// (Android/iOS) for bearing reset functionality. On web, we use the
/// MapLibre GL JS NavigationControl added via JavaScript instead.
class ArtMapView extends StatefulWidget {
  const ArtMapView({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.isDarkMode,
    required this.styleAsset,
    required this.onMapCreated,
    this.attributionButtonPosition,
    this.attributionButtonMargins,
    this.onStyleLoaded,
    this.onCameraMove,
    this.onCameraIdle,
    this.onMapClick,
    this.onMapLongClick,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.compassEnabled,
  });

  final ll.LatLng initialCenter;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final bool isDarkMode;
  final String styleAsset;

  final void Function(ml.MapLibreMapController controller) onMapCreated;
  final ml.AttributionButtonPosition? attributionButtonPosition;
  final math.Point<double>? attributionButtonMargins;
  final VoidCallback? onStyleLoaded;
  final void Function(ml.CameraPosition position)? onCameraMove;
  final VoidCallback? onCameraIdle;

  final void Function(math.Point<double> point, ll.LatLng latLng)? onMapClick;
  final void Function(math.Point<double> point, ll.LatLng latLng)?
      onMapLongClick;

  final bool rotateGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool zoomGesturesEnabled;
  final bool tiltGesturesEnabled;

  /// Whether to show the native MapLibre compass. If null (default), the
  /// compass is enabled on mobile platforms (Android/iOS) and disabled on
  /// web (where we use the JS NavigationControl instead).
  final bool? compassEnabled;

  /// Test-only helper used by widget/service tests to validate the style-ready
  /// gating logic.
  ///
  /// This is intentionally a pure function with no widget state access.
  @visibleForTesting
  static bool isStyleReadyForTest({
    required bool styleLoaded,
    required bool styleFailed,
    required bool pendingStyleApply,
  }) {
    return styleLoaded && !styleFailed && !pendingStyleApply;
  }

  /// Web-only policy for MapLibre's `preserveDrawingBuffer`.
  ///
  /// Mobile browsers are more prone to compositing artifacts ("burn-in"/trail
  /// frames where overlay UI appears baked into the map canvas) when this is
  /// enabled, so we force it off on Android/iOS web even if the feature flag
  /// is enabled.
  @visibleForTesting
  static bool shouldUseWebPreserveDrawingBufferForTest({
    required bool isWeb,
    required TargetPlatform platform,
    required bool featureEnabled,
  }) {
    if (!isWeb || !featureEnabled) return false;
    final isMobileWeb =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return !isMobileWeb;
  }

  @override
  State<ArtMapView> createState() => _ArtMapViewState();
}

class _ArtMapViewState extends State<ArtMapView> {
  static int _debugLiveInstances = 0;
  static int _debugMapCreateSeq = 0;

  Future<String>? _resolvedStyleFuture;
  String? _resolvedStyleString;
  ml.MapLibreMapController? _controller;
  Size? _lastWebLayoutSize;
  Timer? _webResizeDebounce;

  /// Set to `true` once [deactivate] fires; prevents late callbacks from
  /// touching the [_controller] after the widget is going away.
  bool _disposed = false;

  // Web: repeated layout changes (side panels, route transitions) can trigger a
  // storm of resize calls. This is costly across browsers; on some engines it
  // can cause noticeable startup jank. We adapt the debounce based on how
  // quickly layout sizes are changing.
  int _lastWebLayoutChangeMs = 0;
  int _webResizeDebounceMs = 16;

  // Web: force-resize is heavier than resize; throttle to avoid double-calls
  // across lifecycle hooks (map created + style loaded).
  int _lastWebForceResizeMs = 0;

  int _styleRequestId = 0;
  bool _pendingStyleApply = false;
  bool _mapCreated = false;
  int? _debugMapId;

  Timer? _styleLoadTimer;
  bool _styleLoaded = false;
  bool _didFallback = false;
  bool _styleFailed = false;
  String? _styleFailureReason;
  Stopwatch? _styleStopwatch;

  @override
  void initState() {
    super.initState();

    assert(() {
      _debugLiveInstances += 1;
      AppConfig.debugPrint(
        'ArtMapView: instance mounted (live=$_debugLiveInstances)',
      );
      return true;
    }());
    _refreshStyleFuture();
  }

  @override
  void didUpdateWidget(covariant ArtMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.styleAsset != widget.styleAsset ||
        oldWidget.isDarkMode != widget.isDarkMode) {
      _refreshStyleFuture();
      _pendingStyleApply = _controller != null && !_styleLoaded;

      if (_controller != null && _styleLoaded) {
        _resetStyleLoadState();
        _startStyleHealthCheck();
        unawaited(_applyStyleToController());
      }
    }
  }

  @override
  void deactivate() {
    // Mark inactive early (top-down) so callbacks that fire during child
    // disposal (MapLibre plugin removing the platform view) see this flag
    // and bail out instead of touching the already-disposed controller.
    _disposed = true;
    _styleLoadTimer?.cancel();
    _styleLoadTimer = null;
    _webResizeDebounce?.cancel();
    _webResizeDebounce = null;
    _controller = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    // A state can be deactivated and reinserted (e.g. GlobalKey reparenting)
    // without being disposed. Re-enable callbacks in that case.
    _disposed = false;
  }

  @override
  void dispose() {
    // Timers were already cancelled in deactivate; null-guard for safety.
    _styleLoadTimer?.cancel();
    _styleLoadTimer = null;
    _webResizeDebounce?.cancel();
    _webResizeDebounce = null;
    // Do NOT call controller.dispose() here. The MapLibre plugin's own
    // State.dispose() disposes the controller when the platform view is
    // removed. Calling dispose again causes "used after being disposed".
    _controller = null;
    assert(() {
      _debugLiveInstances = math.max(0, _debugLiveInstances - 1);
      AppConfig.debugPrint(
        'ArtMapView: instance disposed (live=$_debugLiveInstances)',
      );
      return true;
    }());
    super.dispose();
  }

  void _handleWebLayoutChanged(Size size) {
    if (!kIsWeb || _disposed) return;
    if (size.width.isNaN ||
        size.height.isNaN ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }
    if (size.width <= 1 || size.height <= 1) return;
    if (_lastWebLayoutSize == size) return;
    _lastWebLayoutSize = size;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final deltaMs =
        _lastWebLayoutChangeMs == 0 ? 999999 : (nowMs - _lastWebLayoutChangeMs);
    _lastWebLayoutChangeMs = nowMs;

    // If layout is churning rapidly, back off from 60fps resizing.
    // Keep it discrete so we don't oscillate.
    _webResizeDebounceMs = deltaMs < 120 ? 66 : 16;

    // Debounce: this can be called repeatedly during animated layout changes
    // (e.g., opening the desktop sidebar). MapLibre GL JS requires an explicit
    // resize to correctly re-measure its canvas within the container.
    _webResizeDebounce?.cancel();
    final debounce = Duration(milliseconds: _webResizeDebounceMs);
    _webResizeDebounce = Timer(debounce, () {
      if (!mounted || _disposed) return;
      final controller = _controller;
      if (controller == null) return;
      try {
        controller.resizeWebMap();
      } catch (e, st) {
        AppConfig.debugPrint('ArtMapView: resizeWebMap failed: $e');
        if (kDebugMode) {
          AppConfig.debugPrint('ArtMapView: resizeWebMap stack: $st');
        }
      }
    });
  }

  void _forceResizeWebMapThrottled(ml.MapLibreMapController controller) {
    if (!kIsWeb) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastWebForceResizeMs < 250) return;
    _lastWebForceResizeMs = nowMs;

    try {
      controller.forceResizeWebMap();
    } catch (e, st) {
      AppConfig.debugPrint('ArtMapView: forceResizeWebMap failed: $e');
      if (kDebugMode) {
        AppConfig.debugPrint('ArtMapView: forceResizeWebMap stack: $st');
      }
    }
  }

  void _refreshStyleFuture() {
    final future = MapStyleService.resolveStyleString(widget.styleAsset);
    _resolvedStyleFuture = future;
    future.then((resolved) {
      if (!mounted || _disposed) return;
      if (_resolvedStyleFuture != future) return;
      if (_resolvedStyleString == resolved) return;
      setState(() {
        _resolvedStyleString = resolved;
      });
    }).catchError((e, st) {
      AppConfig.debugPrint('ArtMapView: resolveStyleString failed: $e');
      if (kDebugMode) {
        AppConfig.debugPrint('ArtMapView: resolveStyleString stack: $st');
      }
    });
  }

  void _resetStyleLoadState() {
    _styleLoadTimer?.cancel();
    _styleLoaded = false;
    _didFallback = false;
    _styleFailed = false;
    _styleFailureReason = null;
    _styleRequestId++;
    _styleStopwatch = Stopwatch()..start();
  }

  void _markStyleFailure(String reason) {
    if (!mounted || _disposed) return;
    if (_styleLoaded) return;
    setState(() {
      _styleFailed = true;
      _styleFailureReason = reason;
    });
  }

  Future<void> _attemptFallbackStyle() async {
    if (_didFallback || _disposed) return;

    final controller = _controller;
    if (controller == null) return;

    _didFallback = true;

    final fallbackRef = MapStyleService.devFallbackEnabled
        ? MapStyleService.devFallbackStyleUrl
        : MapStyleService.fallbackStyleRef(isDarkMode: widget.isDarkMode);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showKubusSnackBar(
      SnackBar(
        content: Text(
          MapStyleService.devFallbackEnabled
              ? 'Map style failed to load; using a fallback style.'
              : 'Map style failed to load; using a bundled fallback style.',
        ),
        duration: const Duration(seconds: 4),
      ),
      tone: KubusSnackBarTone.warning,
    );

    try {
      final resolved = await MapStyleService.resolveStyleString(fallbackRef);
      if (!mounted || _disposed) return;
      if (_controller == null) return;
      await controller.setStyle(resolved);
    } catch (e, st) {
      AppConfig.debugPrint('ArtMapView: failed to apply fallback style: $e');
      if (kDebugMode) {
        AppConfig.debugPrint('ArtMapView: fallback style stack: $st');
      }
    }
  }

  Future<void> _applyStyleToController() async {
    final controller = _controller;
    final future = _resolvedStyleFuture;
    if (controller == null || future == null || _disposed) return;

    final requestId = _styleRequestId;
    final styleString = await future;
    if (!mounted || _disposed) return;
    if (requestId != _styleRequestId) return;
    if (_controller == null) return;

    try {
      await controller.setStyle(styleString);
    } catch (e, st) {
      AppConfig.debugPrint(
          'ArtMapView: failed to apply style via setStyle: $e');
      if (kDebugMode) {
        AppConfig.debugPrint('ArtMapView: setStyle stack: $st');
      }
      _markStyleFailure('Failed to apply map style.');
      unawaited(_attemptFallbackStyle());
    }
  }

  void _startStyleHealthCheck() {
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(MapStyleService.styleLoadTimeout, () {
      if (!mounted || _disposed) return;
      if (_styleLoaded) return;
      if (_didFallback) return;

      final controller = _controller;
      if (controller == null) return;

      _markStyleFailure('Map style failed to load.');
      AppConfig.debugPrint(
          'ArtMapView: style load timeout; switching to fallback');
      unawaited(_attemptFallbackStyle());
    });
  }

  @override
  Widget build(BuildContext context) {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    final isWidgetTest = bindingName.contains('TestWidgetsFlutterBinding') ||
        bindingName.contains('AutomatedTestWidgetsFlutterBinding');
    if (isWidgetTest) {
      return const SizedBox.expand(
        child: ColoredBox(
          key: Key('art_map_view_test_placeholder'),
          color: Colors.transparent,
        ),
      );
    }

    final resolved = _resolvedStyleString;

    // MapLibre is a platform view; in a loose Stack it can end up with a 0-size
    // layout. SizedBox.expand guarantees fullscreen rendering for our map screens.
    if (resolved == null) {
      return const SizedBox.expand(
          child: ColoredBox(color: Colors.transparent));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _handleWebLayoutChanged(
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        return SizedBox.expand(
          child: Stack(
            children: [
              ml.MapLibreMap(
                key: const ValueKey('art_map_view_maplibre'),
                styleString: resolved,
                // On iOS, leaving this null causes the platform view to eagerly
                // claim all gestures, making Flutter overlays (search, buttons,
                // etc.) appear but not receive taps. Use an explicit empty set
                // so the map only receives gestures not claimed by overlays.
                gestureRecognizers: kIsWeb
                    ? null
                    : const <Factory<OneSequenceGestureRecognizer>>{},
                initialCameraPosition: ml.CameraPosition(
                  target: ml.LatLng(
                    widget.initialCenter.latitude,
                    widget.initialCenter.longitude,
                  ),
                  zoom: widget.initialZoom,
                ),
                // Preserve the WebGL drawing buffer to improve context stability
                // in some environments, but can significantly hurt performance.
                // Keep it off by default and enable only when needed.
                webPreserveDrawingBuffer:
                    ArtMapView.shouldUseWebPreserveDrawingBufferForTest(
                  isWeb: kIsWeb,
                  platform: defaultTargetPlatform,
                  featureEnabled:
                      AppConfig.isFeatureEnabled('mapWebPreserveDrawingBuffer'),
                ),
                // We don't use the plugin's annotation managers (we manage sources/layers
                // directly). Disabling them avoids plugin-managed sources being added
                // during style swaps, which can cause platform errors.
                annotationOrder: const <ml.AnnotationType>[],
                minMaxZoomPreference: ml.MinMaxZoomPreference(
                  widget.minZoom,
                  widget.maxZoom,
                ),
                rotateGesturesEnabled: widget.rotateGesturesEnabled,
                scrollGesturesEnabled: widget.scrollGesturesEnabled,
                zoomGesturesEnabled: widget.zoomGesturesEnabled,
                tiltGesturesEnabled: widget.tiltGesturesEnabled,
                // Use explicit value if provided, otherwise enable compass on
                // mobile (for native CompassView) and disable on web (JS
                // NavigationControl handles it via webgl_context_handler.js).
                compassEnabled: widget.compassEnabled ?? !kIsWeb,
                attributionButtonPosition: widget.attributionButtonPosition,
                attributionButtonMargins: widget.attributionButtonMargins,
                myLocationEnabled: false,
                onMapCreated: (controller) {
                  if (_disposed) {
                    // Widget is going away; don't attach this controller.
                    return;
                  }
                  assert(() {
                    if (_mapCreated) {
                      AppConfig.debugPrint(
                        'ArtMapView: duplicate onMapCreated for same State; replacing controller reference',
                      );
                    }
                    _mapCreated = true;
                    _debugMapId = ++_debugMapCreateSeq;
                    return true;
                  }());
                  _controller = controller;
                  _resetStyleLoadState();
                  _startStyleHealthCheck();
                  AppConfig.debugPrint(
                    'ArtMapView: map created (id=$_debugMapId, style="$resolved", platform=${defaultTargetPlatform.name}, web=$kIsWeb)',
                  );
                  widget.onMapCreated(controller);
                  if (kIsWeb) {
                    // MapLibre GL JS sometimes initializes while the element is still
                    // measuring (0x0) during the first frame, especially when the
                    // map is mounted behind onboarding / tab transitions. A forced
                    // resize after layout makes the map reliably paint on web.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || _disposed) return;
                      if (_controller != controller) return;
                      _forceResizeWebMapThrottled(controller);
                    });
                  }
                },
                onStyleLoadedCallback: () {
                  if (_disposed) return;
                  _styleStopwatch?.stop();
                  _styleLoadTimer?.cancel();
                  final elapsedMs = _styleStopwatch?.elapsedMilliseconds;
                  if (elapsedMs != null) {
                    AppConfig.debugPrint(
                        'ArtMapView: style loaded in ${elapsedMs}ms');
                  } else {
                    AppConfig.debugPrint('ArtMapView: style loaded');
                  }
                  if (kIsWeb) {
                    final controller = _controller;
                    if (controller != null && mounted && !_disposed) {
                      _forceResizeWebMapThrottled(controller);
                    }
                  }
                  if (_pendingStyleApply) {
                    _pendingStyleApply = false;
                    _resetStyleLoadState();
                    _startStyleHealthCheck();
                    unawaited(_applyStyleToController());
                    return;
                  }
                  if (!mounted || _disposed) return;
                  setState(() {
                    _styleLoaded = true;
                    _styleFailed = false;
                    _styleFailureReason = null;
                  });
                  widget.onStyleLoaded?.call();
                },
                onCameraMove: widget.onCameraMove,
                onCameraIdle: widget.onCameraIdle,
                onMapClick: widget.onMapClick == null
                    ? null
                    : (math.Point<double> point, ml.LatLng latLng) {
                        if (!_styleLoaded) return;
                        widget.onMapClick!(
                          point,
                          ll.LatLng(latLng.latitude, latLng.longitude),
                        );
                      },
                onMapLongClick: widget.onMapLongClick == null
                    ? null
                    : (math.Point<double> point, ml.LatLng latLng) {
                        if (!_styleLoaded) return;
                        widget.onMapLongClick!(
                          point,
                          ll.LatLng(latLng.latitude, latLng.longitude),
                        );
                      },
                trackCameraPosition: true,
              ),
              if (_styleFailed && !_styleLoaded)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.15),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(20),
                      child: _StyleErrorCard(
                        reason:
                            _styleFailureReason ?? 'Map style failed to load.',
                        onRetry: () {
                          if (!mounted) return;
                          setState(() {
                            _styleFailed = false;
                            _styleFailureReason = null;
                          });
                          _resetStyleLoadState();
                          _refreshStyleFuture();
                          _startStyleHealthCheck();
                          unawaited(_applyStyleToController());
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StyleErrorCard extends StatelessWidget {
  const _StyleErrorCard({
    required this.reason,
    required this.onRetry,
  });

  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = scheme.surface.withValues(alpha: isDark ? 0.92 : 0.97);
    final border = scheme.outlineVariant.withValues(alpha: 0.40);
    final titleColor = scheme.error;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.28 : 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: titleColor),
                  const SizedBox(width: 8),
                  Text(
                    'Map style error',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                reason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
