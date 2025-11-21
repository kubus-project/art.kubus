import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/artwork.dart';
import '../models/artwork_comment.dart';
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
      // Load from API calls
      final artworks = _loadArtwork();
      _artworks.clear();
      _artworks.addAll(artworks as List<Artwork>);
      
      // Load some mock comments
      _loadArtworkComments();
      
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

void _loadArtworkComments() {
  // Placeholder to load some mock comments for artworks
}
  // In production, this would fetch comments from backend API
void _loadArtwork() {
  // Placeholder to load some mock comments for artworks
}