// Browser history helpers (web only): stepping back one entry, and reading the
// state the page stored for its current entry.
//
// Safe to import from every platform; native builds get no-ops.

import 'browser_history_step_stub.dart'
    if (dart.library.html) 'browser_history_step_web.dart' as impl;

/// Moves the browser one entry back, as the Back button does. A no-op off the
/// web.
void stepBrowserHistoryBack() => impl.stepBrowserHistoryBack();

/// The `history.state` stored for the current browser entry, which survives a
/// reload. Null off the web and when the entry has no state.
Object? currentBrowserHistoryState() => impl.currentBrowserHistoryState();
