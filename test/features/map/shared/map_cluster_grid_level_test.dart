import 'package:art_kubus/features/map/shared/map_screen_constants.dart';
import 'package:art_kubus/utils/grid_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile and desktop share walking navigation layer identities', () {
    final mobile = MapScreenConstants.mobileLayerIds;
    final desktop = MapScreenConstants.desktopLayerIds;

    expect(
      mobile.walkingRouteSourceId,
      MapScreenConstants.walkingRouteSourceId,
    );
    expect(desktop.walkingRouteSourceId, mobile.walkingRouteSourceId);
    expect(desktop.walkingRouteCasingLayerId, mobile.walkingRouteCasingLayerId);
    expect(desktop.walkingRouteLayerId, mobile.walkingRouteLayerId);
    expect(
      desktop.walkingRouteConnectorLayerId,
      mobile.walkingRouteConnectorLayerId,
    );
    expect(
      desktop.walkingLocationSymbolLayerId,
      mobile.walkingLocationSymbolLayerId,
    );
    expect(desktop.walkingLocationImageId, mobile.walkingLocationImageId);
  });

  group('MapScreenConstants.clusterGridLevelForZoom', () {
    test('cluster cells stay near the target on-screen size at every zoom', () {
      // Regression: the mobile map used fixed grid levels 2-6, producing
      // cluster cells of 256 * 2^(zoom - level) = 1,000-15,000 screen px —
      // several viewports wide — so everything below clusterMaxZoom collapsed
      // into one or two mega-clusters. Cells must stay within roughly one
      // grid step of the tapered 68-116 px grouping target.
      for (double zoom = 3.0;
          zoom < MapScreenConstants.clusterMaxZoom;
          zoom += 0.25) {
        final level = MapScreenConstants.clusterGridLevelForZoom(zoom);
        final spacingPx = GridUtils.screenSpacingForLevel(zoom, level);
        expect(
          spacingPx,
          inInclusiveRange(44, 168),
          reason: 'zoom=$zoom level=$level → ${spacingPx.toStringAsFixed(1)}px '
              'cluster cell; expected roughly icon-sized grouping distance',
        );
      }
    });

    test('groups more widely far out than near (taper)', () {
      final far = MapScreenConstants.clusterTargetSpacingPx(3.5);
      final mid = MapScreenConstants.clusterTargetSpacingPx(8.0);
      final near = MapScreenConstants.clusterTargetSpacingPx(11.5);
      expect(far, greaterThan(mid));
      expect(mid, greaterThan(near));
      // Never widens while zooming in.
      var previous = double.infinity;
      for (double zoom = 0;
          zoom < MapScreenConstants.clusterMaxZoom;
          zoom += 0.1) {
        final spacing = MapScreenConstants.clusterTargetSpacingPx(zoom);
        expect(spacing, lessThanOrEqualTo(previous), reason: 'zoom=$zoom');
        previous = spacing;
      }
    });

    test('far-out grid cells are wider on screen than near ones', () {
      double cell(double zoom) => GridUtils.screenSpacingForLevel(
            zoom,
            MapScreenConstants.clusterGridLevelForZoom(zoom),
          );
      double average(double from, double to) {
        var sum = 0.0;
        var n = 0;
        for (double z = from; z < to; z += 0.05) {
          sum += cell(z);
          n += 1;
        }
        return sum / n;
      }

      final far = average(3.0, 5.0);
      final mid = average(7.5, 10.0);
      final near = average(10.0, MapScreenConstants.clusterMaxZoom);
      expect(far, greaterThan(mid));
      expect(mid, greaterThan(near));
    });

    test('cluster dissolve zoom is unchanged by the taper', () {
      expect(MapScreenConstants.clusterMaxZoom, 12.0);
    });

    test('grid level tracks zoom monotonically', () {
      int previous = MapScreenConstants.clusterGridLevelForZoom(3.0);
      for (double zoom = 3.25;
          zoom < MapScreenConstants.clusterMaxZoom;
          zoom += 0.25) {
        final level = MapScreenConstants.clusterGridLevelForZoom(zoom);
        expect(
          level,
          greaterThanOrEqualTo(previous),
          reason: 'levels must never coarsen while zooming in (zoom=$zoom)',
        );
        previous = level;
      }
    });
  });
}
