import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/saved_items_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedItemRecord _item(String id) => SavedItemRecord(
      type: SavedItemType.artwork,
      id: id,
      savedAt: DateTime.utc(2026, 11, 14),
    );

class _GatedSavedItemsApi implements BackendApiService {
  final List<String> dispatchedIds = <String>[];
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<SavedItemRecord> firstSaveResponse =
      Completer<SavedItemRecord>();

  @override
  Future<SavedItemRecord> saveSavedItem(SavedItemRecord item) {
    dispatchedIds.add(item.id);
    if (dispatchedIds.length == 1) {
      firstSaveStarted.complete();
      return firstSaveResponse.future;
    }
    return Future<SavedItemRecord>.value(item);
  }

  @override
  Future<void> deleteSavedItem(SavedItemType type, String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(AccountIdentity.resetForTesting);

  test('A replay stops before queued and direct mutations dispatch as B',
      () async {
    AccountIdentity.setAccountKey('account-A');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'saved_items_v3_outbox',
        jsonEncode([
          {
            'action': 'save',
            'type': 'artwork',
            'id': 'queued-A1',
            'item': _item('queued-A1').toJson()
          },
          {
            'action': 'save',
            'type': 'artwork',
            'id': 'queued-A2',
            'item': _item('queued-A2').toJson()
          },
        ]));
    final api = _GatedSavedItemsApi();
    final repository = SavedItemsRepository(api: api, prefs: prefs);
    addTearDown(repository.dispose);

    final pending = repository.save(_item('direct-A'));
    await api.firstSaveStarted.future;
    AccountIdentity.setAccountKey('account-B');
    AccountIdentity.notifyListenersChanged();

    api.firstSaveResponse.complete(_item('queued-A1'));
    await pending;

    expect(api.dispatchedIds, <String>['queued-A1']);
  });

  test('same-account token refresh does not cancel an outbox replay', () async {
    AccountIdentity.setAccountKey('account-A');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'saved_items_v3_outbox',
        jsonEncode([
          {
            'action': 'save',
            'type': 'artwork',
            'id': 'queued-A1',
            'item': _item('queued-A1').toJson()
          },
          {
            'action': 'save',
            'type': 'artwork',
            'id': 'queued-A2',
            'item': _item('queued-A2').toJson()
          },
        ]));
    final api = _GatedSavedItemsApi();
    final repository = SavedItemsRepository(api: api, prefs: prefs);
    addTearDown(repository.dispose);

    final pending = repository.replayPendingMutations();
    await api.firstSaveStarted.future;
    AccountIdentity.setAccountKey('account-A');
    api.firstSaveResponse.complete(_item('queued-A1'));
    await pending;

    expect(api.dispatchedIds, <String>['queued-A1', 'queued-A2']);
  });
}
