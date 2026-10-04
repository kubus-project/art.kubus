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
/// `docs/design/PRODUCT_V5_SPATIAL_SYSTEM.md`). The gate has two jobs:
///
/// * [runSerial] runs cover jobs one at a time with a short breather between
///   them, so readbacks never occupy consecutive frames, and skips a job whose
///   `shouldRun` precondition (camera idle, same style epoch) no longer holds;
/// * [scheduleResync] collapses the resync requests of a batch of finished
///   covers into one rebuild: trailing [resyncDelay] after the last request,
///   but never later than [resyncMaxWait] after the first, so a long batch
///   shows its first covers early instead of only after the last one.
///
/// It holds no map state: callers decide what a job does and what a skipped job
/// means (a skipped cover is simply re-planned the next time the camera idles).
class KubusCoverWorkGate {
  KubusCoverWorkGate({
    this.spacing = const Duration(milliseconds: 24),
    this.resyncDelay = const Duration(milliseconds: 140),
    this.resyncMaxWait = const Duration(milliseconds: 450),
  });

  /// Pause after each job, so the next one starts on a later frame.
  final Duration spacing;

  /// Trailing delay that coalesces resync requests.
  final Duration resyncDelay;

  /// Longest a pending resync may be postponed by further requests.
  final Duration resyncMaxWait;

  Future<void> _tail = Future<void>.value();
  Timer? _resyncTimer;
  Timer? _resyncDeadline;
  Stopwatch? _resyncPending;
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
      if (!_disposed) await Future<void>.delayed(spacing);
    });
    return result.future;
  }

  /// Calls [resync] once, [resyncDelay] after the last request, or at the
  /// latest [resyncMaxWait] after the first pending one.
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
      resync();
    }

    _resyncPending ??= Stopwatch()..start();
    _resyncDeadline ??= Timer(resyncMaxWait, fire);
    _resyncTimer?.cancel();
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
  }
}
