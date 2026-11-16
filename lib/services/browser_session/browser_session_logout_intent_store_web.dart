import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'browser_session_logout_intent_store_contract.dart';

const _intentKey = 'kubus-browser-session-logout-pending-v1';
const _intentValue = 'logout';

/// Tab-scoped fallback for the logout marker, used when the shared preferences
/// write fails. It survives a reload of this tab but not a new tab, so it
/// supplements the shared marker and never replaces it.
class _SessionStorageLogoutIntentStore
    implements BrowserSessionLogoutIntentStore {
  JSObject? _storage() {
    try {
      return globalContext.getProperty<JSObject?>('sessionStorage'.toJS);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> writePendingLogout() async {
    try {
      final storage = _storage();
      if (storage == null) return false;
      storage.callMethod<JSAny?>(
        'setItem'.toJS,
        _intentKey.toJS,
        _intentValue.toJS,
      );
      return _rawRead() == _intentValue;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool?> readPendingLogout() async {
    try {
      final storage = _storage();
      if (storage == null) return null;
      final value = storage.callMethod<JSString?>(
        'getItem'.toJS,
        _intentKey.toJS,
      );
      return value?.toDart == _intentValue;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> clear() async {
    try {
      final storage = _storage();
      if (storage == null) return false;
      storage.callMethod<JSAny?>('removeItem'.toJS, _intentKey.toJS);
      return _rawRead() == null;
    } catch (_) {
      return false;
    }
  }

  String? _rawRead() {
    try {
      final storage = _storage();
      if (storage == null) return null;
      final value = storage.callMethod<JSString?>(
        'getItem'.toJS,
        _intentKey.toJS,
      );
      return value?.toDart;
    } catch (_) {
      return null;
    }
  }
}

BrowserSessionLogoutIntentStore createBrowserSessionLogoutIntentStore() =>
    _SessionStorageLogoutIntentStore();
