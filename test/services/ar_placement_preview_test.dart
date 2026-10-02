import 'dart:math' as math;

import 'package:art_kubus/services/ar_placement_controller.dart';
import 'package:art_kubus/services/ar_placement_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../support/fake_spatial_tracking_adapter.dart';

void main() {
  late FakeSpatialTrackingAdapter tracking;
  late ArPlacementController placement;
  late ArPlacementPreview preview;
  late List<Object> errors;

  setUp(() {
    tracking = FakeSpatialTrackingAdapter(
      initialState: FakeArSessionState.tracking,
    );
    placement = ArPlacementController();
    errors = <Object>[];
    preview = ArPlacementPreview(
      tracking: tracking,
      // Resolution is a no-op here: content routing is exercised elsewhere.
      resolveModel: (raw) async => 'file:///resolved/$raw',
      onError: errors.add,
    );
  });

  tearDown(() {
    preview.dispose();
    placement.dispose();
  });

  ArPlacementAnchorPose pose(
    vector.Vector3 position, [
    vector.Vector4? rotation,
  ]) =>
      ArPlacementAnchorPose(
        position: position,
        rotation: rotation ?? vector.Vector4(0, 0, 0, 1),
      );

  /// Brings the controller to a previewed placement at [position].
  Future<void> place(vector.Vector3 position) async {
    placement.selectArtwork(artworkId: 'art-1', modelPath: 'model.glb');
    placement.setTracking(true);
    placement.setSurfaceAvailable(true);
    placement.applyHitTest(pose(position));
    await preview.sync(placement);
  }

  group('a preview is rendered before confirmation', () {
    test('selecting an artwork alone adds nothing to the scene', () async {
      placement.selectArtwork(artworkId: 'art-1', modelPath: 'model.glb');
      placement.setTracking(true);
      placement.setSurfaceAvailable(true);
      await preview.sync(placement);

      expect(tracking.nodes, isEmpty,
          reason: 'choosing an artwork is not placing it');
      expect(preview.hasPreview, isFalse);
    });

    test('the first hit test puts a visible node at the chosen pose', () async {
      await place(vector.Vector3(1, 0, -2));

      expect(placement.state, ArPlacementState.placed);
      expect(
        placement.state,
        isNot(ArPlacementState.confirmed),
        reason: 'the model is in the scene while the user is still deciding',
      );
      expect(tracking.nodes, hasLength(1));

      final node = tracking.nodes.values.single;
      expect(node.name, ArPlacementPreview.nodeNameFor('art-1'));
      expect(node.position.x, 1);
      expect(node.position.z, -2);
      expect(node.modelPath, 'file:///resolved/model.glb');
      expect(preview.hasPreview, isTrue);
    });
  });

  group('adjustments reach the platform node', () {
    test('rotation is applied to the scene node, not just Dart state',
        () async {
      await place(vector.Vector3(0, 0, -1));
      expect(tracking.nodes.values.single.yawRadians, 0);

      placement.rotateBy(math.pi / 2);
      await preview.sync(placement);

      expect(placement.transform!.localYawRadians, closeTo(math.pi / 2, 1e-9));
      expect(
        tracking.nodes.values.single.yawRadians,
        closeTo(math.pi / 2, 1e-9),
        reason: 'Rotate must change what the user can see',
      );
      expect(
          tracking.calls,
          contains('updateAnchoredNode:'
              '${ArPlacementPreview.nodeNameFor('art-1')}'
              '(anchor:false,yaw:true,scale:false)'));
    });

    test('scale is applied to the scene node', () async {
      await place(vector.Vector3(0, 0, -1));
      expect(tracking.nodes.values.single.scale, 1.0);

      placement.scaleBy(2.0);
      await preview.sync(placement);

      expect(placement.transform!.localScale, closeTo(2.0, 1e-9));
      expect(tracking.nodes.values.single.scale, closeTo(2.0, 1e-9));
      expect(
        tracking.calls.last,
        'updateAnchoredNode:${ArPlacementPreview.nodeNameFor('art-1')}'
        '(anchor:false,yaw:false,scale:true)',
        reason: 'pinch changes only content scale; it never replaces anchor P',
      );
    });

    test('scale stays inside the controller bounds all the way to the node',
        () async {
      await place(vector.Vector3(0, 0, -1));

      placement.scaleBy(100);
      await preview.sync(placement);

      expect(placement.transform!.localScale, placement.maxScale);
      expect(tracking.nodes.values.single.scale, placement.maxScale);
    });

    test('repositioning moves the existing node rather than adding another',
        () async {
      await place(vector.Vector3(0, 0, -1));
      final nodeName = tracking.nodes.keys.single;

      final moved = placement.repositionTo(pose(vector.Vector3(3, 0.5, -4)));
      await preview.sync(placement);

      expect(moved, isTrue);
      expect(tracking.nodes, hasLength(1),
          reason: 'reposition must not leave the old node behind');
      expect(tracking.nodes.keys.single, nodeName);
      final node = tracking.nodes.values.single;
      expect(node.position.x, 3);
      expect(node.position.y, 0.5);
      expect(node.position.z, -4);
      expect(
        tracking.calls.last,
        'updateAnchoredNode:$nodeName(anchor:true,yaw:false,scale:false)',
        reason: 'reposition explicitly replaces the anchor, not a child offset',
      );
    });

    test('rotation and scale survive a reposition', () async {
      await place(vector.Vector3(0, 0, -1));
      placement.rotateBy(math.pi / 4);
      placement.scaleBy(1.5);
      await preview.sync(placement);

      placement.repositionTo(pose(vector.Vector3(2, 0, -2)));
      await preview.sync(placement);

      final node = tracking.nodes.values.single;
      expect(node.yawRadians, closeTo(math.pi / 4, 1e-9));
      expect(node.scale, closeTo(1.5, 1e-9));
      expect(node.position.x, 2);
    });

    test('the doubled-translation regression cannot be reintroduced', () async {
      await place(vector.Vector3(1, 0, -2));
      placement.scaleBy(2);
      await preview.sync(placement);
      placement.rotateBy(math.pi / 3);
      await preview.sync(placement);

      final node = tracking.nodes.values.single;
      expect(node.position, vector.Vector3(1, 0, -2));
      expect(node.scale, 2);
      expect(node.yawRadians, closeTo(math.pi / 3, 1e-9));
      expect(node.position, isNot(vector.Vector3(2, 0, -4)));
    });
  });

  group('the scene never keeps an orphan', () {
    test('cancelling removes the preview node', () async {
      await place(vector.Vector3(0, 0, -1));
      expect(tracking.nodes, hasLength(1));

      placement.cancelPlacement();
      await preview.sync(placement);

      expect(tracking.nodes, isEmpty);
      expect(preview.hasPreview, isFalse);
      expect(
          tracking.calls,
          contains('removeNode:'
              '${ArPlacementPreview.nodeNameFor('art-1')}'));
    });

    test('clear() removes the preview node', () async {
      await place(vector.Vector3(0, 0, -1));

      await preview.clear();

      expect(tracking.nodes, isEmpty);
      expect(preview.hasPreview, isFalse);
    });

    test('choosing a different artwork replaces the node', () async {
      await place(vector.Vector3(0, 0, -1));

      placement.selectArtwork(artworkId: 'art-2', modelPath: 'other.glb');
      placement.applyHitTest(pose(vector.Vector3(1, 0, -1)));
      await preview.sync(placement);

      expect(tracking.nodes, hasLength(1));
      expect(
        tracking.nodes.keys.single,
        ArPlacementPreview.nodeNameFor('art-2'),
      );
    });

    test('committing hands the node over without removing it', () async {
      await place(vector.Vector3(0, 0, -1));
      final nodeName = tracking.nodes.keys.single;

      final committed = await preview.commit();

      expect(committed, nodeName);
      expect(preview.hasPreview, isFalse);
      expect(
        tracking.nodes,
        hasLength(1),
        reason: 'the previewed node becomes the placed node; nothing blinks',
      );
    });

    test(
      'confirming after a commit does not rebuild a second node',
      () async {
        // The screen commits the preview and then marks the placement
        // confirmed, which notifies listeners and syncs again. Without a guard
        // that second sync sees "no preview node but a transform exists" and
        // adds another node with the same name, on top of the placed artwork.
        await place(vector.Vector3(0, 0, -1));
        await preview.commit();
        final addsBeforeConfirm =
            tracking.calls.where((c) => c.startsWith('addModel:')).length;

        placement.confirm();
        await preview.sync(placement);

        expect(placement.state, ArPlacementState.confirmed);
        expect(
          tracking.calls.where((c) => c.startsWith('addModel:')).length,
          addsBeforeConfirm,
          reason: 'a confirmed placement is owned by the scene, not the '
              'preview, so no second node is created',
        );
        expect(preview.hasPreview, isFalse);
      },
    );
  });

  group('tracking loss', () {
    test('the preview is preserved while tracking is lost', () async {
      await place(vector.Vector3(0, 0, -1));

      placement.setTracking(false);
      await preview.sync(placement);

      expect(placement.hasPlacement, isTrue);
      expect(placement.isRecoveringTracking, isTrue);
      expect(placement.canAdjust, isFalse,
          reason:
              'moving an anchor the session cannot localize is meaningless');
      expect(placement.canConfirm, isFalse);
      expect(tracking.nodes, hasLength(1),
          reason: 'the node stays; only the operations are disabled');
    });

    test('adjustment resumes when tracking returns', () async {
      await place(vector.Vector3(0, 0, -1));
      placement.setTracking(false);
      await preview.sync(placement);

      placement.setTracking(true);
      await preview.sync(placement);

      expect(placement.canAdjust, isTrue);
      expect(placement.canConfirm, isTrue);

      placement.scaleBy(1.5);
      await preview.sync(placement);
      expect(tracking.nodes.values.single.scale, closeTo(1.5, 1e-9));
    });
  });

  group('failures are reported, not thrown at the user', () {
    test('an unresolvable model surfaces through the error hook', () async {
      preview.dispose();
      preview = ArPlacementPreview(
        tracking: tracking,
        resolveModel: (_) async => throw StateError('no content route'),
        onError: errors.add,
      );

      await place(vector.Vector3(0, 0, -1));

      expect(errors, hasLength(1));
      expect(tracking.nodes, isEmpty);
      expect(preview.hasPreview, isFalse);
    });
  });

  test('a missing native node is rebuilt from anchor and local transform',
      () async {
    await place(vector.Vector3(1, 0, -2));
    placement.scaleBy(1.5);
    placement.rotateBy(math.pi / 4);
    await preview.sync(placement);
    tracking.nodes.clear();

    await preview.sync(placement);

    final rebuilt = tracking.nodes.values.single;
    expect(rebuilt.position, vector.Vector3(1, 0, -2));
    expect(rebuilt.scale, 1.5);
    expect(rebuilt.yawRadians, closeTo(math.pi / 4, 1e-9));
  });
}
