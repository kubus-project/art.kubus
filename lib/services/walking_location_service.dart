import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../features/map/navigation/walking_navigation_models.dart';

class WalkingLocationFix {
  const WalkingLocationFix({
    required this.position,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final LatLng position;
  final double accuracyMeters;
  final DateTime timestamp;
}

class WalkingLocationAccessResult {
  const WalkingLocationAccessResult(this.status, {this.fix});

  final WalkingLocationAccessStatus status;
  final WalkingLocationFix? fix;

  bool get isAvailable =>
      status == WalkingLocationAccessStatus.available && fix != null;
}

abstract class WalkingLocationApi {
  Future<WalkingLocationAccessResult> acquireLiveFix({
    required bool requestPermission,
  });

  Stream<WalkingLocationFix> liveFixes();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

/// The single location-permission source of truth for walking navigation.
///
/// Cached coordinates deliberately do not enter this API. Callers may retain
/// them for passive map positioning, but every route starts from a live fix.
class GeolocatorWalkingLocationService implements WalkingLocationApi {
  const GeolocatorWalkingLocationService({
    this.fixTimeout = const Duration(seconds: 12),
    Future<bool> Function()? serviceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<WalkingLocationFix> Function()? liveFixLoader,
    Stream<WalkingLocationFix> Function()? liveFixStream,
    Future<bool> Function()? appSettingsOpener,
    Future<bool> Function()? locationSettingsOpener,
  })  : _serviceEnabled = serviceEnabled,
        _checkPermission = checkPermission,
        _requestPermission = requestPermission,
        _liveFixLoader = liveFixLoader,
        _liveFixStream = liveFixStream,
        _appSettingsOpener = appSettingsOpener,
        _locationSettingsOpener = locationSettingsOpener;

  final Duration fixTimeout;
  final Future<bool> Function()? _serviceEnabled;
  final Future<LocationPermission> Function()? _checkPermission;
  final Future<LocationPermission> Function()? _requestPermission;
  final Future<WalkingLocationFix> Function()? _liveFixLoader;
  final Stream<WalkingLocationFix> Function()? _liveFixStream;
  final Future<bool> Function()? _appSettingsOpener;
  final Future<bool> Function()? _locationSettingsOpener;

  @override
  Future<WalkingLocationAccessResult> acquireLiveFix({
    required bool requestPermission,
  }) async {
    try {
      if (!await (_serviceEnabled ?? Geolocator.isLocationServiceEnabled)()) {
        return const WalkingLocationAccessResult(
          WalkingLocationAccessStatus.serviceDisabled,
        );
      }

      var permission = await (_checkPermission ?? Geolocator.checkPermission)();
      if (permission == LocationPermission.denied && !requestPermission) {
        return const WalkingLocationAccessResult(
          WalkingLocationAccessStatus.permissionNotRequested,
        );
      }
      if (permission == LocationPermission.denied && requestPermission) {
        permission =
            await (_requestPermission ?? Geolocator.requestPermission)();
      }
      if (permission == LocationPermission.deniedForever) {
        return const WalkingLocationAccessResult(
          WalkingLocationAccessStatus.permissionDeniedPermanently,
        );
      }
      if (permission == LocationPermission.denied) {
        return const WalkingLocationAccessResult(
          WalkingLocationAccessStatus.permissionDenied,
        );
      }

      final fix =
          await (_liveFixLoader ?? _loadGeolocatorFix)().timeout(fixTimeout);
      return WalkingLocationAccessResult(
        WalkingLocationAccessStatus.available,
        fix: fix,
      );
    } on TimeoutException {
      return const WalkingLocationAccessResult(
        WalkingLocationAccessStatus.timedOut,
      );
    } catch (_) {
      return const WalkingLocationAccessResult(
        WalkingLocationAccessStatus.liveLocationUnavailable,
      );
    }
  }

  @override
  Stream<WalkingLocationFix> liveFixes() =>
      (_liveFixStream ?? _geolocatorFixStream)();

  @override
  Future<bool> openAppSettings() =>
      (_appSettingsOpener ?? Geolocator.openAppSettings)();

  @override
  Future<bool> openLocationSettings() =>
      (_locationSettingsOpener ?? Geolocator.openLocationSettings)();

  static Future<WalkingLocationFix> _loadGeolocatorFix() async => _toFix(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        ),
      );

  static Stream<WalkingLocationFix> _geolocatorFixStream() =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).map(_toFix);

  static WalkingLocationFix _toFix(Position position) => WalkingLocationFix(
        position: LatLng(position.latitude, position.longitude),
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
}
