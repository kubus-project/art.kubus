import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
  final VoidCallback? onStyleLoaded;
  final void Function(ml.CameraPosition position)? onCameraMove;
  final VoidCallback? onCameraIdle;

  final void Function(math.Point<double> point, ll.LatLng latLng)? onMapClick;
  final void Function(math.Point<double> point, ll.LatLng latLng)? onMapLongClick;

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

  @override
  State<ArtMapView> createState() => _ArtMapViewState();
}

class _ArtMapViewState extends State<ArtMapView> {
  static int _debugLiveInstances = 0;
  static int _debugMapCreateSeq = 0;

  Future<String>? _resolvedStyleFuture;
  String? _resolvedStyleString;
  ml.MapLibreMapController? _controller;
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
  void dispose() {
    _styleLoadTimer?.cancel();
    _styleLoadTimer = null;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        controller.dispose();
      } catch (e, st) {
        AppConfig.debugPrint('ArtMapView: controller dispose failed: $e');
        if (kDebugMode) {
          AppConfig.debugPrint('ArtMapView: dispose stack: $st');
        }
      }
    }
    assert(() {
      _debugLiveInstances = math.max(0, _debugLiveInstances - 1);
      AppConfig.debugPrint(
        'ArtMapView: instance disposed (live=$_debugLiveInstances)',
      );
      return true;
    }());
    super.dispose();
  }

  void _refreshStyleFuture() {
    final future = MapStyleService.resolveStyleString(widget.styleAsset);
    _resolvedStyleFuture = future;
    future.then((resolved) {
      if (!mounted) return;
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
    if (!mounted) return;
    if (_styleLoaded) return;
    setState(() {
      _styleFailed = true;
      _styleFailureReason = reason;
    });
  }

  Future<void> _attemptFallbackStyle() async {
    if (_didFallback) return;

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
      if (!mounted) return;
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
    if (controller == null || future == null) return;

    final requestId = _styleRequestId;
    final styleString = await future;
    if (!mounted) return;
    if (requestId != _styleRequestId) return;

    try {
      await controller.setStyle(styleString);
    } catch (e, st) {
      AppConfig.debugPrint('ArtMapView: failed to apply style via setStyle: $e');
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
      if (!mounted) return;
      if (_styleLoaded) return;
      if (_didFallback) return;

      final controller = _controller;
      if (controller == null) return;

      _markStyleFailure('Map style failed to load.');
      AppConfig.debugPrint('ArtMapView: style load timeout; switching to fallback');
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
      return const SizedBox.expand(child: ColoredBox(color: Colors.transparent));
    }

    return SizedBox.expand(
      child: Stack(
        children: [
          ml.MapLibreMap(
            key: const ValueKey('art_map_view_maplibre'),
            styleString: resolved,
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(
                widget.initialCenter.latitude,
                widget.initialCenter.longitude,
              ),
              zoom: widget.initialZoom,
            ),
            // Preserve the WebGL drawing buffer to improve context stability
            // on Firefox, which is prone to context loss under memory pressure.
            // This trades some performance for crash resilience.
            webPreserveDrawingBuffer: kIsWeb,
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
            myLocationEnabled: false,
            myLocationTrackingMode: ml.MyLocationTrackingMode.none,
            onMapCreated: (controller) {
              assert(() {
                if (_mapCreated) {
                  AppConfig.debugPrint(
                    'ArtMapView: map created more than once for same State',
                  );
                  return false;
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
                  try {
                    controller.forceResizeWebMap();
                  } catch (e, st) {
                    AppConfig.debugPrint('ArtMapView: forceResizeWebMap failed: $e');
                    if (kDebugMode) {
                      AppConfig.debugPrint('ArtMapView: forceResizeWebMap stack: $st');
                    }
                  }
                });
              }
            },
            onStyleLoadedCallback: () {
              _styleStopwatch?.stop();
              _styleLoadTimer?.cancel();
              final elapsedMs = _styleStopwatch?.elapsedMilliseconds;
              if (elapsedMs != null) {
                AppConfig.debugPrint('ArtMapView: style loaded in ${elapsedMs}ms');
              } else {
                AppConfig.debugPrint('ArtMapView: style loaded');
              }
              if (kIsWeb) {
                try {
                  _controller?.forceResizeWebMap();
                } catch (e, st) {
                  AppConfig.debugPrint('ArtMapView: forceResizeWebMap after style load failed: $e');
                  if (kDebugMode) {
                    AppConfig.debugPrint('ArtMapView: resize-after-style stack: $st');
                  }
                }
              }
              if (_pendingStyleApply) {
                _pendingStyleApply = false;
                _resetStyleLoadState();
                _startStyleHealthCheck();
                unawaited(_applyStyleToController());
                return;
              }
              if (!mounted) return;
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
                    reason: _styleFailureReason ?? 'Map style failed to load.',
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
