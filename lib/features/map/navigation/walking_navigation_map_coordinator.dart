import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../providers/walking_navigation_provider.dart';
import '../../../services/walking_location_service.dart';
import '../map_layers_manager.dart';
import 'walking_navigation_models.dart';

/// Owns walking-route MapLibre side effects shared by mobile and desktop.
///
/// Camera priority while a session is visible is:
/// walking follow > explicit Resume > passive destination/marker centering.
/// A user gesture clears the screen's [shouldFollow] flag; only Resume restores
/// it. Marker previews may still be opened explicitly, but never start or
/// replace navigation camera ownership on their own.
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
  WalkingNavigationLocationCoordinator(this.locationApi);

  final WalkingLocationApi locationApi;
  StreamSubscription<WalkingLocationFix>? _subscription;

  bool get isRunning => _subscription != null;

  void start({
    required void Function(WalkingLocationFix fix) onPosition,
    required void Function(Object error) onError,
  }) {
    if (_subscription != null) return;
    _subscription = locationApi.liveFixes().listen(
      onPosition,
      onError: (Object error, StackTrace stack) {
        final failed = _subscription;
        _subscription = null;
        unawaited(failed?.cancel());
        onError(error);
      },
    );
  }

  void pause() => _subscription?.pause();

  void resume() => _subscription?.resume();

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
