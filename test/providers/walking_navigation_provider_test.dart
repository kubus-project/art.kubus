import 'dart:async';

import 'package:art_kubus/features/map/navigation/walking_navigation_models.dart';
import 'package:art_kubus/providers/walking_navigation_provider.dart';
import 'package:art_kubus/services/walking_directions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const origin = LatLng(46.0569, 14.5057);
  const destination = LatLng(46.0574, 14.5070);
  const intent = WalkingNavigationIntent(
    destinationId: 'artwork-1',
    destinationLabel: 'Artwork',
    destination: destination,
  );

  test('marks graph snaps as dashed connector features', () {
    const route = WalkingRoute(
      points: <LatLng>[
        LatLng(46, 14),
        LatLng(46, 14.0001),
        LatLng(46, 14.001),
        LatLng(46, 14.0011),
      ],
      steps: <WalkingRouteStep>[],
      distanceMeters: 100,
      durationSeconds: 75,
      graphStartIndex: 1,
      graphEndIndex: 2,
    );

    final features = route.toGeoJson()['features'] as List<dynamic>;
    expect(
      features.map((feature) => feature['properties']['kind']),
      <String>['route', 'connector', 'connector'],
    );
  });

  test('builds a route from the first real location fix', () async {
    final api = _FakeDirectionsApi(_route(origin, destination));
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    provider.prepare(intent);
    await provider.updatePosition(origin, accuracyMeters: 6);

    expect(api.requests, 1);
    expect(provider.status, WalkingNavigationStatus.active);
    expect(provider.route?.points, [origin, destination]);
    expect(provider.positionAccuracyMeters, 6);
  });

  test('requires two consecutive close fixes before arrival', () async {
    final api = _FakeDirectionsApi(_route(origin, destination));
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    provider.prepare(intent);
    await provider.updatePosition(origin);
    await provider.updatePosition(destination);
    expect(provider.status, WalkingNavigationStatus.active);

    await provider.updatePosition(destination);
    expect(provider.status, WalkingNavigationStatus.arrived);
    expect(provider.remainingDistanceMeters, 0);
  });

  test('stop consumes the session and ignores later fixes', () async {
    final api = _FakeDirectionsApi(_route(origin, destination));
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    provider.prepare(intent);
    provider.stop();
    await provider.updatePosition(origin);

    expect(provider.status, WalkingNavigationStatus.idle);
    expect(api.requests, 0);
  });

  test('late live fix recovers a location-unavailable session', () async {
    final api = _FakeDirectionsApi(_route(origin, destination));
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    provider.prepare(intent);
    provider.reportLocationUnavailable();
    expect(
        provider.failureKind, WalkingNavigationFailureKind.locationUnavailable);

    await provider.updatePosition(origin, accuracyMeters: 8);

    expect(api.requests, 1);
    expect(provider.status, WalkingNavigationStatus.active);
    expect(provider.failureKind, isNull);
  });

  test('stale map lease cannot mutate or stop a newer navigation session',
      () async {
    final api = _FakeDirectionsApi(_route(origin, destination));
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    final staleLease = provider.start(intent)!;
    const replacement = WalkingNavigationIntent(
      destinationId: 'artwork-2',
      destinationLabel: 'Replacement artwork',
      destination: LatLng(46.0600, 14.5100),
    );
    final currentLease = provider.start(replacement)!;

    provider.reportLocationUnavailable(lease: staleLease);
    await provider.updatePosition(origin, lease: staleLease);
    await provider.retry(lease: staleLease);
    expect(provider.stopOwned(staleLease), isFalse);
    expect(provider.intent, replacement);
    expect(provider.status, WalkingNavigationStatus.awaitingLocation);
    expect(api.requests, 0);

    expect(provider.stopOwned(currentLease), isTrue);
    expect(provider.status, WalkingNavigationStatus.idle);
  });

  test('a new intent starts a fresh request while the old one is in flight',
      () async {
    const secondDestination = LatLng(46.0600, 14.5100);
    const secondIntent = WalkingNavigationIntent(
      destinationId: 'artwork-2',
      destinationLabel: 'Second artwork',
      destination: secondDestination,
    );
    final firstRequest = Completer<WalkingRoute>();
    final secondRequest = Completer<WalkingRoute>();
    final api = _CompleterDirectionsApi(<Completer<WalkingRoute>>[
      firstRequest,
      secondRequest,
    ]);
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    provider.prepare(intent);
    expect(notifications, 1);
    final firstUpdate = provider.updatePosition(origin);
    expect(api.destinations, <LatLng>[destination]);
    expect(notifications, 2);

    provider.prepare(secondIntent);
    expect(notifications, 3);
    final secondUpdate = provider.updatePosition(origin);
    expect(api.destinations, <LatLng>[destination, secondDestination]);
    expect(notifications, 4);

    firstRequest.complete(_route(origin, destination));
    await firstUpdate;
    expect(notifications, 4);
    final retry = provider.retry();
    expect(api.destinations, <LatLng>[destination, secondDestination]);
    expect(notifications, 4);

    final secondRoute = _route(origin, secondDestination);
    secondRequest.complete(secondRoute);
    await Future.wait(<Future<void>>[secondUpdate, retry]);
    expect(provider.intent, same(secondIntent));
    expect(provider.route, same(secondRoute));
    expect(provider.status, WalkingNavigationStatus.active);
    expect(notifications, 5);
  });

  test('stop invalidates an in-flight request without a stale notification',
      () async {
    final request = Completer<WalkingRoute>();
    final api = _CompleterDirectionsApi(<Completer<WalkingRoute>>[request]);
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    provider.prepare(intent);
    final update = provider.updatePosition(origin);
    provider.stop();
    expect(notifications, 3);

    request.complete(_route(origin, destination));
    await update;

    expect(notifications, 3);
    expect(provider.status, WalkingNavigationStatus.idle);
    expect(provider.intent, isNull);
    expect(provider.route, isNull);
    expect(provider.currentPosition, isNull);
    expect(provider.errorMessage, isNull);
  });

  test('reroute resets progress before applying the replacement geometry',
      () async {
    var now = DateTime(2026, 1, 1);
    const midpoint = LatLng(46.0570, 14.5060);
    const nearDestination = LatLng(46.05715, 14.50665);
    const rerouteOrigin = LatLng(46.0600, 14.5000);
    const detour = LatLng(46.0650, 14.5100);
    final initialRoute = WalkingRoute(
      points: const <LatLng>[
        origin,
        midpoint,
        nearDestination,
        destination,
      ],
      steps: const <WalkingRouteStep>[
        WalkingRouteStep(
          type: 'depart',
          modifier: 'straight',
          roadName: 'First street',
          location: origin,
          distanceMeters: 100,
          durationSeconds: 75,
          geometryIndex: 0,
        ),
        WalkingRouteStep(
          type: 'turn',
          modifier: 'right',
          roadName: 'Middle street',
          location: midpoint,
          distanceMeters: 70,
          durationSeconds: 55,
          geometryIndex: 1,
        ),
        WalkingRouteStep(
          type: 'turn',
          modifier: 'left',
          roadName: 'Last street',
          location: nearDestination,
          distanceMeters: 40,
          durationSeconds: 30,
          geometryIndex: 2,
        ),
        WalkingRouteStep(
          type: 'arrive',
          modifier: 'straight',
          roadName: '',
          location: destination,
          distanceMeters: 0,
          durationSeconds: 0,
          geometryIndex: 3,
        ),
      ],
      distanceMeters: 140,
      durationSeconds: 105,
    );
    final replacementRoute = WalkingRoute(
      points: const <LatLng>[rerouteOrigin, detour, destination],
      steps: const <WalkingRouteStep>[
        WalkingRouteStep(
          type: 'depart',
          modifier: 'straight',
          roadName: 'Detour start',
          location: rerouteOrigin,
          distanceMeters: 1200,
          durationSeconds: 900,
          geometryIndex: 0,
        ),
        WalkingRouteStep(
          type: 'turn',
          modifier: 'right',
          roadName: 'Detour finish',
          location: detour,
          distanceMeters: 600,
          durationSeconds: 450,
          geometryIndex: 1,
        ),
        WalkingRouteStep(
          type: 'arrive',
          modifier: 'straight',
          roadName: '',
          location: destination,
          distanceMeters: 0,
          durationSeconds: 0,
          geometryIndex: 2,
        ),
      ],
      distanceMeters: 1800,
      durationSeconds: 1350,
    );
    final api = _SequenceDirectionsApi(<WalkingRoute>[
      initialRoute,
      replacementRoute,
    ]);
    final provider = WalkingNavigationProvider(
      directionsApi: api,
      now: () => now,
    );
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    provider.prepare(intent);
    await provider.updatePosition(origin, accuracyMeters: 5);
    await provider.updatePosition(nearDestination, accuracyMeters: 5);
    expect(provider.activeStepIndex, 3);
    expect(provider.remainingDistanceMeters, lessThan(100));

    now = now.add(WalkingNavigationProvider.minimumRerouteInterval);
    await provider.updatePosition(rerouteOrigin, accuracyMeters: 5);
    await provider.updatePosition(rerouteOrigin, accuracyMeters: 5);
    await provider.updatePosition(rerouteOrigin, accuracyMeters: 5);
    await Future<void>.delayed(Duration.zero);

    expect(api.requests, 2);
    expect(provider.route, same(replacementRoute));
    expect(provider.activeStepIndex, 1);
    expect(provider.remainingDistanceMeters, greaterThan(1000));
    expect(notifications, 8);
  });

  test('projects progress onto long route segments instead of vertices',
      () async {
    const longOrigin = LatLng(46, 14);
    const longDestination = LatLng(46, 14.02);
    const midpoint = LatLng(46.00003, 14.01);
    final longRoute = WalkingRoute(
      points: const <LatLng>[longOrigin, longDestination],
      steps: <WalkingRouteStep>[
        const WalkingRouteStep(
          type: 'depart',
          modifier: 'straight',
          roadName: 'Long road',
          location: longOrigin,
          distanceMeters: 1544,
          durationSeconds: 1144,
          geometryIndex: 0,
        ),
      ],
      distanceMeters: 1544,
      durationSeconds: 1144,
    );
    final api = _FakeDirectionsApi(longRoute);
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    provider.prepare(const WalkingNavigationIntent(
      destinationId: 'long-artwork',
      destinationLabel: 'Long route artwork',
      destination: longDestination,
    ));
    await provider.updatePosition(longOrigin, accuracyMeters: 5);
    await provider.updatePosition(midpoint, accuracyMeters: 5);

    expect(provider.remainingDistanceMeters, inInclusiveRange(650, 900));
    expect(provider.status, WalkingNavigationStatus.active);
  });
}

WalkingRoute _route(LatLng origin, LatLng destination) => WalkingRoute(
      points: <LatLng>[origin, destination],
      steps: <WalkingRouteStep>[
        WalkingRouteStep(
          type: 'depart',
          modifier: 'straight',
          roadName: 'Test street',
          location: origin,
          distanceMeters: 120,
          durationSeconds: 90,
          geometryIndex: 0,
        ),
        WalkingRouteStep(
          type: 'arrive',
          modifier: 'straight',
          roadName: '',
          location: destination,
          distanceMeters: 0,
          durationSeconds: 0,
          geometryIndex: 1,
        ),
      ],
      distanceMeters: 120,
      durationSeconds: 90,
    );

class _FakeDirectionsApi implements WalkingDirectionsApi {
  _FakeDirectionsApi(this.result);

  final WalkingRoute result;
  int requests = 0;

  @override
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    requests += 1;
    return result;
  }

  @override
  void dispose() {}
}

class _CompleterDirectionsApi implements WalkingDirectionsApi {
  _CompleterDirectionsApi(this.completers);

  final List<Completer<WalkingRoute>> completers;
  final List<LatLng> destinations = <LatLng>[];

  @override
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  }) {
    destinations.add(destination);
    return completers[destinations.length - 1].future;
  }

  @override
  void dispose() {}
}

class _SequenceDirectionsApi implements WalkingDirectionsApi {
  _SequenceDirectionsApi(this.results);

  final List<WalkingRoute> results;
  int requests = 0;

  @override
  Future<WalkingRoute> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final result = results[requests];
    requests += 1;
    return result;
  }

  @override
  void dispose() {}
}
