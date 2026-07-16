import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../config/config.dart';
import '../features/map/navigation/walking_navigation_models.dart';
import '../services/walking_directions_service.dart';
import '../services/walking_navigation_diagnostics.dart';

class WalkingNavigationProvider extends ChangeNotifier {
  WalkingNavigationProvider({
    WalkingDirectionsApi? directionsApi,
    DateTime Function()? now,
  })  : _directionsApi = directionsApi ?? WalkingDirectionsService(),
        _now = now ?? DateTime.now;

  static const double arrivalRadiusMeters = 25;
  static const double offRouteThresholdMeters = 45;
  static const int offRouteSamplesBeforeReroute = 3;
  static const Duration minimumRerouteInterval = Duration(seconds: 20);

  final WalkingDirectionsApi _directionsApi;
  final DateTime Function() _now;
  final Distance _distance = const Distance();

  WalkingNavigationStatus _status = WalkingNavigationStatus.idle;
  WalkingNavigationIntent? _intent;
  WalkingRoute? _route;
  LatLng? _currentPosition;
  WalkingNavigationFailureKind? _failureKind;
  int _activeStepIndex = 0;
  int _nearestGeometryIndex = 0;
  double _remainingDistanceMeters = 0;
  double _remainingDurationSeconds = 0;
  int _offRouteSamples = 0;
  DateTime? _lastRouteRequestAt;
  Future<void>? _routeRequest;
  int? _routeRequestGeneration;
  int _requestGeneration = 0;
  double? _positionAccuracyMeters;
  int _arrivalSamples = 0;

  WalkingNavigationStatus get status => _status;
  WalkingNavigationIntent? get intent => _intent;
  WalkingRoute? get route => _route;
  LatLng? get currentPosition => _currentPosition;
  int get activeStepIndex => _activeStepIndex;
  double get remainingDistanceMeters => _remainingDistanceMeters;
  double get remainingDurationSeconds => _remainingDurationSeconds;
  bool get isVisible => _status != WalkingNavigationStatus.idle;
  bool get hasActiveRoute =>
      _route != null &&
      (_status == WalkingNavigationStatus.active ||
          _status == WalkingNavigationStatus.rerouting ||
          _status == WalkingNavigationStatus.arrived);
  bool get isCalculating => _status == WalkingNavigationStatus.calculating;
  double? get positionAccuracyMeters => _positionAccuracyMeters;
  WalkingNavigationFailureKind? get failureKind => _failureKind;
  bool get needsLiveLocation => switch (_failureKind) {
        WalkingNavigationFailureKind.locationPermissionDenied ||
        WalkingNavigationFailureKind.locationPermissionDeniedPermanently ||
        WalkingNavigationFailureKind.locationServicesDisabled ||
        WalkingNavigationFailureKind.locationUnavailable ||
        WalkingNavigationFailureKind.locationTimedOut =>
          true,
        _ => _currentPosition == null,
      };

  WalkingRouteStep? get activeStep {
    final steps = _route?.steps;
    if (steps == null || steps.isEmpty) return null;
    return steps[_activeStepIndex.clamp(0, steps.length - 1)];
  }

  void prepare(WalkingNavigationIntent intent) {
    _requestGeneration += 1;
    _routeRequest = null;
    _routeRequestGeneration = null;
    _intent = intent;
    _route = null;
    _currentPosition = null;
    _positionAccuracyMeters = null;
    _lastRouteRequestAt = null;
    _failureKind = null;
    _resetRouteProgress();
    _status = WalkingNavigationStatus.awaitingLocation;
    WalkingNavigationDiagnostics.record('session_started');
    notifyListeners();
  }

  /// Starts a bounded navigation session. The shared map location lifecycle
  /// supplies fixes, avoiding a second competing GPS subscription on mobile.
  WalkingNavigationSessionLease? start(WalkingNavigationIntent intent) {
    if (!AppConfig.isFeatureEnabled('mapWalkingNavigation')) return null;
    prepare(intent);
    return WalkingNavigationSessionLease(_requestGeneration);
  }

  Future<void> updatePosition(
    LatLng position, {
    double? accuracyMeters,
    WalkingNavigationSessionLease? lease,
  }) async {
    if (!_ownsSession(lease)) return;
    if (_intent == null || _status == WalkingNavigationStatus.idle) return;
    _currentPosition = position;
    _positionAccuracyMeters = accuracyMeters;

    if (_status == WalkingNavigationStatus.awaitingLocation ||
        (_status == WalkingNavigationStatus.error &&
            _isLocationFailure(_failureKind))) {
      await _requestRoute(position, preserveCurrentRoute: false);
      return;
    }

    final route = _route;
    if (route == null) {
      notifyListeners();
      return;
    }

    _updateProgress(position, route);
    if (_status == WalkingNavigationStatus.arrived) {
      notifyListeners();
      return;
    }

    final distanceFromRoute = _distanceFromRoute(position, route.points);
    final accuracyAwareThreshold = math.max(
      offRouteThresholdMeters,
      (accuracyMeters ?? 0) * 1.5,
    );
    if (distanceFromRoute > accuracyAwareThreshold) {
      _offRouteSamples += 1;
    } else {
      _offRouteSamples = 0;
    }

    final lastRequestAt = _lastRouteRequestAt;
    final canReroute = lastRequestAt == null ||
        _now().difference(lastRequestAt) >= minimumRerouteInterval;
    if (_offRouteSamples >= offRouteSamplesBeforeReroute && canReroute) {
      _offRouteSamples = 0;
      unawaited(_requestRoute(position, preserveCurrentRoute: true));
    }
    notifyListeners();
  }

  Future<void> retry({WalkingNavigationSessionLease? lease}) async {
    if (!_ownsSession(lease)) return;
    final position = _currentPosition;
    if (_intent == null) return;
    if (position == null) {
      _status = WalkingNavigationStatus.awaitingLocation;
      _failureKind = null;
      notifyListeners();
      return;
    }
    await _requestRoute(position, preserveCurrentRoute: false);
  }

  void beginLocationRequest({WalkingNavigationSessionLease? lease}) {
    if (!_ownsSession(lease) || _intent == null) return;
    _status = WalkingNavigationStatus.requestingPermission;
    _failureKind = null;
    WalkingNavigationDiagnostics.record('location_request_started');
    notifyListeners();
  }

  void reportLocationAccess(
    WalkingLocationAccessStatus status, {
    WalkingNavigationSessionLease? lease,
  }) {
    if (!_ownsSession(lease) || _intent == null) return;
    if (status == WalkingLocationAccessStatus.available) return;
    _currentPosition = null;
    _positionAccuracyMeters = null;
    _status = WalkingNavigationStatus.error;
    _currentPosition = null;
    _positionAccuracyMeters = null;
    _failureKind = switch (status) {
      WalkingLocationAccessStatus.permissionDenied =>
        WalkingNavigationFailureKind.locationPermissionDenied,
      WalkingLocationAccessStatus.permissionDeniedPermanently =>
        WalkingNavigationFailureKind.locationPermissionDeniedPermanently,
      WalkingLocationAccessStatus.serviceDisabled =>
        WalkingNavigationFailureKind.locationServicesDisabled,
      WalkingLocationAccessStatus.timedOut =>
        WalkingNavigationFailureKind.locationTimedOut,
      WalkingLocationAccessStatus.permissionNotRequested ||
      WalkingLocationAccessStatus.requestingPermission ||
      WalkingLocationAccessStatus.liveLocationUnavailable ||
      WalkingLocationAccessStatus.available =>
        WalkingNavigationFailureKind.locationUnavailable,
    };
    WalkingNavigationDiagnostics.record(
      'permission_result',
      reason: status.name,
    );
    notifyListeners();
  }

  void reportLocationUnavailable({WalkingNavigationSessionLease? lease}) {
    if (!_ownsSession(lease)) return;
    if (_status == WalkingNavigationStatus.idle ||
        _status == WalkingNavigationStatus.arrived) {
      return;
    }
    _status = WalkingNavigationStatus.error;
    _failureKind = WalkingNavigationFailureKind.locationUnavailable;
    WalkingNavigationDiagnostics.record(
      'route_request_failed',
      reason: _failureKind!.name,
    );
    notifyListeners();
  }

  /// Stops only the session created by [lease]. A stale map route therefore
  /// cannot tear down a newer walking-navigation session during disposal.
  bool stopOwned(WalkingNavigationSessionLease? lease) {
    if (lease == null || lease.generation != _requestGeneration) return false;
    stop();
    return true;
  }

  bool _ownsSession(WalkingNavigationSessionLease? lease) =>
      lease == null || lease.generation == _requestGeneration;

  void stop() {
    _requestGeneration += 1;
    _routeRequest = null;
    _routeRequestGeneration = null;
    _status = WalkingNavigationStatus.idle;
    _intent = null;
    _route = null;
    _currentPosition = null;
    _lastRouteRequestAt = null;
    _failureKind = null;
    _resetRouteProgress();
    _positionAccuracyMeters = null;
    WalkingNavigationDiagnostics.record('navigation_ended');
    notifyListeners();
  }

  Future<void> _requestRoute(
    LatLng origin, {
    required bool preserveCurrentRoute,
  }) {
    final inFlight = _routeRequest;
    if (inFlight != null && _routeRequestGeneration == _requestGeneration) {
      return inFlight;
    }

    final intent = _intent;
    if (intent == null) return Future<void>.value();
    final generation = _requestGeneration;
    _lastRouteRequestAt = _now();
    WalkingNavigationDiagnostics.record(
      preserveCurrentRoute ? 'reroute_triggered' : 'route_request_started',
    );
    if (!preserveCurrentRoute) {
      _status = WalkingNavigationStatus.calculating;
      _failureKind = null;
      notifyListeners();
    } else {
      _status = WalkingNavigationStatus.rerouting;
      notifyListeners();
    }

    final request = () async {
      try {
        final route = await _directionsApi.route(
          origin: origin,
          destination: intent.destination,
        );
        if (generation != _requestGeneration || _intent != intent) return;
        _route = route;
        _status = WalkingNavigationStatus.active;
        _failureKind = null;
        _resetRouteProgress();
        _updateProgress(origin, route);
        WalkingNavigationDiagnostics.record('route_request_succeeded');
        notifyListeners();
      } catch (error) {
        if (generation != _requestGeneration || _intent != intent) return;
        if (!preserveCurrentRoute || _route == null) {
          _status = WalkingNavigationStatus.error;
          _failureKind = _failureFor(error);
        } else {
          _status = WalkingNavigationStatus.active;
        }
        WalkingNavigationDiagnostics.record(
          'route_request_failed',
          reason: _failureFor(error).name,
        );
        notifyListeners();
      } finally {
        if (_routeRequestGeneration == generation) {
          _routeRequest = null;
          _routeRequestGeneration = null;
        }
      }
    }();
    _routeRequest = request;
    _routeRequestGeneration = generation;
    return request;
  }

  WalkingNavigationFailureKind _failureFor(Object error) {
    if (error is! WalkingDirectionsException) {
      return WalkingNavigationFailureKind.routeNetwork;
    }
    return switch (error.type) {
      WalkingDirectionsErrorType.noRoute =>
        WalkingNavigationFailureKind.noRoute,
      WalkingDirectionsErrorType.routeTooLong =>
        WalkingNavigationFailureKind.routeTooLong,
      WalkingDirectionsErrorType.sourceTimeout =>
        WalkingNavigationFailureKind.routeSourceTimeout,
      WalkingDirectionsErrorType.sourceInvalidResponse =>
        WalkingNavigationFailureKind.routeMalformed,
      WalkingDirectionsErrorType.sourceTransport ||
      WalkingDirectionsErrorType.sourceHttp ||
      WalkingDirectionsErrorType.sourceCancelled =>
        WalkingNavigationFailureKind.routeNetwork,
    };
  }

  bool _isLocationFailure(WalkingNavigationFailureKind? failure) =>
      switch (failure) {
        WalkingNavigationFailureKind.locationPermissionDenied ||
        WalkingNavigationFailureKind.locationPermissionDeniedPermanently ||
        WalkingNavigationFailureKind.locationServicesDisabled ||
        WalkingNavigationFailureKind.locationUnavailable ||
        WalkingNavigationFailureKind.locationTimedOut =>
          true,
        _ => false,
      };

  void _resetRouteProgress() {
    _activeStepIndex = 0;
    _nearestGeometryIndex = 0;
    _remainingDistanceMeters = 0;
    _remainingDurationSeconds = 0;
    _offRouteSamples = 0;
    _arrivalSamples = 0;
  }

  void _updateProgress(LatLng position, WalkingRoute route) {
    final destinationDistance = _distance.as(
      LengthUnit.Meter,
      position,
      _intent!.destination,
    );
    if (destinationDistance <= arrivalRadiusMeters) {
      _arrivalSamples += 1;
    } else {
      _arrivalSamples = 0;
    }
    if (_arrivalSamples >= 2) {
      _status = WalkingNavigationStatus.arrived;
      _nearestGeometryIndex = route.points.length - 1;
      _activeStepIndex = route.steps.isEmpty ? 0 : route.steps.length - 1;
      _remainingDistanceMeters = 0;
      _remainingDurationSeconds = 0;
      WalkingNavigationDiagnostics.record('destination_reached');
      return;
    }

    if (_status != WalkingNavigationStatus.rerouting) {
      _status = WalkingNavigationStatus.active;
    }
    final projection = _projectOntoRoute(position, route.points);
    final projectedGeometryIndex =
        projection.segmentIndex + (projection.segmentFraction >= 0.5 ? 1 : 0);
    _nearestGeometryIndex = math.max(
      _nearestGeometryIndex,
      projectedGeometryIndex.clamp(0, route.points.length - 1),
    );
    var nextStep = 0;
    for (var index = 0; index < route.steps.length; index += 1) {
      if (route.steps[index].geometryIndex <= _nearestGeometryIndex + 1) {
        nextStep = index;
      } else {
        break;
      }
    }
    if (nextStep + 1 < route.steps.length) {
      final distanceToNext = _distance.as(
        LengthUnit.Meter,
        position,
        route.steps[nextStep + 1].location,
      );
      if (distanceToNext <= 18) nextStep += 1;
    }
    _activeStepIndex = nextStep;

    var remaining = projection.projectedPoint == null
        ? 0.0
        : _distance.as(
            LengthUnit.Meter,
            projection.projectedPoint!,
            route.points[projection.segmentIndex + 1],
          );
    for (var index = projection.segmentIndex + 1;
        index + 1 < route.points.length;
        index += 1) {
      remaining += _distance.as(
        LengthUnit.Meter,
        route.points[index],
        route.points[index + 1],
      );
    }
    _remainingDistanceMeters = _remainingDistanceMeters > 0
        ? math.min(_remainingDistanceMeters, remaining)
        : remaining;
    _remainingDurationSeconds = route.distanceMeters <= 0
        ? 0
        : route.durationSeconds *
            (_remainingDistanceMeters / route.distanceMeters);
  }

  double _distanceFromRoute(LatLng position, List<LatLng> points) {
    return _projectOntoRoute(position, points).distanceMeters;
  }

  _RouteProjectionRecord _projectOntoRoute(
    LatLng position,
    List<LatLng> points,
  ) {
    if (points.length < 2) {
      return _RouteProjectionRecord(
        segmentIndex: 0,
        segmentFraction: 0,
        projectedPoint: points.isEmpty ? null : points.first,
        distanceMeters: points.isEmpty
            ? double.infinity
            : _distance.as(LengthUnit.Meter, position, points.first),
      );
    }

    var best = const _RouteProjectionRecord(
      segmentIndex: 0,
      segmentFraction: 0,
      projectedPoint: null,
      distanceMeters: double.infinity,
    );
    final longitudeScale = math.cos(position.latitude * math.pi / 180);
    for (var index = 0; index + 1 < points.length; index += 1) {
      final start = points[index];
      final end = points[index + 1];
      final dx = (end.longitude - start.longitude) * longitudeScale;
      final dy = end.latitude - start.latitude;
      final denominator = dx * dx + dy * dy;
      final fraction = denominator <= 0
          ? 0.0
          : (((position.longitude - start.longitude) * longitudeScale * dx +
                      (position.latitude - start.latitude) * dy) /
                  denominator)
              .clamp(0.0, 1.0)
              .toDouble();
      final projected = LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
      final meters = _distance.as(LengthUnit.Meter, position, projected);
      if (meters < best.distanceMeters) {
        best = _RouteProjectionRecord(
          segmentIndex: index,
          segmentFraction: fraction,
          projectedPoint: projected,
          distanceMeters: meters,
        );
      }
    }
    return best;
  }

  @override
  void dispose() {
    _directionsApi.dispose();
    super.dispose();
  }
}

class _RouteProjectionRecord {
  const _RouteProjectionRecord({
    required this.segmentIndex,
    required this.segmentFraction,
    required this.projectedPoint,
    required this.distanceMeters,
  });

  final int segmentIndex;
  final double segmentFraction;
  final LatLng? projectedPoint;
  final double distanceMeters;
}
