import 'dart:ui';

import 'package:art_kubus/features/map/shared/map_marker_lod.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/promotion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker(
  String id,
  double lat,
  double lng, {
  bool promoted = false,
}) {
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
    test('far below the blend centre, mid from it, close at street scale', () {
      expect(KubusMarkerLod.tierForZoom(0), KubusMarkerLodTier.far);
      expect(KubusMarkerLod.tierForZoom(2.55), KubusMarkerLodTier.far);
      expect(KubusMarkerLod.tierForZoom(5.99), KubusMarkerLodTier.far);
      expect(KubusMarkerLod.tierForZoom(6.0), KubusMarkerLodTier.mid);
      expect(KubusMarkerLod.tierForZoom(10), KubusMarkerLodTier.mid);
      expect(KubusMarkerLod.tierForZoom(14.99), KubusMarkerLodTier.mid);
      expect(KubusMarkerLod.tierForZoom(15.0), KubusMarkerLodTier.close);
      expect(KubusMarkerLod.tierForZoom(22), KubusMarkerLodTier.close);
    });

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

    test('covers only at street scale', () {
      expect(KubusMarkerLod.allowsCovers(14.9), isFalse);
      expect(KubusMarkerLod.allowsCovers(15.0), isTrue);
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
      expect(ids.length, 8);
      expect(ids.first, 'm39');
      expect(ids.toSet().length, 8);
    });

    test('markers without a cover, or with a failed one, never take a slot',
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
    });

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

    test('hitbox targets the dot when far and the floating badge otherwise',
        () {
      final anchor = KubusMarkerLod.hitboxAnchorExpression() as List;
      expect(anchor, <Object>[
        'step',
        const <Object>['zoom'],
        'center',
        KubusMarkerLod.blendStartZoom,
        'bottom',
      ]);
    });

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
