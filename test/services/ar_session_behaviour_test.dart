import 'dart:async';
import 'dart:io';

import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/ar_placement_controller.dart';
import 'package:art_kubus/services/camera_ownership_coordinator.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:art_kubus/services/spatial_capture_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../support/fake_spatial_tracking_adapter.dart';

/// End-to-end behaviour across the AR session, capture engine and placement
/// workflow, driven through a controllable fake session rather than asserted
/// against source strings.
void main() {
  late Directory root;
  late FakeSpatialTrackingAdapter ar;
  late SpatialCaptureProvider capture;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_behaviour_');
    ar = FakeSpatialTrackingAdapter();
    capture = SpatialCaptureProvider(
      storageRoot: root,
      policy: const SpatialCapturePolicy(minSampleInterval: Duration.zero),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  SpatialCaptureSession buildSession({void Function(Object)? onError}) {
    return SpatialCaptureSession(
      provider: capture,
      isTracking: () => ar.isReady && ar.isTracking.value,
      captureFrame: ar.captureFrame,
      onCaptureError: onError,
      timerFactory: (_, __) => Timer(Duration.zero, () {}),
    );
  }

  group('session acquisition', () {
    test('capture cannot start before tracking', () async {
      await ar.initialize();
      ar.completeInitialization();
      await capture.begin(artworkId: 'art-1');
      final session = buildSession();

      final outcome = await session.tick();

      expect(outcome, SpatialSampleOutcome.notTracking);
      expect(capture.frameCount, isZero);
    });

    test('tracking enables capture', () async {
      await ar.initialize();
      ar.completeInitialization();
      ar.acquireTracking();
      await capture.begin(artworkId: 'art-1');
      final session = buildSession();

      expect(await session.tick(), SpatialSampleOutcome.accepted);
      expect(capture.frameCount, 1);
    });

    test('an unsupported device never reports ready', () async {
      final unsupported = FakeSpatialTrackingAdapter(
        initialState: FakeArSessionState.unsupported,
      );

      expect(await unsupported.initialize(), isFalse);
      expect(unsupported.isReady, isFalse);
    });
  });

  group('tracking loss and recovery', () {
    test('losing tracking mid-capture preserves what was recorded', () async {
      ar
        ..completeInitialization()
        ..acquireTracking();
      await capture.begin(artworkId: 'art-1');
      final session = buildSession();
      await session.tick();
      await session.tick();
      final before = capture.frameCount;

      ar.loseTracking(reason: 'EXCESSIVE_MOTION');
      final outcome = await session.tick();

      expect(outcome, SpatialSampleOutcome.notTracking);
      expect(capture.frameCount, before, reason: 'nothing is lost');
      expect(capture.state, SpatialCaptureState.capturing);
      expect(ar.trackingFailureReason.value, 'EXCESSIVE_MOTION');
    });

    test('capture continues after tracking recovers', () async {
      ar
        ..completeInitialization()
        ..acquireTracking();
      await capture.begin(artworkId: 'art-1');
      final session = buildSession();
      await session.tick();

      ar.loseTracking();
      await session.tick();
      ar.acquireTracking();
      final outcome = await session.tick();

      expect(outcome, SpatialSampleOutcome.accepted);
      expect(capture.frameCount, 2);
      expect(ar.trackingFailureReason.value, isNull);
    });
  });

  group('transient and fatal platform errors', () {
    test('a temporary frame miss is skipped and retried', () async {
      ar
        ..completeInitialization()
        ..acquireTracking()
        ..queueTransientFrameMiss();
      await capture.begin(artworkId: 'art-1');
      final errors = <Object>[];
      final session = buildSession(onError: errors.add);

      final missed = await session.tick();
      final retried = await session.tick();

      expect(missed, SpatialSampleOutcome.requestInFlight);
      expect(retried, SpatialSampleOutcome.accepted);
      expect(errors, isEmpty, reason: 'a routine miss is not an error');
      expect(capture.frameCount, 1);
    });

    test('a fatal native error is reported once and does not end capture',
        () async {
      ar
        ..completeInitialization()
        ..acquireTracking()
        ..queueFatalCaptureError();
      await capture.begin(artworkId: 'art-1');
      final errors = <Object>[];
      final session = buildSession(onError: errors.add);

      await session.tick();

      expect(errors, hasLength(1));
      expect(capture.state, SpatialCaptureState.capturing);
    });
  });

  group('disposal races', () {
    test('a capture in flight when the session disposes does not hang',
        () async {
      ar
        ..completeInitialization()
        ..acquireTracking();
      await capture.begin(artworkId: 'art-1');
      final errors = <Object>[];
      final session = buildSession(onError: errors.add);

      await ar.disposeSession();
      final outcome = await session.tick();

      // capture_cancelled is transient: teardown, not a failure to report.
      expect(outcome, SpatialSampleOutcome.notTracking);
      expect(errors, isEmpty);
    });

    test('a disposed session never reports ready or tracking', () async {
      ar
        ..completeInitialization()
        ..acquireTracking();

      await ar.disposeSession();

      expect(ar.isReady, isFalse);
      expect(ar.isTracking.value, isFalse);
      expect(ar.trackingFailureReason.value, isNull);
    });

    test('late surface callbacks after dispose are ignored', () async {
      var taps = 0;
      ar.onSurfaceTap = (_) => taps++;
      ar.completeInitialization();

      await ar.disposeSession();
      ar.tapSurface([vector.Vector3.zero()]);

      expect(taps, isZero);
    });
  });

  group('placement against a live session', () {
    test('a surface tap places the artwork at the hit pose', () async {
      final placement = ArPlacementController();
      ar.onSurfaceTap = (hits) => placement.applyHitTest(hits.first);
      ar
        ..completeInitialization()
        ..acquireTracking();
      placement.selectArtwork(artworkId: 'art-1', modelPath: 'm.glb');
      placement.setTracking(true);

      ar.onSurfaceDetected = () => placement.setSurfaceAvailable(true);
      ar.detectSurface();
      ar.tapSurface([vector.Vector3(1, 0, -2)]);

      expect(placement.state, ArPlacementState.placed);
      expect(placement.transform!.position.x, 1);
    });

    test('a tap before tracking is ignored', () async {
      final placement = ArPlacementController();
      ar.onSurfaceTap = (hits) => placement.applyHitTest(hits.first);
      placement.selectArtwork(artworkId: 'art-1', modelPath: 'm.glb');

      ar.tapSurface([vector.Vector3(1, 0, -2)]);

      expect(placement.hasPlacement, isFalse);
    });
  });

  group('camera ownership against a live session', () {
    test('switching to the scanner disposes the AR session exactly once',
        () async {
      final coordinator = CameraOwnershipCoordinator(
        releaseAr: ar.disposeSession,
        releaseScanner: () async {},
        startAr: () async {},
        startScanner: () async {},
      );
      await coordinator.requestOwner(CameraOwner.ar);

      await coordinator.requestOwner(CameraOwner.scanner);

      expect(ar.disposeCount, 1);
      expect(ar.isDisposed, isTrue);
    });

    test('Place to Spatial leaves the AR session untouched', () async {
      final coordinator = CameraOwnershipCoordinator(
        releaseAr: ar.disposeSession,
        releaseScanner: () async {},
        startAr: () async {},
        startScanner: () async {},
      );
      await coordinator.requestOwner(CameraOwner.ar);

      await coordinator.requestOwner(CameraOwner.ar);

      expect(ar.disposeCount, isZero);
      expect(ar.isDisposed, isFalse);
    });
  });
}
