import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing saved/bookmarked items across the app
class SavedItemsProvider extends ChangeNotifier {
  static const _artworkKey = 'saved_artwork_ids';
  static const _postKey = 'saved_post_ids';
  static const _bookmarkKey = 'community_bookmarks';
  static const _timestampKey = 'saved_timestamps';

  final Set<String> _savedArtworkIds = {};
  final Set<String> _savedPostIds = {};
  final Map<String, DateTime> _savedTimestamps = {};
  
  bool _isInitialized = false;
  SharedPreferences? _prefs;

  Set<String> get savedArtworkIds => _savedArtworkIds;
  Set<String> get savedPostIds => _savedPostIds;
  
  int get savedArtworksCount => _savedArtworkIds.length;
  int get savedPostsCount => _savedPostIds.length;
  int get totalSavedCount => _savedArtworkIds.length + _savedPostIds.length;
  DateTime? get mostRecentSave {
    if (_savedTimestamps.isEmpty) return null;
    return _savedTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Initialize and load saved items from SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    await _loadSavedItems();
    _isInitialized = true;
    notifyListeners();
  }

  /// Load saved items from persistent storage
  Future<void> _loadSavedItems({bool resetExisting = true}) async {
    _prefs ??= await SharedPreferences.getInstance();

    if (resetExisting) {
      _savedArtworkIds.clear();
      _savedPostIds.clear();
      _savedTimestamps.clear();
    }

    final artworkList = _prefs?.getStringList(_artworkKey);
    final artworkIdsJson = _prefs?.getString(_artworkKey);
    final postList = _prefs?.getStringList(_postKey);
    final postIdsJson = _prefs?.getString(_postKey);
    final bookmarks = _prefs?.getStringList(_bookmarkKey) ?? const <String>[];
    final timestampsJson = _prefs?.getString(_timestampKey);

    _savedArtworkIds.addAll(
      artworkList ?? _decodeJsonList(artworkIdsJson),
    );

    final legacyPostIds = postList ?? _decodeJsonList(postIdsJson);
    final mergedPostIds = {...legacyPostIds, ...bookmarks};
    for (final id in mergedPostIds) {
      if (!_savedArtworkIds.contains(id)) {
        _savedPostIds.add(id);
      }
    }

    if (timestampsJson != null) {
      final Map<String, dynamic> timestamps = json.decode(timestampsJson);
      _savedTimestamps.addAll(
        timestamps.map((key, value) => MapEntry(key, DateTime.parse(value))),
      );
    }
  }

  /// Save items to persistent storage
  Future<void> _saveToDisk() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setStringList(_artworkKey, _savedArtworkIds.toList());
    await prefs.setStringList(_postKey, _savedPostIds.toList());
    await prefs.setStringList(_bookmarkKey, _savedPostIds.toList());
    await prefs.setString(
      _timestampKey,
      json.encode(
        _savedTimestamps.map((key, value) => MapEntry(key, value.toIso8601String())),
      ),
    );
  }

  /// Toggle artwork save status
  Future<void> toggleArtworkSaved(String artworkId) async {
    if (_savedArtworkIds.contains(artworkId)) {
      _savedArtworkIds.remove(artworkId);
      _savedTimestamps.remove(artworkId);
    } else {
      _savedArtworkIds.add(artworkId);
      _savedTimestamps[artworkId] = DateTime.now();
    }
    
    await _saveToDisk();
    notifyListeners();
  }

  /// Toggle post save status
  Future<void> togglePostSaved(String postId) async {
    final shouldSave = !_savedPostIds.contains(postId);
    await setPostSaved(postId, shouldSave);
  }

  /// Explicitly set post save status (used by community bookmark flow)
  Future<void> setPostSaved(String postId, bool isSaved, {DateTime? timestamp}) async {
    if (postId.isEmpty) return;

    if (isSaved && _savedArtworkIds.contains(postId)) {
      // Treat duplicates as artwork saves to avoid rendering the same item twice.
      _savedTimestamps[postId] = timestamp ?? DateTime.now();
      await _saveToDisk();
      notifyListeners();
      return;
    }

    if (isSaved) {
      _savedPostIds.add(postId);
      _savedTimestamps[postId] = timestamp ?? DateTime.now();
    } else {
      _savedPostIds.remove(postId);
      _savedTimestamps.remove(postId);
    }

    await _saveToDisk();
    notifyListeners();
  }

  /// Check if artwork is saved
  bool isArtworkSaved(String artworkId) {
    return _savedArtworkIds.contains(artworkId);
  }

  /// Check if post is saved
  bool isPostSaved(String postId) {
    return _savedPostIds.contains(postId);
  }

  /// Get timestamp when item was saved
  DateTime? getSavedTimestamp(String itemId) {
    return _savedTimestamps[itemId];
  }

  /// Remove artwork from saved items
  Future<void> removeArtwork(String artworkId) async {
    _savedArtworkIds.remove(artworkId);
    _savedTimestamps.remove(artworkId);
    await _saveToDisk();
    notifyListeners();
  }

  /// Remove post from saved items
  Future<void> removePost(String postId) async {
    _savedPostIds.remove(postId);
    _savedTimestamps.remove(postId);
    await _saveToDisk();
    notifyListeners();
  }

  /// Clear all saved artworks
  Future<void> clearAllArtworks() async {
    final artworkIds = _savedArtworkIds.toList();
    _savedArtworkIds.clear();
    for (final id in artworkIds) {
      _savedTimestamps.remove(id);
    }
    await _saveToDisk();
    notifyListeners();
  }

  /// Clear all saved posts
  Future<void> clearAllPosts() async {
    final postIds = _savedPostIds.toList();
    _savedPostIds.clear();
    for (final id in postIds) {
      _savedTimestamps.remove(id);
    }
    await _saveToDisk();
    notifyListeners();
  }

  /// Clear all saved items
  Future<void> clearAll() async {
    _savedArtworkIds.clear();
    _savedPostIds.clear();
    _savedTimestamps.clear();
    await _saveToDisk();
    notifyListeners();
  }

  /// Get saved items sorted by timestamp (most recent first)
  List<String> getSortedSavedIds({String? type}) {
    Set<String> ids;
    
    switch (type) {
      case 'artwork':
        ids = _savedArtworkIds;
        break;
      case 'post':
        ids = _savedPostIds;
        break;
      default:
        ids = {..._savedArtworkIds, ..._savedPostIds};
    }
    
    final sortedIds = ids.toList();
    sortedIds.sort((a, b) {
      final timestampA = _savedTimestamps[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timestampB = _savedTimestamps[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timestampB.compareTo(timestampA); // Most recent first
    });
    
    return sortedIds;
  }

  /// Force reload from disk (useful after external updates)
  Future<void> reloadFromDisk() async {
    await _loadSavedItems();
    notifyListeners();
  }

  List<String> _decodeJsonList(String? source) {
    if (source == null || source.isEmpty) return const [];
    try {
      final decoded = json.decode(source);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // Ignore malformed payloads and fall back to empty state.
    }
    return const [];
  }
}
