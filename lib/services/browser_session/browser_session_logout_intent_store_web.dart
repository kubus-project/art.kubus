import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'browser_session_logout_intent_store_contract.dart';

const _intentKey = 'kubus-browser-session-logout-pending-v1';

/// Written when the shared marker was written first: this tab marker is stale
/// once the shared one is gone.
const sharedOkIntentValue = 'logout:shared-ok';

/// Written when the shared marker could not be written: this tab marker is the
/// only record that a revocation is owed.
const sharedFailedIntentValue = 'logout:shared-failed';

bool _isIntentValue(String? value) =>
    value == sharedOkIntentValue || value == sharedFailedIntentValue;

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
  Future<bool> writePendingLogout({bool sharedMarkerWritten = false}) async {
    try {
      final storage = _storage();
      if (storage == null) return false;
      final value =
          sharedMarkerWritten ? sharedOkIntentValue : sharedFailedIntentValue;
      storage.callMethod<JSAny?>(
        'setItem'.toJS,
        _intentKey.toJS,
        value.toJS,
      );
      return _rawRead() == value;
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
      return _isIntentValue(value?.toDart);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> readDependsOnSharedMarker() async =>
      _rawRead() == sharedOkIntentValue;

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
