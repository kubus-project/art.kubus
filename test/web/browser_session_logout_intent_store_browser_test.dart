@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:art_kubus/services/browser_session/browser_session_logout_intent_store_web.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'kubus-browser-session-logout-pending-v1';

JSObject get _storage =>
    globalContext.getProperty<JSObject>('sessionStorage'.toJS);

String? _raw() =>
    _storage.callMethod<JSString?>('getItem'.toJS, _key.toJS)?.toDart;

void main() {
  tearDown(() {
    _storage.callMethod<JSAny?>('removeItem'.toJS, _key.toJS);
  });

  test('a tab marker written after the shared one is encoded shared-ok',
      () async {
    final store = createBrowserSessionLogoutIntentStore();

    expect(await store.writePendingLogout(sharedMarkerWritten: true), isTrue);

    expect(_raw(), 'logout:shared-ok');
    expect(await store.readPendingLogout(), isTrue);
    expect(await store.readDependsOnSharedMarker(), isTrue);
  });

  test('a tab marker that is the sole record is encoded shared-failed',
      () async {
    final store = createBrowserSessionLogoutIntentStore();

    expect(await store.writePendingLogout(sharedMarkerWritten: false), isTrue);

    expect(_raw(), 'logout:shared-failed');
    expect(await store.readPendingLogout(), isTrue);
    expect(await store.readDependsOnSharedMarker(), isFalse);
  });

  test('an absent, cleared or unknown value is no marker', () async {
    final store = createBrowserSessionLogoutIntentStore();
    expect(await store.readPendingLogout(), isFalse);
    expect(await store.readDependsOnSharedMarker(), isFalse);

    await store.writePendingLogout(sharedMarkerWritten: true);
    expect(await store.clear(), isTrue);
    expect(_raw(), isNull);
    expect(await store.readPendingLogout(), isFalse);

    _storage.callMethod<JSAny?>('setItem'.toJS, _key.toJS, 'logout'.toJS);
    expect(await store.readPendingLogout(), isFalse);
  });
}
