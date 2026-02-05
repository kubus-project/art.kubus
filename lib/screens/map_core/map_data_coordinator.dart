import 'dart:async';
import 'package:latlong2/latlong.dart';

import '../../utils/debouncer.dart';
import '../../utils/geo_bounds.dart';
import '../../utils/map_marker_helper.dart';
import '../../utils/map_viewport_utils.dart';

/// Centralizes marker refresh scheduling logic shared by mobile + desktop map screens.
///
/// Responsibilities:
/// - Debounce refresh triggers (gesture vs. programmatic)
/// - Decide whether to refresh in radius mode based on distance/time
/// - Decide whether to refetch in travel mode based on viewport bounds + zoom bucket
/// - Defer work when the map is not active/ready (caller decides what "pending" means)
///
/// This coordinator intentionally does NOT fetch markers directly; it only
/// orchestrates when the caller should do so.
class MapDataCoordinator {
  MapDataCoordinator({
    required bool Function() pollingEnabled,
    required bool Function() mapReady,
    required LatLng Function() cameraCenter,
    required double Function() cameraZoom,
    required bool Function() travelModeEnabled,
    required bool Function() hasMarkers,
    required LatLng? Function() lastFetchCenter,
    required DateTime? Function() lastFetchTime,
    required GeoBounds? Function() loadedTravelBounds,
    required int? Function() loadedTravelZoomBucket,
    required Distance distance,
    required Duration refreshInterval,
    required double refreshDistanceMeters,
    required Future<GeoBounds?> Function() getVisibleBounds,
    required Future<void> Function({required LatLng center}) refreshRadiusMode,
    required Future<void> Function({
      required LatLng center,
      required GeoBounds bounds,
      required int zoomBucket,
    }) refreshTravelMode,
    required void Function({bool force}) queuePendingRefresh,
  })  : _pollingEnabled = pollingEnabled,
        _mapReady = mapReady,
        _cameraCenter = cameraCenter,
        _cameraZoom = cameraZoom,
        _travelModeEnabled = travelModeEnabled,
        _hasMarkers = hasMarkers,
        _lastFetchCenter = lastFetchCenter,
        _lastFetchTime = lastFetchTime,
        _loadedTravelBounds = loadedTravelBounds,
        _loadedTravelZoomBucket = loadedTravelZoomBucket,
        _distance = distance,
        _refreshInterval = refreshInterval,
        _refreshDistanceMeters = refreshDistanceMeters,
        _getVisibleBounds = getVisibleBounds,
        _refreshRadiusMode = refreshRadiusMode,
        _refreshTravelMode = refreshTravelMode,
        _queuePendingRefresh = queuePendingRefresh;

  final Debouncer _debouncer = Debouncer();

  final bool Function() _pollingEnabled;
  final bool Function() _mapReady;
  final LatLng Function() _cameraCenter;
  final double Function() _cameraZoom;
  final bool Function() _travelModeEnabled;
  final bool Function() _hasMarkers;

  final LatLng? Function() _lastFetchCenter;
  final DateTime? Function() _lastFetchTime;

  final GeoBounds? Function() _loadedTravelBounds;
  final int? Function() _loadedTravelZoomBucket;

  final Distance _distance;
  final Duration _refreshInterval;
  final double _refreshDistanceMeters;

  final Future<GeoBounds?> Function() _getVisibleBounds;
  final Future<void> Function({required LatLng center}) _refreshRadiusMode;
  final Future<void> Function({
    required LatLng center,
    required GeoBounds bounds,
    required int zoomBucket,
  }) _refreshTravelMode;

  final void Function({bool force}) _queuePendingRefresh;

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _debouncer.dispose();
  }

  void cancelPending() {
    _debouncer.cancel();
  }

  /// Schedules a marker refresh if the refresh conditions are met.
  ///
  /// The debounce behavior matches the current screens:
  /// - Travel mode: ~350–450ms
  /// - Radius mode: ~800ms (programmatic) or 2s (gesture)
  void queueMarkerRefresh({required bool fromGesture}) {
    if (_disposed) return;

    if (!_pollingEnabled()) {
      _queuePendingRefresh(force: false);
      return;
    }

    if (!_mapReady()) return;

    final center = _cameraCenter();
    final zoom = _cameraZoom();

    if (_travelModeEnabled()) {
      final bucket = MapViewportUtils.zoomBucket(zoom);
      final debounceTime = fromGesture
          ? const Duration(milliseconds: 450)
          : const Duration(milliseconds: 350);

      _debouncer(debounceTime, () {
        unawaited(_refreshTravel(center: center, zoomBucket: bucket));
      });
      return;
    }

    final shouldRefresh = MapMarkerHelper.shouldRefreshMarkers(
      newCenter: center,
      lastCenter: _lastFetchCenter(),
      lastFetchTime: _lastFetchTime(),
      distance: _distance,
      refreshInterval: _refreshInterval,
      refreshDistanceMeters: _refreshDistanceMeters,
      hasMarkers: _hasMarkers(),
    );

    if (!shouldRefresh) return;

    final debounceTime = fromGesture
        ? const Duration(seconds: 2)
        : const Duration(milliseconds: 800);

    _debouncer(debounceTime, () {
      unawaited(_refreshRadiusMode(center: center));
    });
  }

  Future<void> _refreshTravel({required LatLng center, required int zoomBucket}) async {
    if (_disposed) return;

    final visibleBounds = await _getVisibleBounds();
    if (_disposed) return;
    if (visibleBounds == null) return;

    final shouldRefetch = MapViewportUtils.shouldRefetchTravelMode(
      visibleBounds: visibleBounds,
      loadedBounds: _loadedTravelBounds(),
      zoomBucket: zoomBucket,
      loadedZoomBucket: _loadedTravelZoomBucket(),
      hasMarkers: _hasMarkers(),
    );
    if (!shouldRefetch) return;

    final queryBounds = MapViewportUtils.expandBounds(
      visibleBounds,
      MapViewportUtils.paddingFractionForZoomBucket(zoomBucket),
    );

    await _refreshTravelMode(
      center: center,
      bounds: queryBounds,
      zoomBucket: zoomBucket,
    );
  }
}
