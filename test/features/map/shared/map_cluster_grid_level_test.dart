import 'package:art_kubus/features/map/shared/map_screen_constants.dart';
import 'package:art_kubus/utils/grid_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapScreenConstants.clusterGridLevelForZoom', () {
    test('cluster cells stay near the target on-screen size at every zoom', () {
      // Regression: the mobile map used fixed grid levels 2-6, producing
      // cluster cells of 256 * 2^(zoom - level) = 1,000-15,000 screen px —
      // several viewports wide — so everything below clusterMaxZoom collapsed
      // into one or two mega-clusters. Cells must stay close to the 56-72 px
      // grouping distance the desktop map already used.
      for (double zoom = 3.0;
          zoom < MapScreenConstants.clusterMaxZoom;
          zoom += 0.25) {
        final level = MapScreenConstants.clusterGridLevelForZoom(zoom);
        final spacingPx = GridUtils.screenSpacingForLevel(zoom, level);
        expect(
          spacingPx,
          inInclusiveRange(36, 132),
          reason: 'zoom=$zoom level=$level → ${spacingPx.toStringAsFixed(1)}px '
              'cluster cell; expected roughly icon-sized grouping distance',
        );
      }
    });

    test('grid level tracks zoom monotonically', () {
      int previous = MapScreenConstants.clusterGridLevelForZoom(3.0);
      for (double zoom = 3.25;
          zoom < MapScreenConstants.clusterMaxZoom;
          zoom += 0.25) {
        final level = MapScreenConstants.clusterGridLevelForZoom(zoom);
        expect(level, greaterThanOrEqualTo(previous),
            reason: 'levels must never coarsen while zooming in (zoom=$zoom)');
        previous = level;
      }
    });
  });
}
