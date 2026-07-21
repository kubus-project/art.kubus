import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../providers/walking_navigation_provider.dart';
import '../../../services/walking_location_service.dart';
import '../../../services/walking_navigation_diagnostics.dart';
import '../map_layers_manager.dart';
import 'walking_navigation_models.dart';

/// Owns walking-route MapLibre side effects shared by mobile and desktop.
///
/// Camera priority while a session is visible is:
/// walking follow > explicit Resume > passive destination/marker centering.
/// A user gesture clears the screen's [shouldFollow] flag; only Resume restores
/// it. Marker previews may still be opened explicitly, but never start or
/// replace navigation camera ownership on their own.
///
/// Rendering synchronization rules:
/// - Route geometry and visibility are cached only after MapLibre confirms the
///   mutation. A failed write keeps the route pending so the next sync retries.
/// - Writes are serialized: one in flight, at most one (latest) queued. An
///   older revision can never overwrite a newer one.
/// - A style epoch change invalidates the confirmed state so the retained route
///   is re-written onto the freshly installed source and layers.
class WalkingNavigationMapCoordinator {
  WalkingNavigationMapCoordinator({
    required this.layersManager,
    required this.isStyleReady,
    required this.shouldFollow,
    required this.followCamera,
    required this.fitRouteBounds,
  });

  final MapLayersManager? Function() layersManager;
  final bool Function() isStyleReady;
  final bool Function() shouldFollow;
  final Future<void> Function(LatLng position) followCamera;

  /// Moves the camera so the whole route is inside the visible viewport.
  /// Screens supply the padding for panels, safe areas, and side rails.
  final Future<void> Function(WalkingRouteBounds bounds) fitRouteBounds;

  /// Confirmed rendered state — only ever updated after a successful write.
  WalkingRoute? _renderedRoute;
  bool? _renderedVisibility;
  int? _renderedStyleEpoch;

  /// Route identity that already received its overview camera fit.
  WalkingRoute? _fittedRoute;

  /// True between the route overview and the user explicitly resuming follow.
  ///
  /// Close follow re-centres on the walker at high zoom, which would instantly
  /// throw the freshly fitted route back out of the viewport, so passive
  /// centering and follow are both suppressed until Resume.
  bool _routeOverviewActive = false;

  bool get isRouteOverviewActive => _routeOverviewActive;

  /// Leaves route-overview mode and hands the camera back to follow mode.
  void resumeFollow() => _routeOverviewActive = false;

  int _revisionCounter = 0;
  int _latestRevision = 0;
  _WalkingRouteRenderRequest? _pending;
  bool _draining = false;

  /// Retry state for syncs that could not run because the map was not ready.
  WalkingNavigationProvider? _pendingNavigation;
  Timer? _retryTimer;
  int _retryAttempts = 0;

  /// Bounded so a permanently broken controller cannot spin forever.
  static const int _maximumRetryAttempts = 40;
  static const Duration _retryInterval = Duration(milliseconds: 250);

  /// Most recent typed failure, exposed for diagnostics and tests.
  WalkingRouteMutationResult? get lastFailure => _lastFailure;
  WalkingRouteMutationResult? _lastFailure;

  /// True once geometry and visibility for the active route are confirmed.
  bool get isRouteVisuallyReady =>
      _renderedRoute != null && _renderedVisibility == true;

  void resetForMapController() {
    _renderedRoute = null;
    _renderedVisibility = null;
    _renderedStyleEpoch = null;
    _fittedRoute = null;
    _pending = null;
    _lastFailure = null;
    _cancelRetry();
    // A recreated controller must re-render whatever the session still shows.
    final navigation = _pendingNavigation;
    if (navigation != null) _scheduleRetry(navigation, reason: 'newController');
  }

  /// Releases the retry timer. Screens must call this when disposing.
  void dispose() {
    _cancelRetry();
    _pendingNavigation = null;
  }

  void _scheduleRetry(
    WalkingNavigationProvider navigation, {
    required String reason,
  }) {
    if (_retryTimer != null) return;
    if (_retryAttempts >= _maximumRetryAttempts) return;
    _retryTimer = Timer(_retryInterval, () {
      _retryTimer = null;
      _retryAttempts += 1;
      unawaited(sync(navigation));
    });
    if (_retryAttempts == 0) {
      WalkingNavigationDiagnostics.record(
        'route_render_deferred',
        reason: reason,
      );
    }
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempts = 0;
  }

  Future<void> sync(WalkingNavigationProvider navigation) async {
    _pendingNavigation = navigation;
    final manager = layersManager();
    if (manager == null || !isStyleReady()) {
      // The controller or style is not usable yet. Nothing external is
      // guaranteed to call us again once it becomes ready — a style reload that
      // lands after the last provider notification would otherwise leave the
      // route permanently undrawn — so schedule our own bounded retry.
      _scheduleRetry(navigation, reason: 'styleNotReady');
      return;
    }

    final styleEpoch = manager.initializedStyleEpoch;
    if (styleEpoch == null) {
      _scheduleRetry(navigation, reason: 'layersNotInstalled');
      return;
    }
    _cancelRetry();
    if (styleEpoch != _renderedStyleEpoch) {
      // The previous style's source and layers are gone; nothing that was
      // written to them still counts as rendered.
      _renderedRoute = null;
      _renderedVisibility = null;
      _fittedRoute = null;
    }

    final route = navigation.route;
    final visible = navigation.isVisible && route != null;
    final needsWrite = !identical(route, _renderedRoute) ||
        visible != _renderedVisibility ||
        styleEpoch != _renderedStyleEpoch;

    if (needsWrite) {
      _revisionCounter += 1;
      _latestRevision = _revisionCounter;
      _pending = _WalkingRouteRenderRequest(
        revision: _revisionCounter,
        route: route,
        visible: visible,
        styleEpoch: styleEpoch,
      );
      await _drain(manager);
    }

    final position = navigation.currentPosition;
    if (position != null &&
        !_routeOverviewActive &&
        shouldFollow() &&
        navigation.hasActiveRoute) {
      await followCamera(position);
    }
  }

  /// Serialized writer: one MapLibre mutation sequence at a time, always
  /// finishing with the newest requested revision.
  Future<void> _drain(MapLayersManager manager) async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pending != null) {
        final request = _pending!;
        _pending = null;
        await _render(manager, request);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _render(
    MapLayersManager manager,
    _WalkingRouteRenderRequest request,
  ) async {
    final route = request.route;
    final geoJson = route?.toGeoJson() ?? _emptyFeatureCollection;
    final featureCount = (geoJson['features'] as List<dynamic>).length;
    if (route != null) {
      WalkingNavigationDiagnostics.record(
        'geojson_created',
        reason: 'features=$featureCount',
      );
      if (featureCount == 0) {
        _lastFailure = const WalkingRouteMutationResult(
          WalkingRouteMutationStatus.invalidGeometry,
          detail: 'empty_feature_collection',
        );
        WalkingNavigationDiagnostics.record(
          'route_source_write_failed',
          reason: 'invalidGeometry',
        );
        return;
      }
    }

    WalkingNavigationDiagnostics.record('route_source_write_started');
    final writeResult = await manager.upsertWalkingRouteData(
      geoJson,
      expectedStyleEpoch: request.styleEpoch,
    );
    if (!writeResult.isSuccess) {
      _lastFailure = writeResult;
      WalkingNavigationDiagnostics.record(
        'route_source_write_failed',
        reason: writeResult.status.name,
      );
      return;
    }
    WalkingNavigationDiagnostics.record('route_source_write_succeeded');

    // A newer revision arrived while this write was in flight. Leave the
    // confirmed state untouched so the newer write owns it.
    if (request.revision != _latestRevision) return;

    _renderedRoute = route;
    _renderedStyleEpoch = request.styleEpoch;

    final visibilityResult = await manager.setWalkingNavigationVisibility(
      request.visible,
      expectedStyleEpoch: request.styleEpoch,
    );
    if (!visibilityResult.isSuccess) {
      _lastFailure = visibilityResult;
      // Force the next sync to redo both halves rather than trusting a
      // half-applied state.
      _renderedRoute = null;
      _renderedVisibility = null;
      WalkingNavigationDiagnostics.record(
        'route_visibility_failed',
        reason: visibilityResult.status.name,
      );
      return;
    }
    if (request.revision != _latestRevision) return;

    _renderedVisibility = request.visible;
    _lastFailure = null;
    WalkingNavigationDiagnostics.record('route_visibility_succeeded');

    if (route != null && request.visible) {
      // Overview first, so follow mode never starts on a route that is
      // technically drawn outside the viewport.
      if (!identical(route, _fittedRoute)) {
        final bounds = route.renderableBounds;
        if (bounds != null) {
          _fittedRoute = route;
          _routeOverviewActive = true;
          await fitRouteBounds(bounds);
          WalkingNavigationDiagnostics.record('route_camera_fitted');
        }
      }
      WalkingNavigationDiagnostics.record('route_visually_ready');
    }
  }

  static const Map<String, dynamic> _emptyFeatureCollection = <String, dynamic>{
    'type': 'FeatureCollection',
    'features': <Object>[],
  };
}

class _WalkingRouteRenderRequest {
  const _WalkingRouteRenderRequest({
    required this.revision,
    required this.route,
    required this.visible,
    required this.styleEpoch,
  });

  final int revision;
  final WalkingRoute? route;
  final bool visible;
  final int styleEpoch;
}

/// Owns the continuous desktop walking-location subscription. Mobile reuses
/// its existing map location stream, so only desktop starts this coordinator.
class WalkingNavigationLocationCoordinator {
  WalkingNavigationLocationCoordinator(this.locationApi);

  final WalkingLocationApi locationApi;
  StreamSubscription<WalkingLocationFix>? _subscription;

  bool get isRunning => _subscription != null;

  void start({
    required void Function(WalkingLocationFix fix) onPosition,
    required void Function(Object error) onError,
  }) {
    if (_subscription != null) return;
    _subscription = locationApi.liveFixes().listen(
      onPosition,
      onError: (Object error, StackTrace stack) {
        final failed = _subscription;
        _subscription = null;
        unawaited(failed?.cancel());
        onError(error);
      },
    );
  }

  void pause() => _subscription?.pause();

  void resume() => _subscription?.resume();

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
