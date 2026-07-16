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
