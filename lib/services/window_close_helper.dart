import 'window_close_helper_stub.dart'
    if (dart.library.js_interop) 'window_close_helper_web.dart';

/// Attempts to close the current browser tab/window (web only).
///
/// Returns `true` when a close attempt was initiated (it may still be blocked
/// by the browser depending on how the window was opened).
bool attemptCloseWindow() => attemptCloseWindowImpl();

