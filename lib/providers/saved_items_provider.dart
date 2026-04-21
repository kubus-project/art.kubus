import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_item.dart';

/// Provider for managing saved/bookmarked items across the app.
class SavedItemsProvider extends ChangeNotifier {
  static const _storageKeyV2 = 'saved_items_v2';
  static const _artworkKey = 'saved_artwork_ids';
  static const _postKey = 'saved_post_ids';
  static const _bookmarkKey = 'community_bookmarks';
  static const _timestampKey = 'saved_timestamps';

  final Map<SavedItemType, Map<String, DateTime>> _itemsByType = {
    for (final type in SavedItemType.values) type: <String, DateTime>{},
  };

  bool _isInitialized = false;
  SharedPreferences? _prefs;

  bool get isInitialized => _isInitialized;

  Set<String> get savedArtworkIds =>
      Set.unmodifiable(_idsForType(SavedItemType.artwork));
  Set<String> get savedEventIds =>
      Set.unmodifiable(_idsForType(SavedItemType.event));
  Set<String> get savedCollectionIds =>
      Set.unmodifiable(_idsForType(SavedItemType.collection));
  Set<String> get savedExhibitionIds =>
      Set.unmodifiable(_idsForType(SavedItemType.exhibition));
  Set<String> get savedPostIds =>
      Set.unmodifiable(_idsForType(SavedItemType.post));

  List<SavedItemRecord> get savedArtworkItems =>
      _sortedItemsForType(SavedItemType.artwork);
  List<SavedItemRecord> get savedEventItems =>
      _sortedItemsForType(SavedItemType.event);
  List<SavedItemRecord> get savedCollectionItems =>
      _sortedItemsForType(SavedItemType.collection);
  List<SavedItemRecord> get savedExhibitionItems =>
      _sortedItemsForType(SavedItemType.exhibition);
  List<SavedItemRecord> get savedPostItems =>
      _sortedItemsForType(SavedItemType.post);

  int get savedArtworksCount => _countForType(SavedItemType.artwork);
  int get savedEventsCount => _countForType(SavedItemType.event);
  int get savedCollectionsCount => _countForType(SavedItemType.collection);
  int get savedExhibitionsCount => _countForType(SavedItemType.exhibition);
  int get savedPostsCount => _countForType(SavedItemType.post);

  int get totalSavedCount =>
      _itemsByType.values.fold<int>(0, (sum, items) => sum + items.length);

  DateTime? get mostRecentSave {
    DateTime? latest;
    for (final items in _itemsByType.values) {
      for (final savedAt in items.values) {
        if (latest == null || savedAt.isAfter(latest)) {
          latest = savedAt;
        }
      }
    }
    return latest;
  }

  /// Initialize and load saved items from SharedPreferences.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadSavedItems();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadSavedItems({bool resetExisting = true}) async {
    _prefs ??= await SharedPreferences.getInstance();

    if (resetExisting) {
      for (final type in SavedItemType.values) {
        _itemsByType[type]!.clear();
      }
    }

    final loaded = <SavedItemRecord>[];
    final v2 = _prefs?.getString(_storageKeyV2);
    if (v2 != null && v2.trim().isNotEmpty) {
      loaded.addAll(_decodeV2(v2));
    }

    if (loaded.isEmpty) {
      loaded.addAll(_loadLegacyItems());
    }

    _replaceAll(loaded);

    if (loaded.isNotEmpty) {
      await _saveToDisk();
    }
  }

  List<SavedItemRecord> _loadLegacyItems() {
    final prefs = _prefs;
    if (prefs == null) return const <SavedItemRecord>[];

    final timestamps = _decodeTimestampMap(prefs.getString(_timestampKey));
    final records = <SavedItemRecord>[];

    void addLegacyItems(SavedItemType type, Iterable<String> ids) {
      final items = _itemsByType[type]!;
      for (final rawId in ids) {
        final id = rawId.trim();
        if (id.isEmpty || items.containsKey(id)) continue;
        final savedAt = timestamps[id] ?? DateTime.now();
        records.add(SavedItemRecord(type: type, id: id, savedAt: savedAt));
      }
    }

    addLegacyItems(
      SavedItemType.artwork,
      [
        ...(_decodeStringList(prefs.getStringList(_artworkKey))),
        ..._decodeJsonList(prefs.getString(_artworkKey)),
      ],
    );

    final postIds = <String>{
      ..._decodeStringList(prefs.getStringList(_postKey)),
      ..._decodeJsonList(prefs.getString(_postKey)),
      ..._decodeStringList(prefs.getStringList(_bookmarkKey)),
    };
    addLegacyItems(SavedItemType.post, postIds);

    return records;
  }

  List<SavedItemRecord> _decodeV2(String source) {
    try {
      final decoded = json.decode(source);
      if (decoded is! List) return const <SavedItemRecord>[];

      return decoded
          .whereType<Map>()
          .map((entry) => SavedItemRecord.fromJson(
                Map<String, dynamic>.from(entry),
              ))
          .where((record) => record.id.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <SavedItemRecord>[];
    }
  }

  Map<String, DateTime> _decodeTimestampMap(String? source) {
    if (source == null || source.trim().isEmpty) {
      return <String, DateTime>{};
    }

    try {
      final decoded = json.decode(source);
      if (decoded is! Map) return <String, DateTime>{};

      final result = <String, DateTime>{};
      decoded.forEach((key, value) {
        final id = key.toString().trim();
        if (id.isEmpty) return;
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) {
          result[id] = parsed;
        }
      });
      return result;
    } catch (_) {
      return <String, DateTime>{};
    }
  }

  List<String> _decodeStringList(List<String>? source) {
    if (source == null || source.isEmpty) return const <String>[];
    return source
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _decodeJsonList(String? source) {
    if (source == null || source.isEmpty) return const <String>[];
    try {
      final decoded = json.decode(source);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Ignore malformed payloads and fall back to empty state.
    }
    return const <String>[];
  }

  void _replaceAll(List<SavedItemRecord> records) {
    for (final type in SavedItemType.values) {
      _itemsByType[type]!.clear();
    }

    for (final record in records) {
      if (record.id.trim().isEmpty) continue;
      _itemsByType[record.type]![record.id] = record.savedAt;
    }
  }

  Future<void> _saveToDisk() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final records = _sortedRecords();

    await prefs.setString(
      _storageKeyV2,
      json.encode(records.map((record) => record.toJson()).toList()),
    );

    // Keep the legacy keys in sync so existing post artwork surfaces keep
    // reflecting bookmarks while the app migrates to the typed storage.
    await prefs.setStringList(
      _artworkKey,
      _idsForType(SavedItemType.artwork).toList(growable: false),
    );
    await prefs.setStringList(
      _postKey,
      _idsForType(SavedItemType.post).toList(growable: false),
    );
    await prefs.setStringList(
      _bookmarkKey,
      _idsForType(SavedItemType.post).toList(growable: false),
    );
    await prefs.setString(
      _timestampKey,
      json.encode(
        {
          for (final record in records)
            '${record.type.storageKey}:${record.id}':
                record.savedAt.toIso8601String(),
        },
      ),
    );
  }

  Future<void> _setSaved(
    SavedItemType type,
    String id,
    bool isSaved, {
    DateTime? timestamp,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return;

    final items = _itemsByType[type]!;
    if (isSaved) {
      items[normalizedId] = timestamp ?? items[normalizedId] ?? DateTime.now();
    } else {
      items.remove(normalizedId);
    }

    await _saveToDisk();
    notifyListeners();
  }

  /// Toggle artwork save status.
  Future<void> toggleArtworkSaved(String artworkId) async {
    await setArtworkSaved(artworkId, !isArtworkSaved(artworkId));
  }

  /// Explicitly set artwork save status.
  Future<void> setArtworkSaved(
    String artworkId,
    bool isSaved, {
    DateTime? timestamp,
  }) async {
    await _setSaved(
      SavedItemType.artwork,
      artworkId,
      isSaved,
      timestamp: timestamp,
    );
  }

  Future<void> toggleEventSaved(String eventId) async {
    await setEventSaved(eventId, !isEventSaved(eventId));
  }

  Future<void> setEventSaved(
    String eventId,
    bool isSaved, {
    DateTime? timestamp,
  }) async {
    await _setSaved(
      SavedItemType.event,
      eventId,
      isSaved,
      timestamp: timestamp,
    );
  }

  Future<void> toggleCollectionSaved(String collectionId) async {
    await setCollectionSaved(
      collectionId,
      !isCollectionSaved(collectionId),
    );
  }

  Future<void> setCollectionSaved(
    String collectionId,
    bool isSaved, {
    DateTime? timestamp,
  }) async {
    await _setSaved(
      SavedItemType.collection,
      collectionId,
      isSaved,
      timestamp: timestamp,
    );
  }

  Future<void> toggleExhibitionSaved(String exhibitionId) async {
    await setExhibitionSaved(
      exhibitionId,
      !isExhibitionSaved(exhibitionId),
    );
  }

  Future<void> setExhibitionSaved(
    String exhibitionId,
    bool isSaved, {
    DateTime? timestamp,
  }) async {
    await _setSaved(
      SavedItemType.exhibition,
      exhibitionId,
      isSaved,
      timestamp: timestamp,
    );
  }

  /// Toggle post save status.
  Future<void> togglePostSaved(String postId) async {
    await setPostSaved(postId, !isPostSaved(postId));
  }

  /// Explicitly set post save status (used by community bookmark flow).
  Future<void> setPostSaved(
    String postId,
    bool isSaved, {
    DateTime? timestamp,
  }) async {
    await _setSaved(
      SavedItemType.post,
      postId,
      isSaved,
      timestamp: timestamp,
    );
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
      _itemsByType[SavedItemType.post]!.containsKey(postId.trim());

  DateTime? getSavedTimestamp(
    String itemId, {
    SavedItemType? type,
  }) {
    final normalizedId = itemId.trim();
    if (normalizedId.isEmpty) return null;

    if (type != null) {
      return _itemsByType[type]![normalizedId];
    }

    DateTime? latest;
    for (final items in _itemsByType.values) {
      final savedAt = items[normalizedId];
      if (savedAt == null) continue;
      if (latest == null || savedAt.isAfter(latest)) {
        latest = savedAt;
      }
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
      getSavedTimestamp(postId, type: SavedItemType.post);

  Future<void> removeArtwork(String artworkId) async {
    await setArtworkSaved(artworkId, false);
  }

  Future<void> removeEvent(String eventId) async {
    await setEventSaved(eventId, false);
  }

  Future<void> removeCollection(String collectionId) async {
    await setCollectionSaved(collectionId, false);
  }

  Future<void> removeExhibition(String exhibitionId) async {
    await setExhibitionSaved(exhibitionId, false);
  }

  Future<void> removePost(String postId) async {
    await setPostSaved(postId, false);
  }

  Future<void> clearAllArtworks() async {
    await _clearType(SavedItemType.artwork);
  }

  Future<void> clearAllEvents() async {
    await _clearType(SavedItemType.event);
  }

  Future<void> clearAllCollections() async {
    await _clearType(SavedItemType.collection);
  }

  Future<void> clearAllExhibitions() async {
    await _clearType(SavedItemType.exhibition);
  }

  Future<void> clearAllPosts() async {
    await _clearType(SavedItemType.post);
  }

  Future<void> clearAll() async {
    for (final type in SavedItemType.values) {
      _itemsByType[type]!.clear();
    }
    await _saveToDisk();
    notifyListeners();
  }

  Future<void> _clearType(SavedItemType type) async {
    _itemsByType[type]!.clear();
    await _saveToDisk();
    notifyListeners();
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
    if (type != null) {
      return _sortedItemsForType(type);
    }
    return _sortedRecords();
  }

  Future<void> reloadFromDisk() async {
    await _loadSavedItems();
    notifyListeners();
  }

  int _countForType(SavedItemType type) => _itemsByType[type]!.length;

  Set<String> _idsForType(SavedItemType type) =>
      _itemsByType[type]!.keys.toSet();

  List<SavedItemRecord> _sortedItemsForType(SavedItemType type) {
    final items = _itemsByType[type]!;
    final records = items.entries
        .map(
          (entry) => SavedItemRecord(
            type: type,
            id: entry.key,
            savedAt: entry.value,
          ),
        )
        .toList(growable: false);
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
