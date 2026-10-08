import 'dart:async';

/// Shared throttle/queue coordinator for marker visual sync.
///
/// Both map screens need to avoid spamming `setGeoJsonSource` and other
/// MapLibre calls while still ensuring we eventually sync after rapid zoom/pan
/// gestures. This helper encapsulates the common "throttle + in-flight + queued"
/// behavior.
///
/// A request inside the throttle window is never lost: it runs as soon as the
/// in-flight sync finishes or, when nothing is in flight, when the window
/// closes. Without that trailing run a request arriving just after a quick
/// sync (a level-of-detail change landing right behind a regroup animation
/// frame) waited for some unrelated later request, which on a continuous zoom
/// meant the camera stopping.
///
/// The coordinator intentionally has no access to BuildContext; callers must
/// inject readiness checks and the sync callback.
class MarkerVisualSyncCoordinator {
  MarkerVisualSyncCoordinator({
    required this.throttleMs,
    required bool Function() isReady,
    required Future<void> Function() sync,
    int Function()? nowMs,
  })  : _isReady = isReady,
        _sync = sync,
        _nowMs = nowMs ?? _wallClockMs;

  static int _wallClockMs() => DateTime.now().millisecondsSinceEpoch;

  final int throttleMs;
  final bool Function() _isReady;
  final Future<void> Function() _sync;
  final int Function() _nowMs;

  bool _disposed = false;
  bool _inFlight = false;
  bool _queued = false;
  int? _lastSyncMs;
  Timer? _trailing;

  void request({bool force = false}) {
    if (_disposed) return;
    if (!_isReady()) return;

    final nowMs = _nowMs();
    if (_inFlight) {
      _queued = true;
      return;
    }
    final lastSyncMs = _lastSyncMs;
    final waitMs = lastSyncMs == null ? 0 : throttleMs - (nowMs - lastSyncMs);
    if (!force && waitMs > 0) {
      _queued = true;
      _trailing ??= Timer(Duration(milliseconds: waitMs), () {
        _trailing = null;
        if (_disposed || !_queued || _inFlight) return;
        _queued = false;
        request(force: true);
      });
      return;
    }

    // The sync starting now reads current state, so it also answers any
    // request still waiting for the window to close.
    _trailing?.cancel();
    _trailing = null;
    _queued = false;
    _lastSyncMs = nowMs;
    _inFlight = true;

    unawaited(_runSync());
  }

  Future<void> _runSync() async {
    try {
      if (_disposed) return;
      await _sync();
    } catch (_) {
      // Intentionally swallow errors here; screens already log in their safe
      // sync wrappers.
      // Keep log noise low; the caller's safe wrapper should log details.
    } finally {
      _inFlight = false;
      final shouldRunQueued = !_disposed && _queued;
      if (shouldRunQueued) {
        _queued = false;
        request(force: true);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _queued = false;
    _trailing?.cancel();
    _trailing = null;
  }
}
