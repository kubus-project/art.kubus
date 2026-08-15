import 'dart:math' as math;

import 'package:art_kubus/services/ar_placement_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  late ArPlacementController controller;

  setUp(() => controller = ArPlacementController());

  /// Selected, tracking, and a surface found: ready for a tap.
  void reachPreviewing() {
    controller.selectArtwork(artworkId: 'art-1', modelPath: 'model.glb');
    controller.setTracking(true);
    controller.setSurfaceAvailable(true);
  }

  void reachPlaced() {
    reachPreviewing();
    controller.applyHitTest(Vector3(1, 0, -2));
  }

  group('selection is not placement', () {
    test('a fresh controller has nothing selected or placed', () {
      expect(controller.state, ArPlacementState.none);
      expect(controller.hasPlacement, isFalse);
      expect(controller.transform, isNull);
    });

    test('selecting an artwork does not place it', () {
      controller.selectArtwork(artworkId: 'art-1', modelPath: 'model.glb');

      expect(controller.state, ArPlacementState.selected);
      expect(controller.artworkId, 'art-1');
      expect(controller.hasPlacement, isFalse);
      expect(controller.transform, isNull,
          reason: 'nothing is positioned until the user taps a surface');
    });

    test('tracking becoming ready does not auto-place', () {
      controller.selectArtwork(artworkId: 'art-1', modelPath: 'model.glb');
      controller.setTracking(true);

      // The regression: the AR view becoming ready used to drop the model at a
      // fixed Vector3(0, 0, -1.5) regardless of the room.
      expect(controller.state, ArPlacementState.searchingSurface);
      expect(controller.hasPlacement, isFalse);
      expect(controller.transform, isNull);
    });

    test('a surface being found does not auto-place either', () {
      reachPreviewing();

      expect(controller.state, ArPlacementState.previewing);
      expect(controller.hasPlacement, isFalse);
    });
  });

  group('surface acquisition', () {
    test('searching becomes previewing once a surface appears', () {
      controller.selectArtwork(artworkId: 'art-1', modelPath: 'm.glb');
      controller.setTracking(true);
      expect(controller.state, ArPlacementState.searchingSurface);

      controller.setSurfaceAvailable(true);

      expect(controller.state, ArPlacementState.previewing);
    });

    test('selecting while already tracking with a surface previews at once',
        () {
      controller.setTracking(true);
      controller.setSurfaceAvailable(true);

      controller.selectArtwork(artworkId: 'art-1', modelPath: 'm.glb');

      expect(controller.state, ArPlacementState.previewing);
    });
  });

  group('hit testing', () {
    test('a valid hit anchors the artwork', () {
      reachPreviewing();

      final applied = controller.applyHitTest(Vector3(1, 0, -2));

      expect(applied, isTrue);
      expect(controller.state, ArPlacementState.placed);
      expect(controller.transform!.position.x, 1);
      expect(controller.transform!.position.z, -2);
      expect(controller.hasPlacement, isTrue);
    });

    test('a missed hit test leaves the placement untouched', () {
      reachPlaced();
      final before = controller.transform!.position.clone();

      final applied = controller.applyHitTest(null);

      expect(applied, isFalse);
      expect(controller.transform!.position, before);
    });

    test('a non-finite pose is rejected', () {
      reachPreviewing();

      expect(controller.applyHitTest(Vector3(double.nan, 0, 0)), isFalse);
      expect(controller.applyHitTest(Vector3(0, double.infinity, 0)), isFalse);
      expect(controller.hasPlacement, isFalse);
    });

    test('a tap is ignored while tracking is lost', () {
      controller.selectArtwork(artworkId: 'art-1', modelPath: 'm.glb');

      expect(controller.acceptsHitTest, isFalse);
      expect(controller.applyHitTest(Vector3(1, 0, -1)), isFalse);
    });

    test('hit rotation is applied when the surface provides one', () {
      reachPreviewing();

      controller.applyHitTest(Vector3.zero(), rotationRadians: 1.2);

      expect(controller.transform!.rotationRadians, closeTo(1.2, 1e-9));
    });
  });

  group('adjustment', () {
    test('rotate wraps into a single turn', () {
      reachPlaced();

      controller.beginAdjusting();
      controller.rotateBy(2 * math.pi + 0.5);

      expect(controller.transform!.rotationRadians, closeTo(0.5, 1e-6));
    });

    test('negative rotation stays positive', () {
      reachPlaced();
      controller.beginAdjusting();

      controller.rotateBy(-0.5);

      expect(controller.transform!.rotationRadians,
          closeTo(2 * math.pi - 0.5, 1e-6));
    });

    test('scale is clamped to the configured bounds', () {
      reachPlaced();
      controller.beginAdjusting();

      controller.scaleBy(100);
      expect(controller.transform!.scale, controller.maxScale);

      controller.scaleBy(0.0001);
      expect(controller.transform!.scale, controller.minScale);
    });

    test('a nonsensical scale factor is ignored', () {
      reachPlaced();
      controller.beginAdjusting();
      final before = controller.transform!.scale;

      controller.scaleBy(0);
      controller.scaleBy(-2);
      controller.scaleBy(double.nan);

      expect(controller.transform!.scale, before);
    });

    test('reposition moves an existing placement', () {
      reachPlaced();
      controller.beginAdjusting();

      final moved = controller.repositionTo(Vector3(5, 0, -5));

      expect(moved, isTrue);
      expect(controller.transform!.position.x, 5);
    });

    test('ending a gesture returns to placed', () {
      reachPlaced();
      controller.beginAdjusting();
      expect(controller.state, ArPlacementState.adjusting);

      controller.endAdjusting();

      expect(controller.state, ArPlacementState.placed);
    });
  });

  group('confirm and cancel', () {
    test('confirm commits the placement', () {
      reachPlaced();

      controller.confirm();

      expect(controller.state, ArPlacementState.confirmed);
      expect(controller.hasPlacement, isTrue);
    });

    test('confirm is refused before anything is placed', () {
      reachPreviewing();

      controller.confirm();

      expect(controller.state, ArPlacementState.previewing);
    });

    test('cancel discards the placement but keeps the artwork selected', () {
      reachPlaced();

      controller.cancelPlacement();

      expect(controller.state, ArPlacementState.previewing);
      expect(controller.artworkId, 'art-1');
      expect(controller.transform, isNull);
      expect(controller.hasPlacement, isFalse);
    });

    test('reset clears the selection too', () {
      reachPlaced();

      controller.reset();

      expect(controller.state, ArPlacementState.none);
      expect(controller.artworkId, isNull);
    });
  });

  group('tracking loss', () {
    test('a placed anchor survives tracking loss', () {
      reachPlaced();
      final before = controller.transform!.position.clone();

      controller.setTracking(false);

      expect(controller.hasPlacement, isTrue);
      expect(controller.transform!.position, before,
          reason: 'the anchor is preserved, not discarded');
      expect(controller.isRecoveringTracking, isTrue);
    });

    test('adjustment is disabled while tracking is lost', () {
      reachPlaced();
      controller.setTracking(false);

      expect(controller.canAdjust, isFalse);
      expect(controller.canConfirm, isFalse);

      controller.rotateBy(1);
      controller.scaleBy(2);

      expect(controller.transform!.rotationRadians, 0);
      expect(controller.transform!.scale, 1.0);
    });

    test('adjustment resumes when tracking returns', () {
      reachPlaced();
      controller.setTracking(false);
      controller.setTracking(true);

      expect(controller.canAdjust, isTrue);
      expect(controller.isRecoveringTracking, isFalse);

      controller.beginAdjusting();
      controller.rotateBy(0.4);
      expect(controller.transform!.rotationRadians, closeTo(0.4, 1e-9));
    });

    test('an unanchored preview falls back to selected on tracking loss', () {
      reachPreviewing();

      controller.setTracking(false);

      expect(controller.state, ArPlacementState.selected);
      expect(controller.hasPlacement, isFalse);
    });
  });

  group('errors', () {
    test('an error is recoverable back to the placed state', () {
      reachPlaced();

      controller.reportError('anchor_failed');
      expect(controller.state, ArPlacementState.error);
      expect(controller.errorCode, 'anchor_failed');

      controller.clearError();

      expect(controller.state, ArPlacementState.placed);
      expect(controller.errorCode, isNull);
    });

    test('an error with nothing placed returns to previewing', () {
      reachPreviewing();

      controller.reportError('hit_failed');
      controller.clearError();

      expect(controller.state, ArPlacementState.previewing);
    });
  });

  test('listeners are notified on every meaningful transition', () {
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.selectArtwork(artworkId: 'a', modelPath: 'm');
    controller.setTracking(true);
    controller.setSurfaceAvailable(true);
    controller.applyHitTest(Vector3(1, 0, 0));
    controller.beginAdjusting();
    controller.rotateBy(0.2);
    controller.endAdjusting();
    controller.confirm();

    expect(notifications, 8);
  });
}
