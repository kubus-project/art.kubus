import 'browser_session_logout_intent_store_contract.dart';

/// In-memory marker for native builds and tests. Each instance is independent;
/// a test that simulates a reload passes the same instance to the new service.
class _MemoryLogoutIntentStore implements BrowserSessionLogoutIntentStore {
  bool _pending = false;
  bool _dependsOnShared = false;

  @override
  Future<bool> writePendingLogout({bool sharedMarkerWritten = false}) async {
    _pending = true;
    _dependsOnShared = sharedMarkerWritten;
    return _pending;
  }

  @override
  Future<bool> readDependsOnSharedMarker() async =>
      _pending && _dependsOnShared;

  @override
  Future<bool?> readPendingLogout() async => _pending;

  @override
  Future<bool> clear() async {
    _pending = false;
    _dependsOnShared = false;
    return !_pending;
  }
}

BrowserSessionLogoutIntentStore createBrowserSessionLogoutIntentStore() =>
    _MemoryLogoutIntentStore();
