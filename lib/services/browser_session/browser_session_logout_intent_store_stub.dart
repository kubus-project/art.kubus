import 'browser_session_logout_intent_store_contract.dart';

/// In-memory marker for native builds and tests. Each instance is independent;
/// a test that simulates a reload passes the same instance to the new service.
class _MemoryLogoutIntentStore implements BrowserSessionLogoutIntentStore {
  bool _pending = false;

  @override
  Future<bool> writePendingLogout() async {
    _pending = true;
    return _pending;
  }

  @override
  Future<bool?> readPendingLogout() async => _pending;

  @override
  Future<bool> clear() async {
    _pending = false;
    return !_pending;
  }
}

BrowserSessionLogoutIntentStore createBrowserSessionLogoutIntentStore() =>
    _MemoryLogoutIntentStore();
