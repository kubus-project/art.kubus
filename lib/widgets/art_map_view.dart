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
    this.compassEnabled = false,
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
  final bool compassEnabled;

  @override
  State<ArtMapView> createState() => _ArtMapViewState();
}

class _ArtMapViewState extends State<ArtMapView> {
  Future<String>? _resolvedStyleFuture;
  ml.MapLibreMapController? _controller;
  int _styleRequestId = 0;
  bool _pendingStyleApply = false;

  Timer? _styleLoadTimer;
  bool _styleLoaded = false;
  bool _didDevFallback = false;
  Stopwatch? _styleStopwatch;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _refreshStyleFuture() {
    _resolvedStyleFuture = MapStyleService.resolveStyleString(widget.styleAsset);
  }

  void _resetStyleLoadState() {
    _styleLoadTimer?.cancel();
    _styleLoaded = false;
    _didDevFallback = false;
    _styleRequestId++;
    _styleStopwatch = Stopwatch()..start();
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
    }
  }

  void _startStyleHealthCheck() {
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(MapStyleService.styleLoadTimeout, () {
      if (!mounted) return;
      if (_styleLoaded) return;
      if (_didDevFallback) return;
      if (!MapStyleService.devFallbackEnabled) return;

      final controller = _controller;
      if (controller == null) return;

      _didDevFallback = true;

      AppConfig.debugPrint('ArtMapView: style load timeout; switching to dev fallback');

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showKubusSnackBar(
        const SnackBar(
          content: Text('Map style failed to load; using a fallback style.'),
          duration: Duration(seconds: 4),
        ),
        tone: KubusSnackBarTone.warning,
      );

      unawaited(controller.setStyle(MapStyleService.devFallbackStyleUrl));
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

    return FutureBuilder<String>(
      future: _resolvedStyleFuture,
      builder: (context, snapshot) {
        final resolved = snapshot.data;

        // MapLibre is a platform view; in a loose Stack it can end up with a 0-size
        // layout. SizedBox.expand guarantees fullscreen rendering for our map screens.
        if (resolved == null) {
          return const SizedBox.expand(child: ColoredBox(color: Colors.transparent));
        }

        return SizedBox.expand(
          child: ml.MapLibreMap(
            styleString: resolved,
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(
                widget.initialCenter.latitude,
                widget.initialCenter.longitude,
              ),
              zoom: widget.initialZoom,
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
            compassEnabled: widget.compassEnabled,
            myLocationEnabled: false,
            myLocationTrackingMode: ml.MyLocationTrackingMode.none,
            onMapCreated: (controller) {
              _controller = controller;
              _resetStyleLoadState();
              _startStyleHealthCheck();
              AppConfig.debugPrint(
                'ArtMapView: map created (style="$resolved", platform=${defaultTargetPlatform.name}, web=$kIsWeb)',
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
              _styleLoaded = true;
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
              widget.onStyleLoaded?.call();
            },
            onCameraMove: widget.onCameraMove,
            onCameraIdle: widget.onCameraIdle,
            onMapClick: widget.onMapClick == null
                ? null
                : (math.Point<double> point, ml.LatLng latLng) {
                    widget.onMapClick!(
                      point,
                      ll.LatLng(latLng.latitude, latLng.longitude),
                    );
                  },
            onMapLongClick: widget.onMapLongClick == null
                ? null
                : (math.Point<double> point, ml.LatLng latLng) {
                    widget.onMapLongClick!(
                      point,
                      ll.LatLng(latLng.latitude, latLng.longitude),
                    );
                  },
            trackCameraPosition: true,
          ),
        );
      },
    );
  }
}
