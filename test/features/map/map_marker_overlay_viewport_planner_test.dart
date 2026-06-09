import 'package:art_kubus/features/map/shared/map_marker_overlay_viewport_planner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planSelectedMarkerOverlayViewport', () {
    test('does not nudge when marker and card pair already fit', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 360),
        cardSize: const Size(320, 260),
        safeInsets: EdgeInsets.zero,
        markerOffset: 24,
      );

      expect(plan.needsNudge, isFalse);
      expect(plan.compositionYOffsetPx, 0);
      expect(plan.needsOverlayShift, isFalse);
      expect(plan.overlayShiftXPx, 0);
    });

    test('nudges marker near top by a small bounded amount', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 170),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(top: 24, bottom: 16),
        markerOffset: 24,
      );

      expect(plan.needsNudge, isTrue);
      expect(plan.compositionYOffsetPx, greaterThan(0));
      expect(plan.compositionYOffsetPx.abs(), lessThanOrEqualTo(120));
    });

    test('clamps extreme top nudge', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 40),
        cardSize: const Size(320, 420),
        safeInsets: const EdgeInsets.only(top: 24),
        markerOffset: 32,
        maxNudgePx: 120,
      );

      expect(plan.needsNudge, isTrue);
      expect(plan.compositionYOffsetPx, 120);
      expect(plan.rawNudgePx, greaterThan(120));
    });

    test('clamps extreme bottom nudge', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(200, 760),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(bottom: 16),
        markerOffset: 24,
        maxNudgePx: 120,
      );

      expect(plan.needsNudge, isTrue);
      expect(plan.compositionYOffsetPx, -94);
      expect(plan.compositionYOffsetPx.abs(), lessThanOrEqualTo(120));
    });

    test('plans horizontal shift for left overflow without camera nudge', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(42, 360),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(left: 16, right: 16),
        markerOffset: 24,
      );

      expect(plan.needsOverlayShift, isTrue);
      expect(plan.overlayShiftXPx, greaterThan(0));
      expect(plan.needsNudge, isFalse);
      expect(plan.compositionYOffsetPx, 0);
    });

    test('plans horizontal shift for right overflow without camera nudge', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(370, 360),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(left: 16, right: 16),
        markerOffset: 24,
      );

      expect(plan.needsOverlayShift, isTrue);
      expect(plan.overlayShiftXPx, lessThan(0));
      expect(plan.needsNudge, isFalse);
      expect(plan.compositionYOffsetPx, 0);
    });

    test('tiny viewport keeps shifts and nudges bounded', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(260, 320),
        markerAnchor: const Offset(245, 40),
        cardSize: const Size(320, 260),
        safeInsets: const EdgeInsets.only(
          left: 12,
          right: 12,
          top: 24,
          bottom: 24,
        ),
        markerOffset: 24,
        maxNudgePx: 80,
        maxOverlayShiftPx: 96,
      );

      expect(plan.needsOverlayShift, isTrue);
      expect(plan.overlayShiftXPx.abs(), lessThanOrEqualTo(96));
      expect(plan.needsNudge, isTrue);
      expect(plan.compositionYOffsetPx.abs(), lessThanOrEqualTo(80));
    });

    test('does not request excessive camera nudge for horizontal overflow', () {
      final plan = planSelectedMarkerOverlayViewport(
        viewportSize: const Size(400, 700),
        markerAnchor: const Offset(390, 360),
        cardSize: const Size(340, 260),
        safeInsets: const EdgeInsets.only(left: 16, right: 16),
        markerOffset: 24,
        maxNudgePx: 64,
      );

      expect(plan.needsOverlayShift, isTrue);
      expect(plan.compositionYOffsetPx.abs(), lessThanOrEqualTo(64));
      expect(plan.needsNudge, isFalse);
    });
  });
}
