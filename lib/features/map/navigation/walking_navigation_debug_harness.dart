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

  /// A real pedestrian route through central Ljubljana, 728 m.
  ///
  /// These are not hand-drawn coordinates. They are the verbatim output of the
  /// production [WalkingDirectionsService] routing Prešernov trg -> Vodnikov trg
  /// over live OSM data, captured once and frozen. The path follows Stritarjeva
  /// ulica, Mačkova ulica, Medarska ulica, Ciril-Metodov trg, Študentovska
  /// ulica, and Za ograjami.
  ///
  /// Real geometry matters here: the app must *never* substitute a straight
  /// line when no connected walking route exists, so a straight line is the
  /// visual signature of a routing failure. A fixture that renders as a
  /// straight diagonal would be indistinguishable from that failure and could
  /// not be validated by eye. Every turn in this path is a real street corner.
  static const List<LatLng> routePoints = <LatLng>[
    LatLng(46.05130, 14.50607),
    LatLng(46.05126, 14.50613),
    LatLng(46.05099, 14.50630),
    LatLng(46.05095, 14.50633),
    LatLng(46.05051, 14.50667),
    LatLng(46.05055, 14.50677),
    LatLng(46.05072, 14.50727),
    LatLng(46.05067, 14.50731),
    LatLng(46.05057, 14.50737),
    LatLng(46.05043, 14.50748),
    LatLng(46.05039, 14.50754),
    LatLng(46.05051, 14.50796),
    LatLng(46.05056, 14.50828),
    LatLng(46.05061, 14.50866),
    LatLng(46.05066, 14.50906),
    LatLng(46.05066, 14.50910),
    LatLng(46.05068, 14.50920),
    LatLng(46.05073, 14.50960),
    LatLng(46.05064, 14.50962),
    LatLng(46.05057, 14.50962),
    LatLng(46.05052, 14.50961),
    LatLng(46.05044, 14.50958),
    LatLng(46.05038, 14.50954),
    LatLng(46.05033, 14.50951),
    LatLng(46.05029, 14.50947),
    LatLng(46.05025, 14.50943),
    LatLng(46.05023, 14.50937),
    LatLng(46.05021, 14.50933),
    LatLng(46.05019, 14.50924),
    LatLng(46.05017, 14.50906),
    LatLng(46.05014, 14.50887),
    LatLng(46.05012, 14.50877),
    LatLng(46.05008, 14.50860),
    LatLng(46.04999, 14.50831),
    LatLng(46.04995, 14.50814),
    LatLng(46.04993, 14.50810),
    LatLng(46.04984, 14.50792),
    LatLng(46.04980, 14.50786),
    LatLng(46.04980, 14.50789),
    LatLng(46.04980, 14.50793),
    LatLng(46.04982, 14.50800),
    LatLng(46.04983, 14.50809),
    LatLng(46.04983, 14.50813),
    LatLng(46.04982, 14.50814),
    LatLng(46.04981, 14.50815),
    LatLng(46.04980, 14.50815),
    LatLng(46.04979, 14.50814),
    LatLng(46.04972, 14.50797),
    LatLng(46.04971, 14.50796),
    LatLng(46.04970, 14.50795),
    LatLng(46.04969, 14.50795),
    LatLng(46.04969, 14.50798),
    LatLng(46.04972, 14.50811),
    LatLng(46.04974, 14.50822),
    LatLng(46.04976, 14.50831),
    LatLng(46.04977, 14.50842),
    LatLng(46.04975, 14.50860),
    LatLng(46.04972, 14.50878),
    LatLng(46.04970, 14.50888),
    LatLng(46.04968, 14.50899),
    LatLng(46.04964, 14.50909),
    LatLng(46.04963, 14.50912),
    LatLng(46.04961, 14.50912),
    LatLng(46.04961, 14.50908),
    LatLng(46.04963, 14.50895),
    LatLng(46.04964, 14.50885),
    LatLng(46.04951, 14.50881),
  ];

  static LatLng get origin => routePoints.first;

  static LatLng get destination => routePoints.last;

  static WalkingNavigationIntent get intent => WalkingNavigationIntent(
        destinationId: 'debug-walking-harness',
        destinationLabel: 'Deterministic route',
        destination: destination,
      );

  /// The canonical harness route, exactly as the production router produced it.
  ///
  /// The graph indices are the real snap indices (1 and 65), so the origin and
  /// destination connectors are genuine graph-snap segments and the casing,
  /// route, and connector layers are all exercised.
  static WalkingRoute get route => WalkingRoute(
        points: routePoints,
        steps: _steps,
        distanceMeters: 728,
        durationSeconds: 539.3,
        graphStartIndex: 1,
        graphEndIndex: 65,
      );

  static List<WalkingRouteStep> get _steps => <WalkingRouteStep>[
        _step('depart', 'straight', '', 0, 39, 28.9),
        _step('turn', 'straight', 'Stritarjeva ulica', 2, 61, 45.2),
        _step('turn', 'left', 'Mačkova ulica', 4, 52, 38.5),
        _step('turn', 'right', 'Medarska ulica', 6, 43, 31.9),
        _step('turn', 'left', 'Ciril-Metodov trg', 10, 165, 122.2),
        _step('turn', 'right', 'Študentovska ulica', 17, 73, 54.1),
        _step('turn', 'straight', 'Za ograjami', 28, 116, 85.9),
        _step('turn', 'left', '', 37, 21, 15.6),
        _step('turn', 'slight right', '', 42, 1, 0.7),
        _step('turn', 'slight right', '', 43, 1, 0.7),
        _step('turn', 'slight right', '', 44, 1, 0.7),
        _step('turn', 'slight right', '', 45, 21, 15.6),
        _step('turn', 'left', '', 50, 95, 70.4),
        _step('turn', 'right', '', 61, 2, 1.5),
        _step('turn', 'right', '', 62, 22, 16.3),
        _step('turn', 'left', '', 65, 15, 11.1),
        _step('arrive', 'straight', '', 66, 0, 0),
      ];

  static WalkingRouteStep _step(
    String type,
    String modifier,
    String roadName,
    int geometryIndex,
    double distanceMeters,
    double durationSeconds,
  ) =>
      WalkingRouteStep(
        type: type,
        modifier: modifier,
        roadName: roadName,
        location: routePoints[geometryIndex],
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        geometryIndex: geometryIndex,
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
