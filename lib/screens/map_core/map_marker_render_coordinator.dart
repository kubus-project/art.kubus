import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../config/config.dart';
import '../../features/map/map_layers_manager.dart';
import '../../features/map/shared/map_screen_constants.dart';
import '../../features/map/shared/map_screen_shared_helpers.dart';
import '../../features/map/controller/kubus_map_controller.dart';

/// Centralizes marker render mode management shared by mobile + desktop map
/// screens.
///
/// Responsibilities:
/// - Own 3-D cube layer visibility state and cube icon animation values
/// - Toggle marker render mode (2-D icon ↔ 3-D cube) via MapLayersManager
/// - Drive the cube spin ticker and selection pop animation
/// - Forward style update requests to the shared [KubusMarkerLayerStyler]
/// - Assert mode invariants (debug only)
///
/// This coordinator intentionally does NOT own a [BuildContext]; callers must
/// inject readiness checks and sync callbacks via constructor closures,
/// following the same pattern as [MapDataCoordinator].
class MapMarkerRenderCoordinator {
  MapMarkerRenderCoordinator({
    required this.screenName,
    required this.markerLayerId,
    required this.cubeLayerId,
    required this.cubeIconLayerId,
    required this.cubeSourceId,
    required bool Function() isMounted,
    required bool Function() isStyleInitialized,
    required bool Function() isStyleInitInProgress,
    required bool Function() isCameraMoving,
    required double Function() getLastPitch,
    required KubusMapController Function() getKubusMapController,
    required ml.MapLibreMapController? Function() getMapController,
    required MapLayersManager? Function() getLayersManager,
    required AnimationController Function() getSelectionController,
    required AnimationController Function() getCubeSpinController,
    required Set<String> Function() getManagedLayerIds,
    required Set<String> Function() getManagedSourceIds,
    required bool Function() isPollingEnabled,
    required Future<void> Function() syncMarkerCubes,
  })  : _isMounted = isMounted,
        _isStyleInitialized = isStyleInitialized,
        _isStyleInitInProgress = isStyleInitInProgress,
        _isCameraMoving = isCameraMoving,
        _getLastPitch = getLastPitch,
        _getKubusMapController = getKubusMapController,
        _getMapController = getMapController,
        _getLayersManager = getLayersManager,
        _getSelectionController = getSelectionController,
        _getCubeSpinController = getCubeSpinController,
        _getManagedLayerIds = getManagedLayerIds,
        _getManagedSourceIds = getManagedSourceIds,
        _isPollingEnabled = isPollingEnabled,
        _syncMarkerCubes = syncMarkerCubes;

  final String screenName;
  final String markerLayerId;
  final String cubeLayerId;
  final String cubeIconLayerId;
  final String cubeSourceId;

  final bool Function() _isMounted;
  final bool Function() _isStyleInitialized;
  final bool Function() _isStyleInitInProgress;
  final bool Function() _isCameraMoving;
  final double Function() _getLastPitch;
  final KubusMapController Function() _getKubusMapController;
  final ml.MapLibreMapController? Function() _getMapController;
  final MapLayersManager? Function() _getLayersManager;
  final AnimationController Function() _getSelectionController;
  final AnimationController Function() _getCubeSpinController;
  final Set<String> Function() _getManagedLayerIds;
  final Set<String> Function() _getManagedSourceIds;
  final bool Function() _isPollingEnabled;
  final Future<void> Function() _syncMarkerCubes;

  // ---------------------------------------------------------------------------
  // Owned state
  // ---------------------------------------------------------------------------

  /// Whether the 3-D cube layer is currently visible.
  bool cubeLayerVisible = false;

  /// Current cube icon spin angle in degrees (0–360).
  double cubeIconSpinDegrees = 0.0;

  /// Current cube icon vertical bob offset in em units.
  double cubeIconBobOffsetEm = 0.0;

  /// Marker layer styler instance (throttles style updates to MapLibre).
  final KubusMarkerLayerStyler markerLayerStyler = KubusMarkerLayerStyler();

  // ---------------------------------------------------------------------------
  // 3-D mode check
  // ---------------------------------------------------------------------------

  /// Returns `true` when camera pitch exceeds the cube pitch threshold and the
  /// isometric view feature flag is enabled.
  bool get is3DModeActive {
    if (!AppConfig.isFeatureEnabled('mapIsometricView')) return false;
    return _getLastPitch() > MapScreenConstants.cubePitchThreshold;
  }

  // ---------------------------------------------------------------------------
  // Animation helpers
  // ---------------------------------------------------------------------------

  /// Starts the selection pop animation on the marker layer.
  void startSelectionPopAnimation() {
    KubusMarkerLayerAnimationHelpers.startSelectionPopAnimation(
      styleInitialized: _isStyleInitialized(),
      animationController: _getSelectionController(),
      requestMarkerLayerStyleUpdate: () => requestStyleUpdate(),
    );
  }

  /// Enables or disables the cube spin ticker based on current state.
  void updateCubeSpinTicker() {
    final shouldSpin = _isPollingEnabled() &&
        _isStyleInitialized() &&
        _getMapController() != null &&
        cubeLayerVisible &&
        is3DModeActive;

    KubusMarkerLayerAnimationHelpers.updateCubeSpinTicker(
      shouldSpin: shouldSpin,
      cubeIconSpinController: _getCubeSpinController(),
    );
  }

  /// Called on every animation frame tick from both the selection pop and cube
  /// spin controllers.
  void handleAnimationTick() {
    final shouldSpin = cubeLayerVisible && is3DModeActive;
    final shouldPop = _getSelectionController().isAnimating;

    KubusMarkerLayerAnimationHelpers.handleMarkerLayerAnimationTick(
      mounted: _isMounted(),
      styleInitialized: _isStyleInitialized(),
      shouldSpin: shouldSpin,
      shouldPop: shouldPop,
      cubeIconSpinController: _getCubeSpinController(),
      setCubeIconSpinDegrees: (v) => cubeIconSpinDegrees = v,
      setCubeIconBobOffsetEm: (v) => cubeIconBobOffsetEm = v,
      requestMarkerLayerStyleUpdate: () => requestStyleUpdate(),
    );
  }

  // ---------------------------------------------------------------------------
  // Style update
  // ---------------------------------------------------------------------------

  /// Requests a marker layer style update, forwarding current state to the
  /// throttled [KubusMarkerLayerStyler].
  void requestStyleUpdate({bool force = false}) {
    final kubus = _getKubusMapController();
    markerLayerStyler.requestUpdate(
      controller: _getMapController(),
      styleInitialized: kubus.styleInitialized && _isStyleInitialized(),
      styleEpoch: kubus.styleEpoch,
      getCurrentStyleEpoch: () => _getKubusMapController().styleEpoch,
      managedLayerIds: _getManagedLayerIds(),
      markerLayerId: markerLayerId,
      cubeIconLayerId: cubeIconLayerId,
      state: KubusMarkerLayerStyleState(
        pressedMarkerId: kubus.pressedMarkerId,
        hoveredMarkerId: kubus.hoveredMarkerId,
        selectedMarkerId: kubus.selectedMarkerId,
        selectionPopAnimationValue: _getSelectionController().value,
        cubeLayerVisible: cubeLayerVisible,
        cubeIconSpinDegrees: cubeIconSpinDegrees,
        cubeIconBobOffsetEm: cubeIconBobOffsetEm,
      ),
      force: force,
    );
  }

  // ---------------------------------------------------------------------------
  // Render mode toggle
  // ---------------------------------------------------------------------------

  /// Switches between 2-D icon and 3-D cube marker rendering.
  ///
  /// No-ops if the current mode already matches the pitch-based decision.
  Future<void> updateRenderMode() async {
    final controller = _getMapController();
    if (controller == null) return;
    if (!_isStyleInitialized()) return;

    final shouldShowCubes = is3DModeActive;
    if (shouldShowCubes == cubeLayerVisible) return;

    cubeLayerVisible = shouldShowCubes;

    if (kDebugMode) {
      final managed = _getManagedLayerIds();
      AppConfig.debugPrint(
        '$screenName: marker render mode -> cubes=$shouldShowCubes '
        'layers(marker=${managed.contains(markerLayerId)} '
        'cubeIcon=${managed.contains(cubeIconLayerId)} '
        'cube=${managed.contains(cubeLayerId)})',
      );
    }

    try {
      await _getLayersManager()?.setMode(
        shouldShowCubes ? MapRenderMode.threeD : MapRenderMode.twoD,
      );
    } catch (_) {
      // Best-effort: layer visibility may fail during style swaps.
    }

    if (!_isMounted()) return;
    requestStyleUpdate(force: true);
    if (shouldShowCubes) {
      await _syncMarkerCubes();
    } else {
      try {
        if (_getManagedSourceIds().contains(cubeSourceId)) {
          await controller.setGeoJsonSource(
            cubeSourceId,
            const <String, dynamic>{
              'type': 'FeatureCollection',
              'features': <dynamic>[],
            },
          );
        }
      } catch (_) {
        // Ignore source update failures during transitions.
      }

      updateCubeSpinTicker();
    }
  }

  // ---------------------------------------------------------------------------
  // Debug invariants
  // ---------------------------------------------------------------------------

  /// Asserts that selected marker ID and data are consistent.
  bool assertMarkerModeInvariant() {
    final kubus = _getKubusMapController();
    final selectedId = kubus.selectedMarkerId;
    final selectedMarker = kubus.selectedMarkerData;
    if (selectedId == null && selectedMarker != null) return false;
    if (selectedId != null && selectedMarker == null) return false;
    return true;
  }

  /// Asserts that cube layer visibility matches the 3-D mode decision.
  bool assertRenderModeInvariant() {
    if (!_isStyleInitialized()) return true;
    if (_isStyleInitInProgress()) return true;
    if (_isCameraMoving()) return true;
    if (cubeLayerVisible && !is3DModeActive) return false;
    if (!cubeLayerVisible && is3DModeActive) return false;
    return true;
  }
}
