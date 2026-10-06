import 'dart:ui';

import 'package:art_kubus/features/map/shared/map_marker_overlay_acknowledgement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kubusCardIsFullyVisible', () {
    const viewport = Rect.fromLTWH(0, 0, 390, 844);

    test('a card inside the viewport is visible', () {
      expect(
        kubusCardIsFullyVisible(
            const Rect.fromLTRB(35, 112, 355, 496), viewport),
        isTrue,
      );
    });

    test(
        'a tall card clamped to the top of the map is still visible even though '
        'it overlaps the marker', () {
      // The card measured on a phone for a marker with a long description:
      // 536 px tall, pinned to the top, its bottom below the marker anchor.
      expect(
        kubusCardIsFullyVisible(
            const Rect.fromLTRB(35, 12, 355, 548), viewport),
        isTrue,
      );
    });

    test('a card that spills outside the viewport is not visible', () {
      expect(
        kubusCardIsFullyVisible(
            const Rect.fromLTRB(35, -40, 355, 400), viewport),
        isFalse,
      );
      expect(
        kubusCardIsFullyVisible(
            const Rect.fromLTRB(35, 300, 355, 900), viewport),
        isFalse,
      );
      expect(
        kubusCardIsFullyVisible(
            const Rect.fromLTRB(-30, 100, 355, 400), viewport),
        isFalse,
      );
    });

    test('empty and non-finite rectangles are never visible', () {
      expect(kubusCardIsFullyVisible(Rect.zero, viewport), isFalse);
      expect(
        kubusCardIsFullyVisible(
          const Rect.fromLTRB(0, 0, double.infinity, 100),
          viewport,
        ),
        isFalse,
      );
    });
  });

  group('kubusMarkerOverlayMayAcknowledge', () {
    test('the ideal frame acknowledges immediately', () {
      expect(
        kubusMarkerOverlayMayAcknowledge(
          finalLayoutIsValid: true,
          cardIsFullyVisible: true,
          compositionSettled: false,
        ),
        isTrue,
      );
    });

    test('a visible but unplaceable card acknowledges once settled', () {
      expect(
        kubusMarkerOverlayMayAcknowledge(
          finalLayoutIsValid: false,
          cardIsFullyVisible: true,
          compositionSettled: true,
        ),
        isTrue,
      );
    });

    test('an unsettled, not ideal frame does not acknowledge', () {
      expect(
        kubusMarkerOverlayMayAcknowledge(
          finalLayoutIsValid: false,
          cardIsFullyVisible: true,
          compositionSettled: false,
        ),
        isFalse,
      );
    });

    test('a card that is not fully on screen never acknowledges', () {
      expect(
        kubusMarkerOverlayMayAcknowledge(
          finalLayoutIsValid: false,
          cardIsFullyVisible: false,
          compositionSettled: true,
        ),
        isFalse,
      );
    });
  });
}
