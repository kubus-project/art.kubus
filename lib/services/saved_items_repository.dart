import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_item.dart';
import 'backend_api_service.dart';

class SavedItemsRepository {
  SavedItemsRepository({
    BackendApiService? api,
    SharedPreferences? prefs,
  })  : _api = api ?? BackendApiService(),
        _prefs = prefs;

  static const _cacheKey = 'saved_items_v3_cache';
  static const _outboxKey = 'saved_items_v3_outbox';

  final BackendApiService _api;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<SavedItemRecord>> loadCachedItems() async {
    final prefs = await _preferences;
    return _decodeRecords(prefs.getString(_cacheKey));
  }

  Future<void> cacheItems(List<SavedItemRecord> items) async {
    final prefs = await _preferences;
    await prefs.setString(
      _cacheKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearCachedState() async {
    final prefs = await _preferences;
    await prefs.remove(_cacheKey);
    await prefs.remove(_outboxKey);
  }

  Future<SavedItemsPage> loadBackendItems({
    SavedItemType? type,
    int limit = 50,
    String? cursor,
  }) async {
    await _api.ensureAuthLoaded();
    return _api.getSavedItems(type: type, limit: limit, cursor: cursor);
  }

  Future<SavedItemRecord> save(SavedItemRecord item) async {
    try {
      await _replayOutbox();
      return await _api.saveSavedItem(item);
    } catch (_) {
      await _enqueue(_SavedMutationRecord.save(item));
      return item;
    }
  }

  Future<void> unsave(SavedItemType type, String id) async {
    try {
      await _replayOutbox();
      await _api.deleteSavedItem(type, id);
    } catch (_) {
      await _enqueue(_SavedMutationRecord.delete(type, id));
    }
  }

  Future<void> replayPendingMutations() => _replayOutbox();

  Future<Map<String, bool>> getSavedBatchStatus(
    Iterable<SavedItemRecord> items,
  ) async {
    try {
      await _replayOutbox();
      return await _api.getSavedBatchStatus(items);
    } catch (_) {
      return const <String, bool>{};
    }
  }

  Future<void> migrateLegacyItems(List<SavedItemRecord> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      await save(item);
    }
  }

  Future<void> _enqueue(_SavedMutationRecord mutation) async {
    final prefs = await _preferences;
    final mutations = _decodeMutations(prefs.getString(_outboxKey));
    mutations.removeWhere((entry) => entry.key == mutation.key);
    mutations.add(mutation);
    await prefs.setString(
      _outboxKey,
      jsonEncode(mutations.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _replayOutbox() async {
    final prefs = await _preferences;
    final mutations = _decodeMutations(prefs.getString(_outboxKey));
    if (mutations.isEmpty) return;

    final remaining = <_SavedMutationRecord>[];
    for (final mutation in mutations) {
      try {
        if (mutation.deleteOnly) {
          await _api.deleteSavedItem(mutation.type, mutation.id);
        } else {
          await _api.saveSavedItem(mutation.item!);
        }
      } catch (_) {
        remaining.add(mutation);
      }
    }

    await prefs.setString(
      _outboxKey,
      jsonEncode(remaining.map((entry) => entry.toJson()).toList()),
    );
  }

  List<SavedItemRecord> _decodeRecords(String? source) {
    if ((source ?? '').trim().isEmpty) return const <SavedItemRecord>[];
    try {
      final decoded = jsonDecode(source!);
      if (decoded is! List) return const <SavedItemRecord>[];
      return decoded
          .whereType<Map>()
          .map((entry) =>
              SavedItemRecord.fromJson(Map<String, dynamic>.from(entry)))
          .where((record) => record.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <SavedItemRecord>[];
    }
  }

  List<_SavedMutationRecord> _decodeMutations(String? source) {
    if ((source ?? '').trim().isEmpty) return <_SavedMutationRecord>[];
    try {
      final decoded = jsonDecode(source!);
      if (decoded is! List) return <_SavedMutationRecord>[];
      return decoded
          .whereType<Map>()
          .map((entry) =>
              _SavedMutationRecord.fromJson(Map<String, dynamic>.from(entry)))
          .whereType<_SavedMutationRecord>()
          .toList(growable: true);
    } catch (_) {
      return <_SavedMutationRecord>[];
    }
  }
}

class _SavedMutationRecord {
  _SavedMutationRecord.save(SavedItemRecord savedItem)
      : item = savedItem,
        type = savedItem.type,
        id = savedItem.id,
        deleteOnly = false;

  _SavedMutationRecord.delete(this.type, this.id)
      : item = null,
        deleteOnly = true;

  final SavedItemRecord? item;
  final bool deleteOnly;
  final SavedItemType type;
  final String id;

  String get key => '${deleteOnly ? 'delete' : 'save'}:${type.storageKey}:$id';

  Map<String, dynamic> toJson() => {
        'action': deleteOnly ? 'delete' : 'save',
        'type': type.storageKey,
        'id': id,
        if (item != null) 'item': item!.toJson(),
      };

  static _SavedMutationRecord? fromJson(Map<String, dynamic> json) {
    final action = json['action']?.toString();
    final itemPayload = json['item'];
    if (action == 'save' && itemPayload is Map) {
      return _SavedMutationRecord.save(
        SavedItemRecord.fromJson(Map<String, dynamic>.from(itemPayload)),
      );
    }
    if (action == 'delete') {
      final type = SavedItemTypeX.fromStorageKey(json['type']?.toString());
      final id = json['id']?.toString().trim() ?? '';
      if (type == null || id.isEmpty) return null;
      return _SavedMutationRecord.delete(type, id);
    }
    return null;
  }
}
