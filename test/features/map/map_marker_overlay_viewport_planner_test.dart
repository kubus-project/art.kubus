import 'package:art_kubus/features/map/shared/map_marker_overlay_viewport_planner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planSelectedMarkerOverlayViewport', () {
    MapMarkerOverlayViewportPlan planLowerThird({
      required Size viewportSize,
      required Offset markerAnchor,
      required Size cardSize,
      required EdgeInsets safeInsets,
      required double markerOffset,
      double topChromePx = 0,
      double bottomChromePx = 0,
      double maxNudgePx = 120,
      double maxOverlayShiftPx = 160,
      double epsilonPx = 8,
      double markerTailPx = 18,
      int layoutRevision = 0,
      int? expectedLayoutRevision,
      int? lastCorrectedLayoutRevision,
    }) {
      return planSelectedMarkerOverlayViewport(
        viewportSize: viewportSize,
        markerAnchor: markerAnchor,
        cardSize: cardSize,
        safeInsets: safeInsets,
        markerOffset: markerOffset,
        topChromePx: topChromePx,
        bottomChromePx: bottomChromePx,
        maxNudgePx: maxNudgePx,
        maxOverlayShiftPx: maxOverlayShiftPx,
        epsilonPx: epsilonPx,
        markerTailPx: markerTailPx,
        verticalComposition: MapMarkerOverlayVerticalComposition.lowerThird,
        layoutRevision: layoutRevision,
        expectedLayoutRevision: expectedLayoutRevision,
        lastCorrectedLayoutRevision: lastCorrectedLayoutRevision,
      );
    }

    test('default strategy preserves existing ensure-visible composition', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(1200, 800),
        markerAnchor: const Offset(600, 400),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.all(24),
        markerOffset: 24,
      );

      expect(plan.targetAnchorY, 400);
      expect(plan.needsNudge, isFalse);
    });

    test('does not correct a marker already on the usable lower-third guide',
        () {
      final plan = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 420),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 80),
        markerOffset: 24,
      );

      expect(plan.targetAnchorY, 420);
      expect(plan.needsNudge, isFalse);
      expect(plan.compositionYOffsetPx, 0);
      expect(plan.needsOverlayShift, isFalse);
    });

    test('moves a marker above the guide down', () {
      final plan = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 350),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 80),
        markerOffset: 24,
      );

      expect(plan.rawNudgePx, 70);
      expect(plan.compositionYOffsetPx, 70);
      expect(plan.needsNudge, isTrue);
    });

    test('moves a marker below the guide up', () {
      final plan = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 500),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 80),
        markerOffset: 24,
      );

      expect(plan.rawNudgePx, -80);
      expect(plan.compositionYOffsetPx, -80);
    });

    test('uses safe insets and persistent top and bottom reservations', () {
      final plan = planLowerThird(
        viewportSize: const Size(400, 800),
        markerAnchor: const Offset(200, 450),
        cardSize: const Size(300, 220),
        safeInsets: const EdgeInsets.only(top: 24, bottom: 34),
        markerOffset: 20,
        topChromePx: 80,
        bottomChromePx: 120,
      );

      expect(plan.safeTop, 104);
      expect(plan.safeBottom, 680);
      expect(plan.targetAnchorY, 488);
      expect(plan.compositionYOffsetPx, 38);
    });

    test('bottom navigation reservation raises the lower-third guide', () {
      final withoutNavigation = planLowerThird(
        viewportSize: const Size(390, 844),
        markerAnchor: const Offset(195, 550),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 44, bottom: 34),
        markerOffset: 24,
      );
      final withNavigation = planLowerThird(
        viewportSize: const Size(390, 844),
        markerAnchor: const Offset(195, 550),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 44, bottom: 34),
        markerOffset: 24,
        bottomChromePx: 100,
      );

      expect(
        withNavigation.targetAnchorY,
        lessThan(withoutNavigation.targetAnchorY),
      );
      expect(withNavigation.safeBottom, 744);
    });

    test('short viewport reports oversized fallback and stays bounded', () {
      final plan = planLowerThird(
        viewportSize: const Size(360, 320),
        markerAnchor: const Offset(180, 80),
        cardSize: const Size(320, 280),
        safeInsets: const EdgeInsets.only(top: 24, bottom: 32),
        markerOffset: 24,
        markerTailPx: 18,
        maxNudgePx: 72,
      );

      expect(plan.oversizedCard, isTrue);
      expect(plan.targetAnchorY, closeTo(200, 0.001));
      expect(plan.compositionYOffsetPx, 72);
      expect(plan.compositionYOffsetPx.abs(), lessThanOrEqualTo(72));
    });

    test('tall viewport constrains guide enough to keep card above marker', () {
      final plan = planLowerThird(
        viewportSize: const Size(412, 1000),
        markerAnchor: const Offset(206, 600),
        cardSize: const Size(336, 500),
        safeInsets: const EdgeInsets.only(top: 40, bottom: 40),
        markerOffset: 24,
      );

      expect(plan.oversizedCard, isFalse);
      expect(plan.targetAnchorY, closeTo(653.333, 0.001));
      expect(
        plan.targetAnchorY - 500 - 24,
        greaterThanOrEqualTo(plan.safeTop),
      );
    });

    test('landscape viewport uses its usable geometry', () {
      final plan = planLowerThird(
        viewportSize: const Size(844, 390),
        markerAnchor: const Offset(422, 250),
        cardSize: const Size(336, 260),
        safeInsets: const EdgeInsets.only(
          left: 44,
          right: 44,
          top: 16,
          bottom: 24,
        ),
        markerOffset: 20,
      );

      expect(plan.oversizedCard, isFalse);
      expect(plan.targetAnchorY, 296);
      expect(plan.compositionYOffsetPx, 46);
    });

    test('centers an oversized card in the usable horizontal region', () {
      final plan = planLowerThird(
        viewportSize: const Size(260, 500),
        markerAnchor: const Offset(210, 350),
        cardSize: const Size(320, 220),
        safeInsets: const EdgeInsets.symmetric(horizontal: 12),
        markerOffset: 20,
      );

      expect(plan.rawOverlayShiftXPx, -80);
      expect(plan.overlayShiftXPx, -80);
      expect(plan.needsOverlayShift, isTrue);
    });

    test('shifts left and right edge cards toward the safe region', () {
      final left = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(42, 460),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.symmetric(horizontal: 16),
        markerOffset: 24,
      );
      final right = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(370, 460),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.symmetric(horizontal: 16),
        markerOffset: 24,
      );

      expect(left.overlayShiftXPx, 134);
      expect(right.overlayShiftXPx, -146);
    });

    test('bounds extreme vertical and horizontal corrections', () {
      final plan = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(390, 40),
        cardSize: const Size(340, 260),
        safeInsets: const EdgeInsets.symmetric(horizontal: 16),
        markerOffset: 24,
        maxNudgePx: 64,
        maxOverlayShiftPx: 96,
      );

      expect(plan.rawNudgePx, greaterThan(64));
      expect(plan.compositionYOffsetPx, 64);
      expect(plan.overlayShiftXPx, -96);
    });

    test('ignores a correction below the geometry epsilon', () {
      final plan = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 414),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 80),
        markerOffset: 24,
        epsilonPx: 8,
      );

      expect(plan.rawNudgePx, 6);
      expect(plan.isMaterialCorrection, isFalse);
      expect(plan.needsNudge, isFalse);
    });

    test('rejects a stale layout revision', () {
      final plan = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 300),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 80),
        markerOffset: 24,
        layoutRevision: 4,
        expectedLayoutRevision: 5,
      );

      expect(plan.isStale, isTrue);
      expect(plan.isMaterialCorrection, isTrue);
      expect(plan.needsNudge, isFalse);
      expect(plan.canApplyCorrection, isFalse);
    });

    test('does not repeat correction for an already applied layout revision',
        () {
      final first = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 300),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 80),
        markerOffset: 24,
        layoutRevision: 9,
      );
      final repeated = planLowerThird(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 300),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 80),
        markerOffset: 24,
        layoutRevision: 9,
        lastCorrectedLayoutRevision: 9,
      );

      expect(first.canApplyCorrection, isTrue);
      expect(repeated.correctionAlreadyApplied, isTrue);
      expect(repeated.needsNudge, isFalse);
    });

    test('new orientation or card-height revision may compose again', () {
      final orientationChanged = planLowerThird(
        viewportSize: const Size(700, 400),
        markerAnchor: const Offset(350, 180),
        cardSize: const Size(320, 220),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 40),
        markerOffset: 20,
        layoutRevision: 11,
        expectedLayoutRevision: 11,
        lastCorrectedLayoutRevision: 10,
      );
      final cardHeightChanged = planLowerThird(
        viewportSize: const Size(700, 400),
        markerAnchor: const Offset(350, 180),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 20, bottom: 40),
        markerOffset: 20,
        layoutRevision: 12,
        expectedLayoutRevision: 12,
        lastCorrectedLayoutRevision: 11,
      );

      expect(orientationChanged.canApplyCorrection, isTrue);
      expect(cardHeightChanged.canApplyCorrection, isTrue);
      expect(cardHeightChanged.layoutRevision, 12);
    });
  });
}
