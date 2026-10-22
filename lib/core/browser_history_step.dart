// Steps the browser history back by one entry (web only).
//
// Safe to import from every platform; native builds get a no-op.

import 'browser_history_step_stub.dart'
    if (dart.library.html) 'browser_history_step_web.dart' as impl;

/// Moves the browser one entry back, as the Back button does. A no-op off the
/// web.
void stepBrowserHistoryBack() => impl.stepBrowserHistoryBack();
