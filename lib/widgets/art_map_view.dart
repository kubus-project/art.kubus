import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  Future<String>? _resolvedStyleFuture;
  ml.MapLibreMapController? _controller;
  int _styleRequestId = 0;
  bool _pendingStyleApply = false;

  Timer? _styleLoadTimer;
  bool _styleLoaded = false;
  bool _didFallback = false;
  bool _styleFailed = false;
  String? _styleFailureReason;
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

  bool get _webDebugMapEnabled {
    if (!kIsWeb) return false;
    try {
      return Uri.base.queryParameters['debug_map'] == '1';
    } catch (_) {
      return false;
    }
  }

  void _webDiagPrint(String message) {
    if (!_webDebugMapEnabled) return;
    // Intentionally use `print` so logs show up in release web builds.
    // This is gated behind `?debug_map=1`.
    // ignore: avoid_print
    print(message);
  }

  Future<void> _runWebMapDiagnosticsIfEnabled(String styleRef) async {
    if (!_webDebugMapEnabled) return;

    // Keep this strictly opt-in to avoid shipping noisy logs.
    // This is a pure connectivity probe to help diagnose blank-map reports on web
    // (CSP blocks, worker restrictions, blocked tile/glyph domains, etc.).
    http.Client? client;
    try {
      client = http.Client();

      Map<String, dynamic> decoded;
      final trimmed = styleRef.trimLeft();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        _webDiagPrint('ArtMapView(web diag): style is inline JSON (length=${styleRef.length})');
        final dynamic rawDecoded = jsonDecode(styleRef);
        if (rawDecoded is! Map<String, dynamic>) {
          _webDiagPrint('ArtMapView(web diag): inline style JSON was not an object');
          return;
        }
        decoded = rawDecoded;
      } else {
        // The plugin supports passing style refs as URLs/asset paths.
        // On web we want to probe fetchability (CSP, origin, etc.).
        final styleUri = Uri.base.resolve(styleRef);
        final styleResp = await client.get(styleUri);
        _webDiagPrint(
          'ArtMapView(web diag): style GET ${styleUri.toString()} -> ${styleResp.statusCode}',
        );

        if (styleResp.statusCode < 200 || styleResp.statusCode >= 300) {
          final body = styleResp.body;
          _webDiagPrint(
            'ArtMapView(web diag): style fetch failed, body=${body.substring(0, math.min(200, body.length))}',
          );
          return;
        }

        final dynamic rawDecoded = jsonDecode(styleResp.body);
        if (rawDecoded is! Map<String, dynamic>) {
          _webDiagPrint('ArtMapView(web diag): style JSON was not an object');
          return;
        }
        decoded = rawDecoded;
      }

      final glyphs = decoded['glyphs']?.toString();
      if (glyphs != null && glyphs.isNotEmpty) {
        final glyphUrl = glyphs
            .replaceAll('{fontstack}', Uri.encodeComponent('Open Sans Regular'))
            .replaceAll('{range}', '0-255');
        try {
          final glyphUri = Uri.parse(glyphUrl);
          final glyphResp = await client.get(glyphUri);
          _webDiagPrint(
            'ArtMapView(web diag): glyphs GET ${glyphUri.toString()} -> ${glyphResp.statusCode}',
          );
        } catch (e) {
          _webDiagPrint('ArtMapView(web diag): glyphs fetch failed: $e');
        }
      }

      final sources = decoded['sources'];
      if (sources is Map<String, dynamic>) {
        String? firstTileTemplate;
        for (final entry in sources.entries) {
          final src = entry.value;
          if (src is! Map<String, dynamic>) continue;
          final type = src['type']?.toString();
          if (type != 'raster' && type != 'vector') continue;
          final tiles = src['tiles'];
          if (tiles is List && tiles.isNotEmpty) {
            firstTileTemplate = tiles.first?.toString();
            if (firstTileTemplate != null && firstTileTemplate.isNotEmpty) break;
          }
        }

        if (firstTileTemplate != null) {
          final tileUrl = firstTileTemplate
              .replaceAll('{z}', '0')
              .replaceAll('{x}', '0')
              .replaceAll('{y}', '0');
          try {
            final tileUri = Uri.parse(tileUrl);
            final tileResp = await client.get(tileUri);
            _webDiagPrint(
              'ArtMapView(web diag): tile GET ${tileUri.toString()} -> ${tileResp.statusCode}',
            );
          } catch (e) {
            _webDiagPrint('ArtMapView(web diag): tile fetch failed: $e');
          }
        } else {
          _webDiagPrint('ArtMapView(web diag): no tile sources found in style');
        }
      }
    } catch (e, st) {
      _webDiagPrint('ArtMapView(web diag): failed: $e');
      if (kDebugMode) {
        _webDiagPrint('ArtMapView(web diag): stack: $st');
      }
    } finally {
      client?.close();
    }
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

        final styleReady = ArtMapView.isStyleReadyForTest(
          styleLoaded: _styleLoaded,
          styleFailed: _styleFailed,
          pendingStyleApply: _pendingStyleApply,
        );

        final mapWidget = kIsWeb
            ? ml.MapLibreMap(
                key: ValueKey<String>('art_map_web:${widget.styleAsset}:${widget.isDarkMode}'),
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
                rotateGesturesEnabled:
                    widget.rotateGesturesEnabled && styleReady,
                scrollGesturesEnabled:
                    widget.scrollGesturesEnabled && styleReady,
                zoomGesturesEnabled: widget.zoomGesturesEnabled && styleReady,
                tiltGesturesEnabled: widget.tiltGesturesEnabled && styleReady,
                compassEnabled: widget.compassEnabled,
                // Web-only: helps reduce WebGL context loss/blank frames in some
                // compositing scenarios (e.g. heavy overlays/filters).
                webPreserveDrawingBuffer: true,
                // Explicitly disable location features on web.
                // Some plugin versions default these on and attempt to send
                // unsupported location render options to the web implementation.
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

                  // Optional: on web, run a one-shot connectivity probe when
                  // `?debug_map=1` is present.
                  unawaited(_runWebMapDiagnosticsIfEnabled(resolved));

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
                        if (!styleReady) return;
                        widget.onMapClick!(
                          point,
                          ll.LatLng(latLng.latitude, latLng.longitude),
                        );
                      },
                onMapLongClick: widget.onMapLongClick == null
                    ? null
                    : (math.Point<double> point, ml.LatLng latLng) {
                        if (!styleReady) return;
                        widget.onMapLongClick!(
                          point,
                          ll.LatLng(latLng.latitude, latLng.longitude),
                        );
                      },
                trackCameraPosition: true,
              )
            : ml.MapLibreMap(
                key: ValueKey<String>('art_map_native:${widget.styleAsset}:${widget.isDarkMode}'),
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
                rotateGesturesEnabled:
                    widget.rotateGesturesEnabled && styleReady,
                scrollGesturesEnabled:
                    widget.scrollGesturesEnabled && styleReady,
                zoomGesturesEnabled: widget.zoomGesturesEnabled && styleReady,
                tiltGesturesEnabled: widget.tiltGesturesEnabled && styleReady,
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
                        if (!styleReady) return;
                        widget.onMapClick!(
                          point,
                          ll.LatLng(latLng.latitude, latLng.longitude),
                        );
                      },
                onMapLongClick: widget.onMapLongClick == null
                    ? null
                    : (math.Point<double> point, ml.LatLng latLng) {
                        if (!styleReady) return;
                        widget.onMapLongClick!(
                          point,
                          ll.LatLng(latLng.latitude, latLng.longitude),
                        );
                      },
                trackCameraPosition: true,
              );

        return SizedBox.expand(
          child: Stack(
            children: [
              mapWidget,
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
