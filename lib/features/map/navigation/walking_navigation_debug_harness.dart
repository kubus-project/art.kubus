import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../services/walking_directions_service.dart';
import '../../../services/walking_location_service.dart';
import 'walking_navigation_models.dart';

/// Debug-only deterministic walking-route rendering harness.
///
/// It drives the *production* pipeline — provider, [WalkingRoute.toGeoJson],
/// `WalkingNavigationMapCoordinator`, `MapLayersManager`, the real MapLibre
/// source and route layers, visibility, and camera fitting — with a fixed route
/// instead of GPS, Overpass, the backend, or artwork data. Nothing here draws
/// anything itself.
///
/// This separates the two halves of the pipeline:
/// - the harness route does not appear -> rendering is broken;
/// - it appears but a live route does not -> location or route acquisition is
///   broken.
///
/// Every entry point is gated behind [isEnabled], which is only ever true in
/// debug builds (asserts enabled). Release builds cannot reach it.
class WalkingNavigationDebugHarness {
  const WalkingNavigationDebugHarness._();

  /// True only when asserts are enabled, i.e. debug builds.
  static bool get isEnabled {
    var enabled = false;
    assert(() {
      enabled = true;
      return true;
    }());
    return enabled;
  }

  /// Route path name recognised by the app router in debug builds.
  static const String routeName = '/debug/walking-route';

  /// A short, valid pedestrian route through central Ljubljana.
  ///
  /// Six points along Prešernov trg -> Trančnjeva/Cankarjevo nabrežje, roughly
  /// 260 m, well inside a single map viewport at walking zoom levels.
  static const List<LatLng> routePoints = <LatLng>[
    LatLng(46.05130, 14.50607),
    LatLng(46.05101, 14.50652),
    LatLng(46.05063, 14.50703),
    LatLng(46.05021, 14.50761),
    LatLng(46.04982, 14.50822),
    LatLng(46.04951, 14.50881),
  ];

  static LatLng get origin => routePoints.first;

  static LatLng get destination => routePoints.last;

  static WalkingNavigationIntent get intent => WalkingNavigationIntent(
        destinationId: 'debug-walking-harness',
        destinationLabel: 'Deterministic route',
        destination: destination,
      );

  /// The canonical harness route. Graph indices deliberately leave one
  /// connector at each end so casing, route, and connector layers are all
  /// exercised.
  static WalkingRoute get route => WalkingRoute(
        points: routePoints,
        steps: <WalkingRouteStep>[
          WalkingRouteStep(
            type: 'depart',
            modifier: '',
            roadName: 'Prešernov trg',
            location: routePoints.first,
            distanceMeters: 120,
            durationSeconds: 95,
            geometryIndex: 0,
          ),
          WalkingRouteStep(
            type: 'arrive',
            modifier: '',
            roadName: 'Cankarjevo nabrežje',
            location: routePoints.last,
            distanceMeters: 0,
            durationSeconds: 0,
            geometryIndex: routePoints.length - 1,
          ),
        ],
        distanceMeters: 260,
        durationSeconds: 205,
        graphStartIndex: 1,
        graphEndIndex: routePoints.length - 2,
      );
}

/// Returns [WalkingNavigationDebugHarness.route] without contacting Overpass.
///
/// The provider still runs its real request, generation, progress, and
/// notification path, so only the network source is replaced.
class DeterministicWalkingDirectionsApi implements WalkingDirectionsApi {
  DeterministicWalkingDirectionsApi();

  int requests = 0;

  @override
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    requests += 1;
    return WalkingNavigationDebugHarness.route;
  }

  @override
  void dispose() {}
}

/// Supplies a fixed live fix so the harness never prompts for permissions.
class DeterministicWalkingLocationService implements WalkingLocationApi {
  DeterministicWalkingLocationService({this.streamInterval});

  /// When set, emits repeated fixes so follow-mode behaviour can be observed.
  final Duration? streamInterval;

  @override
  Future<WalkingLocationAccessResult> acquireLiveFix({
    required bool requestPermission,
  }) async =>
      WalkingLocationAccessResult(
        WalkingLocationAccessStatus.available,
        fix: _fix(),
      );

  @override
  Stream<WalkingLocationFix> liveFixes() {
    final interval = streamInterval;
    if (interval == null) return const Stream<WalkingLocationFix>.empty();
    return Stream<WalkingLocationFix>.periodic(interval, (_) => _fix());
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;

  WalkingLocationFix _fix() => WalkingLocationFix(
        position: WalkingNavigationDebugHarness.origin,
        accuracyMeters: 5,
        timestamp: DateTime.now(),
      );
}
