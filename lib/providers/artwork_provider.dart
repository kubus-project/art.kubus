import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artwork.dart';
import '../models/artwork_comment.dart';
import '../services/ar_content_service.dart';
import '../services/art_content_service.dart';
import '../services/backend_api_service.dart';
import '../services/user_action_logger.dart';
import '../utils/wallet_utils.dart';
import 'saved_items_provider.dart';

class ArtworkProvider extends ChangeNotifier {
  final List<Artwork> _artworks = [];
  final Map<String, Artwork> _artworkById = <String, Artwork>{};
  final Map<String, List<ArtworkComment>> _comments = {};
  final Map<String, String?> _commentLoadErrors = <String, String?>{};
  final Map<String, String?> _commentSubmitErrors = <String, String?>{};
  final Map<String, bool> _loadingStates = {};
  final Set<String> _walletsWithPrivateArtworks = <String>{};
  final Set<String> _walletsWithPublicArtworks = <String>{};
  String? _error;
  SavedItemsProvider? _savedItemsProvider;
  final ArtworkBackendApi _backendApi;
  final Map<String, Future<Artwork>> _inFlightArtworkFetches =
      <String, Future<Artwork>>{};
  static const String _viewHistoryPrefsKey = 'artwork_view_history_v1';
  final List<ViewHistoryEntry> _viewHistory = <ViewHistoryEntry>[];
  bool _historyLoaded = false;

  ArtworkProvider({ArtworkBackendApi? backendApi})
      : _backendApi = backendApi ?? BackendApiService();

  List<Artwork> get artworks => List.unmodifiable(_artworks);
  String? get error => _error;

  bool isLoading(String operation) => _loadingStates[operation] ?? false;

  /// Bind the saved-items provider.
  void bindSavedItemsProvider(SavedItemsProvider provider) {
    if (identical(_savedItemsProvider, provider)) return;
    _savedItemsProvider = provider;
    _reconcileSavedBookmarkState();
  }

  /// Get artwork by ID
  Artwork? getArtworkById(String id) => _artworkById[id];

  /// Ensure artwork exists locally by fetching from backend if needed
  Future<Artwork?> fetchArtworkIfNeeded(String artworkId) async {
    final existing = getArtworkById(artworkId);
    if (existing != null) return existing;

    final key = artworkId.trim();
    if (key.isEmpty) return null;
    final inflight = _inFlightArtworkFetches[key];
    if (inflight != null) {
      return inflight;
    }

    try {
      final future = _backendApi.getArtwork(key).then((fetched) {
        addOrUpdateArtwork(fetched);
        return fetched;
      });
      _inFlightArtworkFetches[key] = future;
      return await future;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ArtworkProvider: fetchArtworkIfNeeded error: $e');
      }
      rethrow;
    } finally {
      _inFlightArtworkFetches.remove(key);
    }
  }

  /// Force-refresh a single artwork from the backend and update local cache.
  Future<Artwork?> refreshArtwork(String artworkId) async {
    final key = artworkId.trim();
    if (key.isEmpty) return null;

    final operation = 'refresh_artwork_$key';
    if (isLoading(operation)) return getArtworkById(key);

    _setLoading(operation, true);
    try {
      final fetched = await _backendApi.getArtwork(key);
      addOrUpdateArtwork(fetched);
      return fetched;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ArtworkProvider: refreshArtwork failed: $e');
      }
      rethrow;
    } finally {
      _setLoading(operation, false);
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
    return _artworks
        .where(
            (artwork) => artwork.isFavoriteByCurrentUser || artwork.isFavorite)
        .toList();
  }

  /// Get user's own artworks (created by current user)
  List<Artwork> get userArtworks {
    if (_walletsWithPrivateArtworks.isNotEmpty) {
      return artworksForWallet(_walletsWithPrivateArtworks.last);
    }
    if (_walletsWithPublicArtworks.isNotEmpty) {
      return artworksForWallet(_walletsWithPublicArtworks.last);
    }
    return const <Artwork>[];
  }

  List<Artwork> artworksForWallet(String walletAddress) {
    final normalizedWallet = WalletUtils.normalize(walletAddress);
    if (normalizedWallet.isEmpty) {
      return const <Artwork>[];
    }

    final matches = _artworks.where((artwork) {
      final artworkWallet = WalletUtils.normalize(artwork.walletAddress);
      return artworkWallet == normalizedWallet;
    }).toList(growable: false);

    matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  /// Get artworks by category
  List<Artwork> getArtworksByCategory(String category) {
    return _artworks.where((artwork) => artwork.category == category).toList();
  }

  /// Add or update artwork
  void addOrUpdateArtwork(Artwork artwork) {
    final nextArtwork = _mergeSavedBookmarkState(artwork);
    final index = _artworks.indexWhere((a) => a.id == artwork.id);
    if (index >= 0) {
      _artworks[index] = nextArtwork;
    } else {
      _artworks.add(nextArtwork);
    }
    _artworkById[nextArtwork.id] = nextArtwork;
    notifyListeners();
  }

  /// Create a brand-new artwork with optional AR assets
  Future<Artwork?> createArtwork({
    required String title,
    required String description,
    required LatLng position,
    required String artistName,
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
      final coverUrl = await ArtContentService.uploadMedia(
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
    _artworkById.remove(artworkId);
    _comments.remove(artworkId);
    notifyListeners();
  }

  Future<Artwork?> publishArtwork(String artworkId) async {
    final operation = 'publish_artwork_$artworkId';
    _setLoading(operation, true);
    try {
      final updated = await _backendApi.publishArtwork(artworkId);
      if (updated != null) {
        addOrUpdateArtwork(updated);
        return updated;
      }

      // Backend returned null even though request succeeded (sparse/empty response).
      // Try to refresh the artwork to verify the publish worked.
      try {
        final refreshed = await _backendApi.getArtwork(artworkId);
        addOrUpdateArtwork(refreshed);
        return refreshed;
      } catch (_) {
        // Refresh failed. Check if we have a cached artwork and update it optimistically.
        final cached = getArtworkById(artworkId);
        if (cached != null) {
          // Return optimistically updated artwork (marked as public)
          final optimistic = cached.copyWith(isPublic: true);
          addOrUpdateArtwork(optimistic);
          return optimistic;
        }
        // No cached artwork; backend likely succeeded but we can't verify
        return null;
      }
    } catch (e) {
      _setError('Failed to publish artwork: $e');
      return null;
    } finally {
      _setLoading(operation, false);
    }
  }

  Future<Artwork?> unpublishArtwork(String artworkId) async {
    final operation = 'unpublish_artwork_$artworkId';
    _setLoading(operation, true);
    try {
      final updated = await _backendApi.unpublishArtwork(artworkId);
      if (updated != null) {
        addOrUpdateArtwork(updated);
        return updated;
      }

      // Backend returned null even though request succeeded (sparse/empty response).
      // Try to refresh the artwork to verify the unpublish worked.
      try {
        final refreshed = await _backendApi.getArtwork(artworkId);
        addOrUpdateArtwork(refreshed);
        return refreshed;
      } catch (_) {
        // Refresh failed. Check if we have a cached artwork and update it optimistically.
        final cached = getArtworkById(artworkId);
        if (cached != null) {
          // Return optimistically updated artwork (marked as not public)
          final optimistic = cached.copyWith(isPublic: false);
          addOrUpdateArtwork(optimistic);
          return optimistic;
        }
        // No cached artwork; backend likely succeeded but we can't verify
        return null;
      }
    } catch (e) {
      _setError('Failed to unpublish artwork: $e');
      return null;
    } finally {
      _setLoading(operation, false);
    }
  }

  Future<Artwork?> updateArtwork(
      String artworkId, Map<String, dynamic> updates) async {
    final id = artworkId.trim();
    if (id.isEmpty) return null;
    final operation = 'update_artwork_$id';
    if (isLoading(operation)) return null;
    _setLoading(operation, true);
    try {
      final updated = await _backendApi.updateArtwork(id, updates);
      if (updated != null) {
        addOrUpdateArtwork(updated);
        return updated;
      }
      try {
        final refreshed = await _backendApi.getArtwork(id);
        addOrUpdateArtwork(refreshed);
        return refreshed;
      } catch (_) {
        final cached = getArtworkById(id);
        if (cached != null) {
          return cached;
        }
      }
      return null;
    } catch (e) {
      _setError('Failed to update artwork: $e');
      return null;
    } finally {
      _setLoading(operation, false);
    }
  }

  /// Like/Unlike artwork
  Future<void> toggleLike(String artworkId) async {
    _setLoading('like_$artworkId', true);
    try {
      final artwork = getArtworkById(artworkId);
      if (artwork != null) {
        final wasLiked = artwork.isLikedByCurrentUser;
        final original = artwork;
        final updatedArtwork = artwork.copyWith(
          isLikedByCurrentUser: !artwork.isLikedByCurrentUser,
          likesCount: artwork.isLikedByCurrentUser
              ? artwork.likesCount - 1
              : artwork.likesCount + 1,
        );
        addOrUpdateArtwork(updatedArtwork);

        if (!wasLiked) {
          UserActionLogger.logArtworkLike(
            artworkId: artwork.id,
            artworkTitle: artwork.title,
            artistName: artwork.artist,
          );
        }

        // Sync with backend and reconcile count.
        try {
          final updatedCount = (!wasLiked)
              ? await _backendApi.likeArtwork(artworkId)
              : await _backendApi.unlikeArtwork(artworkId);

          if (updatedCount != null) {
            final latest = getArtworkById(artworkId);
            if (latest != null) {
              addOrUpdateArtwork(latest.copyWith(likesCount: updatedCount));
            }
          }
        } catch (e) {
          // Rollback optimistic state on failure.
          addOrUpdateArtwork(original);
          rethrow;
        }
      }
    } catch (e) {
      _setError('Failed to toggle like: $e');
    } finally {
      _setLoading('like_$artworkId', false);
    }
  }

  /// Toggle artwork bookmark state.
  Future<void> toggleArtworkSaved(String artworkId) async {
    final id = artworkId.trim();
    if (id.isEmpty) return;

    _setLoading('save_$id', true);
    final savedProvider = _savedItemsProvider;
    final artwork = getArtworkById(id);
    final previousSaved = savedProvider?.isArtworkSaved(id) ?? false;
    final previousArtwork = artwork;
    final previousTimestamp = savedProvider?.getArtworkSavedAt(id);
    final nextSaved = !previousSaved;
    final nextTimestamp = DateTime.now();

    try {
      if (savedProvider != null) {
        await savedProvider.setArtworkSaved(
          id,
          nextSaved,
          timestamp: nextSaved ? nextTimestamp : null,
        );
      }

      if (artwork != null) {
        addOrUpdateArtwork(
          artwork.copyWith(
            isFavoriteByCurrentUser: nextSaved,
          ),
        );
      }

      if (nextSaved) {
        UserActionLogger.logArtworkSave(
          artworkId: id,
          artworkTitle: artwork?.title ?? id,
          artistName: artwork?.artist,
        );
      }

      try {
        if (nextSaved) {
          await _backendApi.bookmarkArtwork(id);
        } else {
          await _backendApi.unbookmarkArtwork(id);
        }
      } catch (e) {
        if (savedProvider != null) {
          await savedProvider.setArtworkSaved(
            id,
            previousSaved,
            timestamp: previousSaved ? previousTimestamp : null,
          );
        }
        if (previousArtwork != null) {
          addOrUpdateArtwork(
            previousArtwork.copyWith(
              isFavoriteByCurrentUser: previousSaved,
            ),
          );
        }
        rethrow;
      }
    } catch (e) {
      _setError('Failed to toggle artwork saved: $e');
    } finally {
      _setLoading('save_$id', false);
    }
  }

  /// Mark artwork as discovered
  Future<void> discoverArtwork(String artworkId) async {
    _setLoading('discover_$artworkId', true);
    try {
      final artwork = getArtworkById(artworkId);
      if (artwork != null && !artwork.isDiscovered) {
        final updatedArtwork = artwork.copyWith(
          status: ArtworkStatus.discovered,
          discoveredAt: DateTime.now(),
          discoveryCount: artwork.discoveryCount + 1,
        );
        addOrUpdateArtwork(updatedArtwork);

        // Auto-save discovered artwork
        if (_savedItemsProvider != null &&
            !_savedItemsProvider!.isArtworkSaved(artworkId)) {
          await _savedItemsProvider!.setArtworkSaved(
            artworkId,
            true,
            timestamp: DateTime.now(),
          );
          addOrUpdateArtwork(
            updatedArtwork.copyWith(isFavoriteByCurrentUser: true),
          );
        }

        // Sync with backend and reconcile server discovery count.
        try {
          final serverCount =
              await _backendApi.discoverArtworkWithCount(artworkId);
          if (serverCount != null) {
            final latest = getArtworkById(artworkId);
            if (latest != null) {
              addOrUpdateArtwork(latest.copyWith(discoveryCount: serverCount));
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('ArtworkProvider: discoverArtwork sync failed: $e');
          }
        }
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

        // Sync with backend and reconcile server count (deduplicates per day for authed users).
        final serverViews = await _backendApi.recordArtworkView(artworkId);
        if (serverViews != null) {
          final latest = getArtworkById(artworkId);
          if (latest != null && latest.viewsCount != serverViews) {
            addOrUpdateArtwork(latest.copyWith(viewsCount: serverViews));
          }
        }
      }
    } catch (e) {
      // Silent fail for view counting
      if (kDebugMode) {
        debugPrint('ArtworkProvider: incrementViewCount failed: $e');
      }
    }
  }

  /// Fetch comments from backend and store them locally.
  Future<void> loadComments(String artworkId, {bool force = false}) async {
    final operation = 'load_comments_$artworkId';
    if (!force && isLoading(operation)) return;
    _commentLoadErrors[artworkId] = null;
    _setLoading(operation, true);
    try {
      final fetched = await _backendApi.getArtworkComments(
          artworkId: artworkId, page: 1, limit: 100);
      // Keep ordering consistent with Community comments: oldest-first so threads read naturally.
      // Backend provides an ORDER BY, but sort defensively to keep behavior stable.
      final sorted = [...fetched]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final nested = _nestArtworkComments(sorted);
      _comments[artworkId] = nested;

      // Keep the artwork's cached commentsCount consistent with what the UI is showing.
      final total = _countArtworkComments(nested);
      final artwork = getArtworkById(artworkId);
      if (artwork != null && artwork.commentsCount != total) {
        addOrUpdateArtwork(artwork.copyWith(commentsCount: total));
      }
      notifyListeners();
    } catch (e) {
      _commentLoadErrors[artworkId] = 'Failed to load comments: $e';
      _setError(_commentLoadErrors[artworkId]!);
    } finally {
      _setLoading(operation, false);
    }
  }

  /// Get comments for artwork
  List<ArtworkComment> getComments(String artworkId) {
    return _comments[artworkId] ?? [];
  }

  String? commentLoadError(String artworkId) => _commentLoadErrors[artworkId];
  String? commentSubmitError(String artworkId) =>
      _commentSubmitErrors[artworkId];

  /// Add a comment to an artwork.
  ///
  /// Mirrors Community comments semantics: POST, then refresh the thread.
  Future<void> addComment({
    required String artworkId,
    required String content,
    String? parentCommentId,
  }) async {
    _setLoading('comment_$artworkId', true);
    _commentSubmitErrors[artworkId] = null;
    try {
      await _backendApi.createArtworkComment(
        artworkId: artworkId,
        content: content,
        parentCommentId: parentCommentId,
      );

      await loadComments(artworkId, force: true);
    } catch (e) {
      _commentSubmitErrors[artworkId] = 'Failed to add comment: $e';
      _setError(_commentSubmitErrors[artworkId]!);
      rethrow;
    } finally {
      _setLoading('comment_$artworkId', false);
    }
  }

  /// Like/Unlike comment
  Future<void> toggleCommentLike(String artworkId, String commentId) async {
    try {
      final roots = _comments[artworkId];
      if (roots == null || roots.isEmpty) return;

      final originalTree = List<ArtworkComment>.from(roots);
      final target = _findArtworkCommentById(roots, commentId);
      if (target == null) return;

      final optimistic = target.copyWith(
        isLikedByCurrentUser: !target.isLikedByCurrentUser,
        likesCount: target.isLikedByCurrentUser
            ? target.likesCount - 1
            : target.likesCount + 1,
      );

      _comments[artworkId] = _updateArtworkCommentById(
        roots,
        commentId,
        (c) => optimistic.copyWith(replies: c.replies),
      );
      notifyListeners();

      try {
        final updatedCount = optimistic.isLikedByCurrentUser
            ? await _backendApi.likeComment(commentId)
            : await _backendApi.unlikeComment(commentId);
        if (updatedCount != null) {
          final afterCount = _comments[artworkId] ?? const <ArtworkComment>[];
          _comments[artworkId] = _updateArtworkCommentById(
            afterCount,
            commentId,
            (c) => c.copyWith(likesCount: updatedCount),
          );
          notifyListeners();
        }
      } catch (e) {
        _comments[artworkId] = originalTree;
        notifyListeners();
        rethrow;
      }
    } catch (e) {
      _setError('Failed to toggle comment like: $e');
    }
  }

  /// Edit an existing artwork comment.
  ///
  /// This refreshes the comment thread from the backend to ensure edited/original
  /// fields are consistent and nested replies remain correct.
  Future<void> editArtworkComment({
    required String artworkId,
    required String commentId,
    required String content,
  }) async {
    final operation = 'edit_comment_${artworkId}_$commentId';
    if (isLoading(operation)) return;
    _commentSubmitErrors[artworkId] = null;
    _setLoading(operation, true);
    try {
      await _backendApi.editArtworkComment(
          commentId: commentId, content: content);
      await loadComments(artworkId, force: true);
    } catch (e) {
      _commentSubmitErrors[artworkId] = 'Failed to edit comment: $e';
      _setError(_commentSubmitErrors[artworkId]!);
      rethrow;
    } finally {
      _setLoading(operation, false);
    }
  }

  /// Delete an artwork comment (and its replies, server-side).
  ///
  /// Updates the artwork commentsCount when the backend returns the new value.
  Future<void> deleteArtworkComment({
    required String artworkId,
    required String commentId,
  }) async {
    final operation = 'delete_comment_${artworkId}_$commentId';
    if (isLoading(operation)) return;
    _commentSubmitErrors[artworkId] = null;
    _setLoading(operation, true);
    try {
      final updatedCount = await _backendApi.deleteArtworkComment(commentId);
      if (updatedCount != null) {
        final artwork = getArtworkById(artworkId);
        if (artwork != null && artwork.commentsCount != updatedCount) {
          addOrUpdateArtwork(artwork.copyWith(commentsCount: updatedCount));
        }
      }
      await loadComments(artworkId, force: true);
    } catch (e) {
      _commentSubmitErrors[artworkId] = 'Failed to delete comment: $e';
      _setError(_commentSubmitErrors[artworkId]!);
      rethrow;
    } finally {
      _setLoading(operation, false);
    }
  }

  /// Load initial artworks
  Future<void> loadArtworks({bool refresh = false}) async {
    _setLoading('load_artworks', true);

    try {
      if (refresh) {
        _walletsWithPrivateArtworks.clear();
        _walletsWithPublicArtworks.clear();
      }
      final artworks = await _backendApi.getArtworks(limit: 100);
      final merged = artworks.map(_mergeSavedBookmarkState).toList();
      _artworks
        ..clear()
        ..addAll(merged);
      _artworkById
        ..clear()
        ..addEntries(merged.map((a) => MapEntry(a.id, a)));
      _comments.clear();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load artworks: $e');
    } finally {
      _setLoading('load_artworks', false);
    }
  }

  Future<void> loadArtworksForWallet(
    String walletAddress, {
    bool force = false,
    bool includePrivateForWallet = true,
  }) async {
    if (walletAddress.isEmpty) return;
    final cacheKey = WalletUtils.canonical(walletAddress);
    final cacheSet = includePrivateForWallet
        ? _walletsWithPrivateArtworks
        : _walletsWithPublicArtworks;

    if (!force && cacheSet.contains(cacheKey)) {
      return;
    }

    final operationKey = 'load_artworks_wallet_$cacheKey';
    _setLoading(operationKey, true);
    try {
      final walletArtworks = await _backendApi.getArtworks(
        walletAddress: walletAddress,
        includePrivateForWallet: includePrivateForWallet,
        limit: 100,
      );
      bool updated = false;
      for (final artwork in walletArtworks) {
        final merged = _mergeSavedBookmarkState(artwork);
        final index = _artworks.indexWhere((a) => a.id == artwork.id);
        if (index >= 0) {
          _artworks[index] = merged;
        } else {
          _artworks.add(merged);
        }
        _artworkById[merged.id] = merged;
        updated = true;
      }
      cacheSet.add(cacheKey);
      if (updated) {
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load wallet artworks: $e');
    } finally {
      _setLoading(operationKey, false);
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
      if (kDebugMode) {
        debugPrint('ArtworkProvider: ensureHistoryLoaded error: $e');
      }
      _historyLoaded = true;
    }
  }

  List<ViewHistoryEntry> get viewHistoryEntries =>
      List.unmodifiable(_viewHistory);

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

  List<ArtworkComment> _nestArtworkComments(List<ArtworkComment> flat) {
    if (flat.isEmpty) return const <ArtworkComment>[];

    final Map<String, ArtworkComment> byId = {
      for (final c in flat) c.id: c.copyWith(replies: const []),
    };
    final List<ArtworkComment> roots = [];

    for (final c in byId.values) {
      final parentId = c.parentCommentId;
      if (parentId != null &&
          parentId.isNotEmpty &&
          byId.containsKey(parentId)) {
        final parent = byId[parentId]!;
        byId[parentId] = parent.copyWith(replies: [...parent.replies, c]);
      } else {
        roots.add(c);
      }
    }

    return roots;
  }

  int _countArtworkComments(List<ArtworkComment> roots) {
    int countNode(ArtworkComment c) {
      var total = 1;
      for (final r in c.replies) {
        total += countNode(r);
      }
      return total;
    }

    var total = 0;
    for (final c in roots) {
      total += countNode(c);
    }
    return total;
  }

  ArtworkComment? _findArtworkCommentById(
      List<ArtworkComment> roots, String commentId) {
    for (final c in roots) {
      if (c.id == commentId) return c;
      final hit = _findArtworkCommentById(c.replies, commentId);
      if (hit != null) return hit;
    }
    return null;
  }

  List<ArtworkComment> _updateArtworkCommentById(
    List<ArtworkComment> roots,
    String commentId,
    ArtworkComment Function(ArtworkComment current) updater,
  ) {
    return roots.map((c) {
      final updatedReplies = c.replies.isEmpty
          ? c.replies
          : _updateArtworkCommentById(c.replies, commentId, updater);
      final withReplies = (updatedReplies == c.replies)
          ? c
          : c.copyWith(replies: updatedReplies);
      if (withReplies.id == commentId) {
        return updater(withReplies);
      }
      return withReplies;
    }).toList();
  }

  Artwork _mergeSavedBookmarkState(Artwork artwork) {
    final savedProvider = _savedItemsProvider;
    if (savedProvider == null) return artwork;
    final isSaved = savedProvider.isArtworkSaved(artwork.id);
    if (artwork.isFavoriteByCurrentUser == isSaved) {
      return artwork;
    }
    return artwork.copyWith(isFavoriteByCurrentUser: isSaved);
  }

  void _reconcileSavedBookmarkState() {
    final savedProvider = _savedItemsProvider;
    if (savedProvider == null || _artworks.isEmpty) return;

    var changed = false;
    for (var i = 0; i < _artworks.length; i++) {
      final artwork = _artworks[i];
      final merged = _mergeSavedBookmarkState(artwork);
      if (identical(merged, artwork)) continue;
      _artworks[i] = merged;
      _artworkById[merged.id] = merged;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
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
      viewedAt: DateTime.tryParse(json['viewedAt']?.toString() ?? '') ??
          DateTime.now(),
      markerId: json['markerId']?.toString(),
    );
  }
}
