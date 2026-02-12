import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../../config/config.dart';
import '../../../models/art_marker.dart';
import '../../../utils/debouncer.dart';
import '../../../utils/map_tap_gating.dart';
import '../shared/map_marker_collision_config.dart';
import '../shared/map_marker_collision_utils.dart';
import '../map_layers_manager.dart';

@immutable
class KubusMapControllerIds {
  const KubusMapControllerIds({
    required this.layers,
  });

  final MapLayersIds layers;
}

@immutable
class KubusMapCameraState {
  const KubusMapCameraState({
    required this.center,
    required this.zoom,
    required this.bearing,
    required this.pitch,
  });

  final LatLng center;
  final double zoom;
  final double bearing;
  final double pitch;
}

@immutable
class KubusMarkerSelectionState {
  const KubusMarkerSelectionState({
    required this.selectionToken,
    required this.selectedMarkerId,
    required this.selectedMarker,
    required this.selectedAt,
    required this.stackedMarkers,
    required this.stackIndex,
  });

  final int selectionToken;
  final String? selectedMarkerId;
  final ArtMarker? selectedMarker;
  final DateTime? selectedAt;

  /// Markers considered "stacked" at the same coordinate (within tolerance).
  final List<ArtMarker> stackedMarkers;

  /// Index into [stackedMarkers] for [selectedMarker].
  final int stackIndex;

  bool get hasSelection =>
      selectedMarkerId != null && selectedMarkerId!.isNotEmpty;
}

@immutable
class KubusRenderedMarker {
  const KubusRenderedMarker({
    required this.marker,
    required this.position,
    required this.entryScale,
    required this.entryOpacity,
    required this.entrySerial,
    required this.sameCoordinateKey,
    required this.isSpiderfied,
  });

  final ArtMarker marker;
  final LatLng position;
  final double entryScale;
  final double entryOpacity;
  final int entrySerial;
  final String sameCoordinateKey;
  final bool isSpiderfied;
}

@immutable
class KubusMapTapConfig {
  const KubusMapTapConfig({
    this.sameCoordinateMeters = 0.75,
    this.tapTolerancePx = 6.0,
    this.clusterIdPrefix = 'cluster:',
    this.sameLocationClusterIdPrefix = 'cluster_same:',
    this.clusterTapZoomDelta = 1.5,
    this.clusterTapMaxZoom = 18.0,
    this.spiderfyAutoExpandZoom =
        MapMarkerCollisionConfig.spiderfyAutoExpandZoom,
  });

  /// Distance threshold for considering two markers as "stacked".
  final double sameCoordinateMeters;

  /// Tap query rect size (radius).
  final double tapTolerancePx;

  /// Prefix used by web feature-tap events for clusters.
  final String clusterIdPrefix;

  /// Prefix used by web feature-tap events for same-location clusters.
  final String sameLocationClusterIdPrefix;

  /// How much to zoom in when tapping a cluster.
  final double clusterTapZoomDelta;

  /// Upper bound for cluster-tap zoom.
  final double clusterTapMaxZoom;

  /// Zoom threshold where stacked same-location marker selections auto-spiderfy.
  final double spiderfyAutoExpandZoom;
}

/// Shared controller for MapLibre-based map screens.
///
/// Responsibilities (shared between mobile + desktop):
/// - attach/detach MapLibre controller + feature listeners
/// - style epoch handling + MapLayersManager initialization
/// - marker selection + stacked marker logic
/// - camera state tracking + auto-follow cancellation on user pan
/// - marker overlay anchor refresh (screen-space anchor)
///
/// Non-responsibilities:
/// - marker fetching/networking
/// - UI composition/layout
/// - provider initialization
///
/// The screen remains responsible for:
/// - calling [setMarkers] when the marker list changes
/// - calling [setMarkerTypeVisibility] when filter toggles change
/// - wiring [handleCameraMove]/[handleCameraIdle]/[handleMapClick] into the map widget
/// - reacting to selection changes (open/close overlays, side panels)
class KubusMapController {
  KubusMapController({
    required this.ids,
    required this.debugTracing,
    required this.tapConfig,
    required Distance distance,
    this.supportsPendingMarker = false,
    this.dismissSelectionOnUserGesture = true,
    Set<String>? managedLayerIdsOut,
    Set<String>? managedSourceIdsOut,
    Set<String>? registeredMapImagesOut,
    this.onSelectionChanged,
    this.onAutoFollowChanged,
    this.onBackgroundTap,
    this.onRequestMarkerLayerStyleUpdate,
    this.onRequestMarkerDataSync,
  })  : _distance = distance,
        managedLayerIds = managedLayerIdsOut ?? <String>{},
        managedSourceIds = managedSourceIdsOut ?? <String>{},
        registeredMapImages = registeredMapImagesOut ?? <String>{};

  final KubusMapControllerIds ids;
  final bool debugTracing;
  final KubusMapTapConfig tapConfig;
  final bool supportsPendingMarker;

  /// Whether a user pan/zoom gesture should close an active marker selection.
  ///
  /// Desktop uses this to avoid confusing anchored overlays while panning.
  /// Mobile keeps the selection open and just re-anchors it.
  final bool dismissSelectionOnUserGesture;

  final Distance _distance;

  /// Called when selection changes (including dismissal).
  final ValueChanged<KubusMarkerSelectionState>? onSelectionChanged;

  /// Called when auto-follow changes due to a user gesture.
  final ValueChanged<bool>? onAutoFollowChanged;

  /// Called when the user taps/clicks on the map background (no marker hit).
  ///
  /// Screens can use this to close side panels / overlays that are not owned
  /// by this controller.
  final VoidCallback? onBackgroundTap;

  /// Called when pressed/hover/selection changes and the screen should restyle marker layers.
  final VoidCallback? onRequestMarkerLayerStyleUpdate;

  /// Called when marker feature payload should be rebuilt (spiderfy or
  /// viewport entry animation state changed).
  final VoidCallback? onRequestMarkerDataSync;

  ml.MapLibreMapController? _mapController;
  MapLayersManager? _layersManager;

  ml.MapLibreMapController? get mapController => _mapController;
  MapLayersManager? get layersManager => _layersManager;

  bool _styleInitialized = false;
  bool _styleInitializationInProgress = false;
  int _styleEpoch = 0;

  /// Exposed so screens can keep their existing guards while the refactor is incremental.
  ///
  /// Screens may pass their own sets to the constructor to keep existing debug
  /// overlays / guards in sync with the manager.
  final Set<String> managedLayerIds;
  final Set<String> managedSourceIds;
  final Set<String> registeredMapImages;

  bool _hitboxLayerReady = false;
  int _hitboxLayerEpoch = -1;

  // Feature listener bookkeeping.
  ml.MapLibreMapController? _featureTapBoundController;
  ml.MapLibreMapController? _featureHoverBoundController;
  DateTime? _lastFeatureTapAt;
  math.Point<double>? _lastFeatureTapPoint;

  /// Timestamp of the most recent web feature-tap event.
  ///
  /// Used by screens to ignore a subsequent `onMapClick` that MapLibre may fire
  /// for the same user action (common on web when interactive layers are hit).
  DateTime? get lastFeatureTapAt => _lastFeatureTapAt;

  /// Screen-space point of the most recent web feature-tap event.
  math.Point<double>? get lastFeatureTapPoint => _lastFeatureTapPoint;

  // Camera state.
  KubusMapCameraState _camera = const KubusMapCameraState(
    center: LatLng(46.056946, 14.505751),
    zoom: 16.0,
    bearing: 0.0,
    pitch: 0.0,
  );

  bool _programmaticCameraMove = false;
  bool _cameraIsMoving = false;

  bool get programmaticCameraMove => _programmaticCameraMove;

  /// Screens that still own some camera animations can keep gesture detection
  /// consistent by syncing their programmatic-move flag into this controller.
  void setProgrammaticCameraMove(bool value) {
    _programmaticCameraMove = value;
  }

  bool _autoFollow = true;

  // Marker data.
  List<ArtMarker> _markers = const <ArtMarker>[];
  Map<ArtMarkerType, bool> _markerTypeVisibility =
      const <ArtMarkerType, bool>{};

  // Selection / interaction.
  int _markerSelectionToken = 0;
  String? _selectedMarkerId;
  ArtMarker? _selectedMarkerData;
  List<ArtMarker> _selectedMarkerStack = const <ArtMarker>[];
  int _selectedMarkerStackIndex = 0;
  DateTime? _selectedMarkerAt;

  String? _hoveredMarkerId;
  String? _pressedMarkerId;
  Timer? _pressedClearTimer;

  final ValueNotifier<double> bearingDegrees = ValueNotifier<double>(0.0);

  /// Screen-space anchor for the selected marker. Used by both mobile and desktop overlays.
  final ValueNotifier<Offset?> selectedMarkerAnchor =
      ValueNotifier<Offset?>(null);

  final Debouncer _overlayAnchorDebouncer = Debouncer();
  final Debouncer _viewportVisibilityDebouncer = Debouncer();
  Timer? _viewportInitRetryTimer;
  int _viewportInitAttemptCount = 0;

  Timer? _entryAnimationTicker;
  bool _viewportStateInitialized = false;
  Set<String> _visibleMarkerIds = <String>{};
  final Map<String, _MarkerEntryAnimationState> _entryAnimationByMarkerId =
      <String, _MarkerEntryAnimationState>{};

  String? _expandedCoordinateKey;
  final Map<String, LatLng> _spiderfiedPositionByMarkerId = <String, LatLng>{};
  int _entrySerialCounter = 0;

  KubusMapCameraState get camera => _camera;
  bool get autoFollow => _autoFollow;
  bool get cameraIsMoving => _cameraIsMoving;

  bool get styleInitialized => _styleInitialized;
  bool get styleInitializationInProgress => _styleInitializationInProgress;
  int get styleEpoch => _styleEpoch;

  String? get selectedMarkerId => _selectedMarkerId;
  ArtMarker? get selectedMarkerData => _selectedMarkerData;
  List<ArtMarker> get selectedMarkerStack => _selectedMarkerStack;
  int get selectedMarkerStackIndex => _selectedMarkerStackIndex;
  DateTime? get selectedMarkerAt => _selectedMarkerAt;
  String? get expandedCoordinateKey => _expandedCoordinateKey;
  bool get hasExpandedSameLocation => _expandedCoordinateKey != null;

  String? get hoveredMarkerId => _hoveredMarkerId;
  String? get pressedMarkerId => _pressedMarkerId;

  KubusMarkerSelectionState get selectionState => KubusMarkerSelectionState(
        selectionToken: _markerSelectionToken,
        selectedMarkerId: _selectedMarkerId,
        selectedMarker: _selectedMarkerData,
        selectedAt: _selectedMarkerAt,
        stackedMarkers: _selectedMarkerStack,
        stackIndex: _selectedMarkerStackIndex,
      );

  void setAutoFollow(bool enabled) {
    if (_autoFollow == enabled) return;
    _autoFollow = enabled;
    onAutoFollowChanged?.call(_autoFollow);
  }

  void setMarkers(List<ArtMarker> markers) {
    _markers = markers;
    _pruneSpiderfyStateIfNeeded();

    // Keep selection data fresh when marker instances are replaced during
    // polling/refresh.
    _refreshSelectionFromLatestMarkers();
    _primeInitialViewportVisibilityIfNeeded();
    _queueViewportVisibilityRefresh(force: true);
  }

  void _refreshSelectionFromLatestMarkers() {
    final selectedId = _selectedMarkerId;
    if (selectedId == null || selectedId.isEmpty) return;

    final latest = _findMarkerById(selectedId);
    if (latest == null) {
      // Selected marker no longer exists.
      dismissSelection();
      return;
    }

    // Recompute stack based on latest marker instance + current visibility.
    final nextStack = _computeMarkerStack(latest, pinSelectedFirst: false);
    final nextIndex = nextStack.indexWhere((m) => m.id == latest.id);
    final resolvedIndex = nextIndex >= 0 ? nextIndex : 0;

    final dataChanged = !identical(_selectedMarkerData, latest);
    final stackChanged = nextStack.length != _selectedMarkerStack.length ||
        !_listsEqualById(_selectedMarkerStack, nextStack);
    final indexChanged = resolvedIndex != _selectedMarkerStackIndex;

    _selectedMarkerData = latest;
    _selectedMarkerStack = nextStack;
    _selectedMarkerStackIndex = resolvedIndex;

    if (dataChanged || stackChanged || indexChanged) {
      onSelectionChanged?.call(selectionState);
      queueOverlayAnchorRefresh(force: true);
      _maybeAutoExpandSelectedSameLocation();
    }
  }

  static bool _listsEqualById(List<ArtMarker> a, List<ArtMarker> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void setMarkerTypeVisibility(Map<ArtMarkerType, bool> visibility) {
    _markerTypeVisibility = visibility;
    _pruneSpiderfyStateIfNeeded();
    _primeInitialViewportVisibilityIfNeeded();
    _queueViewportVisibilityRefresh(force: true);
  }

  void attachMapController(ml.MapLibreMapController controller) {
    // Idempotent attach.
    if (_mapController == controller) return;

    // Detach any existing controller first.
    detachMapController();

    _mapController = controller;

    _layersManager = MapLayersManager(
      controller: MapLibreLayersController(controller),
      ids: ids.layers,
      debugTracing: debugTracing,
      managedLayerIdsOut: managedLayerIds,
      managedSourceIdsOut: managedSourceIds,
      registeredMapImagesOut: registeredMapImages,
    );

    _bindFeatureTapController(controller);

    _styleInitialized = false;
    _styleInitializationInProgress = false;
    _hitboxLayerReady = false;
    _hitboxLayerEpoch = -1;
    _styleEpoch += 1;

    registeredMapImages.clear();
    managedLayerIds.clear();
    managedSourceIds.clear();
  }

  void detachMapController() {
    final controller = _mapController;
    if (controller == null) return;

    try {
      controller.onFeatureTapped.remove(_handleMapFeatureTapped);
      controller.onFeatureHover.remove(_handleMapFeatureHover);
    } catch (_) {
      // Best-effort.
    }

    if (_featureTapBoundController == controller) {
      _featureTapBoundController = null;
    }
    if (_featureHoverBoundController == controller) {
      _featureHoverBoundController = null;
    }

    _mapController = null;
    _layersManager = null;

    _styleInitialized = false;
    _styleInitializationInProgress = false;
    _hitboxLayerReady = false;
    _hitboxLayerEpoch = -1;
    _styleEpoch += 1;

    registeredMapImages.clear();
    managedLayerIds.clear();
    managedSourceIds.clear();

    // Clear in-flight pressed timer.
    _pressedClearTimer?.cancel();
    _pressedClearTimer = null;
    _pressedMarkerId = null;

    // Clear anchor.
    selectedMarkerAnchor.value = null;

    _collapseSpiderfy(requestSync: false);
    _entryAnimationTicker?.cancel();
    _entryAnimationTicker = null;
    _entryAnimationByMarkerId.clear();
    _visibleMarkerIds.clear();
    _viewportStateInitialized = false;
    _viewportInitRetryTimer?.cancel();
    _viewportInitRetryTimer = null;
    _viewportInitAttemptCount = 0;

    // Cancel debouncers so in-flight callbacks don't fire after detach and
    // try to call methods on the now-null controller.
    _overlayAnchorDebouncer.cancel();
    _viewportVisibilityDebouncer.cancel();
  }

  void dispose() {
    detachMapController();
    _overlayAnchorDebouncer.dispose();
    _viewportVisibilityDebouncer.dispose();
    bearingDegrees.dispose();
    selectedMarkerAnchor.dispose();
  }

  void _bindFeatureTapController(ml.MapLibreMapController controller) {
    if (_featureTapBoundController == controller) return;

    if (_featureTapBoundController != null) {
      _featureTapBoundController?.onFeatureTapped
          .remove(_handleMapFeatureTapped);
    }

    _featureTapBoundController = controller;
    controller.onFeatureTapped.add(_handleMapFeatureTapped);

    _bindFeatureHoverController(controller);
  }

  void _bindFeatureHoverController(ml.MapLibreMapController controller) {
    if (!kIsWeb) return;
    if (_featureHoverBoundController == controller) return;

    if (_featureHoverBoundController != null) {
      _featureHoverBoundController?.onFeatureHover
          .remove(_handleMapFeatureHover);
    }

    _featureHoverBoundController = controller;
    controller.onFeatureHover.add(_handleMapFeatureHover);
  }

  /// Call from the screen's `onStyleLoaded` callback.
  Future<void> handleStyleLoaded({
    required MapLayersThemeSpec themeSpec,
    bool applyIsometric = false,
    bool adjustZoomForIsometricScale = false,
  }) async {
    final controller = _mapController;
    final layersManager = _layersManager;
    if (controller == null || layersManager == null) return;
    if (_styleInitializationInProgress) return;

    _styleInitializationInProgress = true;
    _styleInitialized = false;

    _styleEpoch += 1;
    _hitboxLayerReady = false;
    _hitboxLayerEpoch = -1;

    registeredMapImages.clear();
    managedLayerIds.clear();
    managedSourceIds.clear();

    layersManager.onNewStyle(styleEpoch: _styleEpoch);
    layersManager.updateThemeSpec(themeSpec);

    try {
      await layersManager.ensureInitialized(styleEpoch: _styleEpoch);

      _styleInitialized = true;
      _hitboxLayerReady = true;
      _hitboxLayerEpoch = _styleEpoch;

      // Optional camera adjustment.
      if (applyIsometric) {
        await applyIsometricCamera(
          enabled: true,
          adjustZoomForScale: adjustZoomForIsometricScale,
        );
      }

      // Refresh overlay anchor (if any selection exists).
      queueOverlayAnchorRefresh(force: true);
      _primeInitialViewportVisibilityIfNeeded();
      _queueViewportVisibilityRefresh(force: true);
    } catch (e, st) {
      _styleInitialized = false;
      if (kDebugMode) {
        AppConfig.debugPrint('KubusMapController: style init failed: $e');
        AppConfig.debugPrint('KubusMapController: style init stack: $st');
      }
    } finally {
      _styleInitializationInProgress = false;
    }
  }

  void handleCameraMove(ml.CameraPosition position) {
    if (_mapController == null) return;
    _cameraIsMoving = true;

    final bool hasGesture = !_programmaticCameraMove;
    if (hasGesture && _autoFollow) {
      _autoFollow = false;
      onAutoFollowChanged?.call(_autoFollow);
    }

    final nextCenter =
        LatLng(position.target.latitude, position.target.longitude);
    final nextZoom = position.zoom;
    final nextBearing = position.bearing;
    final nextPitch = position.tilt;

    final bearingChanged = (nextBearing - _camera.bearing).abs() > 0.1;

    _camera = KubusMapCameraState(
      center: nextCenter,
      zoom: nextZoom,
      bearing: nextBearing,
      pitch: nextPitch,
    );

    if (bearingChanged) {
      bearingDegrees.value = nextBearing;
    }

    if (_expandedCoordinateKey != null && hasGesture) {
      _collapseSpiderfy();
    }

    // If the user is panning while an overlay is open, close it.
    // This keeps selection + composition stable.
    if (dismissSelectionOnUserGesture &&
        hasGesture &&
        _selectedMarkerId != null) {
      dismissSelection();
    }

    if (_selectedMarkerData != null) {
      queueOverlayAnchorRefresh();
    }

    _queueViewportVisibilityRefresh();
  }

  void handleCameraIdle({required bool fromProgrammaticMove}) {
    if (_mapController == null) return;
    _cameraIsMoving = false;
    _programmaticCameraMove = false;

    if (_selectedMarkerData != null) {
      queueOverlayAnchorRefresh(force: true);
    }
    unawaited(_maybeAutoExpandSameLocationAtHighZoom());

    _queueViewportVisibilityRefresh(force: true);

    // Screen handles marker refresh scheduling; controller does not fetch.
    // This is intentionally a hook rather than embedded side effects.
    // (keeps provider lifecycle stable and avoids surprises.)
    //
    // Note: the hook is invoked with `fromGesture = !fromProgrammaticMove`.
    //
    // No-op here; screens can still wire their existing logic.
  }

  math.Point<double>? _coerceScreenPoint(Object? rawPoint) {
    if (rawPoint is math.Point) {
      final x = (rawPoint.x as num?)?.toDouble();
      final y = (rawPoint.y as num?)?.toDouble();
      if (x == null || y == null || !x.isFinite || !y.isFinite) {
        return null;
      }
      return math.Point<double>(x, y);
    }

    if (rawPoint is Map) {
      final x = (rawPoint['x'] as num?)?.toDouble();
      final y = (rawPoint['y'] as num?)?.toDouble();
      if (x == null || y == null || !x.isFinite || !y.isFinite) {
        return null;
      }
      return math.Point<double>(x, y);
    }

    return null;
  }

  LatLng? _coerceLatLng(Object? rawCoordinates) {
    if (rawCoordinates is ml.LatLng) {
      final lat = rawCoordinates.latitude;
      final lng = rawCoordinates.longitude;
      if (!lat.isFinite || !lng.isFinite) return null;
      return LatLng(lat, lng);
    }

    if (rawCoordinates is Map) {
      final lat = ((rawCoordinates['lat'] ?? rawCoordinates['latitude']) as num?)
          ?.toDouble();
      final lng = ((rawCoordinates['lng'] ?? rawCoordinates['longitude']) as num?)
          ?.toDouble();
      if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
        return null;
      }
      return LatLng(lat, lng);
    }

    return null;
  }

  bool _isFiniteScreenPoint(math.Point<double> point) =>
      point.x.isFinite && point.y.isFinite;

  /// Web only: invoked via MapLibre's onFeatureTapped.
  void _handleMapFeatureTapped(
    dynamic point,
    dynamic coordinates,
    dynamic id,
    dynamic layerId,
    dynamic annotation,
  ) {
    final tapPoint = _coerceScreenPoint(point);
    final tappedCoordinates = _coerceLatLng(coordinates);
    final featureId = id?.toString();
    if (tapPoint == null ||
        tappedCoordinates == null ||
        featureId == null ||
        featureId.isEmpty) {
      return;
    }

    _lastFeatureTapAt = DateTime.now();
    _lastFeatureTapPoint = tapPoint;

    if (featureId.startsWith(tapConfig.sameLocationClusterIdPrefix)) {
      final coordinateKey =
          featureId.substring(tapConfig.sameLocationClusterIdPrefix.length);
      unawaited(
        expandSpiderfyForCoordinateKey(
          coordinateKey,
          anchor: tappedCoordinates,
          triggerSelection: true,
        ),
      );
      return;
    }

    if (featureId.startsWith(tapConfig.clusterIdPrefix)) {
      _collapseSpiderfy();
      final nextZoom = math.min(
        _camera.zoom + tapConfig.clusterTapZoomDelta,
        tapConfig.clusterTapMaxZoom,
      );
      unawaited(
        animateTo(
          tappedCoordinates,
          zoom: nextZoom,
        ),
      );
      return;
    }

    final selected = _findMarkerById(featureId);
    if (selected == null) return;

    final stack = _computeMarkerStack(selected, pinSelectedFirst: true);
    selectMarker(stack.first, stackedMarkers: stack);
  }

  /// Web only: invoked via MapLibre's onFeatureHover.
  void _handleMapFeatureHover(
    dynamic point,
    dynamic coordinates,
    dynamic id,
    dynamic annotation,
    dynamic eventType,
  ) {
    if (!kIsWeb) return;

    final featureId = id?.toString();
    if (featureId == null || featureId.isEmpty) {
      if (_hoveredMarkerId != null) {
        _hoveredMarkerId = null;
        onRequestMarkerLayerStyleUpdate?.call();
      }
      return;
    }

    if (featureId.startsWith(tapConfig.clusterIdPrefix) ||
        featureId.startsWith(tapConfig.sameLocationClusterIdPrefix)) {
      if (_hoveredMarkerId != null) {
        _hoveredMarkerId = null;
        onRequestMarkerLayerStyleUpdate?.call();
      }
      return;
    }

    final isLeave = eventType == ml.HoverEventType.leave ||
        eventType?.toString() == 'HoverEventType.leave';
    final next = isLeave ? null : featureId;
    if (next == _hoveredMarkerId) return;
    _hoveredMarkerId = next;
    onRequestMarkerLayerStyleUpdate?.call();
  }

  /// Non-web: call from the map widget's onMapClick.
  Future<void> handleMapClick(
    math.Point<double> point, {
    required bool isWeb,
  }) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_isFiniteScreenPoint(point)) return;

    if (MapTapGating.shouldIgnoreMapClickAfterFeatureTap(
      lastFeatureTapAt: _lastFeatureTapAt,
      lastFeatureTapPoint: _lastFeatureTapPoint,
      clickPoint: point,
    )) {
      return;
    }

    if (isWeb) {
      // On web, feature hits are delivered via onFeatureTapped; treat this
      // callback as "background" tap.
      _collapseSpiderfy();
      onBackgroundTap?.call();
      dismissSelection();
      return;
    }

    // If style isn't ready, try a best-effort fallback pick.
    if (_styleInitializationInProgress || !_styleInitialized) {
      final fallback = await _fallbackPickMarkerAtPoint(point);
      if (fallback != null) {
        final stack = _computeMarkerStack(fallback, pinSelectedFirst: true);
        selectMarker(stack.first, stackedMarkers: stack);
      }
      return;
    }

    if (!await _canQueryMarkerHitbox(forceRefresh: true)) {
      final fallback = await _fallbackPickMarkerAtPoint(point);
      if (fallback != null) {
        final stack = _computeMarkerStack(fallback, pinSelectedFirst: true);
        selectMarker(stack.first, stackedMarkers: stack);
      }
      return;
    }

    try {
      const double tapTolerance = 6.0;
      final rect = Rect.fromCenter(
        center: Offset(point.x, point.y),
        width: tapTolerance * 2,
        height: tapTolerance * 2,
      );

      final features = await controller.queryRenderedFeaturesInRect(
        rect,
        <String>[ids.layers.markerHitboxLayerId],
        null,
      );

      if (features.isEmpty) {
        _collapseSpiderfy();
        onBackgroundTap?.call();
        dismissSelection();
        return;
      }

      final dynamic first = features.first;
      final propsRaw = first is Map ? first['properties'] : null;
      final Map props = propsRaw is Map ? propsRaw : const <String, dynamic>{};
      final kind = props['kind']?.toString();

      if (kind == 'cluster') {
        final coordinateKey = props['sameCoordinateKey']?.toString();
        if (coordinateKey != null && coordinateKey.isNotEmpty) {
          await expandSpiderfyForCoordinateKey(
            coordinateKey,
            anchor: LatLng(
              (props['lat'] as num?)?.toDouble() ?? _camera.center.latitude,
              (props['lng'] as num?)?.toDouble() ?? _camera.center.longitude,
            ),
            triggerSelection: true,
          );
          return;
        }

        final lng = (props['lng'] as num?)?.toDouble();
        final lat = (props['lat'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        _collapseSpiderfy();
        final nextZoom = math.min(
          _camera.zoom + tapConfig.clusterTapZoomDelta,
          tapConfig.clusterTapMaxZoom,
        );
        await animateTo(LatLng(lat, lng), zoom: nextZoom);
        return;
      }

      final markerId = (props['markerId'] ?? props['id'])?.toString() ?? '';
      if (markerId.isEmpty) return;

      final selected = _findMarkerById(markerId);
      if (selected == null) return;

      final stack = _computeMarkerStack(selected, pinSelectedFirst: true);
      selectMarker(stack.first, stackedMarkers: stack);
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint(
            'KubusMapController: queryRenderedFeatures failed: $e');
      }
      _hitboxLayerReady = false;
      _hitboxLayerEpoch = -1;

      // Treat failures as a background tap (but still try fallback picking).
      _collapseSpiderfy();
      onBackgroundTap?.call();

      final fallback = await _fallbackPickMarkerAtPoint(point);
      if (fallback == null) return;
      final stack = _computeMarkerStack(fallback, pinSelectedFirst: true);
      selectMarker(stack.first, stackedMarkers: stack);
    }
  }

  void selectMarker(
    ArtMarker marker, {
    List<ArtMarker>? stackedMarkers,
    int? stackIndex,
  }) {
    // Guard against rapid repeated taps on the same marker.
    if (_selectedMarkerId == marker.id && _selectedMarkerAt != null) {
      final elapsed = DateTime.now().difference(_selectedMarkerAt!);
      if (elapsed.inMilliseconds < 300) return;
    }

    final stack =
        stackedMarkers ?? _computeMarkerStack(marker, pinSelectedFirst: true);
    final int nextIndex;
    if (stackIndex != null) {
      nextIndex = stackIndex.clamp(0, math.max(0, stack.length - 1));
    } else {
      nextIndex = 0;
    }

    final effective = stack.isNotEmpty ? stack[nextIndex] : marker;

    // Selecting a marker implies exploration; stop snapping back to user.
    if (_autoFollow) {
      _autoFollow = false;
      onAutoFollowChanged?.call(_autoFollow);
    }

    _markerSelectionToken += 1;
    _selectedMarkerStack = stack;
    _selectedMarkerStackIndex = nextIndex;
    _selectedMarkerId = effective.id;
    _selectedMarkerData = effective;
    _selectedMarkerAt = DateTime.now();

    selectedMarkerAnchor.value = null;

    _startPressedMarkerFeedback(effective.id);

    onSelectionChanged?.call(selectionState);
    onRequestMarkerLayerStyleUpdate?.call();

    queueOverlayAnchorRefresh(force: true);
    _maybeAutoExpandSelectedSameLocation();
  }

  void dismissSelection() {
    if (_selectedMarkerId == null && _selectedMarkerData == null) return;

    _selectedMarkerId = null;
    _selectedMarkerData = null;
    _selectedMarkerAt = null;
    _selectedMarkerStack = const <ArtMarker>[];
    _selectedMarkerStackIndex = 0;

    selectedMarkerAnchor.value = null;

    _pressedClearTimer?.cancel();
    _pressedClearTimer = null;
    _pressedMarkerId = null;

    onSelectionChanged?.call(selectionState);
    onRequestMarkerLayerStyleUpdate?.call();
    _collapseSpiderfy();
  }

  /// Update the active marker within the current stacked selection without
  /// incrementing the selection token.
  ///
  /// Used when paging through overlapping markers; this should not trigger
  /// "new selection" side effects like haptics/focus animations.
  void setSelectedStackIndex(int index) {
    final stack = _selectedMarkerStack;
    if (stack.isEmpty) return;
    final int desired = index < 0
        ? 0
        : (index >= stack.length ? math.max(0, stack.length - 1) : index);
    if (desired == _selectedMarkerStackIndex) return;

    // Check if the previous and next marker share the same position.
    // If so, keep the current anchor to avoid a layout flash in the overlay.
    final prev = stack[_selectedMarkerStackIndex];
    final next = stack[desired];
    final samePosition = prev.position.latitude == next.position.latitude &&
        prev.position.longitude == next.position.longitude;

    _selectedMarkerStackIndex = desired;
    _selectedMarkerId = next.id;
    _selectedMarkerData = next;

    if (!samePosition) {
      selectedMarkerAnchor.value = null;
    }

    onSelectionChanged?.call(selectionState);
    onRequestMarkerLayerStyleUpdate?.call();
    queueOverlayAnchorRefresh(force: true);
    _maybeAutoExpandSelectedSameLocation();
  }

  void _startPressedMarkerFeedback(String markerId) {
    _pressedClearTimer?.cancel();
    _pressedClearTimer = null;

    _pressedMarkerId = markerId;
    onRequestMarkerLayerStyleUpdate?.call();

    _pressedClearTimer = Timer(const Duration(milliseconds: 120), () {
      if (_pressedMarkerId != markerId) return;
      _pressedMarkerId = null;
      onRequestMarkerLayerStyleUpdate?.call();
    });
  }

  void queueOverlayAnchorRefresh({bool force = false}) {
    if (_selectedMarkerData == null) return;
    if (!_styleInitialized) return;

    final delay = force ? Duration.zero : const Duration(milliseconds: 66);
    _overlayAnchorDebouncer(delay, () {
      unawaited(_refreshActiveMarkerAnchor());
    });
  }

  Future<void> _refreshActiveMarkerAnchor() async {
    final controller = _mapController;
    final marker = _selectedMarkerData;
    if (controller == null || marker == null) return;
    if (!_styleInitialized) return;

    try {
      final screen = await controller.toScreenLocation(
        ml.LatLng(marker.position.latitude, marker.position.longitude),
      );
      final next = Offset(screen.x.toDouble(), screen.y.toDouble());
      if (selectedMarkerAnchor.value == next) return;
      selectedMarkerAnchor.value = next;
    } catch (_) {
      // Ignore projection failures during style transitions.
    }
  }

  List<ArtMarker> _computeMarkerStack(
    ArtMarker marker, {
    required bool pinSelectedFirst,
  }) {
    if (!marker.hasValidPosition) return <ArtMarker>[marker];

    final visibleMarkers = _markers
        .where((m) =>
            m.hasValidPosition && (_markerTypeVisibility[m.type] ?? true))
        .toList(growable: false);

    final stacked = <ArtMarker>[];
    for (final other in visibleMarkers) {
      final meters = _distance.as(
        LengthUnit.Meter,
        marker.position,
        other.position,
      );
      if (meters <= tapConfig.sameCoordinateMeters) {
        stacked.add(other);
      }
    }

    if (stacked.isEmpty) return <ArtMarker>[marker];

    stacked.sort((a, b) => a.id.compareTo(b.id));

    if (pinSelectedFirst) {
      final idx = stacked.indexWhere((m) => m.id == marker.id);
      if (idx > 0) {
        final selected = stacked.removeAt(idx);
        stacked.insert(0, selected);
      }
    }

    return stacked;
  }

  List<KubusRenderedMarker> buildRenderedMarkers() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final visibleMarkers = _markers
        .where((m) =>
            m.hasValidPosition && (_markerTypeVisibility[m.type] ?? true))
        .toList(growable: false);

    final rendered = <KubusRenderedMarker>[];
    for (final marker in visibleMarkers) {
      final coordinateKey = mapMarkerCoordinateKey(marker.position);
      final isSpiderfied = _expandedCoordinateKey == coordinateKey &&
          _spiderfiedPositionByMarkerId.containsKey(marker.id);
      final overridePosition = _spiderfiedPositionByMarkerId[marker.id];
      final entry = _entryValuesForMarker(marker.id, nowMs: nowMs);

      rendered.add(
        KubusRenderedMarker(
          marker: marker,
          position: overridePosition ?? marker.position,
          entryScale: entry.scale,
          entryOpacity: entry.opacity,
          entrySerial: entry.serial,
          sameCoordinateKey: coordinateKey,
          isSpiderfied: isSpiderfied,
        ),
      );
    }

    return List<KubusRenderedMarker>.unmodifiable(rendered);
  }

  Future<void> expandSpiderfyForCoordinateKey(
    String coordinateKey, {
    LatLng? anchor,
    bool triggerSelection = false,
  }) async {
    final key = coordinateKey.trim();
    if (key.isEmpty) return;

    final grouped = _markersForCoordinateKey(key);
    if (grouped.length <= 1) {
      _collapseSpiderfy();
      return;
    }

    if (triggerSelection) {
      final selected = _selectedMarkerData;
      if (selected == null || !grouped.any((m) => m.id == selected.id)) {
        selectMarker(grouped.first, stackedMarkers: grouped);
      }
    }

    final applied = await _applySpiderfyLayout(
      coordinateKey: key,
      markers: grouped,
      anchor: anchor,
    );
    if (!applied) return;

    _scheduleEntryAnimations(
      grouped.map((m) => m.id).toList(growable: false),
      staggered: true,
    );
    onRequestMarkerDataSync?.call();
  }

  void _maybeAutoExpandSelectedSameLocation() {
    final selected = _selectedMarkerData;
    if (selected == null) {
      _collapseSpiderfy();
      return;
    }

    if (_camera.zoom < tapConfig.spiderfyAutoExpandZoom) {
      return;
    }

    final key = mapMarkerCoordinateKey(selected.position);
    final grouped = _markersForCoordinateKey(key);
    if (grouped.length <= 1) {
      _collapseSpiderfy();
      return;
    }

    if (_expandedCoordinateKey == key) return;
    unawaited(
      expandSpiderfyForCoordinateKey(
        key,
        anchor: selected.position,
        triggerSelection: false,
      ),
    );
  }

  Future<void> _maybeAutoExpandSameLocationAtHighZoom() async {
    if (_camera.zoom < tapConfig.spiderfyAutoExpandZoom) {
      return;
    }

    // Prefer the active selection when present.
    _maybeAutoExpandSelectedSameLocation();
    if (_expandedCoordinateKey != null) return;

    final controller = _mapController;
    if (controller == null) return;

    try {
      final bounds = await controller.getVisibleRegion();
      final visibleMarkers = _markers.where(
        (m) =>
            m.hasValidPosition &&
            (_markerTypeVisibility[m.type] ?? true) &&
            _isMarkerWithinBounds(m.position, bounds),
      );
      final grouped = groupMarkersByCoordinateKey(visibleMarkers);

      String? bestKey;
      LatLng? bestAnchor;
      double? bestDistance;
      for (final entry in grouped.entries) {
        final markers = entry.value;
        if (markers.length <= 1) continue;
        final anchor = markers.first.position;
        final meters = _distance.as(LengthUnit.Meter, _camera.center, anchor);
        if (bestDistance == null || meters < bestDistance) {
          bestDistance = meters;
          bestKey = entry.key;
          bestAnchor = anchor;
        }
      }

      if (bestKey != null && bestAnchor != null) {
        await expandSpiderfyForCoordinateKey(
          bestKey,
          anchor: bestAnchor,
          triggerSelection: false,
        );
      }
    } catch (_) {
      // Best effort only during style/camera transitions.
    }
  }

  Future<bool> _applySpiderfyLayout({
    required String coordinateKey,
    required List<ArtMarker> markers,
    LatLng? anchor,
  }) async {
    final controller = _mapController;
    if (controller == null) return false;

    final sorted = List<ArtMarker>.of(markers)
      ..sort((a, b) => a.id.compareTo(b.id));

    final resolvedAnchor = anchor ?? sorted.first.position;
    try {
      final anchorScreen = await controller.toScreenLocation(
        ml.LatLng(resolvedAnchor.latitude, resolvedAnchor.longitude),
      );
      final offsets = buildSpiderfyOffsets(sorted.length);
      if (offsets.length != sorted.length) return false;

      final nextPositions = <String, LatLng>{};
      for (var i = 0; i < sorted.length; i++) {
        final offset = offsets[i];
        final point = math.Point<double>(
          anchorScreen.x.toDouble() + offset.dx,
          anchorScreen.y.toDouble() + offset.dy,
        );
        final latLng = await controller.toLatLng(point);
        nextPositions[sorted[i].id] = LatLng(latLng.latitude, latLng.longitude);
      }

      _expandedCoordinateKey = coordinateKey;
      _spiderfiedPositionByMarkerId
        ..clear()
        ..addAll(nextPositions);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _collapseSpiderfy({bool requestSync = true}) {
    if (_expandedCoordinateKey == null &&
        _spiderfiedPositionByMarkerId.isEmpty) {
      return;
    }
    _expandedCoordinateKey = null;
    _spiderfiedPositionByMarkerId.clear();
    if (requestSync) {
      onRequestMarkerDataSync?.call();
    }
  }

  void _pruneSpiderfyStateIfNeeded() {
    final key = _expandedCoordinateKey;
    if (key == null) return;
    final grouped = _markersForCoordinateKey(key);
    if (grouped.length <= 1) {
      _collapseSpiderfy();
      return;
    }

    final ids = grouped.map((m) => m.id).toSet();
    final removedAny =
        _spiderfiedPositionByMarkerId.keys.any((id) => !ids.contains(id));
    if (removedAny || _spiderfiedPositionByMarkerId.length != ids.length) {
      _collapseSpiderfy();
    }
  }

  List<ArtMarker> _markersForCoordinateKey(String coordinateKey) {
    final visible = _markers
        .where((m) =>
            m.hasValidPosition && (_markerTypeVisibility[m.type] ?? true))
        .toList(growable: false);
    final grouped = groupMarkersByCoordinateKey(visible);
    final markers = grouped[coordinateKey] ?? const <ArtMarker>[];
    final sorted = List<ArtMarker>.of(markers)
      ..sort((a, b) => a.id.compareTo(b.id));
    return sorted;
  }

  void _queueViewportVisibilityRefresh({bool force = false}) {
    if (!_styleInitialized) return;
    if (_mapController == null) return;

    final delay = force
        ? Duration.zero
        : const Duration(
            milliseconds: MapMarkerCollisionConfig.viewportVisibilityDebounceMs,
          );
    _viewportVisibilityDebouncer(delay, () {
      unawaited(_refreshViewportVisibility());
    });
  }

  void _primeInitialViewportVisibilityIfNeeded() {
    if (_viewportStateInitialized) return;
    if (!_styleInitialized) return;

    final initialVisible = _markers
        .where((m) =>
            m.hasValidPosition && (_markerTypeVisibility[m.type] ?? true))
        .map((m) => m.id)
        .toSet();

    _viewportStateInitialized = true;
    _visibleMarkerIds = initialVisible;
    _viewportInitAttemptCount = 0;
    _viewportInitRetryTimer?.cancel();
    _viewportInitRetryTimer = null;

    if (initialVisible.isNotEmpty) {
      _scheduleEntryAnimations(
        initialVisible.toList(growable: false),
        staggered: true,
      );
    }
  }

  Future<void> _refreshViewportVisibility() async {
    final controller = _mapController;
    if (controller == null) return;
    if (!_styleInitialized) return;

    try {
      final bounds = await controller.getVisibleRegion();
      final visibleMarkers = _markers.where(
        (m) =>
            m.hasValidPosition &&
            (_markerTypeVisibility[m.type] ?? true) &&
            _isMarkerWithinBounds(m.position, bounds),
      );
      final nextVisible = visibleMarkers.map((m) => m.id).toSet();
      final eligibleMarkerIds = _markers
          .where((m) =>
              m.hasValidPosition && (_markerTypeVisibility[m.type] ?? true))
          .map((m) => m.id)
          .toSet();

      if (!_viewportStateInitialized) {
        if (nextVisible.isEmpty &&
            eligibleMarkerIds.isNotEmpty &&
            _viewportInitAttemptCount <
                MapMarkerCollisionConfig.viewportInitMaxRetries) {
          _viewportInitAttemptCount += 1;
          _scheduleViewportInitRetry();
          return;
        }

        _viewportStateInitialized = true;
        _viewportInitAttemptCount = 0;
        _viewportInitRetryTimer?.cancel();
        _viewportInitRetryTimer = null;

        final initialVisible =
            nextVisible.isNotEmpty ? nextVisible : eligibleMarkerIds;
        if (initialVisible.isNotEmpty) {
          _scheduleEntryAnimations(
            initialVisible.toList(growable: false),
            staggered: true,
          );
        }
        _visibleMarkerIds = initialVisible;
        return;
      }

      final entered = nextVisible.difference(_visibleMarkerIds);
      final exited = _visibleMarkerIds.difference(nextVisible);
      for (final id in exited) {
        _entryAnimationByMarkerId.remove(id);
      }
      if (entered.isNotEmpty) {
        _scheduleEntryAnimations(entered.toList(growable: false),
            staggered: true);
      }
      _visibleMarkerIds = nextVisible;
    } catch (_) {
      // Best effort: viewport checks can fail during style transitions,
      // especially on first web navigation into the map route.
      if (!_viewportStateInitialized) {
        final fallbackVisible = _markers
            .where((m) =>
                m.hasValidPosition && (_markerTypeVisibility[m.type] ?? true))
            .map((m) => m.id)
            .toSet();
        _viewportStateInitialized = true;
        _viewportInitAttemptCount = 0;
        _viewportInitRetryTimer?.cancel();
        _viewportInitRetryTimer = null;
        if (fallbackVisible.isNotEmpty) {
          _scheduleEntryAnimations(
            fallbackVisible.toList(growable: false),
            staggered: true,
          );
        }
        _visibleMarkerIds = fallbackVisible;
      }
    }
  }

  void _scheduleViewportInitRetry() {
    _viewportInitRetryTimer?.cancel();
    _viewportInitRetryTimer = Timer(
      const Duration(
          milliseconds: MapMarkerCollisionConfig.viewportInitRetryDelayMs),
      () {
        _viewportInitRetryTimer = null;
        if (_viewportStateInitialized) return;
        if (!_styleInitialized) return;
        if (_mapController == null) return;
        unawaited(_refreshViewportVisibility());
      },
    );
  }

  bool _isMarkerWithinBounds(LatLng point, ml.LatLngBounds bounds) {
    final south = bounds.southwest.latitude;
    final north = bounds.northeast.latitude;
    if (point.latitude < south || point.latitude > north) return false;

    final west = bounds.southwest.longitude;
    final east = bounds.northeast.longitude;
    if (west <= east) {
      return point.longitude >= west && point.longitude <= east;
    }
    return point.longitude >= west || point.longitude <= east;
  }

  void _scheduleEntryAnimations(
    List<String> markerIds, {
    required bool staggered,
  }) {
    if (markerIds.isEmpty) return;

    final sorted = List<String>.of(markerIds)..sort();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final step = staggered ? MapMarkerCollisionConfig.entryStaggerMs : 0;

    for (var i = 0; i < sorted.length; i++) {
      final id = sorted[i];
      _entrySerialCounter += 1;
      _entryAnimationByMarkerId[id] = _MarkerEntryAnimationState(
        revealAtMs: nowMs + (i * step),
        serial: _entrySerialCounter,
      );
    }

    onRequestMarkerDataSync?.call();
    _startEntryAnimationTicker();
  }

  _MarkerEntryValues _entryValuesForMarker(
    String markerId, {
    required int nowMs,
  }) {
    const hidden = _MarkerEntryValues(
      scale: MapMarkerCollisionConfig.entryStartScale,
      opacity: 0.0,
      serial: 0,
    );
    final state = _entryAnimationByMarkerId[markerId];
    if (state == null) {
      if (!_viewportStateInitialized) return hidden;
      if (_spiderfiedPositionByMarkerId.containsKey(markerId)) {
        return const _MarkerEntryValues(scale: 1.0, opacity: 1.0, serial: 0);
      }
      if (_visibleMarkerIds.contains(markerId)) {
        return const _MarkerEntryValues(scale: 1.0, opacity: 1.0, serial: 0);
      }
      return hidden;
    }

    final durationMs = MapMarkerCollisionConfig.entryDurationMs;
    final elapsed = nowMs - state.revealAtMs;
    if (elapsed <= 0) {
      return _MarkerEntryValues(
        scale: MapMarkerCollisionConfig.entryStartScale,
        opacity: 0.0,
        serial: state.serial,
      );
    }
    if (elapsed >= durationMs) {
      return _MarkerEntryValues(scale: 1.0, opacity: 1.0, serial: state.serial);
    }

    final t = (elapsed / durationMs).clamp(0.0, 1.0);
    final scaleT = Curves.easeOutBack.transform(t);
    final opacityT = Curves.easeOutCubic.transform(t);
    final scale = MapMarkerCollisionConfig.entryStartScale +
        (1.0 - MapMarkerCollisionConfig.entryStartScale) * scaleT;

    return _MarkerEntryValues(
      scale:
          scale.clamp(MapMarkerCollisionConfig.entryStartScale, 1.2).toDouble(),
      opacity: opacityT.clamp(0.0, 1.0).toDouble(),
      serial: state.serial,
    );
  }

  void _startEntryAnimationTicker() {
    if (_entryAnimationTicker?.isActive ?? false) return;
    _entryAnimationTicker = Timer.periodic(
      const Duration(milliseconds: 16),
      _handleEntryAnimationTick,
    );
  }

  void _handleEntryAnimationTick(Timer timer) {
    if (_entryAnimationByMarkerId.isEmpty) {
      timer.cancel();
      _entryAnimationTicker = null;
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expireAfter = MapMarkerCollisionConfig.entryDurationMs + 120;
    _entryAnimationByMarkerId.removeWhere(
      (_, state) => nowMs - state.revealAtMs > expireAfter,
    );

    if (_entryAnimationByMarkerId.isEmpty) {
      timer.cancel();
      _entryAnimationTicker = null;
    }

    onRequestMarkerDataSync?.call();
  }

  ArtMarker? _findMarkerById(String id) {
    for (final marker in _markers) {
      if (marker.id == id) return marker;
    }
    return null;
  }

  Future<bool> _canQueryMarkerHitbox({bool forceRefresh = false}) async {
    final controller = _mapController;
    if (controller == null) return false;
    if (!_styleInitialized) return false;

    if (!forceRefresh &&
        _hitboxLayerReady &&
        _hitboxLayerEpoch == _styleEpoch) {
      return true;
    }

    // Prefer the manager's internal knowledge if available.
    final manager = _layersManager;
    if (manager != null && manager.hasLayer(ids.layers.markerHitboxLayerId)) {
      _hitboxLayerReady = true;
      _hitboxLayerEpoch = _styleEpoch;
      return true;
    }

    try {
      final raw = await controller.getLayerIds();
      for (final id in raw) {
        if (id == ids.layers.markerHitboxLayerId) {
          _hitboxLayerReady = true;
          _hitboxLayerEpoch = _styleEpoch;
          return true;
        }
      }
    } catch (_) {
      // Ignore.
    }

    _hitboxLayerReady = false;
    _hitboxLayerEpoch = -1;
    return false;
  }

  Future<ArtMarker?> _fallbackPickMarkerAtPoint(
      math.Point<double> point) async {
    final controller = _mapController;
    if (controller == null) return null;

    // Tight fallback radius to avoid oversized hitboxes.
    final zoomScale = (_camera.zoom / 15.0).clamp(0.7, 1.4);
    final double base = kIsWeb ? 28.0 : 22.0;
    final double maxDistance = base * zoomScale;

    ArtMarker? best;
    double bestDistance = maxDistance;

    final visibleMarkers = _markers.where(
      (m) => _markerTypeVisibility[m.type] ?? true,
    );

    for (final marker in visibleMarkers) {
      try {
        final screen = await controller.toScreenLocation(
          ml.LatLng(marker.position.latitude, marker.position.longitude),
        );
        final dx = screen.x.toDouble() - point.x;
        final dy = screen.y.toDouble() - point.y;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance <= bestDistance) {
          bestDistance = distance;
          best = marker;
        }
      } catch (_) {
        // Ignore.
      }
    }

    return best;
  }

  Future<void> animateTo(
    LatLng target, {
    double? zoom,
    double? rotation,
    double? tilt,
    Duration duration = const Duration(milliseconds: 320),
    double? compositionYOffsetPx,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    // Apply composition by shifting the screen point upward (negative y)
    // and unprojecting back to a LatLng.
    ml.LatLng mlTarget = ml.LatLng(target.latitude, target.longitude);
    if (compositionYOffsetPx != null && compositionYOffsetPx.abs() > 0.5) {
      try {
        final screen = await controller.toScreenLocation(mlTarget);
        final shifted = math.Point<double>(
          screen.x.toDouble(),
          screen.y.toDouble() - compositionYOffsetPx,
        );
        mlTarget = await controller.toLatLng(shifted);
      } catch (_) {
        // Best-effort.
      }
    }

    _programmaticCameraMove = true;

    final double nextZoom = zoom ?? _camera.zoom;
    final double nextBearing = rotation ?? _camera.bearing;
    final double nextTilt = tilt ?? _camera.pitch;

    try {
      await controller.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: mlTarget,
            zoom: nextZoom,
            bearing: nextBearing,
            tilt: nextTilt,
          ),
        ),
        duration: duration,
      );
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint('KubusMapController: animateTo failed: $e');
      }
    }
  }

  Future<void> applyIsometricCamera({
    required bool enabled,
    bool adjustZoomForScale = false,
  }) async {
    final controller = _mapController;
    if (controller == null) return;

    final shouldEnable =
        enabled && AppConfig.isFeatureEnabled('mapIsometricView');
    final targetPitch = shouldEnable ? 54.736 : 0.0;
    final targetBearing = shouldEnable
        ? (_camera.bearing.abs() < 1.0 ? 18.0 : _camera.bearing)
        : 0.0;

    double targetZoom = _camera.zoom;
    if (adjustZoomForScale) {
      const scale = 1.2;
      final delta = math.log(scale) / math.ln2;
      targetZoom =
          shouldEnable ? (_camera.zoom + delta) : (_camera.zoom - delta);
      targetZoom = targetZoom.clamp(3.0, 24.0).toDouble();
    }

    await animateTo(
      _camera.center,
      zoom: targetZoom,
      rotation: targetBearing,
      tilt: targetPitch,
    );
  }

  Future<void> resetBearing() async {
    if (_camera.bearing.abs() < 0.5) return;
    await animateTo(
      _camera.center,
      zoom: _camera.zoom,
      rotation: 0.0,
      tilt: _camera.pitch,
    );
  }
}

@immutable
class _MarkerEntryAnimationState {
  const _MarkerEntryAnimationState({
    required this.revealAtMs,
    required this.serial,
  });

  final int revealAtMs;
  final int serial;
}

@immutable
class _MarkerEntryValues {
  const _MarkerEntryValues({
    required this.scale,
    required this.opacity,
    required this.serial,
  });

  final double scale;
  final double opacity;
  final int serial;
}
