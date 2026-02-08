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
class KubusMapTapConfig {
  const KubusMapTapConfig({
    this.sameCoordinateMeters = 0.75,
    this.tapTolerancePx = 6.0,
    this.clusterIdPrefix = 'cluster:',
    this.clusterTapZoomDelta = 1.5,
    this.clusterTapMaxZoom = 18.0,
  });

  /// Distance threshold for considering two markers as "stacked".
  final double sameCoordinateMeters;

  /// Tap query rect size (radius).
  final double tapTolerancePx;

  /// Prefix used by web feature-tap events for clusters.
  final String clusterIdPrefix;

  /// How much to zoom in when tapping a cluster.
  final double clusterTapZoomDelta;

  /// Upper bound for cluster-tap zoom.
  final double clusterTapMaxZoom;
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
  Map<ArtMarkerType, bool> _markerTypeVisibility = const <ArtMarkerType, bool>{};

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
  final ValueNotifier<Offset?> selectedMarkerAnchor = ValueNotifier<Offset?>(null);

  final Debouncer _overlayAnchorDebouncer = Debouncer();

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

    // Keep selection data fresh when marker instances are replaced during
    // polling/refresh.
    _refreshSelectionFromLatestMarkers();
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
  }

  void dispose() {
    detachMapController();
    _overlayAnchorDebouncer.dispose();
    bearingDegrees.dispose();
    selectedMarkerAnchor.dispose();
  }

  void _bindFeatureTapController(ml.MapLibreMapController controller) {
    if (_featureTapBoundController == controller) return;

    if (_featureTapBoundController != null) {
      _featureTapBoundController?.onFeatureTapped.remove(_handleMapFeatureTapped);
    }

    _featureTapBoundController = controller;
    controller.onFeatureTapped.add(_handleMapFeatureTapped);

    _bindFeatureHoverController(controller);
  }

  void _bindFeatureHoverController(ml.MapLibreMapController controller) {
    if (!kIsWeb) return;
    if (_featureHoverBoundController == controller) return;

    if (_featureHoverBoundController != null) {
      _featureHoverBoundController?.onFeatureHover.remove(_handleMapFeatureHover);
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
    _cameraIsMoving = true;

    final bool hasGesture = !_programmaticCameraMove;
    if (hasGesture && _autoFollow) {
      _autoFollow = false;
      onAutoFollowChanged?.call(_autoFollow);
    }

    final nextCenter = LatLng(position.target.latitude, position.target.longitude);
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

    // If the user is panning while an overlay is open, close it.
    // This keeps selection + composition stable.
    if (dismissSelectionOnUserGesture && hasGesture && _selectedMarkerId != null) {
      dismissSelection();
    }

    if (_selectedMarkerData != null) {
      queueOverlayAnchorRefresh();
    }
  }

  void handleCameraIdle({required bool fromProgrammaticMove}) {
    _cameraIsMoving = false;
    _programmaticCameraMove = false;

    if (_selectedMarkerData != null) {
      queueOverlayAnchorRefresh(force: true);
    }

    // Screen handles marker refresh scheduling; controller does not fetch.
    // This is intentionally a hook rather than embedded side effects.
    // (keeps provider lifecycle stable and avoids surprises.)
    //
    // Note: the hook is invoked with `fromGesture = !fromProgrammaticMove`.
    //
    // No-op here; screens can still wire their existing logic.
  }

  /// Web only: invoked via MapLibre's onFeatureTapped.
  void _handleMapFeatureTapped(
    math.Point<double> point,
    ml.LatLng coordinates,
    String id,
    String layerId,
    ml.Annotation? annotation,
  ) {
    _lastFeatureTapAt = DateTime.now();
    _lastFeatureTapPoint = point;

    if (id.startsWith(tapConfig.clusterIdPrefix)) {
      final nextZoom = math.min(_camera.zoom + tapConfig.clusterTapZoomDelta, tapConfig.clusterTapMaxZoom);
      unawaited(
        animateTo(
          LatLng(coordinates.latitude, coordinates.longitude),
          zoom: nextZoom,
        ),
      );
      return;
    }

    final selected = _findMarkerById(id);
    if (selected == null) return;

    final stack = _computeMarkerStack(selected, pinSelectedFirst: true);
    selectMarker(stack.first, stackedMarkers: stack);
  }

  /// Web only: invoked via MapLibre's onFeatureHover.
  void _handleMapFeatureHover(
    math.Point<double> point,
    ml.LatLng coordinates,
    String id,
    ml.Annotation? annotation,
    ml.HoverEventType eventType,
  ) {
    if (!kIsWeb) return;

    if (id.startsWith(tapConfig.clusterIdPrefix)) {
      if (_hoveredMarkerId != null) {
        _hoveredMarkerId = null;
        onRequestMarkerLayerStyleUpdate?.call();
      }
      return;
    }

    final next = eventType == ml.HoverEventType.leave ? null : id;
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

    if (isWeb) {
      // On web, feature hits are delivered via onFeatureTapped; treat this
      // callback as "background" tap.
      onBackgroundTap?.call();
      dismissSelection();
      return;
    }

    if (MapTapGating.shouldIgnoreMapClickAfterFeatureTap(
      lastFeatureTapAt: _lastFeatureTapAt,
      lastFeatureTapPoint: _lastFeatureTapPoint,
      clickPoint: point,
    )) {
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
        onBackgroundTap?.call();
        dismissSelection();
        return;
      }

      final dynamic first = features.first;
      final propsRaw = first is Map ? first['properties'] : null;
      final Map props = propsRaw is Map ? propsRaw : const <String, dynamic>{};
      final kind = props['kind']?.toString();

      if (kind == 'cluster') {
        final lng = (props['lng'] as num?)?.toDouble();
        final lat = (props['lat'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
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
        AppConfig.debugPrint('KubusMapController: queryRenderedFeatures failed: $e');
      }
      _hitboxLayerReady = false;
      _hitboxLayerEpoch = -1;

      // Treat failures as a background tap (but still try fallback picking).
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

    final stack = stackedMarkers ?? _computeMarkerStack(marker, pinSelectedFirst: true);
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
        .where((m) => m.hasValidPosition && (_markerTypeVisibility[m.type] ?? true))
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

    if (!forceRefresh && _hitboxLayerReady && _hitboxLayerEpoch == _styleEpoch) {
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

  Future<ArtMarker?> _fallbackPickMarkerAtPoint(math.Point<double> point) async {
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

    final shouldEnable = enabled && AppConfig.isFeatureEnabled('mapIsometricView');
    final targetPitch = shouldEnable ? 54.736 : 0.0;
    final targetBearing = shouldEnable
        ? (_camera.bearing.abs() < 1.0 ? 18.0 : _camera.bearing)
        : 0.0;

    double targetZoom = _camera.zoom;
    if (adjustZoomForScale) {
      const scale = 1.2;
      final delta = math.log(scale) / math.ln2;
      targetZoom = shouldEnable ? (_camera.zoom + delta) : (_camera.zoom - delta);
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
