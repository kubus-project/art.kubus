import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../config/config.dart';
import '../features/map/navigation/walking_navigation_models.dart';
import '../services/walking_directions_service.dart';

class WalkingNavigationProvider extends ChangeNotifier {
  WalkingNavigationProvider({WalkingDirectionsApi? directionsApi})
      : _directionsApi = directionsApi ?? WalkingDirectionsService();

  static const double arrivalRadiusMeters = 25;
  static const double offRouteThresholdMeters = 45;
  static const int offRouteSamplesBeforeReroute = 3;
  static const Duration minimumRerouteInterval = Duration(seconds: 20);

  final WalkingDirectionsApi _directionsApi;
  final Distance _distance = const Distance();

  WalkingNavigationStatus _status = WalkingNavigationStatus.idle;
  WalkingNavigationIntent? _intent;
  WalkingRoute? _route;
  LatLng? _currentPosition;
  String? _errorMessage;
  int _activeStepIndex = 0;
  int _nearestGeometryIndex = 0;
  double _remainingDistanceMeters = 0;
  double _remainingDurationSeconds = 0;
  int _offRouteSamples = 0;
  DateTime? _lastRouteRequestAt;
  Future<void>? _routeRequest;
  int _requestGeneration = 0;
  double? _positionAccuracyMeters;
  int _arrivalSamples = 0;

  WalkingNavigationStatus get status => _status;
  WalkingNavigationIntent? get intent => _intent;
  WalkingRoute? get route => _route;
  LatLng? get currentPosition => _currentPosition;
  String? get errorMessage => _errorMessage;
  int get activeStepIndex => _activeStepIndex;
  double get remainingDistanceMeters => _remainingDistanceMeters;
  double get remainingDurationSeconds => _remainingDurationSeconds;
  bool get isVisible => _status != WalkingNavigationStatus.idle;
  bool get hasActiveRoute =>
      _route != null &&
      (_status == WalkingNavigationStatus.active ||
          _status == WalkingNavigationStatus.arrived);
  bool get isCalculating => _status == WalkingNavigationStatus.calculating;
  double? get positionAccuracyMeters => _positionAccuracyMeters;

  WalkingRouteStep? get activeStep {
    final steps = _route?.steps;
    if (steps == null || steps.isEmpty) return null;
    return steps[_activeStepIndex.clamp(0, steps.length - 1)];
  }

  void prepare(WalkingNavigationIntent intent) {
    _requestGeneration += 1;
    _intent = intent;
    _route = null;
    _currentPosition = null;
    _errorMessage = null;
    _activeStepIndex = 0;
    _nearestGeometryIndex = 0;
    _remainingDistanceMeters = 0;
    _remainingDurationSeconds = 0;
    _offRouteSamples = 0;
    _arrivalSamples = 0;
    _status = WalkingNavigationStatus.awaitingLocation;
    notifyListeners();
  }

  /// Starts a bounded navigation session. The shared map location lifecycle
  /// supplies fixes, avoiding a second competing GPS subscription on mobile.
  void start(WalkingNavigationIntent intent) {
    if (!AppConfig.isFeatureEnabled('mapWalkingNavigation')) return;
    prepare(intent);
  }

  Future<void> updatePosition(
    LatLng position, {
    double? accuracyMeters,
  }) async {
    if (_intent == null || _status == WalkingNavigationStatus.idle) return;
    _currentPosition = position;
    _positionAccuracyMeters = accuracyMeters;

    if (_status == WalkingNavigationStatus.awaitingLocation) {
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
        DateTime.now().difference(lastRequestAt) >= minimumRerouteInterval;
    if (_offRouteSamples >= offRouteSamplesBeforeReroute && canReroute) {
      _offRouteSamples = 0;
      unawaited(_requestRoute(position, preserveCurrentRoute: true));
    }
    notifyListeners();
  }

  Future<void> retry() async {
    final position = _currentPosition;
    if (_intent == null || position == null) return;
    await _requestRoute(position, preserveCurrentRoute: false);
  }

  void reportLocationUnavailable() {
    if (_status != WalkingNavigationStatus.awaitingLocation) return;
    _status = WalkingNavigationStatus.error;
    _errorMessage = 'Location is unavailable.';
    notifyListeners();
  }

  void stop() {
    _requestGeneration += 1;
    _status = WalkingNavigationStatus.idle;
    _intent = null;
    _route = null;
    _currentPosition = null;
    _errorMessage = null;
    _activeStepIndex = 0;
    _remainingDistanceMeters = 0;
    _remainingDurationSeconds = 0;
    _offRouteSamples = 0;
    _arrivalSamples = 0;
    _positionAccuracyMeters = null;
    notifyListeners();
  }

  Future<void> _requestRoute(
    LatLng origin, {
    required bool preserveCurrentRoute,
  }) {
    final inFlight = _routeRequest;
    if (inFlight != null) return inFlight;

    final intent = _intent;
    if (intent == null) return Future<void>.value();
    final generation = _requestGeneration;
    _lastRouteRequestAt = DateTime.now();
    if (!preserveCurrentRoute) {
      _status = WalkingNavigationStatus.calculating;
      _errorMessage = null;
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
        _errorMessage = null;
        _activeStepIndex = 0;
        _offRouteSamples = 0;
        _updateProgress(origin, route);
        notifyListeners();
      } catch (error) {
        if (generation != _requestGeneration || _intent != intent) return;
        if (!preserveCurrentRoute || _route == null) {
          _status = WalkingNavigationStatus.error;
          _errorMessage = error.toString();
        }
        notifyListeners();
      } finally {
        _routeRequest = null;
      }
    }();
    _routeRequest = request;
    return request;
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
      return;
    }

    _status = WalkingNavigationStatus.active;
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
