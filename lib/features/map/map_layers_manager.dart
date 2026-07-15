import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'shared/map_marker_collision_config.dart';
import '../../utils/maplibre_style_utils.dart';
import '../../widgets/map_marker_style_config.dart';

/// Minimal controller surface used by [MapLayersManager].
///
/// This keeps [MapLayersManager] unit-testable without requiring the concrete
/// plugin controller implementation.
abstract class MapLayersController {
  Future<List<dynamic>> getLayerIds();

  Future<void> removeLayer(String id);
  Future<void> removeSource(String id);

  Future<void> addGeoJsonSource(
    String id,
    Map<String, dynamic> data, {
    String? promoteId,
  });

  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    ml.FillExtrusionLayerProperties properties,
  );

  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    ml.SymbolLayerProperties properties,
  );

  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    ml.CircleLayerProperties properties,
  );

  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    ml.LineLayerProperties properties, {
    dynamic filter,
  });

  Future<void> addImage(String name, Uint8List bytes);

  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> data);
  Future<void> setLayerVisibility(String layerId, bool visible);
  Future<void> setLayerProperties(
    String layerId,
    ml.LayerProperties properties,
  );

  /// Optional API: implemented via dynamic invocation to tolerate plugin
  /// version differences.
  Future<void> setPaintProperty(String layerId, String name, Object value);
  Future<void> setLayoutProperty(String layerId, String name, Object value);
}

class MapLibreLayersController implements MapLayersController {
  MapLibreLayersController(this._controller);

  final ml.MapLibreMapController _controller;

  @override
  Future<List<dynamic>> getLayerIds() => _controller.getLayerIds();

  @override
  Future<void> removeLayer(String id) => _controller.removeLayer(id);

  @override
  Future<void> removeSource(String id) => _controller.removeSource(id);

  @override
  Future<void> addGeoJsonSource(
    String id,
    Map<String, dynamic> data, {
    String? promoteId,
  }) {
    return _controller.addGeoJsonSource(id, data, promoteId: promoteId);
  }

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    ml.FillExtrusionLayerProperties properties,
  ) {
    return _controller.addFillExtrusionLayer(sourceId, layerId, properties);
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    ml.SymbolLayerProperties properties,
  ) {
    return _controller.addSymbolLayer(sourceId, layerId, properties);
  }

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    ml.CircleLayerProperties properties,
  ) {
    return _controller.addCircleLayer(sourceId, layerId, properties);
  }

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    ml.LineLayerProperties properties, {
    dynamic filter,
  }) {
    return _controller.addLineLayer(
      sourceId,
      layerId,
      properties,
      filter: filter,
      enableInteraction: false,
    );
  }

  @override
  Future<void> addImage(String name, Uint8List bytes) {
    return _controller.addImage(name, bytes);
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> data) {
    return _controller.setGeoJsonSource(sourceId, data);
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) {
    return _controller.setLayerVisibility(layerId, visible);
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    ml.LayerProperties properties,
  ) {
    return _controller.setLayerProperties(layerId, properties);
  }

  @override
  Future<void> setPaintProperty(
    String layerId,
    String name,
    Object value,
  ) async {
    final dyn = _controller as dynamic;
    final Future<dynamic> future = dyn.setPaintProperty(layerId, name, value);
    await future;
  }

  @override
  Future<void> setLayoutProperty(
    String layerId,
    String name,
    Object value,
  ) async {
    final dyn = _controller as dynamic;
    final Future<dynamic> future = dyn.setLayoutProperty(layerId, name, value);
    await future;
  }
}

@immutable
class KubusMarkerLayerStyleState {
  const KubusMarkerLayerStyleState({
    required this.pressedMarkerId,
    required this.hoveredMarkerId,
    required this.selectedMarkerId,
    required this.selectionPopAnimationValue,
    required this.cubeLayerVisible,
    this.markerPulsePhase = 0.0,
    this.markerBadgeBobOffsetPx = 0.0,
  });

  final String? pressedMarkerId;
  final String? hoveredMarkerId;
  final String? selectedMarkerId;

  /// 0..1 from the marker selection pop animation controller.
  final double selectionPopAnimationValue;

  final bool cubeLayerVisible;

  /// 0..1 ambient pulse phase driving the soft ring around each dot.
  final double markerPulsePhase;

  /// Current vertical bob offset (screen px) of the floating marker badge.
  final double markerBadgeBobOffsetPx;
}

/// Centralizes marker/cube icon layer styling updates.
///
/// Both mobile and desktop map screens were previously maintaining duplicated
/// logic to:
/// - build interaction expressions (hover/press/selection)
/// - throttle style updates
/// - queue updates when MapLibre rejects concurrent calls
///
/// This helper keeps behavior stable while making styling a single source of
/// truth.
class KubusMarkerLayerStyler {
  KubusMarkerLayerStyler({
    Duration minInterval = const Duration(milliseconds: 66),
  }) : _minIntervalMs = minInterval.inMilliseconds;

  final int _minIntervalMs;

  int _lastMarkerLayerStyleUpdateMs = 0;
  bool _markerLayerStyleUpdateInFlight = false;
  bool _markerLayerStyleUpdateQueued = false;

  void requestUpdate({
    required ml.MapLibreMapController? controller,
    required bool styleInitialized,
    required int styleEpoch,
    required int Function() getCurrentStyleEpoch,
    required Set<String> managedLayerIds,
    required String markerLayerId,
    required String cubeIconLayerId,
    required KubusMarkerLayerStyleState state,
    String? pulseLayerId,
    bool force = false,
  }) {
    if (controller == null) return;
    if (!styleInitialized) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && nowMs - _lastMarkerLayerStyleUpdateMs < _minIntervalMs) {
      return;
    }
    _lastMarkerLayerStyleUpdateMs = nowMs;

    if (_markerLayerStyleUpdateInFlight) {
      _markerLayerStyleUpdateQueued = true;
      return;
    }

    _markerLayerStyleUpdateInFlight = true;
    unawaited(
      _applyMarkerLayerStyle(
        controller: controller,
        styleEpoch: styleEpoch,
        getCurrentStyleEpoch: getCurrentStyleEpoch,
        styleInitialized: styleInitialized,
        managedLayerIds: managedLayerIds,
        markerLayerId: markerLayerId,
        cubeIconLayerId: cubeIconLayerId,
        pulseLayerId: pulseLayerId,
        state: state,
      ).whenComplete(() {
        _markerLayerStyleUpdateInFlight = false;
        if (_markerLayerStyleUpdateQueued) {
          _markerLayerStyleUpdateQueued = false;
          requestUpdate(
            controller: controller,
            styleInitialized: styleInitialized,
            styleEpoch: getCurrentStyleEpoch(),
            getCurrentStyleEpoch: getCurrentStyleEpoch,
            managedLayerIds: managedLayerIds,
            markerLayerId: markerLayerId,
            cubeIconLayerId: cubeIconLayerId,
            pulseLayerId: pulseLayerId,
            state: state,
            force: true,
          );
        }
      }),
    );
  }

  static Object interactiveIconSizeExpression(
    KubusMarkerLayerStyleState state, {
    double constantScale = 1.0,
  }) {
    final entryScale = <Object>[
      'coalesce',
      <Object>['get', 'entryScale'],
      1.0,
    ];

    final pressedId = state.pressedMarkerId;
    final hoveredId = state.hoveredMarkerId;
    final selectedId = state.selectedMarkerId;
    final any = pressedId != null || hoveredId != null || selectedId != null;
    if (!any) {
      return MapMarkerStyleConfig.iconSizeExpression(
        constantScale: constantScale,
        multiplier: entryScale,
      );
    }

    final double pop = selectedId == null
        ? 1.0
        : (1.0 +
            (MapMarkerStyleConfig.selectedPopScaleFactor - 1.0) *
                math.sin(state.selectionPopAnimationValue * math.pi));

    // On MapLibre GL JS, `['zoom']` must be the input to a top-level
    // "step"/"interpolate". Encode interaction multipliers inside the stop
    // outputs so we never wrap the zoom expression.
    final multiplier = <Object>['case'];
    if (pressedId != null) {
      multiplier.addAll(<Object>[
        <Object>[
          '==',
          <Object>['id'],
          pressedId,
        ],
        MapMarkerStyleConfig.pressedScaleFactor,
      ]);
    }
    if (selectedId != null) {
      multiplier.addAll(<Object>[
        <Object>[
          '==',
          <Object>['id'],
          selectedId,
        ],
        pop,
      ]);
    }
    if (hoveredId != null) {
      multiplier.addAll(<Object>[
        <Object>[
          '==',
          <Object>['id'],
          hoveredId,
        ],
        MapMarkerStyleConfig.hoverScaleFactor,
      ]);
    }
    multiplier.add(1.0);

    return MapMarkerStyleConfig.iconSizeExpression(
      constantScale: constantScale,
      multiplier: <Object>['*', multiplier, entryScale],
    );
  }

  static Object interactiveIconImageExpression(
    KubusMarkerLayerStyleState state,
  ) {
    final selectedId = state.selectedMarkerId;
    if (selectedId == null || selectedId.isEmpty) {
      return const <Object>['get', 'icon'];
    }
    return <Object>[
      'case',
      <Object>[
        '==',
        <Object>['id'],
        selectedId,
      ],
      const <Object>['get', 'iconSelected'],
      const <Object>['get', 'icon'],
    ];
  }

  Future<void> _applyMarkerLayerStyle({
    required ml.MapLibreMapController controller,
    required int styleEpoch,
    required int Function() getCurrentStyleEpoch,
    required bool styleInitialized,
    required Set<String> managedLayerIds,
    required String markerLayerId,
    required String cubeIconLayerId,
    required KubusMarkerLayerStyleState state,
    String? pulseLayerId,
  }) async {
    if (!styleInitialized) return;
    if (styleEpoch != getCurrentStyleEpoch()) return;

    final canStyleMarkerLayer = managedLayerIds.contains(markerLayerId);
    final canStyleCubeIconLayer = managedLayerIds.contains(cubeIconLayerId);
    final canStylePulseLayer =
        pulseLayerId != null && managedLayerIds.contains(pulseLayerId);
    if (!canStyleMarkerLayer && !canStyleCubeIconLayer && !canStylePulseLayer) {
      return;
    }

    final iconImage = interactiveIconImageExpression(state);
    final iconSize = interactiveIconSizeExpression(state);
    final cubeIconSize = interactiveIconSizeExpression(
      state,
      constantScale: 0.92,
    );
    // Clusters carry entryScale/entryOpacity like markers, so both share the
    // same entry/regroup animation; features without the property stay opaque.
    final iconOpacity = <Object>[
      'coalesce',
      <Object>['get', 'entryOpacity'],
      1.0,
    ];

    final markerVisible = !state.cubeLayerVisible;
    final cubeIconVisible = state.cubeLayerVisible;

    // Lift the selected badge above its neighbours (lower sort key draws first).
    final selectedId = state.selectedMarkerId;
    final Object symbolSortKey = selectedId == null
        ? 1.0
        : <Object>[
            'case',
            <Object>[
              '==',
              <Object>['id'],
              selectedId,
            ],
            2.0,
            1.0,
          ];

    try {
      if (canStyleMarkerLayer) {
        if (!styleInitialized || styleEpoch != getCurrentStyleEpoch()) return;
        await controller.setLayerProperties(
          markerLayerId,
          ml.SymbolLayerProperties(
            iconImage: iconImage,
            iconSize: iconSize,
            iconOpacity: iconOpacity,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            // The badge floats above the dot: it is anchored at the icon's
            // bottom (the float gap is baked into the PNG) and kept upright in
            // screen space so it stays readable while the map is pitched or
            // rotated. A subtle vertical bob replaces the old cube spin.
            iconAnchor: 'bottom',
            iconPitchAlignment: 'viewport',
            iconRotationAlignment: 'viewport',
            iconOffset: MapMarkerStyleConfig.badgeBobOffset(
              state.markerBadgeBobOffsetPx,
            ),
            symbolSortKey: symbolSortKey,
            visibility: markerVisible ? 'visible' : 'none',
          ),
        );
      }

      if (canStylePulseLayer) {
        if (!styleInitialized || styleEpoch != getCurrentStyleEpoch()) return;
        await controller.setLayerProperties(
          pulseLayerId,
          ml.CircleLayerProperties(
            circleRadius: MapMarkerStyleConfig.pulseRadiusForPhase(
              state.markerPulsePhase,
            ),
            circleColor: const <Object>['get', 'color'],
            circleOpacity: markerVisible
                ? MapMarkerStyleConfig.pulseOpacityForPhase(
                    state.markerPulsePhase,
                  )
                : 0.0,
            circleBlur: 0.35,
            circleStrokeWidth: 0.0,
            circlePitchAlignment: 'map',
          ),
        );
      }

      if (canStyleCubeIconLayer) {
        if (!styleInitialized || styleEpoch != getCurrentStyleEpoch()) return;
        await controller.setLayerProperties(
          cubeIconLayerId,
          ml.SymbolLayerProperties(
            iconImage: iconImage,
            iconSize: cubeIconSize,
            iconOpacity: iconOpacity,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconAnchor: 'bottom',
            iconPitchAlignment: 'viewport',
            iconRotationAlignment: 'viewport',
            iconOffset: MapMarkerStyleConfig.isometricBadgeOffset(
              state.markerBadgeBobOffsetPx,
            ),
            visibility: cubeIconVisible ? 'visible' : 'none',
          ),
        );
      }
    } catch (_) {
      // Best-effort: style swaps or platform limitations can reject updates.
    }
  }
}

enum MapRenderMode {
  /// Marker symbols (2D) are visible; cube layers are hidden.
  twoD,

  /// Cube extrusion + floating icons (3D) are visible; marker symbols hidden.
  threeD,
}

@immutable
class MapLayersIds {
  const MapLayersIds({
    required this.markerSourceId,
    required this.markerLayerId,
    required this.markerHitboxLayerId,
    required this.markerHitboxImageId,
    required this.markerDotLayerId,
    required this.markerPulseLayerId,
    required this.cubeLayerId,
    required this.cubeIconLayerId,
    required this.locationSourceId,
    required this.locationLayerId,
    this.walkingRouteSourceId = 'kubus_walking_route',
    this.walkingRouteCasingLayerId = 'kubus_walking_route_casing_layer',
    this.walkingRouteLayerId = 'kubus_walking_route_layer',
    this.walkingRouteConnectorLayerId = 'kubus_walking_route_connector_layer',
    this.walkingLocationSymbolLayerId = 'kubus_walking_location_symbol_layer',
    this.walkingLocationImageId = 'kubus_walking_location_person',
    this.pendingSourceId,
    this.pendingLayerId,
  });

  final String markerSourceId;
  final String markerLayerId;
  final String markerHitboxLayerId;
  final String markerHitboxImageId;

  /// Precise coordinate dot rendered at each marker/cluster point.
  final String markerDotLayerId;

  /// Soft pulsing ring rendered beneath the dot.
  final String markerPulseLayerId;

  final String cubeLayerId;
  final String cubeIconLayerId;

  final String locationSourceId;
  final String locationLayerId;

  final String walkingRouteSourceId;
  final String walkingRouteCasingLayerId;
  final String walkingRouteLayerId;
  final String walkingRouteConnectorLayerId;
  final String walkingLocationSymbolLayerId;
  final String walkingLocationImageId;

  final String? pendingSourceId;
  final String? pendingLayerId;

  bool get supportsPending => pendingSourceId != null && pendingLayerId != null;
}

@immutable
class MapLayersThemeSpec {
  const MapLayersThemeSpec({
    required this.locationFill,
    required this.locationStroke,
    this.walkingRouteColor,
    this.walkingRouteCasingColor,
    this.walkingLocationGlyphColor,
    this.walkingLocationGlyphStrokeColor,
    this.isometricPedestalTop,
    this.isometricPedestalLeft,
    this.isometricPedestalRight,
    this.isometricPedestalStroke,
    this.pendingFill,
    this.pendingStroke,
  });

  final Color locationFill;
  final Color locationStroke;

  final Color? walkingRouteColor;
  final Color? walkingRouteCasingColor;
  final Color? walkingLocationGlyphColor;
  final Color? walkingLocationGlyphStrokeColor;
  final Color? isometricPedestalTop;
  final Color? isometricPedestalLeft;
  final Color? isometricPedestalRight;
  final Color? isometricPedestalStroke;

  final Color? pendingFill;
  final Color? pendingStroke;

  Color get resolvedWalkingRouteColor => walkingRouteColor ?? locationFill;
  Color get resolvedWalkingRouteCasingColor =>
      walkingRouteCasingColor ?? locationStroke;
  Color get resolvedWalkingLocationGlyphColor =>
      walkingLocationGlyphColor ?? locationFill;
  Color get resolvedWalkingLocationGlyphStrokeColor =>
      walkingLocationGlyphStrokeColor ?? locationStroke;
  Color get resolvedIsometricPedestalTop =>
      isometricPedestalTop ??
      Color.alphaBlend(
        locationFill.withValues(alpha: 0.18),
        locationStroke,
      );
  Color get resolvedIsometricPedestalLeft =>
      isometricPedestalLeft ??
      Color.alphaBlend(locationFill.withValues(alpha: 0.10), locationStroke);
  Color get resolvedIsometricPedestalRight =>
      isometricPedestalRight ??
      Color.alphaBlend(locationFill.withValues(alpha: 0.26), locationStroke);
  Color get resolvedIsometricPedestalStroke =>
      isometricPedestalStroke ?? locationFill.withValues(alpha: 0.48);
}

@immutable
class MapLayersManagerStats {
  const MapLayersManagerStats({
    required this.addSourceCalls,
    required this.addLayerCalls,
    required this.removeLayerCalls,
    required this.removeSourceCalls,
    required this.sourceUpdateCalls,
    required this.sourceUpdateSkips,
    required this.layerPropertiesCalls,
    required this.visibilityCalls,
    required this.modeToggles,
  });

  final int addSourceCalls;
  final int addLayerCalls;
  final int removeLayerCalls;
  final int removeSourceCalls;
  final int sourceUpdateCalls;

  /// GeoJSON writes avoided because the canonical payload was unchanged.
  final int sourceUpdateSkips;
  final int layerPropertiesCalls;
  final int visibilityCalls;
  final int modeToggles;
}

class _MarkerSourceWriteRequest {
  _MarkerSourceWriteRequest({
    required this.featureCollection,
    required this.fingerprint,
    required this.styleEpoch,
  });

  final Map<String, dynamic> featureCollection;
  final String fingerprint;
  final int styleEpoch;
  final Completer<bool> completer = Completer<bool>();
}

class _MarkerSourceWriteQueue {
  bool isDraining = false;
  _MarkerSourceWriteRequest? pending;
}

/// Single source of truth for MapLibre source/layer lifecycle.
///
/// Key design constraints:
/// - Screens still own the controller lifecycle (incremental safety).
/// - Initialization is idempotent and guarded against re-entry.
/// - Style swaps are handled by resetting per styleEpoch.
/// - Runtime errors are prevented by design:
///   - missing layer/source operations are best-effort no-ops
///   - all MapLibre calls are wrapped in try/catch
///
/// Note: This manager currently installs the same set of layers/sources that
/// were previously duplicated in `MapScreen` and `DesktopMapScreen`.
class MapLayersManager {
  MapLayersManager({
    required MapLayersController controller,
    required MapLayersIds ids,
    required bool debugTracing,
    Set<String>? managedLayerIdsOut,
    Set<String>? managedSourceIdsOut,
    Set<String>? registeredMapImagesOut,
  })  : _controller = controller,
        _ids = ids,
        _debugTracing = debugTracing,
        _managedLayerIdsOut = managedLayerIdsOut,
        _managedSourceIdsOut = managedSourceIdsOut,
        _registeredMapImagesOut = registeredMapImagesOut;

  final MapLayersController _controller;
  final MapLayersIds _ids;
  final bool _debugTracing;

  final Set<String>? _managedLayerIdsOut;
  final Set<String>? _managedSourceIdsOut;
  final Set<String>? _registeredMapImagesOut;

  final Set<String> _layerIds = <String>{};
  final Set<String> _sourceIds = <String>{};
  final Set<String> _registeredImages = <String>{};

  // Retain the exact canonical payload rather than a lossy integer hash: a
  // collision must never suppress marker selection, entry, or spiderfy state.
  // Map keys are sorted while feature/list order remains significant.
  final Map<String, String> _sourceFingerprints = <String, String>{};
  // MapLibre source writes are asynchronous. Keeping every intermediate
  // animation frame in a FIFO queue makes a busy renderer show stale marker
  // topology long after the camera has settled. Each source therefore has one
  // in-flight write and, at most, the latest requested frame waiting behind it.
  final Map<String, _MarkerSourceWriteQueue> _markerSourceWriteQueues =
      <String, _MarkerSourceWriteQueue>{};

  int? _initializedForStyleEpoch;
  MapRenderMode _currentMode = MapRenderMode.twoD;
  MapLayersThemeSpec? _themeSpec;
  Map<String, dynamic> _walkingRouteData = _emptyFeatureCollection();
  bool _walkingNavigationVisible = false;

  String get _isometricPedestalImageId =>
      '${_ids.cubeLayerId}_screen_space_image';

  Completer<void>? _initCompleter;

  int _addSourceCalls = 0;
  int _addLayerCalls = 0;
  int _removeLayerCalls = 0;
  int _removeSourceCalls = 0;
  int _sourceUpdateCalls = 0;
  int _sourceUpdateSkips = 0;
  int _layerPropertiesCalls = 0;
  int _visibilityCalls = 0;
  int _modeToggles = 0;

  MapLayersManagerStats get stats => MapLayersManagerStats(
        addSourceCalls: _addSourceCalls,
        addLayerCalls: _addLayerCalls,
        removeLayerCalls: _removeLayerCalls,
        removeSourceCalls: _removeSourceCalls,
        sourceUpdateCalls: _sourceUpdateCalls,
        sourceUpdateSkips: _sourceUpdateSkips,
        layerPropertiesCalls: _layerPropertiesCalls,
        visibilityCalls: _visibilityCalls,
        modeToggles: _modeToggles,
      );

  bool hasLayer(String id) => _layerIds.contains(id);

  bool hasSource(String id) => _sourceIds.contains(id);

  void updateThemeSpec(MapLayersThemeSpec spec) {
    _themeSpec = spec;
  }

  /// Call this whenever the style is (re)loaded and `styleEpoch` increments.
  ///
  /// This resets cached layer/source knowledge so initialization can safely
  /// re-install everything once per style.
  void onNewStyle({required int styleEpoch}) {
    if (_initializedForStyleEpoch == styleEpoch) return;
    _initializedForStyleEpoch = null;
    _layerIds.clear();
    _sourceIds.clear();
    _registeredImages.clear();
    _sourceFingerprints.clear();
    for (final queue in _markerSourceWriteQueues.values) {
      final pending = queue.pending;
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.complete(false);
      }
      queue.pending = null;
    }
    _mirrorToScreenSets();
  }

  /// Idempotent initializer.
  ///
  /// - If called multiple times for the same styleEpoch, only the first call
  ///   will perform MapLibre mutations.
  /// - If a previous call is in flight, subsequent calls await it.
  Future<void> ensureInitialized({required int styleEpoch}) async {
    if (_initializedForStyleEpoch == styleEpoch) return;
    final inFlight = _initCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      if (_themeSpec == null) {
        // Without theme colors we can't configure location/pending layers.
        // Treat as a hard precondition (but don't crash the app).
        if (_debugTracing && kDebugMode) {
          // ignore: avoid_print
          debugPrint('MapLayersManager: missing themeSpec; init skipped');
        }
        return;
      }

      await _installLayersForStyle(styleEpoch: styleEpoch);
      _initializedForStyleEpoch = styleEpoch;
      _mirrorToScreenSets();

      if (_debugTracing && kDebugMode) {
        final s = stats;
        // ignore: avoid_print
        debugPrint(
          'MapLayersManager: initialized styleEpoch=$styleEpoch '
          '(sources=${_sourceIds.length} layers=${_layerIds.length}) '
          'calls(addSource=${s.addSourceCalls} addLayer=${s.addLayerCalls} ',
        );
      }
    } finally {
      completer.complete();
      _initCompleter = null;
    }
  }

  /// Writes marker GeoJSON only when its complete rendered payload changed.
  ///
  /// Returns true after a material write succeeds. Failed writes are not
  /// fingerprinted, and concurrent requests serialize so duplicates can skip.
  Future<bool> upsertMarkerData(Map<String, dynamic> featureCollection) {
    return _upsertMarkerData(featureCollection);
  }

  Future<bool> _upsertMarkerData(Map<String, dynamic> featureCollection) {
    final sourceId = _ids.markerSourceId;
    if (!hasSource(sourceId)) return Future<bool>.value(false);

    final requestedStyleEpoch = _initializedForStyleEpoch;
    if (requestedStyleEpoch == null) return Future<bool>.value(false);
    final fingerprint = _canonicalSourceFingerprint(featureCollection);
    final request = _MarkerSourceWriteRequest(
      featureCollection: featureCollection,
      fingerprint: fingerprint,
      styleEpoch: requestedStyleEpoch,
    );
    final queue = _markerSourceWriteQueues.putIfAbsent(
      sourceId,
      _MarkerSourceWriteQueue.new,
    );

    // Supersede an obsolete queued animation frame. The in-flight write is
    // retained because platform APIs do not support cancellation safely.
    final superseded = queue.pending;
    if (superseded != null && !superseded.completer.isCompleted) {
      superseded.completer.complete(false);
    }
    queue.pending = request;

    if (!queue.isDraining) {
      queue.isDraining = true;
      unawaited(_drainMarkerSourceWrites(sourceId, queue));
    }

    return request.completer.future;
  }

  Future<void> _drainMarkerSourceWrites(
    String sourceId,
    _MarkerSourceWriteQueue queue,
  ) async {
    try {
      while (queue.pending != null) {
        final request = queue.pending!;
        queue.pending = null;
        bool didWrite = false;

        // A style swap/source recreation while queued invalidates this frame.
        if (_initializedForStyleEpoch == request.styleEpoch &&
            hasSource(sourceId)) {
          if (_sourceFingerprints[sourceId] == request.fingerprint) {
            _sourceUpdateSkips += 1;
          } else {
            try {
              _sourceUpdateCalls += 1;
              await _controller.setGeoJsonSource(
                sourceId,
                request.featureCollection,
              );
              if (_initializedForStyleEpoch == request.styleEpoch &&
                  hasSource(sourceId)) {
                _sourceFingerprints[sourceId] = request.fingerprint;
                didWrite = true;
              }
            } catch (_) {
              // Do not commit the fingerprint so a later frame can retry.
            }
          }
        }
        if (!request.completer.isCompleted) {
          request.completer.complete(didWrite);
        }
      }
    } finally {
      queue.isDraining = false;
      if (queue.pending != null) {
        queue.isDraining = true;
        unawaited(_drainMarkerSourceWrites(sourceId, queue));
      } else if (identical(_markerSourceWriteQueues[sourceId], queue)) {
        _markerSourceWriteQueues.remove(sourceId);
      }
    }
  }

  static String _canonicalSourceFingerprint(Object? value) {
    Object? canonicalize(Object? current) {
      if (current is Map) {
        final entries = current.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        return <String, Object?>{
          for (final entry in entries)
            entry.key.toString(): canonicalize(entry.value),
        };
      }
      if (current is List) {
        return <Object?>[for (final item in current) canonicalize(item)];
      }
      return current;
    }

    return jsonEncode(canonicalize(value));
  }

  Future<void> upsertUserLocationData(
    Map<String, dynamic> featureCollection,
  ) async {
    if (!hasSource(_ids.locationSourceId)) return;
    try {
      _sourceUpdateCalls += 1;
      await _controller.setGeoJsonSource(
        _ids.locationSourceId,
        featureCollection,
      );
    } catch (_) {
      // Best-effort.
    }
  }

  /// Retains and renders the complete walking route FeatureCollection.
  ///
  /// Route features use `properties.kind == "route"`; short connectors from
  /// the exact user/artwork coordinates to the routable graph use
  /// `properties.kind == "connector"`. Retaining the payload here lets a
  /// MapLibre style reload restore an active navigation session without
  /// waiting for another location or route calculation event.
  Future<void> upsertWalkingRouteData(
    Map<String, dynamic> featureCollection,
  ) async {
    _walkingRouteData = Map<String, dynamic>.from(featureCollection);
    if (!hasSource(_ids.walkingRouteSourceId)) return;
    try {
      _sourceUpdateCalls += 1;
      await _controller.setGeoJsonSource(
        _ids.walkingRouteSourceId,
        _walkingRouteData,
      );
    } catch (_) {
      // Best-effort. The retained payload is replayed after the next style load.
    }
  }

  /// Shows or hides the route and walking-person marker as one UI state.
  ///
  /// The ordinary location dot remains visible and is shared by navigation;
  /// only the floating walking glyph is toggled here.
  Future<void> setWalkingNavigationVisibility(bool visible) async {
    _walkingNavigationVisible = visible;
    await safeSetLayerVisibility(_ids.walkingRouteCasingLayerId, visible);
    await safeSetLayerVisibility(_ids.walkingRouteLayerId, visible);
    await safeSetLayerVisibility(_ids.walkingRouteConnectorLayerId, visible);
    await safeSetLayerVisibility(_ids.walkingLocationSymbolLayerId, visible);
  }

  Future<void> upsertPendingMarkerData(
    Map<String, dynamic> featureCollection,
  ) async {
    final sourceId = _ids.pendingSourceId;
    if (sourceId == null) return;
    if (!hasSource(sourceId)) return;
    try {
      _sourceUpdateCalls += 1;
      await _controller.setGeoJsonSource(sourceId, featureCollection);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> setMode(MapRenderMode mode) async {
    if (_currentMode == mode) return;
    _currentMode = mode;
    _modeToggles += 1;

    // Deterministic and safe visibility switching.
    final show3d = mode == MapRenderMode.threeD;
    await safeSetLayerVisibility(_ids.cubeLayerId, show3d);
    await safeSetLayerVisibility(_ids.cubeIconLayerId, show3d);
    await safeSetLayerVisibility(_ids.markerLayerId, !show3d);
  }

  Future<void> setVisibility({
    bool? markers2d,
    bool? markers3d,
    bool? userLocation,
    bool? pendingMarker,
  }) async {
    if (markers2d != null) {
      await safeSetLayerVisibility(_ids.markerLayerId, markers2d);
    }
    if (markers3d != null) {
      await safeSetLayerVisibility(_ids.cubeLayerId, markers3d);
      await safeSetLayerVisibility(_ids.cubeIconLayerId, markers3d);
    }
    if (userLocation != null) {
      await safeSetLayerVisibility(_ids.locationLayerId, userLocation);
    }
    if (pendingMarker != null && _ids.pendingLayerId != null) {
      await safeSetLayerVisibility(_ids.pendingLayerId!, pendingMarker);
    }
  }

  Future<void> safeSetLayerVisibility(String layerId, bool visible) async {
    if (!hasLayer(layerId)) return;
    try {
      _visibilityCalls += 1;
      await _controller.setLayerVisibility(layerId, visible);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> safeSetLayerProperties(
    String layerId,
    ml.LayerProperties properties,
  ) async {
    if (!hasLayer(layerId)) return;
    try {
      _layerPropertiesCalls += 1;
      await _controller.setLayerProperties(layerId, properties);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Best-effort paint property setter. Uses dynamic invocation so it works
  /// across maplibre_gl plugin versions.
  Future<void> safeSetPaintProperty(
    String layerId,
    String name,
    Object value,
  ) async {
    if (!hasLayer(layerId)) return;
    try {
      await _controller.setPaintProperty(layerId, name, value);
    } catch (_) {
      // If the plugin doesn't support paint property mutation, ignore.
    }
  }

  /// Best-effort layout property setter. Uses dynamic invocation so it works
  /// across maplibre_gl plugin versions.
  Future<void> safeSetLayoutProperty(
    String layerId,
    String name,
    Object value,
  ) async {
    if (!hasLayer(layerId)) return;
    try {
      await _controller.setLayoutProperty(layerId, name, value);
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> _installLayersForStyle({required int styleEpoch}) async {
    final theme = _themeSpec!;

    // If the style swapped, previous layers might still be present under the
    // same IDs. Clear them best-effort.
    final existingLayerIds = await _fetchExistingLayerIds();
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.markerLayerId);
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.markerHitboxLayerId);
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.markerDotLayerId);
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.markerPulseLayerId);
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.cubeLayerId);
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.cubeIconLayerId);
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.locationLayerId);
    await _safeRemoveLayerIfExists(
      existingLayerIds,
      _ids.walkingLocationSymbolLayerId,
    );
    await _safeRemoveLayerIfExists(
      existingLayerIds,
      _ids.walkingRouteConnectorLayerId,
    );
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.walkingRouteLayerId);
    await _safeRemoveLayerIfExists(
      existingLayerIds,
      _ids.walkingRouteCasingLayerId,
    );
    if (_ids.pendingLayerId != null) {
      await _safeRemoveLayerIfExists(existingLayerIds, _ids.pendingLayerId!);
    }

    await _safeRemoveSource(_ids.markerSourceId);
    await _safeRemoveSource(_ids.locationSourceId);
    await _safeRemoveSource(_ids.walkingRouteSourceId);
    if (_ids.pendingSourceId != null) {
      await _safeRemoveSource(_ids.pendingSourceId!);
    }

    await _controller.addGeoJsonSource(
      _ids.markerSourceId,
      const <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      },
      promoteId: 'id',
    );
    _addSourceCalls += 1;
    _sourceIds.add(_ids.markerSourceId);

    await _controller.addGeoJsonSource(
      _ids.walkingRouteSourceId,
      _walkingRouteData,
    );
    _addSourceCalls += 1;
    _sourceIds.add(_ids.walkingRouteSourceId);

    // Walking route layers sit below all art markers and the user location.
    // A separate casing preserves contrast over both light and dark map styles,
    // while approach connectors remain visibly distinct from routable paths.
    await _controller.addLineLayer(
      _ids.walkingRouteSourceId,
      _ids.walkingRouteCasingLayerId,
      ml.LineLayerProperties(
        lineColor: MapLibreStyleUtils.hexRgb(
          theme.resolvedWalkingRouteCasingColor,
        ),
        lineWidth: const <Object>[
          'interpolate',
          <Object>['linear'],
          <Object>['zoom'],
          11,
          6.0,
          16,
          9.0,
          20,
          12.0,
        ],
        lineOpacity: 0.9,
        lineCap: 'round',
        lineJoin: 'round',
        visibility: _walkingNavigationVisible ? 'visible' : 'none',
      ),
      filter: const <Object>[
        '==',
        <Object>['get', 'kind'],
        'route',
      ],
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.walkingRouteCasingLayerId);

    await _controller.addLineLayer(
      _ids.walkingRouteSourceId,
      _ids.walkingRouteLayerId,
      ml.LineLayerProperties(
        lineColor: MapLibreStyleUtils.hexRgb(theme.resolvedWalkingRouteColor),
        lineWidth: const <Object>[
          'interpolate',
          <Object>['linear'],
          <Object>['zoom'],
          11,
          3.0,
          16,
          5.0,
          20,
          7.0,
        ],
        lineOpacity: 1.0,
        lineCap: 'round',
        lineJoin: 'round',
        visibility: _walkingNavigationVisible ? 'visible' : 'none',
      ),
      filter: const <Object>[
        '==',
        <Object>['get', 'kind'],
        'route',
      ],
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.walkingRouteLayerId);

    await _controller.addLineLayer(
      _ids.walkingRouteSourceId,
      _ids.walkingRouteConnectorLayerId,
      ml.LineLayerProperties(
        lineColor: MapLibreStyleUtils.hexRgb(theme.resolvedWalkingRouteColor),
        lineWidth: const <Object>[
          'interpolate',
          <Object>['linear'],
          <Object>['zoom'],
          11,
          2.0,
          16,
          3.5,
          20,
          5.0,
        ],
        lineOpacity: 0.8,
        lineDasharray: const <double>[1.2, 1.2],
        lineCap: 'round',
        lineJoin: 'round',
        visibility: _walkingNavigationVisible ? 'visible' : 'none',
      ),
      filter: const <Object>[
        '==',
        <Object>['get', 'kind'],
        'connector',
      ],
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.walkingRouteConnectorLayerId);

    // Layer order (bottom to top):
    // 1) isometric screen-space pedestal (hidden outside pitched mode)
    // 2) marker pulse ring (flat on the ground, below the dot)
    // 3) marker coordinate dot (flat on the ground)
    // 4) marker floating badge symbol (hovers above the dot)
    // 5) cube floating icon (experimental; hidden by default)
    // 6) marker hitbox (transparent, on top for reliable taps)

    await _ensureIsometricPedestalImageRegistered(theme);
    await _controller.addSymbolLayer(
      _ids.markerSourceId,
      _ids.cubeLayerId,
      ml.SymbolLayerProperties(
        iconImage: _isometricPedestalImageId,
        iconSize: MapMarkerStyleConfig.iconSizeExpression(
          constantScale: MapMarkerStyleConfig.isometricPedestalScale,
          multiplier: <Object>[
            'coalesce',
            <Object>['get', 'entryScale'],
            1.0,
          ],
        ),
        iconOpacity: <Object>[
          'coalesce',
          <Object>['get', 'entryOpacity'],
          1.0,
        ],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAnchor: 'bottom',
        iconPitchAlignment: 'viewport',
        iconRotationAlignment: 'viewport',
        visibility: 'none',
      ),
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.cubeLayerId);

    // Soft pulse ring beneath the dot. Radius/opacity are animated at runtime by
    // the marker layer styler; it lies flat on the ground so it reads correctly
    // when the map is pitched (isometric view).
    await _controller.addCircleLayer(
      _ids.markerSourceId,
      _ids.markerPulseLayerId,
      ml.CircleLayerProperties(
        circleRadius: MapMarkerStyleConfig.pulseMinRadiusPx,
        circleColor: const <Object>['get', 'color'],
        circleOpacity: 0.0,
        circleBlur: 0.35,
        circleStrokeWidth: 0.0,
        circlePitchAlignment: 'map',
      ),
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.markerPulseLayerId);

    // Precise coordinate dot at every marker/cluster point. Fades in with the
    // shared entry/regroup animation so the dot never appears before its badge.
    await _controller.addCircleLayer(
      _ids.markerSourceId,
      _ids.markerDotLayerId,
      ml.CircleLayerProperties(
        circleRadius: <Object>[
          'case',
          <Object>[
            '==',
            <Object>['get', 'kind'],
            'cluster',
          ],
          MapMarkerStyleConfig.clusterDotRadiusPx,
          MapMarkerStyleConfig.dotRadiusPx,
        ],
        circleColor: const <Object>['get', 'color'],
        circleOpacity: <Object>[
          'coalesce',
          <Object>['get', 'entryOpacity'],
          1.0,
        ],
        circleStrokeWidth: MapMarkerStyleConfig.dotStrokeWidthPx,
        circleStrokeColor: MapLibreStyleUtils.hexRgb(theme.locationStroke),
        circlePitchAlignment: 'map',
      ),
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.markerDotLayerId);

    await _controller.addSymbolLayer(
      _ids.markerSourceId,
      _ids.markerLayerId,
      ml.SymbolLayerProperties(
        iconImage: const <Object>['get', 'icon'],
        iconSize: MapMarkerStyleConfig.iconSizeExpression(
          multiplier: <Object>[
            'coalesce',
            <Object>['get', 'entryScale'],
            1.0,
          ],
        ),
        iconOpacity: <Object>[
          'coalesce',
          <Object>['get', 'entryOpacity'],
          1.0,
        ],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        // Floating badge: anchored at the icon bottom (float gap baked into
        // the PNG) and kept upright in screen space so it stays readable under
        // pitch + bearing rotation.
        iconAnchor: 'bottom',
        iconPitchAlignment: 'viewport',
        iconRotationAlignment: 'viewport',
      ),
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.markerLayerId);

    await _controller.addSymbolLayer(
      _ids.markerSourceId,
      _ids.cubeIconLayerId,
      ml.SymbolLayerProperties(
        iconImage: const <Object>['get', 'icon'],
        iconSize: MapMarkerStyleConfig.iconSizeExpression(
          constantScale: 0.92,
          multiplier: <Object>[
            'coalesce',
            <Object>['get', 'entryScale'],
            1.0,
          ],
        ),
        iconOpacity: <Object>[
          'coalesce',
          <Object>['get', 'entryOpacity'],
          1.0,
        ],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAnchor: 'bottom',
        iconPitchAlignment: 'viewport',
        iconRotationAlignment: 'viewport',
        iconOffset: MapMarkerStyleConfig.isometricBadgeOffset(0),
        visibility: 'none',
      ),
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.cubeIconLayerId);

    await _ensureHitboxImageRegistered();

    final Object hitboxIconSize = kIsWeb
        ? MapMarkerCollisionConfig.webHitboxIconSizeExpression()
        : <Object>[
            'interpolate',
            <Object>['linear'],
            <Object>['zoom'],
            3,
            <Object>[
              'case',
              <Object>[
                '==',
                <Object>['get', 'kind'],
                'cluster',
              ],
              50,
              36,
            ],
            12,
            <Object>[
              'case',
              <Object>[
                '==',
                <Object>['get', 'kind'],
                'cluster',
              ],
              64,
              44,
            ],
            15,
            <Object>[
              'case',
              <Object>[
                '==',
                <Object>['get', 'kind'],
                'cluster',
              ],
              76,
              56,
            ],
            24,
            <Object>[
              'case',
              <Object>[
                '==',
                <Object>['get', 'kind'],
                'cluster',
              ],
              84,
              76,
            ],
          ];

    try {
      await _controller.addSymbolLayer(
        _ids.markerSourceId,
        _ids.markerHitboxLayerId,
        ml.SymbolLayerProperties(
          iconImage: _ids.markerHitboxImageId,
          iconSize: hitboxIconSize,
          iconOpacity: 0.0,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          // Match the floating badge anchor so the tap target covers the badge
          // (which hovers above the coordinate point), keeping hitboxes generous
          // and reliable.
          iconAnchor: 'bottom',
          iconPitchAlignment: 'viewport',
          iconRotationAlignment: 'viewport',
        ),
      );
      _addLayerCalls += 1;
    } catch (_) {
      final Object hitboxRadius = kIsWeb
          ? MapMarkerCollisionConfig.webHitboxRadiusExpression()
          : <Object>[
              'interpolate',
              <Object>['linear'],
              <Object>['zoom'],
              3,
              <Object>[
                'case',
                <Object>[
                  '==',
                  <Object>['get', 'kind'],
                  'cluster',
                ],
                25,
                18,
              ],
              12,
              <Object>[
                'case',
                <Object>[
                  '==',
                  <Object>['get', 'kind'],
                  'cluster',
                ],
                32,
                22,
              ],
              15,
              <Object>[
                'case',
                <Object>[
                  '==',
                  <Object>['get', 'kind'],
                  'cluster',
                ],
                38,
                28,
              ],
              24,
              <Object>[
                'case',
                <Object>[
                  '==',
                  <Object>['get', 'kind'],
                  'cluster',
                ],
                42,
                38,
              ],
            ];
      await _controller.addCircleLayer(
        _ids.markerSourceId,
        _ids.markerHitboxLayerId,
        ml.CircleLayerProperties(
          circleColor: '#000000',
          circleOpacity: 0.0,
          circleStrokeOpacity: 0.0,
          circleStrokeWidth: 0.0,
          circleRadius: hitboxRadius,
          // Shift the circle up toward the floating badge (this is only the
          // fallback path when symbol hitboxes are unavailable).
          circleTranslate: const <Object>[0, -22],
        ),
      );
      _addLayerCalls += 1;
    }
    _layerIds.add(_ids.markerHitboxLayerId);

    await _controller.addGeoJsonSource(
      _ids.locationSourceId,
      const <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      },
      promoteId: 'id',
    );
    _addSourceCalls += 1;
    _sourceIds.add(_ids.locationSourceId);

    await _controller.addCircleLayer(
      _ids.locationSourceId,
      _ids.locationLayerId,
      ml.CircleLayerProperties(
        circleRadius: 6,
        circleColor: MapLibreStyleUtils.hexRgb(theme.locationFill),
        circleOpacity: 1.0,
        circleStrokeWidth: 2,
        circleStrokeColor: MapLibreStyleUtils.hexRgb(theme.locationStroke),
      ),
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.locationLayerId);

    await _ensureWalkingLocationImageRegistered(theme);
    if (_registeredImages.contains(_ids.walkingLocationImageId)) {
      await _controller.addSymbolLayer(
        _ids.locationSourceId,
        _ids.walkingLocationSymbolLayerId,
        ml.SymbolLayerProperties(
          iconImage: _ids.walkingLocationImageId,
          iconSize: 0.6,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'bottom',
          iconOffset: const <double>[0, -0.35],
          iconPitchAlignment: 'viewport',
          iconRotationAlignment: 'viewport',
          visibility: _walkingNavigationVisible ? 'visible' : 'none',
        ),
      );
      _addLayerCalls += 1;
      _layerIds.add(_ids.walkingLocationSymbolLayerId);
    }

    if (_ids.supportsPending) {
      final pendingSourceId = _ids.pendingSourceId!;
      final pendingLayerId = _ids.pendingLayerId!;
      await _controller.addGeoJsonSource(
        pendingSourceId,
        const <String, dynamic>{
          'type': 'FeatureCollection',
          'features': <dynamic>[],
        },
        promoteId: 'id',
      );
      _addSourceCalls += 1;
      _sourceIds.add(pendingSourceId);

      final pendingFill = theme.pendingFill ?? theme.locationFill;
      final pendingStroke = theme.pendingStroke ?? theme.locationStroke;
      await _controller.addCircleLayer(
        pendingSourceId,
        pendingLayerId,
        ml.CircleLayerProperties(
          circleRadius: 7,
          circleColor: MapLibreStyleUtils.hexRgb(pendingFill),
          circleOpacity: 0.92,
          circleStrokeWidth: 2,
          circleStrokeColor: MapLibreStyleUtils.hexRgb(pendingStroke),
        ),
      );
      _addLayerCalls += 1;
      _layerIds.add(pendingLayerId);
    }

    // Default mode is 2D: ensure 3D layers hidden.
    _currentMode = MapRenderMode.twoD;
    await safeSetLayerVisibility(_ids.cubeLayerId, false);
    await safeSetLayerVisibility(_ids.cubeIconLayerId, false);
    await safeSetLayerVisibility(_ids.markerLayerId, true);
    await setWalkingNavigationVisibility(_walkingNavigationVisible);
  }

  Future<Set<String>> _fetchExistingLayerIds() async {
    final result = <String>{};
    try {
      final raw = await _controller.getLayerIds();
      for (final id in raw) {
        if (id is String) result.add(id);
      }
    } catch (_) {
      // Ignore.
    }
    return result;
  }

  Future<void> _safeRemoveLayerIfExists(Set<String> existing, String id) async {
    if (!existing.contains(id)) return;
    try {
      await _controller.removeLayer(id);
      _removeLayerCalls += 1;
    } catch (_) {
      // Ignore.
    }
    existing.remove(id);
  }

  Future<void> _safeRemoveSource(String id) async {
    _sourceFingerprints.remove(id);
    try {
      await _controller.removeSource(id);
      _removeSourceCalls += 1;
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> _ensureHitboxImageRegistered() async {
    if (_registeredImages.contains(_ids.markerHitboxImageId)) return;
    try {
      final bytes = _createTransparentSquareImage();
      await _controller.addImage(_ids.markerHitboxImageId, bytes);
      _registeredImages.add(_ids.markerHitboxImageId);
    } catch (_) {
      // Ignore; hitbox symbol layer might fallback to circle.
    }
  }

  Future<void> _ensureWalkingLocationImageRegistered(
    MapLayersThemeSpec theme,
  ) async {
    if (_registeredImages.contains(_ids.walkingLocationImageId)) return;
    try {
      final bytes = await _createWalkingLocationImage(theme);
      await _controller.addImage(_ids.walkingLocationImageId, bytes);
      _registeredImages.add(_ids.walkingLocationImageId);
    } catch (_) {
      // The route remains usable if a renderer cannot create the glyph.
    }
  }

  Future<void> _ensureIsometricPedestalImageRegistered(
    MapLayersThemeSpec theme,
  ) async {
    if (_registeredImages.contains(_isometricPedestalImageId)) return;
    try {
      final bytes = await _createIsometricPedestalImage(theme);
      await _controller.addImage(_isometricPedestalImageId, bytes);
      _registeredImages.add(_isometricPedestalImageId);
    } catch (_) {
      // Marker badges remain usable if a renderer cannot create the pedestal.
    }
  }

  Future<Uint8List> _createIsometricPedestalImage(
    MapLayersThemeSpec theme,
  ) async {
    const logicalWidth = 58.0;
    const logicalHeight = 38.0;
    const pixelRatio = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(pixelRatio, pixelRatio);

    final top = ui.Path()
      ..moveTo(29, 1)
      ..lineTo(56, 13)
      ..lineTo(29, 25)
      ..lineTo(2, 13)
      ..close();
    final left = ui.Path()
      ..moveTo(2, 13)
      ..lineTo(29, 25)
      ..lineTo(29, 37)
      ..lineTo(2, 25)
      ..close();
    final right = ui.Path()
      ..moveTo(56, 13)
      ..lineTo(29, 25)
      ..lineTo(29, 37)
      ..lineTo(56, 25)
      ..close();

    ui.Paint fill(Color color) => ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    final stroke = ui.Paint()
      ..color = theme.resolvedIsometricPedestalStroke
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = ui.StrokeJoin.round;

    canvas.drawPath(left, fill(theme.resolvedIsometricPedestalLeft));
    canvas.drawPath(right, fill(theme.resolvedIsometricPedestalRight));
    canvas.drawPath(top, fill(theme.resolvedIsometricPedestalTop));
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
    canvas.drawPath(top, stroke);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (logicalWidth * pixelRatio).round(),
      (logicalHeight * pixelRatio).round(),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Unable to rasterize isometric pedestal');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<Uint8List> _createWalkingLocationImage(
    MapLayersThemeSpec theme,
  ) async {
    const logicalWidth = 24.0;
    const logicalHeight = 34.0;
    const pixelRatio = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(pixelRatio, pixelRatio);

    final outline = ui.Paint()
      ..color = theme.resolvedWalkingLocationGlyphStrokeColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;
    final glyph = ui.Paint()
      ..color = theme.resolvedWalkingLocationGlyphColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;
    final outlineFill = ui.Paint()
      ..color = theme.resolvedWalkingLocationGlyphStrokeColor
      ..style = ui.PaintingStyle.fill;
    final glyphFill = ui.Paint()
      ..color = theme.resolvedWalkingLocationGlyphColor
      ..style = ui.PaintingStyle.fill;

    void drawPerson(ui.Paint stroke, ui.Paint fill) {
      canvas.drawCircle(const ui.Offset(12, 5), 3.0, fill);
      final path = ui.Path()
        ..moveTo(12, 10)
        ..lineTo(11, 20)
        ..moveTo(11.6, 13)
        ..lineTo(5.5, 18)
        ..moveTo(11.6, 13)
        ..lineTo(18.5, 16.5)
        ..moveTo(11, 20)
        ..lineTo(5.5, 30)
        ..moveTo(11, 20)
        ..lineTo(19, 29.5);
      canvas.drawPath(path, stroke);
    }

    drawPerson(outline, outlineFill);
    drawPerson(glyph, glyphFill);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (logicalWidth * pixelRatio).round(),
      (logicalHeight * pixelRatio).round(),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Unable to rasterize walking location glyph');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Uint8List _createTransparentSquareImage() {
    const String base64Png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    return Uint8List.fromList(base64Decode(base64Png));
  }

  static Map<String, dynamic> _emptyFeatureCollection() => <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      };

  void _mirrorToScreenSets() {
    // Preserve existing guards in screens during incremental refactor.
    _managedLayerIdsOut
      ?..clear()
      ..addAll(_layerIds);
    _managedSourceIdsOut
      ?..clear()
      ..addAll(_sourceIds);
    _registeredMapImagesOut
      ?..clear()
      ..addAll(_registeredImages);
  }
}
