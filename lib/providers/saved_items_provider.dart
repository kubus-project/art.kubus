import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_item.dart';
import '../services/saved_items_repository.dart';

class SavedItemsProvider extends ChangeNotifier {
  SavedItemsProvider({SavedItemsRepository? repository})
      : _repository = repository ?? SavedItemsRepository();

  static const _storageKeyV2 = 'saved_items_v2';
  static const _artworkKey = 'saved_artwork_ids';
  static const _postKey = 'saved_post_ids';
  static const _bookmarkKey = 'community_bookmarks';
  static const _timestampKey = 'saved_timestamps';

  final SavedItemsRepository _repository;
  final Map<SavedItemType, Map<String, SavedItemRecord>> _itemsByType = {
    for (final type in SavedItemType.values) type: <String, SavedItemRecord>{},
  };
  final Map<SavedItemType, String?> _nextCursorByType = {
    for (final type in SavedItemType.values) type: null,
  };
  final Map<SavedItemType, bool> _typePageLoaded = {
    for (final type in SavedItemType.values) type: false,
  };
  final Map<SavedItemType, bool> _hasMoreByType = {
    for (final type in SavedItemType.values) type: true,
  };

  bool _isInitialized = false;
  bool _isSyncing = false;
  SharedPreferences? _prefs;

  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;

  Set<String> get savedArtworkIds =>
      Set.unmodifiable(_idsForType(SavedItemType.artwork));
  Set<String> get savedEventIds =>
      Set.unmodifiable(_idsForType(SavedItemType.event));
  Set<String> get savedCollectionIds =>
      Set.unmodifiable(_idsForType(SavedItemType.collection));
  Set<String> get savedExhibitionIds =>
      Set.unmodifiable(_idsForType(SavedItemType.exhibition));
  Set<String> get savedPostIds =>
      Set.unmodifiable(_idsForType(SavedItemType.communityPost));

  List<SavedItemRecord> get savedArtworkItems =>
      _sortedItemsForType(SavedItemType.artwork);
  List<SavedItemRecord> get savedEventItems =>
      _sortedItemsForType(SavedItemType.event);
  List<SavedItemRecord> get savedCollectionItems =>
      _sortedItemsForType(SavedItemType.collection);
  List<SavedItemRecord> get savedExhibitionItems =>
      _sortedItemsForType(SavedItemType.exhibition);
  List<SavedItemRecord> get savedPostItems =>
      _sortedItemsForType(SavedItemType.communityPost);
  List<SavedItemRecord> get savedArtistItems =>
      _sortedItemsForType(SavedItemType.artist);
  List<SavedItemRecord> get savedInstitutionItems =>
      _sortedItemsForType(SavedItemType.institution);
  List<SavedItemRecord> get savedGroupItems =>
      _sortedItemsForType(SavedItemType.group);
  List<SavedItemRecord> get savedMarkerItems =>
      _sortedItemsForType(SavedItemType.marker);

  int get savedArtworksCount => _countForType(SavedItemType.artwork);
  int get savedEventsCount => _countForType(SavedItemType.event);
  int get savedCollectionsCount => _countForType(SavedItemType.collection);
  int get savedExhibitionsCount => _countForType(SavedItemType.exhibition);
  int get savedPostsCount => _countForType(SavedItemType.communityPost);
  int get savedArtistsCount => _countForType(SavedItemType.artist);
  int get savedInstitutionsCount => _countForType(SavedItemType.institution);
  int get savedGroupsCount => _countForType(SavedItemType.group);
  int get savedMarkersCount => _countForType(SavedItemType.marker);

  int get totalSavedCount =>
      _itemsByType.values.fold<int>(0, (sum, items) => sum + items.length);

  bool hasMore(SavedItemType type) => _hasMoreByType[type] ?? false;

  DateTime? get mostRecentSave {
    DateTime? latest;
    for (final items in _itemsByType.values) {
      for (final item in items.values) {
        if (latest == null || item.savedAt.isAfter(latest)) {
          latest = item.savedAt;
        }
      }
    }
    return latest;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    final cached = await _repository.loadCachedItems();
    final legacy = _loadLegacyItems();
    _replaceAll(_mergeRecords([...cached, ...legacy]));
    _isInitialized = true;
    notifyListeners();

    await _repository.migrateLegacyItems(legacy);
    await refreshFromBackend();
  }

  Future<void> refreshFromBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    try {
      final page = await _repository.loadBackendItems(limit: 100);
      _replaceAll(page.items);
      await _repository.cacheItems(_sortedRecords());
      await _saveLegacyCompatKeys();
      await _repository.replayPendingMutations();
    } catch (_) {
      // Cached state remains authoritative for offline display until replay.
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(SavedItemType type) async {
    final cursor = _nextCursorByType[type];
    if ((_typePageLoaded[type] ?? false) && cursor == null) {
      _hasMoreByType[type] = false;
      notifyListeners();
      return;
    }
    final page = await _repository.loadBackendItems(
      type: type,
      limit: 50,
      cursor: cursor,
    );
    _nextCursorByType[type] = page.nextCursor;
    _typePageLoaded[type] = true;
    _hasMoreByType[type] = page.nextCursor != null;
    _upsertAll(page.items);
    await _repository.cacheItems(_sortedRecords());
    notifyListeners();
  }

  Future<void> saveItem(SavedItemRecord record) async {
    final normalized = record.copyWith(
      savedAt: record.savedAt.millisecondsSinceEpoch <= 0
          ? DateTime.now()
          : record.savedAt,
    );
    _upsert(normalized);
    notifyListeners();
    await _repository.cacheItems(_sortedRecords());
    final synced = await _repository.save(normalized);
    _upsert(synced);
    await _repository.cacheItems(_sortedRecords());
    await _saveLegacyCompatKeys();
    notifyListeners();
  }

  Future<void> _setSaved(
    SavedItemType type,
    String id,
    bool isSaved, {
    DateTime? timestamp,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? authorId,
    String? authorName,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return;

    if (isSaved) {
      await saveItem(SavedItemRecord(
        type: type,
        id: normalizedId,
        savedAt: timestamp ?? DateTime.now(),
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        authorId: authorId,
        authorName: authorName,
        metadata: metadata,
      ));
      return;
    }

    final removed = _itemsByType[type]!.remove(normalizedId);
    notifyListeners();
    await _repository.cacheItems(_sortedRecords());
    await _repository.unsave(type, normalizedId);
    await _saveLegacyCompatKeys();
    if (removed == null) notifyListeners();
  }

  Future<void> toggleArtworkSaved(String artworkId) async {
    await setArtworkSaved(artworkId, !isArtworkSaved(artworkId));
  }

  Future<void> setArtworkSaved(String artworkId, bool isSaved,
      {DateTime? timestamp,
      String? title,
      String? subtitle,
      String? imageUrl,
      String? authorId,
      String? authorName,
      Map<String, dynamic> metadata = const <String, dynamic>{}}) {
    return _setSaved(SavedItemType.artwork, artworkId, isSaved,
        timestamp: timestamp,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        authorId: authorId,
        authorName: authorName,
        metadata: metadata);
  }

  Future<void> toggleEventSaved(String eventId) async {
    await setEventSaved(eventId, !isEventSaved(eventId));
  }

  Future<void> setEventSaved(String eventId, bool isSaved,
      {DateTime? timestamp}) {
    return _setSaved(SavedItemType.event, eventId, isSaved,
        timestamp: timestamp);
  }

  Future<void> toggleCollectionSaved(String collectionId) async {
    await setCollectionSaved(collectionId, !isCollectionSaved(collectionId));
  }

  Future<void> setCollectionSaved(String collectionId, bool isSaved,
      {DateTime? timestamp}) {
    return _setSaved(SavedItemType.collection, collectionId, isSaved,
        timestamp: timestamp);
  }

  Future<void> toggleExhibitionSaved(String exhibitionId) async {
    await setExhibitionSaved(exhibitionId, !isExhibitionSaved(exhibitionId));
  }

  Future<void> setExhibitionSaved(String exhibitionId, bool isSaved,
      {DateTime? timestamp}) {
    return _setSaved(SavedItemType.exhibition, exhibitionId, isSaved,
        timestamp: timestamp);
  }

  Future<void> togglePostSaved(String postId) async {
    await setPostSaved(postId, !isPostSaved(postId));
  }

  Future<void> setPostSaved(String postId, bool isSaved,
      {DateTime? timestamp,
      String? title,
      String? subtitle,
      String? imageUrl,
      String? authorId,
      String? authorName,
      Map<String, dynamic> metadata = const <String, dynamic>{}}) {
    return _setSaved(SavedItemType.communityPost, postId, isSaved,
        timestamp: timestamp,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        authorId: authorId,
        authorName: authorName,
        metadata: metadata);
  }

  bool isArtworkSaved(String artworkId) =>
      _itemsByType[SavedItemType.artwork]!.containsKey(artworkId.trim());
  bool isEventSaved(String eventId) =>
      _itemsByType[SavedItemType.event]!.containsKey(eventId.trim());
  bool isCollectionSaved(String collectionId) =>
      _itemsByType[SavedItemType.collection]!.containsKey(collectionId.trim());
  bool isExhibitionSaved(String exhibitionId) =>
      _itemsByType[SavedItemType.exhibition]!.containsKey(exhibitionId.trim());
  bool isPostSaved(String postId) =>
      _itemsByType[SavedItemType.communityPost]!.containsKey(postId.trim());

  DateTime? getSavedTimestamp(String itemId, {SavedItemType? type}) {
    final normalizedId = itemId.trim();
    if (normalizedId.isEmpty) return null;
    if (type != null) return _itemsByType[type]![normalizedId]?.savedAt;
    DateTime? latest;
    for (final items in _itemsByType.values) {
      final savedAt = items[normalizedId]?.savedAt;
      if (savedAt == null) continue;
      if (latest == null || savedAt.isAfter(latest)) latest = savedAt;
    }
    return latest;
  }

  DateTime? getArtworkSavedAt(String artworkId) =>
      getSavedTimestamp(artworkId, type: SavedItemType.artwork);
  DateTime? getEventSavedAt(String eventId) =>
      getSavedTimestamp(eventId, type: SavedItemType.event);
  DateTime? getCollectionSavedAt(String collectionId) =>
      getSavedTimestamp(collectionId, type: SavedItemType.collection);
  DateTime? getExhibitionSavedAt(String exhibitionId) =>
      getSavedTimestamp(exhibitionId, type: SavedItemType.exhibition);
  DateTime? getPostSavedAt(String postId) =>
      getSavedTimestamp(postId, type: SavedItemType.communityPost);

  Future<void> removeArtwork(String artworkId) => setArtworkSaved(artworkId, false);
  Future<void> removeEvent(String eventId) => setEventSaved(eventId, false);
  Future<void> removeCollection(String collectionId) =>
      setCollectionSaved(collectionId, false);
  Future<void> removeExhibition(String exhibitionId) =>
      setExhibitionSaved(exhibitionId, false);
  Future<void> removePost(String postId) => setPostSaved(postId, false);
  Future<void> removeItem(SavedItemType type, String id) =>
      _setSaved(type, id, false);

  Future<void> clearAllArtworks() => _clearType(SavedItemType.artwork);
  Future<void> clearAllEvents() => _clearType(SavedItemType.event);
  Future<void> clearAllCollections() => _clearType(SavedItemType.collection);
  Future<void> clearAllExhibitions() => _clearType(SavedItemType.exhibition);
  Future<void> clearAllPosts() => _clearType(SavedItemType.communityPost);

  Future<void> clearAll() async {
    final records = _sortedRecords();
    for (final record in records) {
      _itemsByType[record.type]!.remove(record.id);
      await _repository.unsave(record.type, record.id);
    }
    await _repository.cacheItems(const <SavedItemRecord>[]);
    await _saveLegacyCompatKeys();
    notifyListeners();
  }

  Future<void> _clearType(SavedItemType type) async {
    final records = _sortedItemsForType(type);
    _itemsByType[type]!.clear();
    notifyListeners();
    for (final record in records) {
      await _repository.unsave(type, record.id);
    }
    await _repository.cacheItems(_sortedRecords());
    await _saveLegacyCompatKeys();
  }

  List<String> getSortedSavedIds({String? type}) {
    final resolvedType = SavedItemTypeX.fromStorageKey(type);
    if (resolvedType != null) {
      return _sortedItemsForType(resolvedType)
          .map((item) => item.id)
          .toList(growable: false);
    }
    return _sortedRecords().map((record) => record.id).toList(growable: false);
  }

  List<SavedItemRecord> getSavedItems({SavedItemType? type}) {
    if (type != null) return _sortedItemsForType(type);
    return _sortedRecords();
  }

  Future<void> reloadFromDisk() => refreshFromBackend();

  List<SavedItemRecord> _loadLegacyItems() {
    final prefs = _prefs;
    if (prefs == null) return const <SavedItemRecord>[];
    final records = <SavedItemRecord>[];
    records.addAll(_decodeV2(prefs.getString(_storageKeyV2)));
    final timestamps = _decodeTimestampMap(prefs.getString(_timestampKey));

    void addLegacyItems(SavedItemType type, Iterable<String> ids) {
      for (final rawId in ids) {
        final id = rawId.trim();
        if (id.isEmpty) continue;
        final savedAt = timestamps['${type.storageKey}:$id'] ??
            timestamps[id] ??
            DateTime.now();
        records.add(SavedItemRecord(type: type, id: id, savedAt: savedAt));
      }
    }

    addLegacyItems(SavedItemType.artwork, [
      ..._decodeStringList(prefs.getStringList(_artworkKey)),
      ..._decodeJsonList(prefs.getString(_artworkKey)),
    ]);
    addLegacyItems(SavedItemType.communityPost, {
      ..._decodeStringList(prefs.getStringList(_postKey)),
      ..._decodeJsonList(prefs.getString(_postKey)),
      ..._decodeStringList(prefs.getStringList(_bookmarkKey)),
    });
    return _mergeRecords(records);
  }

  List<SavedItemRecord> _decodeV2(String? source) {
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

  Map<String, DateTime> _decodeTimestampMap(String? source) {
    if ((source ?? '').trim().isEmpty) return <String, DateTime>{};
    try {
      final decoded = jsonDecode(source!);
      if (decoded is! Map) return <String, DateTime>{};
      return {
        for (final entry in decoded.entries)
          if (DateTime.tryParse(entry.value.toString()) != null)
            entry.key.toString(): DateTime.parse(entry.value.toString()),
      };
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  List<String> _decodeStringList(List<String>? source) =>
      (source ?? const <String>[])
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

  List<String> _decodeJsonList(String? source) {
    if ((source ?? '').trim().isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(source!);
      if (decoded is! List) return const <String>[];
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _saveLegacyCompatKeys() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setStringList(
      _artworkKey,
      _idsForType(SavedItemType.artwork).toList(growable: false),
    );
    await prefs.setStringList(
      _postKey,
      _idsForType(SavedItemType.communityPost).toList(growable: false),
    );
  }

  void _replaceAll(List<SavedItemRecord> records) {
    for (final type in SavedItemType.values) {
      _itemsByType[type]!.clear();
      _typePageLoaded[type] = false;
      _hasMoreByType[type] = true;
      _nextCursorByType[type] = null;
    }
    _upsertAll(records);
  }

  void _upsertAll(List<SavedItemRecord> records) {
    for (final record in records) {
      _upsert(record);
    }
  }

  void _upsert(SavedItemRecord record) {
    if (record.id.trim().isEmpty) return;
    _itemsByType[record.type]![record.id] = record;
  }

  List<SavedItemRecord> _mergeRecords(List<SavedItemRecord> records) {
    final byKey = <String, SavedItemRecord>{};
    for (final record in records) {
      final key = '${record.type.storageKey}:${record.id}';
      final existing = byKey[key];
      if (existing == null || record.savedAt.isAfter(existing.savedAt)) {
        byKey[key] = record;
      }
    }
    return byKey.values.toList(growable: false);
  }

  int _countForType(SavedItemType type) => _itemsByType[type]!.length;
  Set<String> _idsForType(SavedItemType type) =>
      _itemsByType[type]!.keys.toSet();

  List<SavedItemRecord> _sortedItemsForType(SavedItemType type) {
    final records = _itemsByType[type]!.values.toList(growable: false);
    records.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return records;
  }

  List<SavedItemRecord> _sortedRecords() {
    final records = <SavedItemRecord>[
      for (final type in SavedItemType.values) ..._sortedItemsForType(type),
    ];
    records.sort((a, b) {
      final timeCompare = b.savedAt.compareTo(a.savedAt);
      if (timeCompare != 0) return timeCompare;
      return a.type.index.compareTo(b.type.index);
    });
    return records;
  }
}
