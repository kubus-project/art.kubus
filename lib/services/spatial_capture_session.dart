import 'dart:async';

import '../providers/spatial_capture_provider.dart';
import 'spatial_capture_policy.dart';

/// Drives automatic spatial sampling.
///
/// The sampling engine used to be a `Timer.periodic` owned by the AR screen's
/// `State`, which tied capture progress to widget lifecycle and made it
/// untestable without a camera. The session owns the cadence; the screen only
/// renders state and issues commands.
class SpatialCaptureSession {
  SpatialCaptureSession({
    required SpatialCaptureProvider provider,
    required Future<Map<String, dynamic>> Function() captureFrame,
    required bool Function() isTracking,
    void Function(Object error)? onCaptureError,
    Timer Function(Duration, void Function(Timer))? timerFactory,
  })  : _provider = provider,
        _captureFrame = captureFrame,
        _isTracking = isTracking,
        _onCaptureError = onCaptureError,
        _timerFactory = timerFactory ?? Timer.periodic;

  final SpatialCaptureProvider _provider;
  final Future<Map<String, dynamic>> Function() _captureFrame;
  final bool Function() _isTracking;
  final void Function(Object error)? _onCaptureError;
  final Timer Function(Duration, void Function(Timer)) _timerFactory;

  Timer? _timer;
  bool _disposed = false;

  /// Whether the sampler is ticking.
  bool get isSampling => _timer != null;

  /// Errors ARCore raises routinely while tracking. A later tick retries, so
  /// they must never reach the user or fail the session.
  static const _transientCodes = <String>[
    'frame_not_yet_available',
    'tracking_unavailable',
    'capture_cancelled',
  ];

  /// Starts sampling. Idempotent.
  void start() {
    if (_disposed || _timer != null) return;
    // Cadence comes from the provider's policy, which also owns the limits, so
    // the two can never disagree.
    _timer = _timerFactory(
      _provider.policy.minSampleInterval,
      (_) => unawaited(tick()),
    );
  }

  /// Stops sampling without touching capture state.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Suspends the capture and the sampler together, so the provider can never
  /// be left `capturing` with nothing driving it.
  void pause(SpatialCapturePauseReason reason) {
    stop();
    _provider.pause(reason);
  }

  /// Resumes a paused capture and restarts sampling.
  void resume() {
    if (_disposed) return;
    _provider.resume();
    start();
  }

  /// One sampling opportunity.
  ///
  /// Exposed so tests can drive the engine deterministically instead of
  /// waiting on wall-clock timers.
  Future<SpatialSampleOutcome> tick() async {
    if (_disposed) return SpatialSampleOutcome.captureInactive;

    // A capture that is no longer running - finished, paused, or at a limit -
    // stops the sampler rather than spinning.
    if (!_provider.isCapturing) {
      stop();
      return SpatialSampleOutcome.captureInactive;
    }

    final tracking = _isTracking();
    if (!tracking) {
      // Tracking loss pauses sampling but keeps ticking, so capture resumes on
      // its own once tracking returns.
      return _provider.evaluateCandidate(isTracking: false);
    }

    // Cheap pre-check: never ask the platform for a frame the policy would
    // reject anyway.
    final predicted = _provider.evaluateCandidate(isTracking: true);
    if (predicted != SpatialSampleOutcome.accepted) {
      // The pre-check short-circuits before offerFrame, so a ceiling reached
      // here must pause the capture itself, not just stop the timer.
      if (predicted.isLimit) pause(SpatialCapturePauseReason.limitReached);
      return predicted;
    }

    _provider.markRequestInFlight();
    try {
      final frame = await _captureFrame();
      if (_disposed) return SpatialSampleOutcome.captureInactive;
      final outcome = await _provider.offerFrame(frame, isTracking: true);
      if (outcome.isLimit) stop();
      return outcome;
    } catch (error) {
      if (_isTransient(error)) {
        return SpatialSampleOutcome.requestInFlight;
      }
      _onCaptureError?.call(error);
      return SpatialSampleOutcome.captureInactive;
    } finally {
      _provider.clearRequestInFlight();
    }
  }

  bool _isTransient(Object error) {
    final text = error.toString();
    return _transientCodes.any(text.contains);
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
