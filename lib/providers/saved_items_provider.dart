import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Provider for managing saved/bookmarked items across the app
class SavedItemsProvider extends ChangeNotifier {
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

  /// Initialize and load saved items from SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    await _loadSavedItems();
    _isInitialized = true;
    notifyListeners();
  }

  /// Load saved items from persistent storage
  Future<void> _loadSavedItems() async {
    final artworkIdsJson = _prefs?.getString('saved_artwork_ids');
    final postIdsJson = _prefs?.getString('saved_post_ids');
    final timestampsJson = _prefs?.getString('saved_timestamps');
    
    if (artworkIdsJson != null) {
      final List<dynamic> artworkIds = json.decode(artworkIdsJson);
      _savedArtworkIds.addAll(artworkIds.cast<String>());
    }
    
    if (postIdsJson != null) {
      final List<dynamic> postIds = json.decode(postIdsJson);
      _savedPostIds.addAll(postIds.cast<String>());
    }
    
    if (timestampsJson != null) {
      final Map<String, dynamic> timestamps = json.decode(timestampsJson);
      _savedTimestamps.addAll(
        timestamps.map((key, value) => MapEntry(key, DateTime.parse(value)))
      );
    }
  }

  /// Save items to persistent storage
  Future<void> _saveToDisk() async {
    await _prefs?.setString('saved_artwork_ids', json.encode(_savedArtworkIds.toList()));
    await _prefs?.setString('saved_post_ids', json.encode(_savedPostIds.toList()));
    await _prefs?.setString('saved_timestamps', json.encode(
      _savedTimestamps.map((key, value) => MapEntry(key, value.toIso8601String()))
    ));
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
    if (_savedPostIds.contains(postId)) {
      _savedPostIds.remove(postId);
      _savedTimestamps.remove(postId);
    } else {
      _savedPostIds.add(postId);
      _savedTimestamps[postId] = DateTime.now();
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
    _savedArtworkIds.clear();
    for (var id in _savedArtworkIds.toList()) {
      _savedTimestamps.remove(id);
    }
    await _saveToDisk();
    notifyListeners();
  }

  /// Clear all saved posts
  Future<void> clearAllPosts() async {
    _savedPostIds.clear();
    for (var id in _savedPostIds.toList()) {
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
}
