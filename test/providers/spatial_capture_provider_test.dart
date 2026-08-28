import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:art_kubus/models/spatial_capture_target.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List rgb([int length = 3]) =>
    Uint8List.fromList(List<int>.filled(length, 1));

/// A frame from a distinct viewpoint, so pose filtering accepts it.
Map<String, dynamic> frameAt(
  int index, {
  bool withDepth = false,
  int rgbBytes = 3,
}) {
  final angle = (index / 12) * 2 * math.pi;
  return <String, dynamic>{
    'rgb': rgb(rgbBytes),
    'timestampNanos': index,
    'poseTranslation': [math.cos(angle), 0.0, math.sin(angle)],
    'poseRotation': [0.0, math.sin(angle / 2), 0.0, math.cos(angle / 2)],
    'intrinsics': {'width': 640, 'height': 480, 'fx': 100, 'fy': 100},
    'depthAvailable': withDepth,
    if (withDepth) 'depth': Uint8List.fromList([0, 1]),
  };
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_provider_test_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// No cadence floor: these tests drive sampling directly, so real time is
  /// not the thing under test.
  SpatialCaptureProvider buildProvider({SpatialCapturePolicy? policy}) {
    return SpatialCaptureProvider(
      storageRoot: root,
      policy: policy ??
          const SpatialCapturePolicy(minSampleInterval: Duration.zero),
    );
  }

  Future<SpatialCaptureProvider> capturing({
    SpatialCapturePolicy? policy,
  }) async {
    final provider = buildProvider(policy: policy);
    await provider.begin(
      target: const SpatialCaptureTarget(artworkId: 'art-1'),
      capturedBy: 'wallet-1',
    );
    return provider;
  }

  group('capture accounting', () {
    test('tracked capture reports coverage and device depth honestly',
        () async {
      final provider = await capturing();

      for (var index = 0; index < 10; index++) {
        await provider.offerFrame(
          frameAt(index, withDepth: index == 9),
          isTracking: true,
        );
      }

      expect(provider.frameCount, 10);
      expect(provider.depthObserved, isTrue);
      expect(provider.estimatedInputBytes, 32);
      // Coverage is viewpoint diversity now, not frameCount / 40.
      expect(provider.coverage, greaterThan(0));
      expect(provider.coverage, lessThan(1));
      expect(provider.viewpointCount, greaterThan(1));
    });

    test('capture rejects samples without an RGB frame', () async {
      final provider = await capturing();

      expect(
        () => provider.offerFrame(
          {'depthAvailable': false},
          isTracking: true,
        ),
        throwsFormatException,
      );
    });

    test('processing choice and review states are distinct', () {
      expect(
        SpatialCaptureState.values,
        containsAll([
          SpatialCaptureState.awaitingProcessingChoice,
          SpatialCaptureState.queued,
          SpatialCaptureState.verifying,
          SpatialCaptureState.reviewReady,
        ]),
      );
    });

    test('starting or resetting a capture invalidates active polling',
        () async {
      final provider = buildProvider();
      final initial = provider.operationGeneration;

      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      expect(provider.operationGeneration, initial + 1);

      await provider.reset();
      expect(provider.operationGeneration, initial + 2);
    });
  });

  group('bounded, disk-backed capture', () {
    test('payload goes to disk, not into the provider', () async {
      final provider = await capturing();

      for (var index = 0; index < 12; index++) {
        await provider.offerFrame(frameAt(index, rgbBytes: 512),
            isTracking: true);
      }

      expect(provider.estimatedInputBytes, 12 * 512);
      // Every accepted sample exists as a file.
      final files = await root
          .list(recursive: true)
          .where((e) => e is File && e.path.endsWith('.jpg'))
          .length;
      expect(files, 12);
    });

    test('a duplicate viewpoint is skipped rather than stored', () async {
      final provider = await capturing();
      final frame = frameAt(0);

      await provider.offerFrame(frame, isTracking: true);
      final second = await provider.offerFrame(frame, isTracking: true);

      expect(second, SpatialSampleOutcome.viewTooSimilar);
      expect(provider.frameCount, 1);
      expect(provider.skippedSamples, 1);
    });

    test('reaching the sample ceiling pauses instead of growing forever',
        () async {
      final provider = await capturing(
        policy: const SpatialCapturePolicy(
          minSampleInterval: Duration.zero,
          maxAcceptedSamples: 5,
        ),
      );

      for (var index = 0; index < 40; index++) {
        await provider.offerFrame(frameAt(index), isTracking: true);
      }

      expect(provider.frameCount, 5);
      expect(provider.state, SpatialCaptureState.paused);
      expect(provider.pauseReason, SpatialCapturePauseReason.limitReached);
      // Structured, not a sentence: the provider reports the case and the AR
      // screen localizes it, so this guidance exists in EN and SL alike.
      expect(provider.guidance, SpatialCaptureGuidance.limitReached);
    });

    test('reaching the byte ceiling pauses and preserves the capture',
        () async {
      final provider = await capturing(
        policy: const SpatialCapturePolicy(
          minSampleInterval: Duration.zero,
          maxCaptureBytes: 1024,
        ),
      );

      for (var index = 0; index < 40; index++) {
        await provider.offerFrame(frameAt(index, rgbBytes: 256),
            isTracking: true);
      }

      expect(provider.state, SpatialCaptureState.paused);
      expect(provider.estimatedInputBytes, lessThanOrEqualTo(1024 + 256));
      expect(provider.frameCount, greaterThan(0),
          reason: 'the capture is preserved, not discarded');
    });
  });

  group('tracking loss', () {
    test('a frame offered while tracking is lost is skipped, not fatal',
        () async {
      final provider = await capturing();

      final outcome = await provider.offerFrame(frameAt(0), isTracking: false);

      expect(outcome, SpatialSampleOutcome.notTracking);
      expect(provider.frameCount, isZero);
      expect(provider.state, SpatialCaptureState.capturing,
          reason: 'tracking loss must not end the capture');
    });
  });

  group('mode transitions', () {
    test('pausing keeps the capture and its files intact', () async {
      final provider = await capturing();
      await provider.offerFrame(frameAt(0), isTracking: true);

      provider.pause(SpatialCapturePauseReason.modeChanged);

      expect(provider.state, SpatialCaptureState.paused);
      expect(provider.frameCount, 1);
      expect(provider.isCapturing, isFalse);
    });

    test('leaving and returning resumes the same capture', () async {
      final provider = await capturing();
      for (var index = 0; index < 3; index++) {
        await provider.offerFrame(frameAt(index), isTracking: true);
      }

      provider.pause(SpatialCapturePauseReason.modeChanged);
      provider.resume();
      await provider.offerFrame(frameAt(5), isTracking: true);

      expect(provider.state, SpatialCaptureState.capturing);
      expect(provider.frameCount, 4, reason: 'earlier samples are retained');
    });

    test('a paused capture never strands the session', () async {
      // The regression: leaving Create cancelled the sampler but left the
      // provider in `capturing`, so returning showed a disabled Finish button
      // with nothing driving the capture and no way to make progress.
      final provider = await capturing();
      await provider.offerFrame(frameAt(0), isTracking: true);

      provider.pause(SpatialCapturePauseReason.modeChanged);

      expect(provider.state, isNot(SpatialCaptureState.capturing));
      expect(provider.isPaused, isTrue);
      // Resuming is always available, so the session can always progress.
      provider.resume();
      expect(provider.state, SpatialCaptureState.capturing);
    });

    test('pause is ignored unless a capture is active', () async {
      final provider = buildProvider();

      provider.pause(SpatialCapturePauseReason.modeChanged);

      expect(provider.state, SpatialCaptureState.idle);
    });
  });

  group('finish readiness', () {
    test('finish is refused until viewpoint diversity is reached', () async {
      final provider = await capturing();
      // Many samples from one viewpoint must not unlock Finish.
      for (var index = 0; index < 30; index++) {
        await provider.offerFrame(
          {...frameAt(0), 'timestampNanos': index},
          isTracking: true,
        );
      }

      expect(provider.canFinish, isFalse);
    });

    test('finish unlocks once volume and diversity are both met', () async {
      final provider = await capturing(
        policy: const SpatialCapturePolicy(
          minSampleInterval: Duration.zero,
          minSamplesForFinish: 6,
          minViewpointsForFinish: 4,
        ),
      );

      for (var index = 0; index < 12; index++) {
        await provider.offerFrame(frameAt(index), isTracking: true);
      }

      expect(provider.canFinish, isTrue);
      expect(provider.coverageGrade, SpatialCoverageGrade.ready);
    });
  });

  group('discard', () {
    test('discarding removes the capture directory and resets state', () async {
      final provider = await capturing();
      await provider.offerFrame(frameAt(0), isTracking: true);

      await provider.discard();

      expect(provider.state, SpatialCaptureState.idle);
      expect(provider.frameCount, isZero);
      expect(provider.coverage, isZero);
    });
  });
}
