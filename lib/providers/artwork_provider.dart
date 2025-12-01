import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artwork.dart';
import '../models/artwork_comment.dart';
import '../services/ar_content_service.dart';
import '../services/backend_api_service.dart';
import '../services/user_action_logger.dart';
import 'task_provider.dart';
import 'saved_items_provider.dart';

class ArtworkProvider extends ChangeNotifier {
  final List<Artwork> _artworks = [];
  final Map<String, List<ArtworkComment>> _comments = {};
  final Map<String, bool> _loadingStates = {};
  String? _error;
  TaskProvider? _taskProvider;
  SavedItemsProvider? _savedItemsProvider;
  bool _useMockData = false;
  final BackendApiService _backendApi = BackendApiService();
  static const String _viewHistoryPrefsKey = 'artwork_view_history_v1';
  final List<ViewHistoryEntry> _viewHistory = <ViewHistoryEntry>[];
  bool _historyLoaded = false;

  List<Artwork> get artworks => List.unmodifiable(_artworks);
  String? get error => _error;
  
  bool isLoading(String operation) => _loadingStates[operation] ?? false;

  /// Set SavedItemsProvider reference
  void setSavedItemsProvider(SavedItemsProvider provider) {
    _savedItemsProvider = provider;
  }

  /// Set mock data usage
  void setUseMockData(bool useMockData) {
    if (_useMockData != useMockData) {
      _useMockData = useMockData;
      if (useMockData) {
        loadArtworks();
      } else {
        _artworks.clear();
        _comments.clear();
        notifyListeners();
      }
    }
  }

  /// Set the task provider for tracking user actions
  void setTaskProvider(TaskProvider taskProvider) {
    _taskProvider = taskProvider;
  }

  /// Get artwork by ID
  Artwork? getArtworkById(String id) {
    try {
      return _artworks.firstWhere((artwork) => artwork.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get artworks near a location
  List<Artwork> getArtworksNear(LatLng location, {double radiusMeters = 1000}) {
    return _artworks.where((artwork) {
      final distance = artwork.getDistanceFrom(location);
      return distance <= radiusMeters;
    }).toList();
  }

  /// Get discovered artworks
  List<Artwork> get discoveredArtworks {
    return _artworks.where((artwork) => artwork.isDiscovered).toList();
  }

  /// Get favorite artworks
  List<Artwork> get favoriteArtworks {
    return _artworks.where((artwork) => artwork.isFavorite).toList();
  }

  /// Get user's own artworks (created by current user)
  List<Artwork> get userArtworks {
    // For now, return discovered and favorite artworks as user's collection
    // In a real app, this would filter by creator/owner ID
    return _artworks.where((artwork) => artwork.isDiscovered || artwork.isFavorite).toList();
  }

  /// Get artworks by rarity
  List<Artwork> getArtworksByRarity(ArtworkRarity rarity) {
    return _artworks.where((artwork) => artwork.rarity == rarity).toList();
  }

  /// Get artworks by category
  List<Artwork> getArtworksByCategory(String category) {
    return _artworks.where((artwork) => artwork.category == category).toList();
  }

  /// Add or update artwork
  void addOrUpdateArtwork(Artwork artwork) {
    final index = _artworks.indexWhere((a) => a.id == artwork.id);
    if (index >= 0) {
      _artworks[index] = artwork;
    } else {
      _artworks.add(artwork);
    }
    notifyListeners();
  }

  /// Create a brand-new artwork with optional AR assets
  Future<Artwork?> createArtwork({
    required String title,
    required String description,
    required LatLng position,
    required String artistName,
    required ArtworkRarity rarity,
    required int rewards,
    required Uint8List coverImageBytes,
    required String coverImageFilename,
    List<String> tags = const [],
    String category = 'General',
    bool isPublic = true,
    bool arEnabled = true,
    Uint8List? modelBytes,
    String? modelFilename,
    double modelScale = 1.0,
    Map<String, dynamic>? metadata,
  }) async {
    if (arEnabled && (modelBytes == null || modelFilename == null)) {
      throw ArgumentError('AR-enabled artworks require a 3D asset.');
    }

    const operation = 'create_artwork';
    _setLoading(operation, true);
    try {
      final coverUrl = await ARContentService.uploadToHTTP(
        coverImageBytes,
        coverImageFilename,
        metadata: {
          'type': 'artwork_cover',
          'title': title,
        },
      );

      String? modelCid;
      String? modelUrl;
      if (arEnabled) {
        final uploadResult = await ARContentService.uploadContent(
          modelBytes!,
          modelFilename!,
          metadata: {
            'type': 'ar_model',
            'title': title,
            'artist': artistName,
          },
        );
        modelCid = uploadResult['cid'];
        modelUrl = uploadResult['url'];
      }

      final artwork = Artwork(
        id: 'artwork_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        artist: artistName,
        description: description,
        imageUrl: coverUrl,
        position: position,
        rarity: rarity,
        status: ArtworkStatus.undiscovered,
        arEnabled: arEnabled && (modelCid != null || modelUrl != null),
        rewards: rewards,
        createdAt: DateTime.now(),
        arScale: arEnabled ? modelScale : null,
        model3DCID: modelCid,
        model3DURL: modelUrl,
        tags: tags,
        category: category,
        metadata: {
          'isPublic': isPublic,
          'createdFrom': 'artist_studio',
          if (metadata != null) ...metadata,
        },
      );

      addOrUpdateArtwork(artwork);
      return artwork;
    } catch (e) {
      _setError('Failed to create artwork: $e');
      return null;
    } finally {
      _setLoading(operation, false);
    }
  }

  /// Remove artwork
  void removeArtwork(String artworkId) {
    _artworks.removeWhere((artwork) => artwork.id == artworkId);
    _comments.remove(artworkId);
    notifyListeners();
  }

  /// Like/Unlike artwork
  Future<void> toggleLike(String artworkId) async {
    _setLoading('like_$artworkId', true);
    try {
      final artwork = getArtworkById(artworkId);
      if (artwork != null) {
        final wasLiked = artwork.isLikedByCurrentUser;
        final updatedArtwork = artwork.copyWith(
          isLikedByCurrentUser: !artwork.isLikedByCurrentUser,
          likesCount: artwork.isLikedByCurrentUser 
              ? artwork.likesCount - 1 
              : artwork.likesCount + 1,
        );
        addOrUpdateArtwork(updatedArtwork);
        
        // Track like action for tasks
        if (!wasLiked && _taskProvider != null) {
          _taskProvider!.trackArtworkLike(artworkId);
        }

        if (!wasLiked) {
          UserActionLogger.logArtworkLike(
            artworkId: artwork.id,
            artworkTitle: artwork.title,
            artistName: artwork.artist,
          );
        }
        
        // Sync with backend (fire-and-forget - don't block UI)
        _syncLikeWithBackend(artworkId, !wasLiked).catchError((e) {
          debugPrint('Failed to sync like with backend: $e');
        });
        await _simulateApiDelay();
      }
    } catch (e) {
      _setError('Failed to toggle like: $e');
    } finally {
      _setLoading('like_$artworkId', false);
    }
  }

  /// Add artwork to favorites
  Future<void> toggleFavorite(String artworkId) async {
    _setLoading('favorite_$artworkId', true);
    try {
      final artwork = getArtworkById(artworkId);
      if (artwork != null) {
        final isAddingToFavorites = !artwork.isFavoriteByCurrentUser;
        final newStatus = artwork.isFavorite 
            ? ArtworkStatus.discovered 
            : ArtworkStatus.favorite;
        
        final updatedArtwork = artwork.copyWith(
          status: newStatus,
          isFavoriteByCurrentUser: !artwork.isFavoriteByCurrentUser,
        );
        addOrUpdateArtwork(updatedArtwork);
        
        // Sync with SavedItemsProvider
        if (_savedItemsProvider != null) {
          await _savedItemsProvider!.toggleArtworkSaved(artworkId);
        }
        
        // Track favorite action for tasks
        if (_taskProvider != null && isAddingToFavorites) {
          _taskProvider!.trackArtworkFavorite(artworkId);
        }

        if (isAddingToFavorites) {
          UserActionLogger.logArtworkSave(
            artworkId: artwork.id,
            artworkTitle: artwork.title,
            artistName: artwork.artist,
          );
        }
        
        // Sync with backend (fire-and-forget)
        _syncFavoriteWithBackend(artworkId, isAddingToFavorites).catchError((e) {
          debugPrint('Failed to sync favorite with backend: $e');
        });
        await _simulateApiDelay();
      }
    } catch (e) {
      _setError('Failed to toggle favorite: $e');
    } finally {
      _setLoading('favorite_$artworkId', false);
    }
  }

  /// Mark artwork as discovered
  Future<void> discoverArtwork(String artworkId, String userId) async {
    _setLoading('discover_$artworkId', true);
    try {
      final artwork = getArtworkById(artworkId);
      if (artwork != null && !artwork.isDiscovered) {
        final updatedArtwork = artwork.copyWith(
          status: ArtworkStatus.discovered,
          discoveredAt: DateTime.now(),
          discoveryUserId: userId,
          discoveryCount: artwork.discoveryCount + 1,
        );
        addOrUpdateArtwork(updatedArtwork);
        
        // Auto-save discovered artwork
        if (_savedItemsProvider != null && !_savedItemsProvider!.isArtworkSaved(artworkId)) {
          await _savedItemsProvider!.toggleArtworkSaved(artworkId);
        }
        
        // Track artwork visit for tasks
        if (_taskProvider != null) {
          _taskProvider!.trackArtworkVisit(artworkId);
        }
        
        // Sync with backend and potentially award discovery tokens
        _syncDiscoveryWithBackend(artworkId, userId).then((_) {
          // Award KUB8 tokens for first discovery (handled by achievement system)
          debugPrint('Artwork $artworkId discovered by $userId');
        }).catchError((e) {
          debugPrint('Failed to sync discovery with backend: $e');
        });
        await _simulateApiDelay();
      }
    } catch (e) {
      _setError('Failed to discover artwork: $e');
    } finally {
      _setLoading('discover_$artworkId', false);
    }
  }

  /// Increment view count
  Future<void> incrementViewCount(String artworkId) async {
    try {
      final artwork = getArtworkById(artworkId);
      if (artwork != null) {
        final updatedArtwork = artwork.copyWith(
          viewsCount: artwork.viewsCount + 1,
        );
        addOrUpdateArtwork(updatedArtwork);
        await _recordViewHistory(updatedArtwork);
        
        // Track artwork visit for tasks (first time only per session)
        if (_taskProvider != null) {
          _taskProvider!.trackArtworkVisit(artworkId);
        }
        
        // Sync with backend quietly (fire-and-forget, no error propagation)
        _syncViewCountWithBackend(artworkId).catchError((e) {
          // Silent fail - view counting is not critical
        });
      }
    } catch (e) {
      // Silent fail for view counting
      debugPrint('Failed to increment view count: $e');
    }
  }

  /// Get comments for artwork
  List<ArtworkComment> getComments(String artworkId) {
    return _comments[artworkId] ?? [];
  }

  /// Add comment to artwork
  Future<void> addComment(String artworkId, String content, String userId, String userName) async {
    _setLoading('comment_$artworkId', true);
    try {
      final newComment = ArtworkComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        artworkId: artworkId,
        userId: userId,
        userName: userName,
        content: content,
        createdAt: DateTime.now(),
      );

      if (_comments[artworkId] == null) {
        _comments[artworkId] = [];
      }
      _comments[artworkId]!.insert(0, newComment);

      // Update artwork comment count
      final artwork = getArtworkById(artworkId);
      if (artwork != null) {
        final updatedArtwork = artwork.copyWith(
          commentsCount: artwork.commentsCount + 1,
        );
        addOrUpdateArtwork(updatedArtwork);
      }

      notifyListeners();
      
      // Sync with backend
      await _syncCommentWithBackend(artworkId, newComment).catchError((e) {
        debugPrint('Failed to sync comment with backend: $e');
        // Comment is still saved locally
      });
      await _simulateApiDelay();

      // Track comment interaction for achievements/tasks
      if (_taskProvider != null) {
        _taskProvider!.trackArtworkComment(artworkId);
      }
    } catch (e) {
      _setError('Failed to add comment: $e');
    } finally {
      _setLoading('comment_$artworkId', false);
    }
  }

  /// Like/Unlike comment
  Future<void> toggleCommentLike(String artworkId, String commentId) async {
    try {
      final comments = _comments[artworkId];
      if (comments != null) {
        final commentIndex = comments.indexWhere((c) => c.id == commentId);
        if (commentIndex >= 0) {
          final comment = comments[commentIndex];
          final updatedComment = comment.copyWith(
            isLikedByCurrentUser: !comment.isLikedByCurrentUser,
            likesCount: comment.isLikedByCurrentUser 
                ? comment.likesCount - 1 
                : comment.likesCount + 1,
          );
          comments[commentIndex] = updatedComment;
          notifyListeners();
          
          // Sync with backend (fire-and-forget)
          _syncCommentLikeWithBackend(artworkId, commentId, updatedComment.isLikedByCurrentUser)
            .catchError((e) => debugPrint('Failed to sync comment like: $e'));
          await _simulateApiDelay();
        }
      }
    } catch (e) {
      _setError('Failed to toggle comment like: $e');
    }
  }

  /// Load initial artworks
  Future<void> loadArtworks() async {

    _setLoading('load_artworks', true);
    
    try {
      final artworks = await _backendApi.getArtworks(limit: 100);
      _artworks
        ..clear()
        ..addAll(artworks);
      _comments.clear();

      notifyListeners();
      await _simulateApiDelay();
    } catch (e) {
      _setError('Failed to load artworks: $e');
    } finally {
      _setLoading('load_artworks', false);
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> ensureHistoryLoaded() async {
    if (_historyLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_viewHistoryPrefsKey) ?? <String>[];
      _viewHistory
        ..clear()
        ..addAll(raw.map((item) {
          try {
            final map = jsonDecode(item);
            if (map is Map<String, dynamic>) {
              return ViewHistoryEntry.fromJson(map);
            }
          } catch (_) {}
          return null;
        }).whereType<ViewHistoryEntry>());
      _historyLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('ArtworkProvider.ensureHistoryLoaded error: $e');
      _historyLoaded = true;
    }
  }

  List<ViewHistoryEntry> get viewHistoryEntries => List.unmodifiable(_viewHistory);

  List<Artwork> getViewHistoryArtworks() {
    return _viewHistory
        .map((entry) => getArtworkById(entry.artworkId))
        .whereType<Artwork>()
        .toList();
  }

  Future<void> clearViewHistory() async {
    await ensureHistoryLoaded();
    _viewHistory.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_viewHistoryPrefsKey);
    } catch (_) {}
  }

  Future<void> _recordViewHistory(Artwork artwork) async {
    await ensureHistoryLoaded();
    _viewHistory.removeWhere((entry) => entry.artworkId == artwork.id);
    _viewHistory.insert(
      0,
      ViewHistoryEntry(
        artworkId: artwork.id,
        viewedAt: DateTime.now(),
        markerId: artwork.arMarkerId,
      ),
    );
    if (_viewHistory.length > 60) {
      _viewHistory.removeRange(60, _viewHistory.length);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _viewHistoryPrefsKey,
        _viewHistory.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (_) {}

    try {
      await UserActionLogger.logArtworkView(
        artworkId: artwork.id,
        artworkTitle: artwork.title,
        markerId: artwork.arMarkerId,
      );
    } catch (_) {}

    notifyListeners();
  }

  void _setLoading(String operation, bool loading) {
    _loadingStates[operation] = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  Future<void> _simulateApiDelay() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ===========================================
  // BACKEND SYNC METHODS
  // ===========================================
  
  /// Sync like action with backend (fire-and-forget)
  Future<void> _syncLikeWithBackend(String artworkId, bool isLiked) async {
    // In production: Call BackendApiService().likeArtwork(artworkId, isLiked)
    // For now: Placeholder that simulates backend call
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('Backend sync: Artwork $artworkId ${isLiked ? "liked" : "unliked"}');
  }
  
  /// Sync favorite action with backend
  Future<void> _syncFavoriteWithBackend(String artworkId, bool isFavorite) async {
    // In production: Call BackendApiService().favoriteArtwork(artworkId, isFavorite)
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('Backend sync: Artwork $artworkId ${isFavorite ? "favorited" : "unfavorited"}');
  }
  
  /// Sync discovery with backend and trigger achievement check
  Future<void> _syncDiscoveryWithBackend(String artworkId, String userId) async {
    // In production: Call BackendApiService().discoverArtwork(artworkId)
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('Backend sync: Artwork $artworkId discovered by $userId');
  }
  
  /// Sync view count increment with backend (silent)
  Future<void> _syncViewCountWithBackend(String artworkId) async {
    // In production: Call BackendApiService().incrementViewCount(artworkId)
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  /// Sync comment with backend
  Future<void> _syncCommentWithBackend(String artworkId, ArtworkComment comment) async {
    // In production: Call BackendApiService().addComment(artworkId, comment)
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('Backend sync: Comment added to artwork $artworkId');
  }
  
  /// Sync comment like with backend
  Future<void> _syncCommentLikeWithBackend(String artworkId, String commentId, bool isLiked) async {
    // In production: Call BackendApiService().likeComment(artworkId, commentId, isLiked)
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

class ViewHistoryEntry {
  final String artworkId;
  final DateTime viewedAt;
  final String? markerId;

  const ViewHistoryEntry({
    required this.artworkId,
    required this.viewedAt,
    this.markerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'artworkId': artworkId,
      'viewedAt': viewedAt.toIso8601String(),
      if (markerId != null) 'markerId': markerId,
    };
  }

  factory ViewHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ViewHistoryEntry(
      artworkId: json['artworkId']?.toString() ?? '',
      viewedAt: DateTime.tryParse(json['viewedAt']?.toString() ?? '') ?? DateTime.now(),
      markerId: json['markerId']?.toString(),
    );
  }
}
