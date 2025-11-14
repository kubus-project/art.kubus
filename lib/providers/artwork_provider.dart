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

  /// Load initial artworks (mock data for now)
  Future<void> loadArtworks() async {
    if (!_useMockData) return; // Only load if mock data is enabled
    
    _setLoading('load_artworks', true);
    try {
      // Mock data - replace with actual API calls
      final mockArtworks = _generateMockArtworks();
      _artworks.clear();
      _artworks.addAll(mockArtworks);
      
      // Load some mock comments
      _loadMockComments();
      
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

  List<Artwork> _generateMockArtworks() {
    return [
      Artwork(
        id: '1',
        title: 'Digital Sculpture #1',
        artist: 'CryptoArtist',
        description: 'An interactive digital sculpture that responds to touch and sound.',
        position: const LatLng(46.0569, 14.5058),
        rarity: ArtworkRarity.rare,
        status: ArtworkStatus.undiscovered,
        arEnabled: true,
        rewards: 150,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        likesCount: 234,
        commentsCount: 12,
        viewsCount: 1500,
        discoveryCount: 8,
        tags: ['digital', 'sculpture', 'interactive'],
        category: 'AR Sculpture',
        averageRating: 4.2,
        ratingsCount: 15,
      ),
      Artwork(
        id: '2',
        title: 'Neon Dreams',
        artist: 'VirtualVisionary',
        description: 'A mesmerizing neon light installation that pulses with the city\'s rhythm.',
        position: const LatLng(46.0469, 14.5158),
        rarity: ArtworkRarity.epic,
        status: ArtworkStatus.discovered,
        arEnabled: true,
        rewards: 300,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        discoveredAt: DateTime.now().subtract(const Duration(days: 5)),
        discoveryUserId: 'user123',
        likesCount: 567,
        commentsCount: 34,
        viewsCount: 3200,
        discoveryCount: 23,
        isLikedByCurrentUser: true,
        tags: ['neon', 'light', 'installation'],
        category: 'Interactive Art',
        averageRating: 4.7,
        ratingsCount: 28,
      ),
      Artwork(
        id: '3',
        title: 'Quantum Canvas',
        artist: 'PixelPioneer',
        description: 'A constantly evolving digital painting that changes based on quantum data.',
        position: const LatLng(46.0469, 14.5038),
        rarity: ArtworkRarity.common,
        status: ArtworkStatus.undiscovered,
        arEnabled: false,
        rewards: 75,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        likesCount: 123,
        commentsCount: 21,
        viewsCount: 890,
        discoveryCount: 12,
        tags: ['digital', 'painting', 'quantum'],
        category: 'Digital Painting',
        averageRating: 4.0,
        ratingsCount: 31,
      ),
      Artwork(
        id: '4',
        title: 'Holographic Garden',
        artist: 'NatureCode',
        description: 'Experience a holographic garden that blooms as you explore.',
        position: const LatLng(46.0599, 14.5058),
        rarity: ArtworkRarity.legendary,
        status: ArtworkStatus.undiscovered,
        arEnabled: true,
        rewards: 500,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        likesCount: 789,
        commentsCount: 45,
        viewsCount: 4500,
        discoveryCount: 5,
        tags: ['holographic', 'nature', 'immersive'],
        category: 'AR Experience',
        averageRating: 4.9,
        ratingsCount: 67,
      ),
      Artwork(
        id: '5',
        title: 'Sound Waves',
        artist: 'AudioVisual',
        description: 'Visualize sound as colorful waves that dance around you.',
        position: const LatLng(46.0579, 14.5078),
        rarity: ArtworkRarity.rare,
        status: ArtworkStatus.discovered,
        arEnabled: true,
        rewards: 200,
        createdAt: DateTime.now().subtract(const Duration(days: 35)),
        discoveredAt: DateTime.now().subtract(const Duration(days: 10)),
        discoveryUserId: 'user123',
        likesCount: 456,
        commentsCount: 28,
        viewsCount: 2100,
        discoveryCount: 15,
        isLikedByCurrentUser: false,
        tags: ['audio', 'visual', 'interactive'],
        category: 'Interactive Art',
        averageRating: 4.5,
        ratingsCount: 42,
      ),
    ];
  }

  void _loadMockComments() {
    _comments['1'] = [
      ArtworkComment(
        id: 'c1',
        artworkId: '1',
        userId: 'user456',
        userName: 'Sarah Johnson',
        content: 'This is absolutely beautiful! The way technology and nature blend together is mesmerizing.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likesCount: 5,
      ),
      ArtworkComment(
        id: 'c2',
        artworkId: '1',
        userId: 'user789',
        userName: 'Mike Wilson',
        content: 'Love the AR integration! Really makes the piece come alive.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        likesCount: 3,
        isLikedByCurrentUser: true,
      ),
    ];

    _comments['2'] = [
      ArtworkComment(
        id: 'c3',
        artworkId: '2',
        userId: 'user101',
        userName: 'Emma Davis',
        content: 'The colors are so vibrant! This brightens up the whole street.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        likesCount: 8,
      ),
    ];
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
