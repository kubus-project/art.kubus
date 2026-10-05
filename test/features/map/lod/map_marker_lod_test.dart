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
      expect(KubusMarkerLod.coverStageForZoom(13.5), 4);
      expect(KubusMarkerLod.coverStageForZoom(14.5), 5);
      expect(KubusMarkerLod.coverStageForZoom(double.nan), 0);
    });
  });

  group('zoom-sensitive cover budget', () {
    const desktop = Size(1440, 900);
    const phone = Size(390, 844);

    test('no nearby covers below the display zoom', () {
      expect(KubusMarkerLod.coverBudget(desktop, zoom: 12.4), 0);
      expect(KubusMarkerLod.coverBudget(desktop, zoom: 9), 0);
    });

    test('early < medium < full, and full equals the viewport budget', () {
      for (final viewport in [desktop, phone]) {
        final early = KubusMarkerLod.coverBudget(viewport, zoom: 12.6);
        final medium = KubusMarkerLod.coverBudget(viewport, zoom: 13.6);
        final full = KubusMarkerLod.coverBudget(viewport, zoom: 15);
        expect(
          early,
          greaterThanOrEqualTo(KubusMarkerLod.earlyCoverBudgetFloor),
        );
        expect(early, lessThan(medium), reason: '$viewport');
        expect(medium, lessThan(full), reason: '$viewport');
        expect(full, KubusMarkerLod.coverBudget(viewport));
        expect(full, lessThanOrEqualTo(KubusMarkerLod.maxCoverBudget));
      }
    });

    test('prefetch warms the next stage, bounded by it', () {
      expect(KubusMarkerLod.coverPrefetchBudget(desktop, zoom: 11.0), 0);
      expect(
        KubusMarkerLod.coverPrefetchBudget(desktop, zoom: 11.6),
        KubusMarkerLod.coverBudget(desktop, zoom: 12.5),
      );
      expect(
        KubusMarkerLod.coverPrefetchBudget(desktop, zoom: 12.6),
        KubusMarkerLod.coverBudget(desktop, zoom: 13.5),
      );
      expect(
        KubusMarkerLod.coverPrefetchBudget(desktop, zoom: 16),
        KubusMarkerLod.coverBudget(desktop),
      );
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

  group('cover budget', () {
    test('scales with the visible area and stays inside the clamp', () {
      expect(
        KubusMarkerLod.coverBudget(const Size(320, 568)),
        KubusMarkerLod.minCoverBudget,
      );
      expect(
        KubusMarkerLod.coverBudget(const Size(390, 844)),
        KubusMarkerLod.minCoverBudget,
      );
      final desktop = KubusMarkerLod.coverBudget(const Size(1440, 900));
      expect(desktop, greaterThan(KubusMarkerLod.minCoverBudget));
      expect(desktop, lessThanOrEqualTo(KubusMarkerLod.maxCoverBudget));
      expect(
        KubusMarkerLod.coverBudget(const Size(3840, 2160)),
        KubusMarkerLod.maxCoverBudget,
      );
    });

    test('a degenerate viewport gets the floor, not zero', () {
      expect(
        KubusMarkerLod.coverBudget(Size.zero),
        KubusMarkerLod.minCoverBudget,
      );
      expect(
        KubusMarkerLod.coverBudget(const Size(double.nan, 100)),
        KubusMarkerLod.minCoverBudget,
      );
    });
  });

  group('cover plan by zoom', () {
    const center = LatLng(46.05, 14.5);
    const desktop = Size(1440, 900);
    final markers = <ArtMarker>[
      for (var i = 0; i < 40; i++) _marker('m$i', 46.05 + i * 0.0003, 14.5),
      _marker('sel', 46.06, 14.51),
    ];
    List<String> plan(double zoom, {String? selectedId = 'sel'}) =>
        KubusMarkerLod.planCoverIds(
          candidates: markers,
          selectedId: selectedId,
          center: center,
          viewport: desktop,
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

    test('a selection never costs the early stage a nearby cover', () {
      const phone = Size(390, 844);
      final ids = KubusMarkerLod.planCoverIds(
        candidates: markers,
        selectedId: 'sel',
        center: center,
        viewport: phone,
        zoom: 12.6,
        hasCover: (_) => true,
      );
      expect(ids.first, 'sel');
      expect(ids.length - 1, KubusMarkerLod.earlyCoverBudgetFloor);
    });

    test('nearby covers arrive progressively, never as one photo wall', () {
      final early = plan(12.6);
      final medium = plan(13.6);
      final full = plan(15.0);
      expect(early.first, 'sel');
      expect(early.length, lessThan(medium.length));
      expect(medium.length, lessThan(full.length));
      // The selection rides on top of the nearby budget.
      expect(full.length, KubusMarkerLod.coverBudget(desktop) + 1);
      // Every stage is a prefix of the next: covers already shown stay shown.
      expect(medium.take(early.length), early);
      expect(full.take(medium.length), medium);
    });
  });

  group('cover selection', () {
    const center = LatLng(46.05, 14.5);
    bool allHaveCovers(ArtMarker _) => true;

    test('selected first, then promoted, then nearest', () {
      final near = _marker('near', 46.0501, 14.5001);
      final far = _marker('far', 46.06, 14.51);
      final promoted = _marker('promo', 46.07, 14.52, promoted: true);
      final selected = _marker('sel', 46.2, 14.9);
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: [far, near, promoted, selected],
        selectedId: 'sel',
        center: center,
        budget: 4,
        hasCover: allHaveCovers,
      );
      expect(ids, <String>['sel', 'promo', 'near', 'far']);
    });

    test('the selected marker is kept even when the budget is zero', () {
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: [_marker('a', 46.05, 14.5), _marker('sel', 46.9, 14.9)],
        selectedId: 'sel',
        center: center,
        budget: 0,
        hasCover: allHaveCovers,
      );
      expect(ids, <String>['sel']);
    });

    test('the budget bounds everything except the selection', () {
      final many = [
        for (var i = 0; i < 40; i++) _marker('m$i', 46.05 + i * 0.001, 14.5),
      ];
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: many,
        selectedId: 'm39',
        center: center,
        budget: 8,
        hasCover: allHaveCovers,
      );
      // Eight nearby covers plus the selection, which never costs one.
      expect(ids.length, 9);
      expect(ids.first, 'm39');
      expect(ids.toSet().length, 9);
    });

    test(
      'markers without a cover, or with a failed one, never take a slot',
      () {
        final bare = _marker('bare', 46.0501, 14.5);
        final failed = _marker('failed', 46.0502, 14.5);
        final ok = _marker('ok', 46.0503, 14.5);
        final ids = KubusMarkerLod.selectCoverMarkerIds(
          candidates: [bare, failed, ok],
          selectedId: null,
          center: center,
          budget: 5,
          hasCover: (m) => m.id != 'bare',
          failedIds: <String>{'failed'},
        );
        expect(ids, <String>['ok']);
      },
    );

    test('a selected marker whose cover failed falls back to its marker', () {
      final selected = _marker('sel', 46.05, 14.5);
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: [selected],
        selectedId: 'sel',
        center: center,
        budget: 5,
        hasCover: allHaveCovers,
        failedIds: <String>{'sel'},
      );
      expect(ids, isEmpty);
    });

    test('ordering is deterministic for equal distances', () {
      final a = _marker('b', 46.06, 14.5);
      final b = _marker('a', 46.06, 14.5);
      final ids = KubusMarkerLod.selectCoverMarkerIds(
        candidates: [a, b],
        selectedId: null,
        center: center,
        budget: 5,
        hasCover: allHaveCovers,
      );
      expect(ids, <String>['a', 'b']);
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
