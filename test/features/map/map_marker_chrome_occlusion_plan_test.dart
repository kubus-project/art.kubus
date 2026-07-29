import 'package:art_kubus/features/map/shared/map_marker_chrome_occlusion_plan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const card = Rect.fromLTWH(100, 200, 200, 240);

  group('MapMarkerChromeOcclusionPlan', () {
    test('keeps all chrome visible when nothing overlaps', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 1,
        cardRect: card,
        searchRect: const Rect.fromLTWH(20, 20, 320, 56),
        discoveryRect: const Rect.fromLTWH(20, 500, 160, 80),
        controlsRect: const Rect.fromLTWH(330, 200, 48, 180),
        nearbyRect: const Rect.fromLTWH(20, 600, 360, 80),
      );

      expect(plan.hasOcclusion, isFalse);
    });

    test('reports search-only overlap', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 2,
        cardRect: card,
        searchRect: const Rect.fromLTWH(80, 180, 240, 56),
        discoveryRect: const Rect.fromLTWH(20, 500, 160, 80),
      );

      expect(plan.searchOccluded, isTrue);
      expect(plan.discoveryOccluded, isFalse);
      expect(plan.controlsOccluded, isFalse);
      expect(plan.nearbyOccluded, isFalse);
    });

    test('reports Discovery-only overlap', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 3,
        cardRect: card,
        discoveryRect: const Rect.fromLTWH(20, 380, 160, 80),
      );

      expect(plan.discoveryOccluded, isTrue);
      expect(plan.searchOccluded, isFalse);
    });

    test('reports control-only overlap', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 4,
        cardRect: card,
        controlsRect: const Rect.fromLTWH(280, 240, 48, 180),
      );

      expect(plan.controlsOccluded, isTrue);
      expect(plan.nearbyOccluded, isFalse);
    });

    test('reports Nearby-only overlap', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 5,
        cardRect: card,
        nearbyRect: const Rect.fromLTWH(20, 420, 360, 80),
      );

      expect(plan.nearbyOccluded, isTrue);
      expect(plan.controlsOccluded, isFalse);
    });

    test('reports multiple independent overlaps', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 6,
        cardRect: card,
        searchRect: const Rect.fromLTWH(80, 180, 240, 56),
        discoveryRect: const Rect.fromLTWH(20, 380, 160, 80),
        controlsRect: const Rect.fromLTWH(280, 240, 48, 180),
        nearbyRect: const Rect.fromLTWH(20, 420, 360, 80),
      );

      expect(plan.searchOccluded, isTrue);
      expect(plan.discoveryOccluded, isTrue);
      expect(plan.controlsOccluded, isTrue);
      expect(plan.nearbyOccluded, isTrue);
    });

    test('collision margin detects a close but non-overlapping rectangle', () {
      final withoutMargin = MapMarkerChromeOcclusionPlan.resolve(
        revision: 7,
        cardRect: card,
        controlsRect: const Rect.fromLTWH(304, 240, 48, 180),
      );
      final withMargin = MapMarkerChromeOcclusionPlan.resolve(
        revision: 8,
        cardRect: card,
        controlsRect: const Rect.fromLTWH(304, 240, 48, 180),
        collisionMargin: 8,
      );

      expect(withoutMargin.controlsOccluded, isFalse);
      expect(withMargin.controlsOccluded, isTrue);
    });

    test('edge touching alone is not an intersection', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 9,
        cardRect: card,
        nearbyRect: const Rect.fromLTWH(100, 440, 200, 80),
      );

      expect(plan.nearbyOccluded, isFalse);
    });

    test('missing and unmeasurable chrome rectangles remain visible', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 10,
        cardRect: card,
        searchRect: Rect.zero,
        discoveryRect: const Rect.fromLTWH(20, 20, 0, 80),
      );

      expect(plan.hasOcclusion, isFalse);
    });

    test('invalid card geometry restores visible state', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 11,
        cardRect: Rect.zero,
        searchRect: const Rect.fromLTWH(0, 0, 100, 100),
      );

      expect(plan, MapMarkerChromeOcclusionPlan.visible(revision: 11));
    });

    test('revision helper rejects stale plans', () {
      final plan = MapMarkerChromeOcclusionPlan.resolve(
        revision: 12,
        cardRect: card,
        searchRect: const Rect.fromLTWH(80, 180, 240, 56),
      );

      expect(plan.isCurrentRevision(12), isTrue);
      expect(plan.isCurrentRevision(13), isFalse);
    });

    test('fresh geometry restores each component independently', () {
      final occluded = MapMarkerChromeOcclusionPlan.resolve(
        revision: 13,
        cardRect: card,
        searchRect: const Rect.fromLTWH(80, 180, 240, 56),
      );
      final restored = MapMarkerChromeOcclusionPlan.resolve(
        revision: 14,
        cardRect: const Rect.fromLTWH(100, 300, 200, 240),
        searchRect: const Rect.fromLTWH(80, 180, 240, 56),
      );

      expect(occluded.searchOccluded, isTrue);
      expect(restored.searchOccluded, isFalse);
      expect(restored.isCurrentRevision(14), isTrue);
    });
  });
}
