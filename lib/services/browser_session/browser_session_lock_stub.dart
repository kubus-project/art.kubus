import 'browser_session_lock_contract.dart';

/// Native and test builds: one tab-equivalent queue. Native never restores a
/// browser session, so this only serves tests.
BrowserSessionLock createBrowserSessionLock() => InProcessBrowserSessionLock();
