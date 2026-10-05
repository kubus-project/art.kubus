import 'dart:math' as math;

import 'package:art_kubus/features/map/shared/map_screen_constants.dart';
import 'package:art_kubus/utils/grid_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

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
      for (double zoom = 0.0;
          zoom < MapScreenConstants.clusterMaxZoom;
          zoom += 0.25) {
        final level = MapScreenConstants.clusterGridLevelForZoom(zoom);
        final spacingPx = GridUtils.screenSpacingForLevel(zoom, level);
        final target = MapScreenConstants.clusterTargetSpacingPx(zoom);
        // The level is an integer, so a cell is within one grid step of the
        // target; never a viewport-wide mega-cell.
        expect(spacingPx, inInclusiveRange(target / 1.5, target * 1.5),
            reason: 'zoom=$zoom level=$level → '
                '${spacingPx.toStringAsFixed(1)}px vs target $target');
      }
    });

    test('far zoom does not widen the grouping distance', () {
      // 0.8.1 final: the old curve grouped more widely far out (116 px),
      // which folded the world into a few mega-clusters.
      for (double zoom = 0; zoom <= 4; zoom += 0.25) {
        expect(MapScreenConstants.clusterTargetSpacingPx(zoom),
            inInclusiveRange(20, 64),
            reason: 'zoom=$zoom');
      }
      for (double zoom = 4;
          zoom < MapScreenConstants.clusterMaxZoom;
          zoom += 0.25) {
        expect(MapScreenConstants.clusterTargetSpacingPx(zoom),
            inInclusiveRange(56, 76),
            reason: 'zoom=$zoom');
      }
    });

    test('a world-scale cell never spans more than the geographic cap', () {
      for (double zoom = -1; zoom <= 3; zoom += 0.25) {
        final spacing = MapScreenConstants.clusterTargetSpacingPx(zoom);
        final metres = spacing * 156543.03392 / math.pow(2, zoom);
        // The floor can exceed the cap only where the whole map is a few
        // hundred px wide; elsewhere the cap holds.
        if (spacing > MapScreenConstants.clusterMinSpacingPx) {
          expect(
            metres,
            lessThanOrEqualTo(MapScreenConstants.clusterMaxSpanMeters + 1),
            reason: 'zoom=$zoom',
          );
        }
      }
    });

    test('cluster dissolve zoom is unchanged', () {
      expect(MapScreenConstants.clusterMaxZoom, 12.0);
    });

    test('grid level tracks zoom monotonically (no topology flicker)', () {
      int previous = MapScreenConstants.clusterGridLevelForZoom(-1.0);
      for (double zoom = -0.95;
          zoom < MapScreenConstants.clusterMaxZoom;
          zoom += 0.05) {
        final level = MapScreenConstants.clusterGridLevelForZoom(zoom);
        expect(level, greaterThanOrEqualTo(previous),
            reason: 'levels must never coarsen while zooming in (zoom=$zoom)');
        previous = level;
      }
    });

    test('membership is deterministic when zooming out and back in', () {
      final markers = _worldMarkers();
      Set<String> signature(double zoom) => {
            for (final g in _groupByCell(markers, zoom).entries)
              '${g.key}=${(g.value.toList()..sort()).join(',')}',
          };
      final first = signature(1.5);
      signature(6);
      signature(11);
      expect(signature(1.5), first);
    });
  });

  group('world clustering reads as a distributed field', () {
    final markers = _worldMarkers();

    test('the world does not collapse into one or two clusters', () {
      for (final zoom in [0.5, 1.0, 1.5, 2.0]) {
        final groups = _groupByCell(markers, zoom);
        expect(groups.length, greaterThanOrEqualTo(10),
            reason: 'zoom=$zoom → ${groups.length} nodes');
      }
    });

    test('distant regions stay separate; isolated records stay their own dot',
        () {
      for (final zoom in [0.5, 1.0, 1.5, 2.0]) {
        final groups = _groupByCell(markers, zoom);
        String cellOf(String id) =>
            groups.entries.firstWhere((e) => e.value.contains(id)).key;
        expect(cellOf('lisbon'), isNot(cellOf('ljubljana')),
            reason: 'zoom=$zoom: Lisbon vs Ljubljana');
        expect(cellOf('tokyo'), isNot(cellOf('ljubljana')));
        expect(cellOf('nyc'), isNot(cellOf('ljubljana')));
        for (final lonely in ['reykjavik', 'honolulu', 'cape-town']) {
          expect(groups[cellOf(lonely)], {lonely},
              reason: 'zoom=$zoom: $lonely is alone');
        }
      }
    });

    test('dense local records still cluster', () {
      for (final zoom in [0.5, 1.0, 2.0, 4.0]) {
        final groups = _groupByCell(markers, zoom);
        final cells = {
          for (var i = 0; i < 20; i++)
            groups.entries.firstWhere((e) => e.value.contains('lj-$i')).key,
        };
        expect(cells.length, lessThanOrEqualTo(2),
            reason: 'zoom=$zoom: 20 records within 200 m');
      }
    });

    test('groups split progressively from world to city', () {
      var previous = 0;
      for (final zoom in [1.0, 3.0, 5.0, 7.0, 9.0, 11.0]) {
        final count = _groupByCell(markers, zoom).length;
        expect(count, greaterThanOrEqualTo(previous),
            reason: 'zoom=$zoom must not merge what a lower zoom split');
        previous = count;
      }
      // Central Europe splits into its cities by country scale.
      final country = _groupByCell(markers, 7.0);
      String cellOf(String id) =>
          country.entries.firstWhere((e) => e.value.contains(id)).key;
      expect(cellOf('ljubljana'), isNot(cellOf('zagreb')));
      expect(cellOf('ljubljana'), isNot(cellOf('vienna')));
    });
  });
}

class _Pt {
  const _Pt(this.id, this.lat, this.lng);
  final String id;
  final double lat;
  final double lng;
}

List<_Pt> _worldMarkers() => [
      const _Pt('lisbon', 38.72, -9.14),
      const _Pt('madrid', 40.42, -3.70),
      const _Pt('paris', 48.86, 2.35),
      const _Pt('berlin', 52.52, 13.40),
      const _Pt('vienna', 48.21, 16.37),
      const _Pt('ljubljana', 46.05, 14.50),
      const _Pt('celje', 46.23, 15.27),
      const _Pt('zagreb', 45.81, 15.98),
      const _Pt('nyc', 40.71, -74.00),
      const _Pt('la', 34.05, -118.24),
      const _Pt('mexico', 19.43, -99.13),
      const _Pt('sao-paulo', -23.55, -46.63),
      const _Pt('buenos-aires', -34.60, -58.38),
      const _Pt('tokyo', 35.68, 139.69),
      const _Pt('seoul', 37.57, 126.98),
      const _Pt('sydney', -33.87, 151.21),
      const _Pt('cape-town', -33.92, 18.42),
      const _Pt('nairobi', -1.29, 36.82),
      const _Pt('reykjavik', 64.15, -21.94),
      const _Pt('honolulu', 21.31, -157.86),
      for (var i = 0; i < 20; i++)
        _Pt('lj-$i', 46.0569 + (i % 5) * 0.0004, 14.5058 + (i ~/ 5) * 0.0004),
    ];

Map<String, Set<String>> _groupByCell(List<_Pt> markers, double zoom) {
  final level = MapScreenConstants.clusterGridLevelForZoom(zoom);
  final groups = <String, Set<String>>{};
  for (final m in markers) {
    final key =
        GridUtils.gridCellForLevel(LatLng(m.lat, m.lng), level).anchorKey;
    groups.putIfAbsent(key, () => <String>{}).add(m.id);
  }
  return groups;
}
