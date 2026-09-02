import 'package:art_kubus/features/map/filters/map_filter_state.dart';
import 'package:art_kubus/screens/map_core/map_data_coordinator.dart';
import 'package:art_kubus/utils/geo_bounds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('MapDataCoordinator viewport policy', () {
    test(
      'does not refetch while the visible bounds fit the loaded buffer',
      () async {
        var viewportCalls = 0;
        final coordinator = _coordinator(
          loadedBounds: const GeoBounds(
            south: 45.8,
            west: 13.8,
            north: 47.2,
            east: 15.2,
          ),
          onViewport: () => viewportCalls += 1,
        );

        coordinator.queueMarkerRefresh(fromGesture: false);
        await Future<void>.delayed(const Duration(milliseconds: 380));

        expect(viewportCalls, 0);
        coordinator.dispose();
      },
    );

    test('refetches when bounds escape or zoom density changes', () async {
      var viewportCalls = 0;
      var zoom = 13.0;
      GeoBounds loaded = const GeoBounds(
        south: 46,
        west: 14,
        north: 47,
        east: 15,
      );
      final coordinator = _coordinator(
        cameraZoom: () => zoom,
        loadedBoundsProvider: () => loaded,
        onViewport: () => viewportCalls += 1,
      );

      coordinator.queueMarkerRefresh(fromGesture: false);
      await Future<void>.delayed(const Duration(milliseconds: 380));
      expect(viewportCalls, 0);

      zoom = 15;
      coordinator.queueMarkerRefresh(fromGesture: false);
      await Future<void>.delayed(const Duration(milliseconds: 380));
      expect(viewportCalls, 1);

      loaded = const GeoBounds(south: 50, west: 20, north: 51, east: 21);
      coordinator.queueMarkerRefresh(fromGesture: false);
      await Future<void>.delayed(const Duration(milliseconds: 380));
      expect(viewportCalls, 2);
      coordinator.dispose();
    });

    test(
      'Near Me ignores camera refreshes and uses a real location origin',
      () async {
        var scope = KubusMapScope.nearMe;
        var nearMeCalls = 0;
        LatLng? nearMeOrigin;
        final coordinator = _coordinator(
          scope: () => scope,
          hasMarkers: () => false,
          onNearMe: (origin) {
            nearMeCalls += 1;
            nearMeOrigin = origin;
          },
        );

        coordinator.queueMarkerRefresh(fromGesture: true);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(nearMeCalls, 0);

        const userLocation = LatLng(46.05, 14.51);
        coordinator.refreshNearMeForLocation(userLocation);
        await Future<void>.delayed(Duration.zero);
        expect(nearMeCalls, 1);
        expect(nearMeOrigin, userLocation);
        scope = KubusMapScope.currentViewport;
        coordinator.refreshNearMeForLocation(const LatLng(0, 0));
        expect(nearMeCalls, 1);
        coordinator.dispose();
      },
    );
  });
}

MapDataCoordinator _coordinator({
  KubusMapScope Function()? scope,
  double Function()? cameraZoom,
  GeoBounds? loadedBounds,
  GeoBounds? Function()? loadedBoundsProvider,
  void Function()? onViewport,
  void Function(LatLng origin)? onNearMe,
  bool Function()? hasMarkers,
}) {
  return MapDataCoordinator(
    pollingEnabled: () => true,
    mapReady: () => true,
    scope: scope ?? () => KubusMapScope.currentViewport,
    cameraCenter: () => const LatLng(46.5, 14.5),
    cameraZoom: cameraZoom ?? () => 13,
    hasMarkers: hasMarkers ?? () => true,
    lastFetchCenter: () => null,
    lastFetchTime: () => null,
    loadedViewportBounds: loadedBoundsProvider ?? () => loadedBounds,
    loadedViewportZoomBucket: () => 13,
    distance: const Distance(),
    refreshInterval: const Duration(minutes: 1),
    refreshDistanceMeters: 100,
    getVisibleBounds: () async =>
        const GeoBounds(south: 46, west: 14, north: 47, east: 15),
    refreshNearMe: ({required center}) async => onNearMe?.call(center),
    refreshViewport: (
            {required center, required bounds, required zoomBucket}) async =>
        onViewport?.call(),
    queuePendingRefresh: ({bool force = false}) {},
  );
}
