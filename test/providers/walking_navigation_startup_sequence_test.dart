import 'package:art_kubus/features/map/navigation/walking_navigation_models.dart';
import 'package:art_kubus/providers/walking_navigation_provider.dart';
import 'package:art_kubus/services/walking_directions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Reproduces the exact production startup order used by `MapScreen` and
/// `DesktopMapScreen`, which always announces the permission request before the
/// first live fix arrives. Provider tests that call `updatePosition` straight
/// after `prepare` skip that transition and cannot observe this failure.
void main() {
  const origin = LatLng(46.0569, 14.5057);
  const destination = LatLng(46.0574, 14.5070);
  const intent = WalkingNavigationIntent(
    destinationId: 'artwork-1',
    destinationLabel: 'Artwork',
    destination: destination,
  );

  test('requests a route after the production permission-prompt sequence',
      () async {
    final api = _FakeDirectionsApi(_route(origin, destination));
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    // 1. MapScreen.didChangeDependencies -> provider.start(intent)
    final lease = provider.start(intent);
    expect(provider.status, WalkingNavigationStatus.awaitingLocation);

    // 2. MapScreen._getLocation -> navigation.beginLocationRequest(lease)
    provider.beginLocationRequest(lease: lease);
    expect(provider.status, WalkingNavigationStatus.requestingPermission);

    // 3. The live fix arrives and MapScreen._updateCurrentPosition forwards it.
    await provider.updatePosition(origin, accuracyMeters: 6, lease: lease);

    expect(
      api.requests,
      1,
      reason: 'the first live fix after a permission prompt must route',
    );
    expect(provider.status, WalkingNavigationStatus.active);
    expect(provider.route, isNotNull);
  });

  test('routes when a permission prompt precedes an explicit retry', () async {
    final api = _FakeDirectionsApi(_route(origin, destination));
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    final lease = provider.start(intent);
    provider.beginLocationRequest(lease: lease);
    await provider.updatePosition(origin, lease: lease);
    expect(api.requests, 1);

    // Retry re-arms the permission prompt before a new fix lands.
    provider.beginLocationRequest(lease: lease);
    await provider.updatePosition(origin, lease: lease);

    expect(provider.status, WalkingNavigationStatus.active);
    expect(provider.route, isNotNull);
  });

  test('a stale lease cannot route after the session was replaced', () async {
    final api = _FakeDirectionsApi(_route(origin, destination));
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    final staleLease = provider.start(intent);
    provider.start(intent);
    provider.beginLocationRequest(lease: staleLease);
    await provider.updatePosition(origin, lease: staleLease);

    expect(api.requests, 0);
    expect(provider.status, WalkingNavigationStatus.awaitingLocation);
  });
}

WalkingRoute _route(LatLng origin, LatLng destination) => WalkingRoute(
      points: <LatLng>[origin, destination],
      steps: const <WalkingRouteStep>[],
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
