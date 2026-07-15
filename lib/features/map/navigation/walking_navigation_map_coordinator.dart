import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../providers/walking_navigation_provider.dart';
import '../map_layers_manager.dart';
import 'walking_navigation_models.dart';

/// Owns walking-route MapLibre side effects shared by mobile and desktop.
class WalkingNavigationMapCoordinator {
  WalkingNavigationMapCoordinator({
    required this.layersManager,
    required this.isStyleReady,
    required this.shouldFollow,
    required this.followCamera,
  });

  final MapLayersManager? Function() layersManager;
  final bool Function() isStyleReady;
  final bool Function() shouldFollow;
  final Future<void> Function(LatLng position) followCamera;

  WalkingRoute? _lastRoute;
  bool? _lastVisibility;

  void resetForMapController() {
    _lastRoute = null;
    _lastVisibility = null;
  }

  Future<void> sync(WalkingNavigationProvider navigation) async {
    final manager = layersManager();
    if (manager == null || !isStyleReady()) return;

    final route = navigation.route;
    if (!identical(route, _lastRoute)) {
      _lastRoute = route;
      await manager.upsertWalkingRouteData(
        route?.toGeoJson() ??
            const <String, dynamic>{
              'type': 'FeatureCollection',
              'features': <Object>[],
            },
      );
    }

    final visible = navigation.isVisible && route != null;
    if (_lastVisibility != visible) {
      _lastVisibility = visible;
      await manager.setWalkingNavigationVisibility(visible);
    }

    final position = navigation.currentPosition;
    if (position != null && shouldFollow() && navigation.hasActiveRoute) {
      await followCamera(position);
    }
  }
}

/// Owns the continuous desktop walking-location subscription. Mobile reuses
/// its existing map location stream, so only desktop starts this coordinator.
class WalkingNavigationLocationCoordinator {
  StreamSubscription<Position>? _subscription;

  bool get isRunning => _subscription != null;

  void start({required void Function(Position position) onPosition}) {
    if (_subscription != null) return;
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(onPosition);
  }

  void pause() => _subscription?.pause();

  void resume() => _subscription?.resume();

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
