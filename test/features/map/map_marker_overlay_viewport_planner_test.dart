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
  });
}
