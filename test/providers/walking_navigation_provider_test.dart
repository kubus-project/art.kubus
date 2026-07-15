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
