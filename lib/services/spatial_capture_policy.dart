import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

/// Camera pose of a single AR frame, in AR world space.
///
/// Built from the `poseTranslation` / `poseRotation` fields the native ARCore
/// capture already returns, so pose-aware sampling needs no new platform work.
@immutable
class SpatialPose {
  const SpatialPose({required this.translation, required this.rotation});

  /// Metres, AR world space.
  final Vector3 translation;

  /// Camera orientation.
  final Quaternion rotation;

  /// Reads a pose from a native capture payload.
  ///
  /// Returns `null` when either component is missing or malformed rather than
  /// throwing: a frame without a usable pose is skipped, not fatal.
  static SpatialPose? tryFromFramePayload(Map<String, dynamic> frame) {
    final t = _doubles(frame['poseTranslation'], 3);
    final r = _doubles(frame['poseRotation'], 4);
    if (t == null || r == null) return null;
    // ARCore serializes the rotation quaternion as [x, y, z, w].
    final quaternion = Quaternion(r[0], r[1], r[2], r[3]);
    if (quaternion.length2 == 0 || quaternion.length2.isNaN) return null;
    return SpatialPose(
      translation: Vector3(t[0], t[1], t[2]),
      rotation: quaternion.normalized(),
    );
  }

  static List<double>? _doubles(Object? raw, int expected) {
    if (raw is! List || raw.length < expected) return null;
    final out = <double>[];
    for (var i = 0; i < expected; i++) {
      final value = raw[i];
      if (value is! num || !value.toDouble().isFinite) return null;
      out.add(value.toDouble());
    }
    return out;
  }

  /// Straight-line distance to [other], in metres.
  double distanceTo(SpatialPose other) =>
      (translation - other.translation).length;

  /// Smallest rotation angle between the two orientations, in radians.
  double angleTo(SpatialPose other) {
    final dot = (rotation.x * other.rotation.x +
            rotation.y * other.rotation.y +
            rotation.z * other.rotation.z +
            rotation.w * other.rotation.w)
        .abs()
        .clamp(0.0, 1.0);
    return 2 * math.acos(dot);
  }

  /// Unit vector the camera is looking along (ARCore cameras face -Z).
  Vector3 get forward => rotation.rotated(Vector3(0, 0, -1))..normalize();
}

/// Why a candidate frame was accepted or skipped.
enum SpatialSampleOutcome {
  accepted,
  captureInactive,
  notTracking,
  requestInFlight,
  tooSoon,
  viewTooSimilar,
  writerSaturated,
  sampleLimitReached,
  byteLimitReached,
  durationLimitReached;

  /// Whether this outcome means the session should stop sampling entirely
  /// rather than wait for the next opportunity.
  bool get isLimit =>
      this == sampleLimitReached ||
      this == byteLimitReached ||
      this == durationLimitReached;
}

/// Limits and thresholds governing a spatial capture session.
///
/// Centralized so no numeric constant is scattered through the AR screen, and
/// so an unattended capture can never grow without bound.
@immutable
class SpatialCapturePolicy {
  const SpatialCapturePolicy({
    this.minSampleInterval = const Duration(milliseconds: 650),
    this.minTranslationMeters = 0.05,
    this.minRotationRadians = 0.087, // ~5 degrees
    this.maxAcceptedSamples = 240,
    this.maxCaptureBytes = 192 * 1024 * 1024,
    this.maxCaptureDuration = const Duration(minutes: 6),
    this.maxPendingWrites = 3,
    this.minSamplesForFinish = 24,
    this.minViewpointsForFinish = 8,
  });

  /// Floor on sampling cadence. One input to the decision, not the whole
  /// policy: a stationary phone still produces nothing useful at any cadence.
  final Duration minSampleInterval;

  /// A candidate must differ from the last accepted view by at least this
  /// translation, or [minRotationRadians] of rotation.
  final double minTranslationMeters;
  final double minRotationRadians;

  /// Hard ceilings. Reaching any of these stops sampling and preserves the
  /// capture so the user can still finish.
  final int maxAcceptedSamples;
  final int maxCaptureBytes;
  final Duration maxCaptureDuration;

  /// Backpressure: how many writes may be in flight before samples are
  /// skipped. Dropping a frame is always preferable to unbounded queueing.
  final int maxPendingWrites;

  /// Finish readiness thresholds.
  final int minSamplesForFinish;
  final int minViewpointsForFinish;
}

/// Live counters a sampling decision is made against.
@immutable
class SpatialCaptureProgress {
  const SpatialCaptureProgress({
    required this.acceptedSamples,
    required this.captureBytes,
    required this.elapsed,
    required this.pendingWrites,
    this.sinceLastAccepted,
    this.lastAcceptedPose,
  });

  final int acceptedSamples;
  final int captureBytes;
  final Duration elapsed;
  final int pendingWrites;

  /// `null` before the first accepted sample.
  final Duration? sinceLastAccepted;
  final SpatialPose? lastAcceptedPose;
}

/// Decides whether a candidate AR frame is worth capturing.
///
/// Pure and synchronous so the whole sampling policy is unit-testable without
/// an AR session, a camera, or a disk.
class SpatialSamplingGate {
  const SpatialSamplingGate({this.policy = const SpatialCapturePolicy()});

  final SpatialCapturePolicy policy;

  SpatialSampleOutcome evaluate({
    required bool isCapturing,
    required bool isTracking,
    required bool hasRequestInFlight,
    required SpatialCaptureProgress progress,
    SpatialPose? candidatePose,
  }) {
    if (!isCapturing) return SpatialSampleOutcome.captureInactive;

    // Limits win over everything else so a session at its ceiling reports the
    // real reason instead of "tracking lost" or "too soon".
    if (progress.acceptedSamples >= policy.maxAcceptedSamples) {
      return SpatialSampleOutcome.sampleLimitReached;
    }
    if (progress.captureBytes >= policy.maxCaptureBytes) {
      return SpatialSampleOutcome.byteLimitReached;
    }
    if (progress.elapsed >= policy.maxCaptureDuration) {
      return SpatialSampleOutcome.durationLimitReached;
    }

    if (!isTracking) return SpatialSampleOutcome.notTracking;
    if (hasRequestInFlight) return SpatialSampleOutcome.requestInFlight;
    if (progress.pendingWrites >= policy.maxPendingWrites) {
      return SpatialSampleOutcome.writerSaturated;
    }

    final since = progress.sinceLastAccepted;
    if (since != null && since < policy.minSampleInterval) {
      return SpatialSampleOutcome.tooSoon;
    }

    final last = progress.lastAcceptedPose;
    final candidate = candidatePose;
    if (last != null && candidate != null) {
      final movedFar =
          candidate.distanceTo(last) >= policy.minTranslationMeters;
      final turnedFar = candidate.angleTo(last) >= policy.minRotationRadians;
      if (!movedFar && !turnedFar) {
        return SpatialSampleOutcome.viewTooSimilar;
      }
    }

    return SpatialSampleOutcome.accepted;
  }
}

/// How complete a capture looks.
enum SpatialCoverageGrade { low, fair, good, ready }

/// Viewpoint-diversity accumulator.
///
/// Replaces `frameCount / 40`, under which forty identical frames read as full
/// coverage. Diversity is measured by binning the camera's viewing direction,
/// so repeated views of the same angle stop contributing.
class SpatialCoverageAccumulator {
  SpatialCoverageAccumulator({this.policy = const SpatialCapturePolicy()});

  final SpatialCapturePolicy policy;

  static const int _yawBuckets = 12; // 30 degrees each
  static const double _pitchBandRadians = 0.349; // ~20 degrees

  final Set<int> _viewpoints = <int>{};
  Vector3? _min;
  Vector3? _max;
  int _accepted = 0;

  /// Distinct viewing directions observed.
  int get viewpointCount => _viewpoints.length;

  int get acceptedSamples => _accepted;

  /// Largest camera displacement observed, in metres. A capture taken from a
  /// single spot has no baseline and cannot reconstruct depth.
  double get baselineMeters {
    final min = _min;
    final max = _max;
    if (min == null || max == null) return 0;
    return (max - min).length;
  }

  void addAccepted(SpatialPose pose) {
    _accepted++;
    _viewpoints.add(_bucketFor(pose));
    final t = pose.translation;
    final min = _min;
    final max = _max;
    _min = min == null
        ? t.clone()
        : Vector3(
            math.min(min.x, t.x),
            math.min(min.y, t.y),
            math.min(min.z, t.z),
          );
    _max = max == null
        ? t.clone()
        : Vector3(
            math.max(max.x, t.x),
            math.max(max.y, t.y),
            math.max(max.z, t.z),
          );
  }

  void reset() {
    _viewpoints.clear();
    _min = null;
    _max = null;
    _accepted = 0;
  }

  int _bucketFor(SpatialPose pose) {
    final f = pose.forward;
    final yaw = math.atan2(f.x, f.z); // -pi..pi
    final yawIndex =
        (((yaw + math.pi) / (2 * math.pi)) * _yawBuckets).floor() % _yawBuckets;
    final pitch = math.asin(f.y.clamp(-1.0, 1.0));
    final pitchIndex = pitch > _pitchBandRadians
        ? 2
        : pitch < -_pitchBandRadians
            ? 0
            : 1;
    return pitchIndex * _yawBuckets + yawIndex;
  }

  SpatialCoverageGrade get grade {
    if (isReadyToFinish) return SpatialCoverageGrade.ready;
    if (_accepted >= policy.minSamplesForFinish ~/ 2 &&
        viewpointCount >= policy.minViewpointsForFinish ~/ 2) {
      return SpatialCoverageGrade.good;
    }
    if (_accepted >= 4 && viewpointCount >= 2) return SpatialCoverageGrade.fair;
    return SpatialCoverageGrade.low;
  }

  /// Finish readiness needs both volume and diversity, so a long stationary
  /// capture never qualifies on sample count alone.
  bool get isReadyToFinish =>
      _accepted >= policy.minSamplesForFinish &&
      viewpointCount >= policy.minViewpointsForFinish;

  /// Fraction of the readiness bar reached, limited by whichever of volume or
  /// diversity is furthest behind.
  double get progress {
    final byCount = _accepted / policy.minSamplesForFinish;
    final byViews = viewpointCount / policy.minViewpointsForFinish;
    return math.min(byCount, byViews).clamp(0.0, 1.0);
  }
}
