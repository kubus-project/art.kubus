import 'package:art_kubus/services/browser_session/browser_session_logout_intent_store_contract.dart';
import 'package:art_kubus/services/browser_session/browser_session_logout_intent_store_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the memory marker remembers whether the shared marker was written',
      () async {
    final BrowserSessionLogoutIntentStore store =
        createBrowserSessionLogoutIntentStore();
    expect(await store.readDependsOnSharedMarker(), isFalse);

    await store.writePendingLogout(sharedMarkerWritten: true);
    expect(await store.readDependsOnSharedMarker(), isTrue);

    await store.writePendingLogout();
    expect(await store.readDependsOnSharedMarker(), isFalse);

    await store.writePendingLogout(sharedMarkerWritten: true);
    await store.clear();
    expect(await store.readDependsOnSharedMarker(), isFalse);
  });
}
