import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'browser_session_lock_contract.dart';

/// Web Locks (`navigator.locks`) serialize restore calls across every tab of
/// the origin. The cookie is single-use, so two overlapping restores would be
/// read as a replay and revoke the whole session.
BrowserSessionLock createBrowserSessionLock() => _WebLocksBrowserSessionLock();

class _WebLocksBrowserSessionLock implements BrowserSessionLock {
  static const String _lockName = 'kubus-browser-session';

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    final locks = _locksOrNull();
    // A per-tab queue cannot protect the shared single-use cookie from another
    // tab. Fail closed when cross-tab coordination is unavailable.
    if (locks == null) {
      throw StateError('Cross-tab browser session locking is unavailable');
    }

    T? result;
    Object? failure;
    StackTrace? failureStack;

    // The lock is held until the callback's promise settles, so the body runs
    // inside the lock. Its outcome is carried out through the closure, not the
    // JS promise value.
    Future<JSAny?> hold() async {
      try {
        result = await body();
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      }
      return null;
    }

    final callback = (() => hold().toJS).toJS;
    final promise = locks.callMethod<JSPromise<JSAny?>>(
      'request'.toJS,
      _lockName.toJS,
      callback,
    );
    await promise.toDart;

    final error = failure;
    if (error != null) {
      Error.throwWithStackTrace(error, failureStack ?? StackTrace.current);
    }
    return result as T;
  }

  JSObject? _locksOrNull() {
    try {
      final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
      return navigator?.getProperty<JSObject?>('locks'.toJS);
    } catch (_) {
      return null;
    }
  }
}
