import 'dart:math' as math;

import 'dart:ui';

import 'package:art_kubus/features/map/shared/map_marker_lod.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/promotion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker(String id, double lat, double lng, {bool promoted = false}) {
  return ArtMarker(
    id: id,
    name: id,
    description: '',
    position: LatLng(lat, lng),
    type: ArtMarkerType.artwork,
    createdAt: DateTime.utc(2026, 1, 1),
    createdBy: 'test',
    promotion: promoted
        ? const PromotionMetadata(isPromoted: true)
        : PromotionMetadata.none,
  );
}

void main() {
  group('tier boundaries', () {
    test(
      'far below the blend centre, mid from it, close at street approach',
      () {
        expect(KubusMarkerLod.tierForZoom(0), KubusMarkerLodTier.far);
        expect(KubusMarkerLod.tierForZoom(2.55), KubusMarkerLodTier.far);
        expect(KubusMarkerLod.tierForZoom(5.99), KubusMarkerLodTier.far);
        expect(KubusMarkerLod.tierForZoom(6.0), KubusMarkerLodTier.mid);
        expect(KubusMarkerLod.tierForZoom(10), KubusMarkerLodTier.mid);
        expect(KubusMarkerLod.tierForZoom(12.49), KubusMarkerLodTier.mid);
        expect(KubusMarkerLod.tierForZoom(12.5), KubusMarkerLodTier.close);
        expect(KubusMarkerLod.tierForZoom(22), KubusMarkerLodTier.close);
      },
    );

    test('a non-finite zoom is treated as far (cheapest, never blank)', () {
      expect(KubusMarkerLod.tierForZoom(double.nan), KubusMarkerLodTier.far);
      expect(KubusMarkerLod.needsMarkerArtwork(double.nan), isFalse);
      expect(KubusMarkerLod.allowsCovers(double.nan), isFalse);
    });

    test('marker artwork is prepared before the opacity ramp reveals it', () {
      expect(KubusMarkerLod.needsMarkerArtwork(5.49), isFalse);
      expect(
        KubusMarkerLod.needsMarkerArtwork(KubusMarkerLod.blendStartZoom),
        isTrue,
      );
      expect(KubusMarkerLod.blendStartZoom < KubusMarkerLod.farMaxZoom, isTrue);
      expect(KubusMarkerLod.blendEndZoom > KubusMarkerLod.farMaxZoom, isTrue);
    });

    test('nearby covers display from street approach, not street scale', () {
      expect(KubusMarkerLod.allowsCovers(12.49), isFalse);
      expect(KubusMarkerLod.allowsCovers(12.5), isTrue);
      expect(
        KubusMarkerLod.coverDisplayMinZoom,
        lessThan(15.0),
        reason: '0.8.0 waited for zoom 15; covers were visibly too late',
      );
    });

    test('prefetch starts one step before display, never after it', () {
      expect(KubusMarkerLod.allowsCoverPrefetch(11.49), isFalse);
      expect(KubusMarkerLod.allowsCoverPrefetch(11.5), isTrue);
      expect(
        KubusMarkerLod.coverPrefetchMinZoom,
        lessThan(KubusMarkerLod.coverDisplayMinZoom),
      );
    });

    test('the selected marker may show its cover earlier than nearby ones', () {
      expect(KubusMarkerLod.allowsSelectedCover(9.99), isFalse);
      expect(KubusMarkerLod.allowsSelectedCover(10.0), isTrue);
      expect(KubusMarkerLod.allowsCovers(10.0), isFalse);
      expect(
        KubusMarkerLod.selectedCoverMinZoom,
        lessThan(KubusMarkerLod.coverPrefetchMinZoom),
      );
    });

    test('idle re-plans in the selected-only band only with a selection', () {
      expect(KubusMarkerLod.plansCoversAt(10.5), isFalse);
      expect(KubusMarkerLod.plansCoversAt(10.5, hasSelection: true), isTrue,
          reason: 'a selection made while the camera moved needs its cover');
      expect(KubusMarkerLod.plansCoversAt(9.5, hasSelection: true), isFalse);
      expect(KubusMarkerLod.plansCoversAt(12.0), isTrue);
    });

    test('cover stages rise monotonically with zoom', () {
      var previous = KubusMarkerLod.coverStageForZoom(0);
      expect(previous, 0);
      for (double zoom = 0; zoom <= 22; zoom += 0.25) {
        final stage = KubusMarkerLod.coverStageForZoom(zoom);
        expect(stage, greaterThanOrEqualTo(previous), reason: 'zoom=$zoom');
        previous = stage;
      }
      expect(KubusMarkerLod.coverStageForZoom(10.0), 1);
      expect(KubusMarkerLod.coverStageForZoom(11.5), 2);
      expect(KubusMarkerLod.coverStageForZoom(12.5), 3);
      // Display is one stage: every eligible marker, no staged budget.
      expect(KubusMarkerLod.coverStageForZoom(13.5), 3);
      expect(KubusMarkerLod.coverStageForZoom(16), 3);
      expect(KubusMarkerLod.coverStageForZoom(double.nan), 0);
    });
  });

  group('cover fetch size', () {
    test('download width gives a 16:9 source its short side, still bounded',
        () {
      for (final ratio in [1.0, 2.0, 3.0, double.nan]) {
        final face = KubusMarkerLod.coverFetchWidthPx(ratio);
        final download = KubusMarkerLod.coverDownloadWidthPx(ratio);
        expect(download, greaterThanOrEqualTo(face));
        // A 16:9 landscape clamped to `download` keeps >= face on its short edge.
        expect(download * 9 / 16, greaterThanOrEqualTo(face - 1));
        expect(download, lessThanOrEqualTo(512));
        expect(download % 32, 0);
      }
    });

    test('tracks the marker face, never archival media', () {
      final w1 = KubusMarkerLod.coverFetchWidthPx(1);
      final w2 = KubusMarkerLod.coverFetchWidthPx(2);
      final w3 = KubusMarkerLod.coverFetchWidthPx(3);
      expect(w1, lessThanOrEqualTo(w2));
      expect(w2, lessThanOrEqualTo(w3));
      expect(
        w2,
        greaterThanOrEqualTo(KubusMarkerLod.coverFaceLogicalPx * 2),
        reason: 'never below the physical face size',
      );
      expect(w3, lessThanOrEqualTo(256));
      expect(w2 % 32, 0, reason: 'snapped so caches see few sizes');
      expect(KubusMarkerLod.coverFetchWidthPx(double.nan), w1);
    });
  });

  group('cover plan by zoom', () {
    final markers = <ArtMarker>[
      for (var i = 0; i < 40; i++) _marker('m$i', 46.05 + i * 0.0003, 14.5),
      _marker('sel', 46.06, 14.51),
    ];
    List<String> plan(double zoom, {String? selectedId = 'sel'}) =>
        KubusMarkerLod.planCoverIds(
          candidates: markers,
          selectedId: selectedId,
          zoom: zoom,
          hasCover: (_) => true,
        );

    test('nothing at city scale, not even the selected marker', () {
      expect(plan(9.5), isEmpty);
    });

    test('the selected marker shows its cover before nearby covers', () {
      expect(plan(10.5), <String>['sel']);
      expect(plan(12.0), <String>['sel']);
      expect(plan(12.0, selectedId: null), isEmpty);
    });

    test('at display zoom every eligible marker is planned, selected first',
        () {
      for (final zoom in [12.5, 13.6, 15.0]) {
        final ids = plan(zoom);
        expect(ids.first, 'sel');
        expect(ids.length, 41, reason: 'zoom=$zoom: no display budget');
        expect(ids.toSet().length, 41);
      }
    });
  });

  group('cover selection (all eligible markers in view)', () {
    bool allHaveCovers(ArtMarker _) => true;

    for (final count in [5, 24, 25, 150]) {
      test('$count eligible markers are all selected', () {
        final many = [
          for (var i = 0; i < count; i++)
            _marker('m$i', 46.0 + (i % 13) * 0.01, 14.4 + (i ~/ 13) * 0.01),
        ];
        final ids = KubusMarkerLod.selectCoverMarkerIds(
          candidates: many,
          selectedId: null,
          hasCover: allHaveCovers,
        );
        expect(ids.length, count);
        expect(ids.toSet(), {for (final m in many) m.id});
      });
    }

    test('viewport-edge markers are included; centre distance is irrelevant',
        () {
      // One marker at the middle, four at the far edges of the view.
      final edge = [
        _marker('centre', 46.05, 14.5),
        _marker('north', 46.15, 14.5),
        _marker('south', 45.95, 14.5),
        _marker('east', 46.05, 14.6),
        _marker('west', 46.05, 14.4),
      ];
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: edge,
        selectedId: null,
        hasCover: allHaveCovers,
      );
      expect(ids.toSet(), {'centre', 'north', 'south', 'east', 'west'});
    });

    test('selected first, then promoted, then the rest', () {
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: [
          _marker('far', 46.06, 14.51),
          _marker('near', 46.0501, 14.5001),
          _marker('promo', 46.07, 14.52, promoted: true),
          _marker('sel', 46.2, 14.9),
        ],
        selectedId: 'sel',
        hasCover: allHaveCovers,
      );
      expect(ids.take(2), <String>['sel', 'promo']);
      expect(ids.toSet(), {'sel', 'promo', 'near', 'far'});
    });

    test('the selected marker is kept first whatever else is queued', () {
      final many = [
        for (var i = 0; i < 60; i++) _marker('m$i', 46.05 + i * 0.001, 14.5),
      ];
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: many,
        selectedId: 'm59',
        hasCover: allHaveCovers,
      );
      expect(ids.first, 'm59');
      expect(ids.length, 60);
    });

    test('loading order spreads across the viewport, not centre-out', () {
      // A 10 x 10 lattice: the first sixteen to load must touch every
      // quadrant, which a nearest-to-centre ranking never does.
      final lattice = [
        for (var r = 0; r < 10; r++)
          for (var c = 0; c < 10; c++)
            _marker('m${r * 10 + c}', 46.0 + r * 0.01, 14.4 + c * 0.01),
      ];
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: lattice,
        selectedId: null,
        hasCover: allHaveCovers,
      );
      final byId = {for (final m in lattice) m.id: m};
      final quadrants = <String>{};
      for (final id in ids.take(16)) {
        final m = byId[id]!;
        quadrants.add(
          '${m.position.latitude >= 46.045 ? 'n' : 's'}'
          '${m.position.longitude >= 14.445 ? 'e' : 'w'}',
        );
      }
      expect(quadrants, {'ne', 'nw', 'se', 'sw'});
      // And not a growing disc: the first batch reaches the extremes.
      final lats = ids.take(16).map((id) => byId[id]!.position.latitude);
      expect(lats.reduce(math.min), lessThan(46.02));
      expect(lats.reduce(math.max), greaterThan(46.06));
    });

    test('markers without a cover, or with a failed one, are never queued', () {
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: [
          _marker('bare', 46.0501, 14.5),
          _marker('failed', 46.0502, 14.5),
          _marker('ok', 46.0503, 14.5),
        ],
        selectedId: null,
        hasCover: (m) => m.id != 'bare',
        failedIds: <String>{'failed'},
      );
      expect(ids, <String>['ok']);
    });

    test('a selected marker whose cover failed falls back to its marker', () {
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: [_marker('sel', 46.05, 14.5)],
        selectedId: 'sel',
        hasCover: allHaveCovers,
        failedIds: <String>{'sel'},
      );
      expect(ids, isEmpty);
    });

    test('panning to a new viewport drops the old priority', () {
      final a = [
        for (var i = 0; i < 20; i++) _marker('a$i', 46.0 + i * 0.001, 14.4)
      ];
      final b = [
        for (var i = 0; i < 20; i++) _marker('b$i', 47.0 + i * 0.001, 15.4)
      ];
      // The plan is a function of the *current* visible set only.
      final first = KubusMarkerLod.selectCoverMarkerIds(
          candidates: a, selectedId: null, hasCover: allHaveCovers);
      final second = KubusMarkerLod.selectCoverMarkerIds(
          candidates: b, selectedId: null, hasCover: allHaveCovers);
      expect(first.every((id) => id.startsWith('a')), isTrue);
      expect(second.every((id) => id.startsWith('b')), isTrue);
      expect(second.length, 20);
    });

    test('a limit (prefetch) truncates the rest, never the selection', () {
      final many = [
        for (var i = 0; i < 80; i++) _marker('m$i', 46.05 + i * 0.001, 14.5),
      ];
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: many,
        selectedId: 'm79',
        hasCover: allHaveCovers,
        limit: KubusMarkerLod.coverPrefetchLimit,
      );
      expect(ids.length, KubusMarkerLod.coverPrefetchLimit + 1);
      expect(ids.first, 'm79');
    });

    test('ordering is deterministic', () {
      final markers = [
        for (var i = 0; i < 30; i++)
          _marker(
              'm$i', 46.0 + (i * 7 % 11) * 0.01, 14.4 + (i * 5 % 13) * 0.01),
      ];
      List<String> run(List<ArtMarker> input) =>
          KubusMarkerLod.selectCoverMarkerIds(
              candidates: input, selectedId: null, hasCover: allHaveCovers);
      expect(run(markers), run(markers.reversed.toList()));
    });
  });

  group('style expressions', () {
    test('opacity ramp keeps zoom as the top-level input', () {
      final expr = KubusMarkerLod.markerOpacityExpression(
        entryOpacity: const <Object>[
          'coalesce',
          <Object>['get', 'entryOpacity'],
          1.0,
        ],
      ) as List;
      expect(expr[0], 'interpolate');
      expect(expr[2], const <Object>['zoom']);
      expect(expr[3], KubusMarkerLod.blendStartZoom);
      expect(expr[4], 0.0);
      expect(expr[5], KubusMarkerLod.blendEndZoom);
    });

    test('with a selection the far stop keeps that marker fully visible', () {
      final expr = KubusMarkerLod.markerOpacityExpression(
        entryOpacity: 1.0,
        selectedId: 'abc',
      ) as List;
      final hidden = expr[4] as List;
      expect(hidden[0], 'case');
      expect(hidden[1], const <Object>[
        '==',
        <Object>['id'],
        'abc',
      ]);
      expect(hidden[2], 1.0);
      expect(hidden[3], 0.0);
    });

    test(
      'hitbox targets the dot when far and the floating badge otherwise',
      () {
        final anchor = KubusMarkerLod.hitboxAnchorExpression() as List;
        expect(anchor, <Object>[
          'step',
          const <Object>['zoom'],
          'center',
          KubusMarkerLod.blendStartZoom,
          'bottom',
        ]);
      },
    );

    test('far clusters grow with member count and are capped', () {
      final expr = KubusMarkerLod.dotRadiusExpression(
        dotRadius: 4.5,
        clusterDotRadius: 5.5,
      ) as List;
      expect(expr[2], const <Object>['zoom']);
      final farStop = expr[4] as List;
      expect(farStop[0], 'case');
      final cluster = farStop[2] as List;
      expect(cluster[0], 'min');
      expect(cluster[1], 14.0);
      final nearStop = expr[6] as List;
      expect(nearStop[2], 5.5);
    });
  });
}
