import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:art_kubus/models/spatial_capture_target.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:art_kubus/services/spatial_capture_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> frameAt(int index, {int rgbBytes = 8}) {
  final angle = (index / 12) * 2 * math.pi;
  return <String, dynamic>{
    'rgb': Uint8List.fromList(List<int>.filled(rgbBytes, 1)),
    'timestampNanos': index,
    'poseTranslation': [math.cos(angle), 0.0, math.sin(angle)],
    'poseRotation': [0.0, math.sin(angle / 2), 0.0, math.cos(angle / 2)],
  };
}

void main() {
  late Directory root;
  late SpatialCaptureProvider provider;
  late bool tracking;
  late int frameIndex;
  late List<Object> reportedErrors;
  Object? nextError;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_session_test_');
    provider = SpatialCaptureProvider(
      storageRoot: root,
      policy: const SpatialCapturePolicy(minSampleInterval: Duration.zero),
    );
    tracking = true;
    frameIndex = 0;
    reportedErrors = <Object>[];
    nextError = null;
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  SpatialCaptureSession build() {
    return SpatialCaptureSession(
      provider: provider,
      isTracking: () => tracking,
      captureFrame: () async {
        final error = nextError;
        if (error != null) {
          nextError = null;
          throw error;
        }
        return frameAt(frameIndex++);
      },
      onCaptureError: reportedErrors.add,
      // Never schedule real timers in tests.
      timerFactory: (_, __) => Timer(Duration.zero, () {}),
    );
  }

  group('sampling', () {
    test('a tick captures while tracking', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build();

      final outcome = await session.tick();

      expect(outcome, SpatialSampleOutcome.accepted);
      expect(provider.frameCount, 1);
    });

    test('a tick before capture starts does nothing', () async {
      final session = build();

      expect(await session.tick(), SpatialSampleOutcome.captureInactive);
      expect(provider.frameCount, isZero);
    });

    test('tracking loss skips without ending the capture', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build();
      tracking = false;

      final outcome = await session.tick();

      expect(outcome, SpatialSampleOutcome.notTracking);
      expect(provider.state, SpatialCaptureState.capturing);
      expect(provider.frameCount, isZero);
    });

    test('sampling resumes on its own when tracking returns', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build();
      tracking = false;
      await session.tick();

      tracking = true;
      final outcome = await session.tick();

      expect(outcome, SpatialSampleOutcome.accepted);
      expect(provider.frameCount, 1);
    });

    test('a duplicate viewpoint never reaches the platform', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      var captureCalls = 0;
      final session = SpatialCaptureSession(
        provider: provider,
        isTracking: () => true,
        captureFrame: () async {
          captureCalls++;
          return frameAt(0);
        },
        timerFactory: (_, __) => Timer(Duration.zero, () {}),
      );

      await session.tick();
      await session.tick();

      expect(provider.frameCount, 1);
      expect(captureCalls, 2,
          reason: 'the pose is only known after the frame is captured');
      expect(provider.lastSampleOutcome, SpatialSampleOutcome.viewTooSimilar);
    });
  });

  group('transient platform errors', () {
    test('a temporarily unavailable frame is skipped silently', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build();
      nextError = PlatformException(code: 'frame_not_yet_available');

      final outcome = await session.tick();

      expect(outcome, SpatialSampleOutcome.requestInFlight);
      expect(reportedErrors, isEmpty,
          reason: 'a routine frame miss must never surface to the user');
      expect(provider.state, SpatialCaptureState.capturing);
    });

    test('a cancelled capture during teardown is not an error', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build();
      nextError = PlatformException(code: 'capture_cancelled');

      await session.tick();

      expect(reportedErrors, isEmpty);
    });

    test('an unexpected failure is reported once', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build();
      nextError = StateError('camera exploded');

      await session.tick();

      expect(reportedErrors, hasLength(1));
    });

    test('an in-flight marker is always cleared, even on failure', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build();
      nextError = StateError('boom');

      await session.tick();
      tracking = true;

      // A stuck in-flight flag would block every later sample.
      expect(await session.tick(), SpatialSampleOutcome.accepted);
    });
  });

  group('limits stop the sampler', () {
    test('reaching the sample ceiling stops sampling and pauses', () async {
      // Limits live on the provider, which is the single source of truth for
      // both cadence and ceilings.
      provider = SpatialCaptureProvider(
        storageRoot: root,
        policy: const SpatialCapturePolicy(
          minSampleInterval: Duration.zero,
          maxAcceptedSamples: 3,
        ),
      );
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build();
      session.start();

      for (var i = 0; i < 20; i++) {
        await session.tick();
      }

      expect(provider.frameCount, 3);
      expect(provider.state, SpatialCaptureState.paused);
      expect(session.isSampling, isFalse,
          reason: 'the sampler must stop once the capture is bounded out');
    });
  });

  group('pause and resume', () {
    test('pause suspends the provider and the sampler together', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build()..start();

      session.pause(SpatialCapturePauseReason.modeChanged);

      expect(session.isSampling, isFalse);
      expect(provider.state, SpatialCaptureState.paused);
    });

    test('resume restarts both', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build()..start();
      session.pause(SpatialCapturePauseReason.modeChanged);

      session.resume();

      expect(session.isSampling, isTrue);
      expect(provider.state, SpatialCaptureState.capturing);
      expect(await session.tick(), SpatialSampleOutcome.accepted);
    });

    test('a tick after pause stops the sampler rather than capturing',
        () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build()..start();
      provider.pause(SpatialCapturePauseReason.user);

      final outcome = await session.tick();

      expect(outcome, SpatialSampleOutcome.captureInactive);
      expect(session.isSampling, isFalse);
      expect(provider.frameCount, isZero);
    });
  });

  group('lifecycle', () {
    test('start is idempotent', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build()
        ..start()
        ..start();

      expect(session.isSampling, isTrue);
      session.stop();
      expect(session.isSampling, isFalse);
    });

    test('a disposed session never captures again', () async {
      await provider.begin(
          target: const SpatialCaptureTarget(artworkId: 'art-1'));
      final session = build()..start();

      session.dispose();

      expect(session.isSampling, isFalse);
      expect(await session.tick(), SpatialSampleOutcome.captureInactive);
      expect(provider.frameCount, isZero);
    });
  });
}
