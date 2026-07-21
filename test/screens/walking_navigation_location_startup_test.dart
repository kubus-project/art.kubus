import 'dart:async';

import 'package:art_kubus/features/map/navigation/walking_navigation_models.dart';
import 'package:art_kubus/providers/walking_navigation_provider.dart';
import 'package:art_kubus/services/walking_directions_service.dart';
import 'package:art_kubus/services/walking_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Navigation startup must await a bounded first-live-fix outcome instead of
/// racing a still-starting location stream against an immediate
/// `locationUnavailable` transition, and must never downgrade an already-typed
/// permission/service failure to a generic one.
void main() {
  const origin = LatLng(46.0569, 14.5057);
  const destination = LatLng(46.0574, 14.5070);
  const intent = WalkingNavigationIntent(
    destinationId: 'artwork-1',
    destinationLabel: 'Artwork',
    destination: destination,
  );

  test('a delayed first fix still routes rather than failing early', () async {
    final api = _FakeDirectionsApi(_route());
    final provider = WalkingNavigationProvider(directionsApi: api);
    addTearDown(provider.dispose);

    final lease = provider.start(intent);
    provider.beginLocationRequest(lease: lease);

    final location = GeolocatorWalkingLocationService(
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.always,
      // The platform takes a while to produce the first fix.
      liveFixLoader: () => Future<WalkingLocationFix>.delayed(
        const Duration(milliseconds: 400),
        () => WalkingLocationFix(
          position: origin,
          accuracyMeters: 8,
          timestamp: DateTime.now(),
        ),
      ),
    );

    final result = await location.acquireLiveFix(requestPermission: true);
    expect(result.status, WalkingLocationAccessStatus.available);
    expect(
      provider.status,
      WalkingNavigationStatus.requestingPermission,
      reason: 'nothing may report failure while the fix is still in flight',
    );

    await provider.updatePosition(result.fix!.position, lease: lease);

    expect(provider.status, WalkingNavigationStatus.active);
    expect(provider.route, isNotNull);
    expect(api.requests, 1);
  });

  test('a bounded timeout is reported as its own failure kind', () async {
    final provider = WalkingNavigationProvider(
      directionsApi: _FakeDirectionsApi(_route()),
    );
    addTearDown(provider.dispose);
    final lease = provider.start(intent);
    provider.beginLocationRequest(lease: lease);

    final location = GeolocatorWalkingLocationService(
      fixTimeout: const Duration(milliseconds: 40),
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.always,
      liveFixLoader: () => Completer<WalkingLocationFix>().future,
    );

    final result = await location.acquireLiveFix(requestPermission: true);
    expect(result.status, WalkingLocationAccessStatus.timedOut);

    provider.reportLocationAccess(result.status, lease: lease);
    expect(
      provider.failureKind,
      WalkingNavigationFailureKind.locationTimedOut,
    );
  });

  test('permanent denial keeps its settings-capable failure kind', () async {
    final provider = WalkingNavigationProvider(
      directionsApi: _FakeDirectionsApi(_route()),
    );
    addTearDown(provider.dispose);
    final lease = provider.start(intent);
    provider.beginLocationRequest(lease: lease);

    final location = GeolocatorWalkingLocationService(
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.deniedForever,
    );
    final result = await location.acquireLiveFix(requestPermission: true);
    provider.reportLocationAccess(result.status, lease: lease);

    expect(
      provider.failureKind,
      WalkingNavigationFailureKind.locationPermissionDeniedPermanently,
    );

    // The generic startup fallback must not overwrite the precise reason,
    // otherwise the user loses the "open settings" recovery action.
    provider.reportLocationUnavailable(lease: lease);
    expect(
      provider.failureKind,
      WalkingNavigationFailureKind.locationPermissionDeniedPermanently,
    );
  });
}

WalkingRoute _route() => const WalkingRoute(
      points: <LatLng>[
        LatLng(46.0569, 14.5057),
        LatLng(46.0574, 14.5070),
      ],
      steps: <WalkingRouteStep>[],
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
