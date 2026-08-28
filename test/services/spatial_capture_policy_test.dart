import 'dart:math' as math;

import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

SpatialPose poseAt({
  double x = 0,
  double y = 0,
  double z = 0,
  double yawRadians = 0,
}) {
  return SpatialPose(
    translation: Vector3(x, y, z),
    rotation: Quaternion.axisAngle(Vector3(0, 1, 0), yawRadians),
  );
}

SpatialCaptureProgress progress({
  int acceptedSamples = 0,
  int captureBytes = 0,
  Duration elapsed = Duration.zero,
  int pendingWrites = 0,
  Duration? sinceLastAccepted,
  SpatialPose? lastAcceptedPose,
}) {
  return SpatialCaptureProgress(
    acceptedSamples: acceptedSamples,
    captureBytes: captureBytes,
    elapsed: elapsed,
    pendingWrites: pendingWrites,
    sinceLastAccepted: sinceLastAccepted,
    lastAcceptedPose: lastAcceptedPose,
  );
}

void main() {
  const policy = SpatialCapturePolicy();
  const gate = SpatialSamplingGate(policy: policy);

  SpatialSampleOutcome evaluate({
    bool isCapturing = true,
    bool isTracking = true,
    bool hasRequestInFlight = false,
    SpatialCaptureProgress? state,
    SpatialPose? candidatePose,
  }) {
    return gate.evaluate(
      isCapturing: isCapturing,
      isTracking: isTracking,
      hasRequestInFlight: hasRequestInFlight,
      progress: state ?? progress(),
      candidatePose: candidatePose,
    );
  }

  group('pose parsing', () {
    test('reads translation and rotation from a native frame payload', () {
      final pose = SpatialPose.tryFromFramePayload({
        'poseTranslation': [1.0, 2.0, 3.0],
        'poseRotation': [0.0, 0.0, 0.0, 1.0],
      });

      expect(pose, isNotNull);
      expect(pose!.translation.x, closeTo(1.0, 1e-9));
      expect(pose.translation.z, closeTo(3.0, 1e-9));
    });

    test('a malformed or missing pose yields null rather than throwing', () {
      expect(SpatialPose.tryFromFramePayload(const {}), isNull);
      expect(
        SpatialPose.tryFromFramePayload(const {
          'poseTranslation': [1.0, 2.0],
          'poseRotation': [0.0, 0.0, 0.0, 1.0],
        }),
        isNull,
      );
      expect(
        SpatialPose.tryFromFramePayload(const {
          'poseTranslation': [1.0, 2.0, 3.0],
          'poseRotation': [0.0, 0.0, 0.0, 0.0],
        }),
        isNull,
        reason: 'a zero quaternion is not a rotation',
      );
    });

    test('angleTo measures the shortest rotation between orientations', () {
      final a = poseAt();
      final b = poseAt(yawRadians: math.pi / 2);

      expect(a.angleTo(b), closeTo(math.pi / 2, 1e-6));
      expect(a.angleTo(a), closeTo(0, 1e-9));
    });
  });

  group('sampling gate', () {
    test('accepts the first sample of an active tracking session', () {
      expect(evaluate(candidatePose: poseAt()), SpatialSampleOutcome.accepted);
    });

    test('rejects everything while capture is inactive', () {
      expect(
        evaluate(isCapturing: false),
        SpatialSampleOutcome.captureInactive,
      );
    });

    test('skips while tracking is lost instead of failing', () {
      expect(evaluate(isTracking: false), SpatialSampleOutcome.notTracking);
    });

    test('skips while a capture request is already in flight', () {
      expect(
        evaluate(hasRequestInFlight: true),
        SpatialSampleOutcome.requestInFlight,
      );
    });

    test('skips when the writer is saturated rather than queueing', () {
      expect(
        evaluate(state: progress(pendingWrites: policy.maxPendingWrites)),
        SpatialSampleOutcome.writerSaturated,
      );
    });

    test('enforces the cadence floor', () {
      expect(
        evaluate(
          state: progress(
            sinceLastAccepted: const Duration(milliseconds: 100),
            lastAcceptedPose: poseAt(),
          ),
          candidatePose: poseAt(x: 5),
        ),
        SpatialSampleOutcome.tooSoon,
      );
    });
  });

  group('duplicate view rejection', () {
    test('a near-identical view is rejected even after the cadence elapses',
        () {
      expect(
        evaluate(
          state: progress(
            sinceLastAccepted: const Duration(seconds: 5),
            lastAcceptedPose: poseAt(),
          ),
          candidatePose: poseAt(x: 0.001),
        ),
        SpatialSampleOutcome.viewTooSimilar,
      );
    });

    test('a meaningful translation is accepted', () {
      expect(
        evaluate(
          state: progress(
            sinceLastAccepted: const Duration(seconds: 5),
            lastAcceptedPose: poseAt(),
          ),
          candidatePose: poseAt(x: policy.minTranslationMeters + 0.01),
        ),
        SpatialSampleOutcome.accepted,
      );
    });

    test('a meaningful rotation from the same spot is accepted', () {
      expect(
        evaluate(
          state: progress(
            sinceLastAccepted: const Duration(seconds: 5),
            lastAcceptedPose: poseAt(),
          ),
          candidatePose: poseAt(yawRadians: 0.5),
        ),
        SpatialSampleOutcome.accepted,
      );
    });
  });

  group('capture limits', () {
    test('stops at the accepted-sample ceiling', () {
      final outcome = evaluate(
        state: progress(acceptedSamples: policy.maxAcceptedSamples),
      );
      expect(outcome, SpatialSampleOutcome.sampleLimitReached);
      expect(outcome.isLimit, isTrue);
    });

    test('stops at the byte ceiling', () {
      final outcome =
          evaluate(state: progress(captureBytes: policy.maxCaptureBytes));
      expect(outcome, SpatialSampleOutcome.byteLimitReached);
      expect(outcome.isLimit, isTrue);
    });

    test('stops at the duration ceiling', () {
      final outcome =
          evaluate(state: progress(elapsed: policy.maxCaptureDuration));
      expect(outcome, SpatialSampleOutcome.durationLimitReached);
      expect(outcome.isLimit, isTrue);
    });

    test('a limit is reported even while tracking is lost', () {
      expect(
        evaluate(
          isTracking: false,
          state: progress(acceptedSamples: policy.maxAcceptedSamples),
        ),
        SpatialSampleOutcome.sampleLimitReached,
        reason: 'the session must stop, not wait for tracking to return',
      );
    });

    test('an unattended session cannot sample forever', () {
      var accepted = 0;
      var elapsed = Duration.zero;
      // Simulate a phone left running and moving enough to defeat pose
      // filtering; the ceilings must still terminate sampling.
      for (var tick = 0; tick < 5000; tick++) {
        elapsed += policy.minSampleInterval;
        final outcome = gate.evaluate(
          isCapturing: true,
          isTracking: true,
          hasRequestInFlight: false,
          progress: progress(
            acceptedSamples: accepted,
            elapsed: elapsed,
            sinceLastAccepted: policy.minSampleInterval,
            lastAcceptedPose: poseAt(x: tick.toDouble()),
          ),
          candidatePose: poseAt(x: tick + 1.0),
        );
        if (outcome.isLimit) break;
        if (outcome == SpatialSampleOutcome.accepted) accepted++;
      }

      expect(accepted, lessThanOrEqualTo(policy.maxAcceptedSamples));
      expect(elapsed, lessThanOrEqualTo(policy.maxCaptureDuration));
    });
  });

  group('coverage', () {
    test('forty identical frames are not full coverage', () {
      final coverage = SpatialCoverageAccumulator(policy: policy);
      for (var i = 0; i < 40; i++) {
        coverage.addAccepted(poseAt());
      }

      // The regression: coverage used to be frameCount / 40, so this read 100%.
      expect(coverage.viewpointCount, 1);
      expect(coverage.isReadyToFinish, isFalse);
      expect(coverage.progress, lessThan(1.0));
      expect(coverage.grade, isNot(SpatialCoverageGrade.ready));
    });

    test('orbiting the subject accumulates distinct viewpoints', () {
      final coverage = SpatialCoverageAccumulator(policy: policy);
      for (var i = 0; i < 24; i++) {
        final angle = (i / 24) * 2 * math.pi;
        coverage.addAccepted(poseAt(
          x: math.cos(angle),
          z: math.sin(angle),
          yawRadians: angle,
        ));
      }

      expect(coverage.viewpointCount,
          greaterThanOrEqualTo(policy.minViewpointsForFinish));
      expect(coverage.isReadyToFinish, isTrue);
      expect(coverage.grade, SpatialCoverageGrade.ready);
      expect(coverage.progress, 1.0);
    });

    test('a stationary capture reports no baseline', () {
      final coverage = SpatialCoverageAccumulator(policy: policy);
      for (var i = 0; i < 10; i++) {
        coverage.addAccepted(poseAt(yawRadians: i.toDouble()));
      }

      expect(coverage.baselineMeters, closeTo(0, 1e-9));
    });

    test('a moving capture reports a baseline', () {
      final coverage = SpatialCoverageAccumulator(policy: policy)
        ..addAccepted(poseAt())
        ..addAccepted(poseAt(x: 2));

      expect(coverage.baselineMeters, closeTo(2, 1e-9));
    });

    test('reset clears accumulated coverage', () {
      final coverage = SpatialCoverageAccumulator(policy: policy)
        ..addAccepted(poseAt(x: 1))
        ..reset();

      expect(coverage.viewpointCount, 0);
      expect(coverage.acceptedSamples, 0);
      expect(coverage.baselineMeters, 0);
      expect(coverage.grade, SpatialCoverageGrade.low);
    });
  });
}
