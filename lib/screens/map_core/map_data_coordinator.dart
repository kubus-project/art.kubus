import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../features/map/filters/map_filter_state.dart';
import '../../utils/debouncer.dart';
import '../../utils/geo_bounds.dart';
import '../../utils/map_marker_helper.dart';
import '../../utils/map_viewport_utils.dart';

/// Shared marker-refresh policy for the mobile and desktop maps.
///
/// Camera idle drives [KubusMapScope.currentViewport]. Near Me is deliberately
/// not camera-driven: callers invoke [refreshNearMeForLocation] only when an
/// actual user-location fix changes.
class MapDataCoordinator {
  MapDataCoordinator({
    required bool Function() pollingEnabled,
    required bool Function() mapReady,
    required KubusMapScope Function() scope,
    required LatLng Function() cameraCenter,
    required double Function() cameraZoom,
    required bool Function() hasMarkers,
    required LatLng? Function() lastFetchCenter,
    required DateTime? Function() lastFetchTime,
    required GeoBounds? Function() loadedViewportBounds,
    required int? Function() loadedViewportZoomBucket,
    required Distance distance,
    required Duration refreshInterval,
    required double refreshDistanceMeters,
    required Future<GeoBounds?> Function() getVisibleBounds,
    required Future<void> Function({required LatLng center}) refreshNearMe,
    required Future<void> Function({
      required LatLng center,
      required GeoBounds bounds,
      required int zoomBucket,
    }) refreshViewport,
    required void Function({bool force}) queuePendingRefresh,
  })  : _pollingEnabled = pollingEnabled,
        _mapReady = mapReady,
        _scope = scope,
        _cameraCenter = cameraCenter,
        _cameraZoom = cameraZoom,
        _hasMarkers = hasMarkers,
        _lastFetchCenter = lastFetchCenter,
        _lastFetchTime = lastFetchTime,
        _loadedViewportBounds = loadedViewportBounds,
        _loadedViewportZoomBucket = loadedViewportZoomBucket,
        _distance = distance,
        _refreshInterval = refreshInterval,
        _refreshDistanceMeters = refreshDistanceMeters,
        _getVisibleBounds = getVisibleBounds,
        _refreshNearMe = refreshNearMe,
        _refreshViewport = refreshViewport,
        _queuePendingRefresh = queuePendingRefresh;

  final Debouncer _debouncer = Debouncer();
  final bool Function() _pollingEnabled;
  final bool Function() _mapReady;
  final KubusMapScope Function() _scope;
  final LatLng Function() _cameraCenter;
  final double Function() _cameraZoom;
  final bool Function() _hasMarkers;
  final LatLng? Function() _lastFetchCenter;
  final DateTime? Function() _lastFetchTime;
  final GeoBounds? Function() _loadedViewportBounds;
  final int? Function() _loadedViewportZoomBucket;
  final Distance _distance;
  final Duration _refreshInterval;
  final double _refreshDistanceMeters;
  final Future<GeoBounds?> Function() _getVisibleBounds;
  final Future<void> Function({required LatLng center}) _refreshNearMe;
  final Future<void> Function({
    required LatLng center,
    required GeoBounds bounds,
    required int zoomBucket,
  }) _refreshViewport;
  final void Function({bool force}) _queuePendingRefresh;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _debouncer.dispose();
  }

  void cancelPending() => _debouncer.cancel();

  /// Called on camera idle. Only viewport scope may make a camera-driven query.
  void queueMarkerRefresh({required bool fromGesture}) {
    if (_disposed) return;
    if (!_pollingEnabled()) {
      _queuePendingRefresh(force: false);
      return;
    }
    if (!_mapReady() || _scope() != KubusMapScope.currentViewport) return;

    final center = _cameraCenter();
    final bucket = MapViewportUtils.zoomBucket(_cameraZoom());
    _debouncer(
      fromGesture
          ? const Duration(milliseconds: 350)
          : const Duration(milliseconds: 300),
      () => unawaited(_refreshViewportIfNeeded(center, bucket)),
    );
  }

  /// Called only after a resolved user-location update while Near Me is active.
  void refreshNearMeForLocation(LatLng userLocation, {bool force = false}) {
    if (_disposed || _scope() != KubusMapScope.nearMe) return;
    if (!_pollingEnabled()) {
      _queuePendingRefresh(force: force);
      return;
    }
    final shouldRefresh = MapMarkerHelper.shouldRefreshMarkers(
      newCenter: userLocation,
      lastCenter: _lastFetchCenter(),
      lastFetchTime: _lastFetchTime(),
      distance: _distance,
      refreshInterval: _refreshInterval,
      refreshDistanceMeters: _refreshDistanceMeters,
      hasMarkers: _hasMarkers(),
      force: force,
    );
    if (shouldRefresh) unawaited(_refreshNearMe(center: userLocation));
  }

  Future<void> _refreshViewportIfNeeded(LatLng center, int zoomBucket) async {
    if (_disposed || _scope() != KubusMapScope.currentViewport) return;
    final visibleBounds = await _getVisibleBounds();
    if (_disposed || visibleBounds == null) return;
    if (!MapViewportUtils.shouldRefetchViewport(
      visibleBounds: visibleBounds,
      loadedBounds: _loadedViewportBounds(),
      zoomBucket: zoomBucket,
      loadedZoomBucket: _loadedViewportZoomBucket(),
      hasMarkers: _hasMarkers(),
    )) {
      return;
    }

    final queryBounds = MapViewportUtils.expandBounds(
      visibleBounds,
      MapViewportUtils.paddingFractionForZoomBucket(zoomBucket),
    );
    await _refreshViewport(
      center: center,
      bounds: queryBounds,
      zoomBucket: zoomBucket,
    );
  }
}
