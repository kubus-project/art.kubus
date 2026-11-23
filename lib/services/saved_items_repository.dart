import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_item.dart';
import 'account_identity.dart';
import 'backend_api_service.dart';

class SavedItemsRepository {
  SavedItemsRepository({
    BackendApiService? api,
    SharedPreferences? prefs,
  })  : _api = api ?? BackendApiService(),
        _prefs = prefs {
    AccountIdentity.addListener(_handleAccountIdentityChanged);
  }

  static const _cacheKey = 'saved_items_v3_cache';
  static const _outboxKey = 'saved_items_v3_outbox';

  final BackendApiService _api;
  SharedPreferences? _prefs;
  int _identityGeneration = 0;

  void _handleAccountIdentityChanged() {
    _identityGeneration += 1;
  }

  bool _isCurrentIdentity(int generation) => generation == _identityGeneration;

  void dispose() {
    AccountIdentity.removeListener(_handleAccountIdentityChanged);
  }

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

  /// Whether a backend account session exists.
  ///
  /// Saved items are account-scoped; without a session the per-type page
  /// requests in [loadBackendItems] can only 401, so callers skip syncing.
  Future<bool> hasBackendSession() async {
    try {
      await _api.ensureAuthLoaded();
    } catch (_) {}
    return _api.hasAuthSession;
  }

  Future<SavedItemsPage> loadBackendItems({
    SavedItemType? type,
    int limit = 50,
    String? cursor,
  }) async {
    final generation = _identityGeneration;
    await _api.ensureAuthLoaded();
    if (!_isCurrentIdentity(generation)) {
      return const SavedItemsPage(items: <SavedItemRecord>[]);
    }
    final page =
        await _api.getSavedItems(type: type, limit: limit, cursor: cursor);
    if (!_isCurrentIdentity(generation)) {
      return const SavedItemsPage(items: <SavedItemRecord>[]);
    }
    return page;
  }

  Future<SavedItemRecord> save(SavedItemRecord item) async {
    return _saveForGeneration(item, _identityGeneration);
  }

  Future<SavedItemRecord> _saveForGeneration(
    SavedItemRecord item,
    int generation,
  ) async {
    try {
      await _replayOutbox(generation);
      if (!_isCurrentIdentity(generation)) return item;
      final saved = await _api.saveSavedItem(item);
      if (!_isCurrentIdentity(generation)) return item;
      return saved;
    } catch (_) {
      if (!_isCurrentIdentity(generation)) return item;
      await _enqueue(_SavedMutationRecord.save(item), generation);
      return item;
    }
  }

  Future<void> unsave(SavedItemType type, String id) async {
    final generation = _identityGeneration;
    try {
      await _replayOutbox(generation);
      if (!_isCurrentIdentity(generation)) return;
      await _api.deleteSavedItem(type, id);
      if (!_isCurrentIdentity(generation)) return;
    } catch (_) {
      if (!_isCurrentIdentity(generation)) return;
      await _enqueue(_SavedMutationRecord.delete(type, id), generation);
    }
  }

  Future<void> replayPendingMutations() => _replayOutbox(_identityGeneration);

  Future<List<SavedItemRecord>> loadPendingSaves() async {
    final prefs = await _preferences;
    return _decodeMutations(prefs.getString(_outboxKey))
        .where((mutation) => !mutation.deleteOnly && mutation.item != null)
        .map((mutation) => mutation.item!)
        .toList(growable: false);
  }

  Future<Set<String>> loadPendingDeleteKeys() async {
    final prefs = await _preferences;
    return _decodeMutations(prefs.getString(_outboxKey))
        .where((mutation) => mutation.deleteOnly)
        .map((mutation) => mutation.itemKey)
        .toSet();
  }

  Future<Map<String, bool>> getSavedBatchStatus(
    Iterable<SavedItemRecord> items,
  ) async {
    final generation = _identityGeneration;
    try {
      await _replayOutbox(generation);
      if (!_isCurrentIdentity(generation)) return const <String, bool>{};
      final status = await _api.getSavedBatchStatus(items);
      if (!_isCurrentIdentity(generation)) return const <String, bool>{};
      return status;
    } catch (_) {
      return const <String, bool>{};
    }
  }

  Future<void> migrateLegacyItems(List<SavedItemRecord> items) async {
    if (items.isEmpty) return;
    final generation = _identityGeneration;
    for (final item in items) {
      if (!_isCurrentIdentity(generation)) return;
      await _saveForGeneration(item, generation);
      if (!_isCurrentIdentity(generation)) return;
    }
  }

  Future<void> _enqueue(
    _SavedMutationRecord mutation,
    int generation,
  ) async {
    final prefs = await _preferences;
    if (!_isCurrentIdentity(generation)) return;
    final mutations = _decodeMutations(prefs.getString(_outboxKey));
    mutations.removeWhere((entry) => entry.key == mutation.key);
    mutations.add(mutation);
    if (!_isCurrentIdentity(generation)) return;
    await prefs.setString(
      _outboxKey,
      jsonEncode(mutations.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _replayOutbox(int generation) async {
    final prefs = await _preferences;
    if (!_isCurrentIdentity(generation)) return;
    final mutations = _decodeMutations(prefs.getString(_outboxKey));
    if (mutations.isEmpty) return;

    final remaining = <_SavedMutationRecord>[];
    for (final mutation in mutations) {
      if (!_isCurrentIdentity(generation)) return;
      try {
        if (mutation.deleteOnly) {
          await _api.deleteSavedItem(mutation.type, mutation.id);
        } else {
          await _api.saveSavedItem(mutation.item!);
        }
        if (!_isCurrentIdentity(generation)) return;
      } catch (_) {
        if (!_isCurrentIdentity(generation)) return;
        remaining.add(mutation);
      }
    }

    if (!_isCurrentIdentity(generation)) return;
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
  String get itemKey => '${type.storageKey}:$id';

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
