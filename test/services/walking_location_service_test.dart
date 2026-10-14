import 'dart:async';

import 'package:art_kubus/features/map/navigation/walking_navigation_models.dart';
import 'package:art_kubus/services/walking_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

final _fix = WalkingLocationFix(
  position: LatLng(46.0569, 14.5057),
  accuracyMeters: 6,
  timestamp: _timestamp,
);
final _timestamp = DateTime(2026, 1, 1);

void main() {
  test('concurrent explicit actions share one permission request and fix',
      () async {
    var requests = 0;
    var fixes = 0;
    final permission = Completer<LocationPermission>();
    final service = GeolocatorWalkingLocationService(
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () {
        requests += 1;
        return permission.future;
      },
      liveFixLoader: () async {
        fixes += 1;
        return _fix;
      },
    );
    final first = service.acquireLiveFix(requestPermission: true);
    final second = service.acquireLiveFix(requestPermission: true);
    final passive = await service.acquireLiveFix(requestPermission: false);
    expect(passive.status, WalkingLocationAccessStatus.permissionNotRequested);
    expect(requests, 1);
    permission.complete(LocationPermission.whileInUse);
    expect((await first).fix, same(_fix));
    expect((await second).fix, same(_fix));
    expect(fixes, 1);
  });

  test('granted permission revisit never requests permission', () async {
    var requests = 0;
    final service = GeolocatorWalkingLocationService(
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async {
        requests += 1;
        return LocationPermission.whileInUse;
      },
      liveFixLoader: () async => _fix,
    );
    await service.acquireLiveFix(requestPermission: true);
    await service.acquireLiveFix(requestPermission: false);
    await service.acquireLiveFix(requestPermission: true);
    expect(requests, 0);
  });

  test('explicit user action requests a previously denied permission again',
      () async {
    var requests = 0;
    final service = GeolocatorWalkingLocationService(
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async {
        requests += 1;
        return requests == 1
            ? LocationPermission.denied
            : LocationPermission.whileInUse;
      },
      liveFixLoader: () async => _fix,
    );

    final denied = await service.acquireLiveFix(requestPermission: true);
    final recovered = await service.acquireLiveFix(requestPermission: true);

    expect(denied.status, WalkingLocationAccessStatus.permissionDenied);
    expect(recovered.status, WalkingLocationAccessStatus.available);
    expect(recovered.fix?.position, _fix.position);
    expect(requests, 2);
  });

  test('permanent denial does not request again and opens app settings',
      () async {
    var permissionRequests = 0;
    var settingsOpens = 0;
    final service = GeolocatorWalkingLocationService(
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.deniedForever,
      requestPermission: () async {
        permissionRequests += 1;
        return LocationPermission.deniedForever;
      },
      appSettingsOpener: () async {
        settingsOpens += 1;
        return true;
      },
    );

    final result = await service.acquireLiveFix(requestPermission: true);
    await service.openAppSettings();

    expect(
      result.status,
      WalkingLocationAccessStatus.permissionDeniedPermanently,
    );
    expect(permissionRequests, 0);
    expect(settingsOpens, 1);
  });

  test('disabled service opens location settings without requesting permission',
      () async {
    var permissionChecks = 0;
    var settingsOpens = 0;
    final service = GeolocatorWalkingLocationService(
      serviceEnabled: () async => false,
      checkPermission: () async {
        permissionChecks += 1;
        return LocationPermission.whileInUse;
      },
      locationSettingsOpener: () async {
        settingsOpens += 1;
        return true;
      },
    );

    final result = await service.acquireLiveFix(requestPermission: true);
    await service.openLocationSettings();

    expect(result.status, WalkingLocationAccessStatus.serviceDisabled);
    expect(permissionChecks, 0);
    expect(settingsOpens, 1);
  });

  test('live-fix timeout is distinct from other location failures', () async {
    final service = GeolocatorWalkingLocationService(
      fixTimeout: const Duration(milliseconds: 1),
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      liveFixLoader: () => Completer<WalkingLocationFix>().future,
    );

    final result = await service.acquireLiveFix(requestPermission: true);

    expect(result.status, WalkingLocationAccessStatus.timedOut);
  });
}
