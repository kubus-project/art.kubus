import 'dart:async';

import 'package:flutter/foundation.dart';

import 'kubus_cover_perf_probe.dart';

/// Keeps close-level cover work from competing with the camera for frames.
///
/// Rendering a cover marker icon rasterises it on the CanvasKit surface and
/// reads the pixels back (a GPU stall on web), and every finished cover asks the
/// marker source to be rebuilt. Done per cover and while the camera moves, that
/// is a burst of long main-thread tasks in the middle of a pan or zoom (measured
/// in the Wave 5B web A/B/C experiment, see
/// `docs/map-system.md`). The gate has two jobs:
///
/// * [runSerial] runs cover jobs one at a time with a short breather between
///   them, so readbacks never occupy consecutive frames, and skips a job whose
///   `shouldRun` precondition (still wanted, same style epoch) no longer
///   holds. While [isPaced] reports the camera moving, the breather widens to
///   [motionSpacing]: covers keep arriving during a pan or zoom, a few per
///   second, instead of all waiting for the camera to stop;
/// * [scheduleResync] collapses the resync requests of a batch of finished
///   covers into one rebuild at [resyncDelay] after the first request, or at
///   [resyncMaxWait] after the first request for a longer window. Requests in
///   that window update the callback to the most recent host resync.
///
/// It holds no map state: callers decide what a job does and what a skipped job
/// means (a skipped cover is simply re-planned at the next sync or idle).
class KubusCoverWorkGate {
  KubusCoverWorkGate({
    this.spacing = const Duration(milliseconds: 24),
    this.motionSpacing = const Duration(milliseconds: 64),
    this.isPaced,
    this.resyncDelay = const Duration(milliseconds: 140),
    this.resyncMaxWait = const Duration(milliseconds: 450),
  });

  /// Pause after each job, so the next one starts on a later frame.
  final Duration spacing;

  /// Pause after each job while [isPaced] is true (the camera is moving).
  ///
  /// A cover job measured 4 ms median, 10 ms p95 (raster plus readback) and
  /// 1.4 ms to register in the Slice C web probe. With the canonical source
  /// plan cached and invisible source payload removed, a 64 ms breather keeps
  /// jobs on separate frames without a multi-second cover staircase on zoom.
  final Duration motionSpacing;

  /// Whether jobs currently run at [motionSpacing]; null means never.
  final bool Function()? isPaced;

  /// Window from the first resync request that coalesces a cover batch.
  final Duration resyncDelay;

  /// Longest a pending resync may be postponed by further requests.
  final Duration resyncMaxWait;

  Future<void> _tail = Future<void>.value();
  Timer? _resyncTimer;
  Timer? _resyncDeadline;
  Stopwatch? _resyncPending;
  VoidCallback? _pendingResync;
  bool _disposed = false;

  /// Runs [job] after every earlier job. Returns null when the gate was
  /// disposed or [shouldRun] was false at the moment the job's turn came.
  Future<T?> runSerial<T>(
    Future<T> Function() job, {
    bool Function()? shouldRun,
  }) {
    final result = Completer<T?>();
    _tail = _tail.then((_) async {
      if (_disposed || (shouldRun != null && !shouldRun())) {
        result.complete(null);
        return;
      }
      try {
        result.complete(await job());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
      if (!_disposed) {
        await Future<void>.delayed(
          isPaced?.call() == true ? motionSpacing : spacing,
        );
      }
    });
    return result.future;
  }

  /// Calls the most recently supplied [resync] callback once, [resyncDelay]
  /// after the first request, or at [resyncMaxWait] after the first pending
  /// request. Later covers join the pending rebuild instead of postponing it.
  void scheduleResync(VoidCallback resync) {
    if (_disposed) return;
    void fire() {
      _resyncTimer?.cancel();
      _resyncTimer = null;
      _resyncDeadline?.cancel();
      _resyncDeadline = null;
      final waited = _resyncPending?.elapsed ?? Duration.zero;
      _resyncPending = null;
      if (_disposed) return;
      recordKubusCoverPhase(KubusCoverPhase.resyncDelay, waited);
      final callback = _pendingResync;
      _pendingResync = null;
      callback?.call();
    }

    _pendingResync = resync;
    if (_resyncPending != null) return;
    _resyncPending ??= Stopwatch()..start();
    _resyncDeadline ??= Timer(resyncMaxWait, fire);
    _resyncTimer = Timer(resyncDelay, fire);
  }

  bool get hasPendingResync => _resyncTimer != null;

  void dispose() {
    _disposed = true;
    _resyncTimer?.cancel();
    _resyncTimer = null;
    _resyncDeadline?.cancel();
    _resyncDeadline = null;
    _resyncPending = null;
    _pendingResync = null;
  }
}
