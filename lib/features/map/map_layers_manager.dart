import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

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

  Future<void> addImage(String name, Uint8List bytes);

  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> data);
  Future<void> setLayerVisibility(String layerId, bool visible);
  Future<void> setLayerProperties(String layerId, ml.LayerProperties properties);

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
  Future<void> setLayerProperties(String layerId, ml.LayerProperties properties) {
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
    required this.cubeIconSpinDegrees,
    required this.cubeIconBobOffsetEm,
  });

  final String? pressedMarkerId;
  final String? hoveredMarkerId;
  final String? selectedMarkerId;

  /// 0..1 from the marker selection pop animation controller.
  final double selectionPopAnimationValue;

  final bool cubeLayerVisible;
  final double cubeIconSpinDegrees;
  final double cubeIconBobOffsetEm;
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
        <Object>['==', <Object>['id'], pressedId],
        MapMarkerStyleConfig.pressedScaleFactor,
      ]);
    }
    if (selectedId != null) {
      multiplier.addAll(<Object>[
        <Object>['==', <Object>['id'], selectedId],
        pop,
      ]);
    }
    if (hoveredId != null) {
      multiplier.addAll(<Object>[
        <Object>['==', <Object>['id'], hoveredId],
        MapMarkerStyleConfig.hoverScaleFactor,
      ]);
    }
    multiplier.add(1.0);

    return MapMarkerStyleConfig.iconSizeExpression(
      constantScale: constantScale,
      multiplier: <Object>['*', multiplier, entryScale],
    );
  }

  static Object interactiveIconImageExpression(KubusMarkerLayerStyleState state) {
    final selectedId = state.selectedMarkerId;
    if (selectedId == null || selectedId.isEmpty) {
      return const <Object>['get', 'icon'];
    }
    return <Object>[
      'case',
      <Object>['==', <Object>['id'], selectedId],
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
  }) async {
    if (!styleInitialized) return;
    if (styleEpoch != getCurrentStyleEpoch()) return;

    final canStyleMarkerLayer = managedLayerIds.contains(markerLayerId);
    final canStyleCubeIconLayer = managedLayerIds.contains(cubeIconLayerId);
    if (!canStyleMarkerLayer && !canStyleCubeIconLayer) return;

    final iconImage = interactiveIconImageExpression(state);
    final iconSize = interactiveIconSizeExpression(state);
    final cubeIconSize = interactiveIconSizeExpression(
      state,
      constantScale: 0.92,
    );
    final iconOpacity = <Object>[
      'case',
      <Object>['==', <Object>['get', 'kind'], 'cluster'],
      1.0,
      <Object>['coalesce', <Object>['get', 'entryOpacity'], 1.0],
    ];

    final markerVisible = !state.cubeLayerVisible;
    final cubeIconVisible = state.cubeLayerVisible;

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
            iconAnchor: 'center',
            iconPitchAlignment: 'map',
            iconRotationAlignment: 'map',
            visibility: markerVisible ? 'visible' : 'none',
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
            iconAnchor: 'center',
            iconPitchAlignment: 'viewport',
            iconRotationAlignment: 'viewport',
            iconOffset: MapMarkerStyleConfig.cubeFloatingIconOffsetEmWithBob(
              state.cubeIconBobOffsetEm,
            ),
            iconRotate: state.cubeIconSpinDegrees,
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
    required this.cubeSourceId,
    required this.cubeLayerId,
    required this.cubeIconLayerId,
    required this.locationSourceId,
    required this.locationLayerId,
    this.pendingSourceId,
    this.pendingLayerId,
  });

  final String markerSourceId;
  final String markerLayerId;
  final String markerHitboxLayerId;
  final String markerHitboxImageId;

  final String cubeSourceId;
  final String cubeLayerId;
  final String cubeIconLayerId;

  final String locationSourceId;
  final String locationLayerId;

  final String? pendingSourceId;
  final String? pendingLayerId;

  bool get supportsPending => pendingSourceId != null && pendingLayerId != null;
}

@immutable
class MapLayersThemeSpec {
  const MapLayersThemeSpec({
    required this.locationFill,
    required this.locationStroke,
    this.pendingFill,
    this.pendingStroke,
  });

  final Color locationFill;
  final Color locationStroke;

  final Color? pendingFill;
  final Color? pendingStroke;
}

@immutable
class MapLayersManagerStats {
  const MapLayersManagerStats({
    required this.addSourceCalls,
    required this.addLayerCalls,
    required this.removeLayerCalls,
    required this.removeSourceCalls,
    required this.sourceUpdateCalls,
    required this.layerPropertiesCalls,
    required this.visibilityCalls,
    required this.modeToggles,
  });

  final int addSourceCalls;
  final int addLayerCalls;
  final int removeLayerCalls;
  final int removeSourceCalls;
  final int sourceUpdateCalls;
  final int layerPropertiesCalls;
  final int visibilityCalls;
  final int modeToggles;
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

  int? _initializedForStyleEpoch;
  MapRenderMode _currentMode = MapRenderMode.twoD;
  MapLayersThemeSpec? _themeSpec;

  Completer<void>? _initCompleter;

  int _addSourceCalls = 0;
  int _addLayerCalls = 0;
  int _removeLayerCalls = 0;
  int _removeSourceCalls = 0;
  int _sourceUpdateCalls = 0;
  int _layerPropertiesCalls = 0;
  int _visibilityCalls = 0;
  int _modeToggles = 0;

  MapLayersManagerStats get stats => MapLayersManagerStats(
        addSourceCalls: _addSourceCalls,
        addLayerCalls: _addLayerCalls,
        removeLayerCalls: _removeLayerCalls,
        removeSourceCalls: _removeSourceCalls,
        sourceUpdateCalls: _sourceUpdateCalls,
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

  Future<void> upsertMarkerData(Map<String, dynamic> featureCollection) async {
    if (!hasSource(_ids.markerSourceId)) return;
    try {
      _sourceUpdateCalls += 1;
      await _controller.setGeoJsonSource(_ids.markerSourceId, featureCollection);
    } catch (_) {
      // Best-effort: style swaps can invalidate the source mid-flight.
    }
  }

  Future<void> upsertCubeData(Map<String, dynamic> featureCollection) async {
    if (!hasSource(_ids.cubeSourceId)) return;
    try {
      _sourceUpdateCalls += 1;
      await _controller.setGeoJsonSource(_ids.cubeSourceId, featureCollection);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> upsertUserLocationData(Map<String, dynamic> featureCollection) async {
    if (!hasSource(_ids.locationSourceId)) return;
    try {
      _sourceUpdateCalls += 1;
      await _controller.setGeoJsonSource(_ids.locationSourceId, featureCollection);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> upsertPendingMarkerData(Map<String, dynamic> featureCollection) async {
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
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.cubeLayerId);
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.cubeIconLayerId);
    await _safeRemoveLayerIfExists(existingLayerIds, _ids.locationLayerId);
    if (_ids.pendingLayerId != null) {
      await _safeRemoveLayerIfExists(existingLayerIds, _ids.pendingLayerId!);
    }

    await _safeRemoveSource(_ids.markerSourceId);
    await _safeRemoveSource(_ids.cubeSourceId);
    await _safeRemoveSource(_ids.locationSourceId);
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
      _ids.cubeSourceId,
      const <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      },
      promoteId: 'id',
    );
    _addSourceCalls += 1;
    _sourceIds.add(_ids.cubeSourceId);

    // Layer order (bottom to top):
    // 1) cube extrusion
    // 2) marker symbol
    // 3) cube floating icon
    // 4) marker hitbox

    await _controller.addFillExtrusionLayer(
      _ids.cubeSourceId,
      _ids.cubeLayerId,
      ml.FillExtrusionLayerProperties(
        fillExtrusionColor: <Object>['get', 'color'],
        fillExtrusionHeight: <Object>['get', 'height'],
        fillExtrusionBase: 0.0,
        fillExtrusionOpacity: 0.95,
        fillExtrusionVerticalGradient: false,
        visibility: 'none',
      ),
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.cubeLayerId);

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
            'case',
            <Object>['==', <Object>['get', 'kind'], 'cluster'],
            1.0,
            <Object>['coalesce', <Object>['get', 'entryOpacity'], 1.0],
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          iconPitchAlignment: 'map',
          iconRotationAlignment: 'map',
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
            'case',
            <Object>['==', <Object>['get', 'kind'], 'cluster'],
            1.0,
            <Object>['coalesce', <Object>['get', 'entryOpacity'], 1.0],
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          iconPitchAlignment: 'viewport',
          iconRotationAlignment: 'viewport',
          iconOffset: MapMarkerStyleConfig.cubeFloatingIconOffsetEm,
          visibility: 'none',
        ),
    );
    _addLayerCalls += 1;
    _layerIds.add(_ids.cubeIconLayerId);

    await _ensureHitboxImageRegistered();

    final Object hitboxIconSize = kIsWeb
        ? 60.0
        : <Object>[
            'interpolate',
            <Object>['linear'],
            <Object>['zoom'],
            3,
            <Object>[
              'case',
              <Object>['==', <Object>['get', 'kind'], 'cluster'],
              50,
              36,
            ],
            12,
            <Object>[
              'case',
              <Object>['==', <Object>['get', 'kind'], 'cluster'],
              64,
              44,
            ],
            15,
            <Object>[
              'case',
              <Object>['==', <Object>['get', 'kind'], 'cluster'],
              76,
              56,
            ],
            24,
            <Object>[
              'case',
              <Object>['==', <Object>['get', 'kind'], 'cluster'],
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
          iconAnchor: 'center',
          iconPitchAlignment: 'map',
          iconRotationAlignment: 'map',
        ),
      );
      _addLayerCalls += 1;
    } catch (_) {
      final Object hitboxRadius = kIsWeb
          ? 32.0
          : <Object>[
              'interpolate',
              <Object>['linear'],
              <Object>['zoom'],
              3,
              <Object>[
                'case',
                <Object>['==', <Object>['get', 'kind'], 'cluster'],
                25,
                18,
              ],
              12,
              <Object>[
                'case',
                <Object>['==', <Object>['get', 'kind'], 'cluster'],
                32,
                22,
              ],
              15,
              <Object>[
                'case',
                <Object>['==', <Object>['get', 'kind'], 'cluster'],
                38,
                28,
              ],
              24,
              <Object>[
                'case',
                <Object>['==', <Object>['get', 'kind'], 'cluster'],
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

  Uint8List _createTransparentSquareImage() {
    const String base64Png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    return Uint8List.fromList(base64Decode(base64Png));
  }

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
