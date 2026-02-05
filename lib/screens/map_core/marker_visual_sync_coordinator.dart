import 'dart:async';

/// Shared throttle/queue coordinator for marker visual sync.
///
/// Both map screens need to avoid spamming `setGeoJsonSource` and other
/// MapLibre calls while still ensuring we eventually sync after rapid zoom/pan
/// gestures. This helper encapsulates the common "throttle + in-flight + queued"
/// behavior.
///
/// The coordinator intentionally has no access to BuildContext; callers must
/// inject readiness checks and the sync callback.
class MarkerVisualSyncCoordinator {
  MarkerVisualSyncCoordinator({
    required this.throttleMs,
    required bool Function() isReady,
    required Future<void> Function() sync,
  })  : _isReady = isReady,
        _sync = sync;

  final int throttleMs;
  final bool Function() _isReady;
  final Future<void> Function() _sync;

  bool _disposed = false;
  bool _inFlight = false;
  bool _queued = false;
  int _lastSyncMs = 0;

  void request({bool force = false}) {
    if (_disposed) return;
    if (!_isReady()) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && nowMs - _lastSyncMs < throttleMs) {
      _queued = true;
      return;
    }
    if (_inFlight) {
      _queued = true;
      return;
    }

    _lastSyncMs = nowMs;
    _inFlight = true;

    unawaited(_runSync());
  }

  Future<void> _runSync() async {
    try {
      if (_disposed) return;
      await _sync();
    } catch (e) {
      // Intentionally swallow errors here; screens already log in their safe
      // sync wrappers.
      // Keep log noise low; the caller's safe wrapper should log details.
      // ignore: unused_local_variable
      final _ = e;
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
  }
}
