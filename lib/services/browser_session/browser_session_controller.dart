import 'browser_session_api.dart';
import 'browser_session_lock.dart';

/// Tab-level coordination for browser sessions: one restore in flight at a
/// time, restores serialized across tabs by [BrowserSessionLock], and no call
/// that throws. Callers decide what a result means for their in-memory state.
class BrowserSessionController {
  BrowserSessionController({
    required BrowserSessionApi api,
    BrowserSessionLock? lock,
  })  : _api = api,
        _lock = lock ?? createBrowserSessionLock();

  final BrowserSessionApi _api;
  final BrowserSessionLock _lock;
  Future<BrowserSessionResult>? _restoreFlight;

  /// Best effort. Never throws; any failure is an unavailable result.
  Future<BrowserSessionResult> issue({required String loginToken}) {
    return _guarded(() => _api.issue(loginToken: loginToken));
  }

  /// Joins the restore already in flight in this tab, or starts one inside the
  /// cross-tab lock. Never throws.
  Future<BrowserSessionResult> restore() {
    final existing = _restoreFlight;
    if (existing != null) return existing;
    final flight = _guarded(() => _lock.run(() => _api.restore()));
    _restoreFlight = flight;
    flight.whenComplete(() {
      if (identical(_restoreFlight, flight)) _restoreFlight = null;
    });
    return flight;
  }

  /// Revokes the session family. Never throws.
  Future<BrowserSessionResult> logout() => _guarded(_api.logout);

  static Future<BrowserSessionResult> _guarded(
    Future<BrowserSessionResult> Function() call,
  ) async {
    try {
      return await call();
    } catch (_) {
      return const BrowserSessionResult.unavailable();
    }
  }
}
