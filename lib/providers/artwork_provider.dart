import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artwork.dart';
import '../models/artwork_comment.dart';
import '../models/kubus_node_models.dart';
import '../services/ar_content_service.dart';
import '../services/art_content_service.dart';
import '../services/backend_api_service.dart';
import '../services/profile_package_mutation_tracker.dart';
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
  final BackendApiService? _spatialApi;
  final Map<String, ArtworkSpatialHistory> _spatialHistory = {};
  final Map<String, Future<ArtworkSpatialHistory>> _spatialHistoryLoads = {};
  final Map<String, String> _spatialHistoryErrors = {};
  final Map<String, Future<Artwork>> _inFlightArtworkFetches =
      <String, Future<Artwork>>{};
  // Individual detail requests may return artwork outside the first page used
  // by the startup list. Keep those records available for the provider's
  // lifetime instead of treating an omitted first-page row as a deletion.
  final Set<String> _supplementalArtworkIds = <String>{};
  Future<void>? _inFlightLoadArtworks;
  DateTime? _lastArtworksLoadAt;
  // Bumped by clearAccountScopedState. A response that started under an
  // earlier account is dropped instead of merged into the next account's cache.
  int _accountEpoch = 0;
  static const Duration _artworksFreshWindow = Duration(seconds: 60);

  /// Device view history. Sign-out removes it so the next account never sees
  /// the previous account's browsing.
  static const String viewHistoryStorageKey = 'artwork_view_history_v1';
  static const String _viewHistoryPrefsKey = viewHistoryStorageKey;
  final List<ViewHistoryEntry> _viewHistory = <ViewHistoryEntry>[];
  bool _historyLoaded = false;

  ArtworkProvider({ArtworkBackendApi? backendApi})
      : _backendApi = backendApi ?? BackendApiService(),
        _spatialApi = backendApi == null
            ? BackendApiService()
            : (backendApi is BackendApiService ? backendApi : null);

  List<Artwork> get artworks => List.unmodifiable(_artworks);
  String? get error => _error;

  ArtworkSpatialHistory? spatialHistoryFor(String artworkId) =>
      _spatialHistory[artworkId];

  String? spatialHistoryErrorFor(String artworkId) =>
      _spatialHistoryErrors[artworkId];

  bool isSpatialHistoryLoading(String artworkId) =>
      _spatialHistoryLoads.containsKey(artworkId);

  /// Replaces the in-memory artwork list, order included.
  ///
  /// Exists so a test can reproduce the ordering churn that used to decide
  /// which artwork a spatial capture was filed under: surfaces must resolve
  /// each record by its own id, so reordering this list changes nothing they
  /// display.
  @visibleForTesting
  void seedArtworksForTesting(List<Artwork> artworks) {
    _artworks
      ..clear()
      ..addAll(artworks);
    _artworkById
      ..clear()
      ..addEntries(artworks.map((artwork) => MapEntry(artwork.id, artwork)));
    notifyListeners();
  }

  @visibleForTesting
  void seedSpatialHistoryForTesting(
    String artworkId,
    ArtworkSpatialHistory history,
  ) {
    _spatialHistory[artworkId] = history;
  }

  Future<ArtworkSpatialHistory> loadSpatialHistory(
    String artworkId, {
    bool refresh = false,
  }) async {
    final id = artworkId.trim();
    if (id.isEmpty) return const ArtworkSpatialHistory(history: []);
    final cached = _spatialHistory[id];
    if (!refresh && cached != null) return cached;
    final pending = _spatialHistoryLoads[id];
    if (pending != null) return pending;
    final api = _spatialApi;
    if (api == null) return const ArtworkSpatialHistory(history: []);
    final epoch = _accountEpoch;
    final future = api.getArtworkSpatialHistory(id);
    _spatialHistoryLoads[id] = future;
    _spatialHistoryErrors.remove(id);
    notifyListeners();
    try {
      final history = await future;
      if (epoch == _accountEpoch) _spatialHistory[id] = history;
      return history;
    } catch (error) {
      _spatialHistoryErrors[id] = error.toString();
      rethrow;
    } finally {
      _spatialHistoryLoads.remove(id);
      notifyListeners();
    }
  }

  bool isLoading(String operation) => _loadingStates[operation] ?? false;

  /// Bind the saved-items provider.
  void bindSavedItemsProvider(SavedItemsProvider provider) {
    if (identical(_savedItemsProvider, provider)) return;
    _savedItemsProvider = provider;
    _reconcileSavedBookmarkState();
  }

  /// Drops what this provider holds about the account that just signed out.
  ///
  /// Public artwork data stays. What goes is anything the ending session could
  /// see only as itself: private artworks, artworks listed for a wallet, the
  /// viewer's like, bookmark and discovery state, cached comments, spatial
  /// history, view history, and the optimistic like/save markers. Responses
  /// still in flight for the ending session are discarded when they land.
  void clearAccountScopedState() {
    _accountEpoch += 1;

    final ownedWallets = <String>{
      ..._walletsWithPrivateArtworks,
      ..._walletsWithPublicArtworks,
    };
    bool ownedByEndingSession(Artwork artwork) {
      if (!artwork.isPublic) return true;
      final wallet = artwork.walletAddress?.trim() ?? '';
      return wallet.isNotEmpty &&
          ownedWallets.contains(WalletUtils.canonical(wallet));
    }

    final dropped = _artworks
        .where(ownedByEndingSession)
        .map((artwork) => artwork.id)
        .toSet();
    _artworks.removeWhere((artwork) => dropped.contains(artwork.id));
    _artworkById.removeWhere(
      (id, artwork) => dropped.contains(id) || ownedByEndingSession(artwork),
    );

    _supplementalArtworkIds.clear();
    _walletsWithPrivateArtworks.clear();
    _walletsWithPublicArtworks.clear();
    _lastArtworksLoadAt = null;
    _inFlightLoadArtworks = null;
    _inFlightArtworkFetches.clear();

    _spatialHistory.clear();
    _spatialHistoryLoads.clear();
    _spatialHistoryErrors.clear();

    _viewHistory.clear();
    _historyLoaded = false;

    _comments.clear();
    _commentLoadErrors.clear();
    _commentSubmitErrors.clear();

    for (final id in _artworkById.keys.toList(growable: false)) {
      final artwork = _artworkById[id]!;
      final viewerScoped = artwork.isLikedByCurrentUser ||
          artwork.isFavoriteByCurrentUser ||
          artwork.isDiscovered ||
          artwork.discoveredAt != null ||
          artwork.discoveryUserId != null;
      if (!viewerScoped) continue;
      // discoveryCount is a public total and stays; the status, the time and
      // the discoverer are the viewer's own discovery state.
      _artworkById[id] = artwork.copyWith(
        isLikedByCurrentUser: false,
        isFavoriteByCurrentUser: false,
        status: ArtworkStatus.undiscovered,
        clearDiscoveredAt: true,
        clearDiscoveryUserId: true,
      );
    }
    for (var i = 0; i < _artworks.length; i++) {
      final current = _artworkById[_artworks[i].id];
      if (current != null) _artworks[i] = current;
    }

    _loadingStates.removeWhere(
      (operation, _) =>
          operation.startsWith('like_') || operation.startsWith('save_'),
    );
    notifyListeners();
  }

  /// Get artwork by ID
  Artwork? getArtworkById(String id) => _artworkById[id];

  /// Seeds the normal detail cache from the server's public presentation.
  /// The caller revalidates this value in the background; private/account
  /// fields are intentionally not part of this conversion.
  void seedPublicPresentation(Map<String, dynamic> presentation) {
    final isCollectible = presentation['type'] == 'collectible';
    final backingId = isCollectible
        ? presentation['backingArtworkId']?.toString().trim()
        : presentation['id']?.toString().trim();
    // A public collectible identity is not implicitly an artwork API ID.
    // Older payloads without the explicit relationship fall back to fetching.
    if (backingId == null || backingId.isEmpty) return;
    final media = presentation['primaryMedia'];
    final primaryMedia = media is Map
        ? Map<String, dynamic>.from(media)
        : const <String, dynamic>{};
    final authorship = presentation['authorship'];
    final artist =
        authorship is Map ? (authorship['name']?.toString() ?? '') : '';
    final place = presentation['place'];
    final placeData = place is Map
        ? Map<String, dynamic>.from(place)
        : const <String, dynamic>{};
    final provenance = presentation['provenance'];
    final provenanceData = provenance is Map
        ? Map<String, dynamic>.from(provenance)
        : const <String, dynamic>{};
    final isLegacyPresentation = presentation['version'] == 1;
    final legacyImageCredit = provenanceData['imageCredit'];
    final legacyImageCreditData = legacyImageCredit is Map
        ? Map<String, dynamic>.from(legacyImageCredit)
        : const <String, dynamic>{};
    final source = provenanceData['recordSource'] ??
        (isLegacyPresentation ? provenanceData['source'] : null);
    final sourceData = source is Map
        ? Map<String, dynamic>.from(source)
        : const <String, dynamic>{};
    final imageCreator = primaryMedia['creator'] ??
        (isLegacyPresentation ? legacyImageCreditData['credit'] : null);
    final imageCreditText = primaryMedia['creditText'];
    final imageLicense = primaryMedia['license'] ??
        (isLegacyPresentation ? legacyImageCreditData['license'] : null);
    final imageSourceUrl = primaryMedia['sourceUrl'] ??
        (isLegacyPresentation ? legacyImageCreditData['sourceUrl'] : null);
    final latitude = placeData['latitude'];
    final longitude = placeData['longitude'];
    final artwork = Artwork.fromMap(<String, dynamic>{
      'id': backingId,
      'title': presentation['title']?.toString() ?? '',
      'artist': artist,
      'description': presentation['description']?.toString() ?? '',
      'imageUrl': primaryMedia['url'],
      'latitude': latitude is num ? latitude.toDouble() : 0.0,
      'longitude': longitude is num ? longitude.toDouble() : 0.0,
      'isPublic': true,
      'isActive': true,
      'isNft': presentation['type'] == 'collectible',
      'category': presentation['type'] == 'collectible'
          ? 'Public collectible'
          : 'Public artwork',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'metadata': <String, dynamic>{
        if (imageCreator != null) 'imageAuthor': imageCreator,
        if (imageCreditText != null) 'imageAttribution': imageCreditText,
        if (imageLicense != null) 'imageLicense': imageLicense,
        if (imageSourceUrl != null) 'imageSourceUrl': imageSourceUrl,
        if (sourceData['name'] != null) 'sourceName': sourceData['name'],
        if (sourceData['id'] != null) 'sourceId': sourceData['id'],
        if (sourceData['url'] != null) 'sourceUrl': sourceData['url'],
      },
    });
    if (artwork.id.trim().isNotEmpty && artwork.title.trim().isNotEmpty) {
      addOrUpdateArtwork(artwork, retainWhenListRefresh: true);
    }
  }

  /// Ensure artwork exists locally by fetching from backend if needed
  Future<Artwork?> fetchArtworkIfNeeded(String artworkId) async {
    final key = artworkId.trim();
    if (key.isEmpty) return null;
    final existing = getArtworkById(key);
    if (existing != null) {
      _supplementalArtworkIds.add(key);
      return existing;
    }
    final inflight = _inFlightArtworkFetches[key];
    if (inflight != null) {
      return inflight;
    }

    try {
      final epoch = _accountEpoch;
      final future = _backendApi.getArtwork(key).then((fetched) {
        if (epoch == _accountEpoch) {
          addOrUpdateArtwork(fetched, retainWhenListRefresh: true);
        }
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

  /// Fetch several artworks in one request and merge them into the cache.
  ///
  /// Returns the ids that are still missing afterwards (not returned by the
  /// backend — e.g. deleted, private, or an older backend without `ids`
  /// support). Callers may fall back to per-id fetches for those.
  Future<Set<String>> fetchArtworksByIds(Iterable<String> artworkIds) async {
    final wanted = artworkIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && getArtworkById(id) == null)
        .toSet();
    if (wanted.isEmpty) return const <String>{};

    try {
      final epoch = _accountEpoch;
      final fetched = await _backendApi.getArtworks(
        ids: wanted.toList(growable: false),
      );
      if (epoch != _accountEpoch) return wanted;
      var updated = false;
      for (final artwork in fetched) {
        if (!wanted.contains(artwork.id)) continue;
        final merged = _mergeSavedBookmarkState(artwork);
        _upsertArtwork(merged);
        _supplementalArtworkIds.add(merged.id);
        updated = true;
      }
      if (updated) notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ArtworkProvider: fetchArtworksByIds failed: $e');
      }
    }
    return wanted.where((id) => getArtworkById(id) == null).toSet();
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
      addOrUpdateArtwork(fetched, retainWhenListRefresh: true);
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
          (artwork) => artwork.isFavoriteByCurrentUser || artwork.isFavorite,
        )
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
  void addOrUpdateArtwork(
    Artwork artwork, {
    bool retainWhenListRefresh = false,
  }) {
    final nextArtwork = _mergeSavedBookmarkState(artwork);
    _upsertArtwork(nextArtwork);
    if (retainWhenListRefresh) {
      _supplementalArtworkIds.add(nextArtwork.id);
    }
    notifyListeners();
  }

  void _upsertArtwork(Artwork artwork) {
    final index = _artworks.indexWhere((a) => a.id == artwork.id);
    if (index >= 0) {
      _artworks[index] = artwork;
    } else {
      _artworks.add(artwork);
    }
    _artworkById[artwork.id] = artwork;
  }

  void _invalidateShowcaseForArtwork(Artwork artwork) {
    final wallet = artwork.walletAddress;
    if (wallet != null && wallet.trim().isNotEmpty) {
      ProfilePackageMutationTracker.showcaseChanged(wallet);
    }
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
        metadata: {'type': 'artwork_cover', 'title': title},
      );

      String? modelCid;
      String? modelUrl;
      if (arEnabled) {
        final uploadResult = await ARContentService.uploadContent(
          modelBytes!,
          modelFilename!,
          metadata: {'type': 'ar_model', 'title': title, 'artist': artistName},
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
      final wallet = artwork.walletAddress;
      if (wallet != null && wallet.trim().isNotEmpty) {
        ProfilePackageMutationTracker.artworkChanged(
          artwork,
          kind: ProfilePackageMutationKind.artworkCreated,
        );
      }
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
        _invalidateShowcaseForArtwork(updated);
        return updated;
      }

      // Backend returned null even though request succeeded (sparse/empty response).
      // Try to refresh the artwork to verify the publish worked.
      try {
        final refreshed = await _backendApi.getArtwork(artworkId);
        addOrUpdateArtwork(refreshed);
        _invalidateShowcaseForArtwork(refreshed);
        return refreshed;
      } catch (_) {
        // Refresh failed. Check if we have a cached artwork and update it optimistically.
        final cached = getArtworkById(artworkId);
        if (cached != null) {
          // Return optimistically updated artwork (marked as public)
          final optimistic = cached.copyWith(isPublic: true);
          addOrUpdateArtwork(optimistic);
          _invalidateShowcaseForArtwork(optimistic);
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
        _invalidateShowcaseForArtwork(updated);
        return updated;
      }

      // Backend returned null even though request succeeded (sparse/empty response).
      // Try to refresh the artwork to verify the unpublish worked.
      try {
        final refreshed = await _backendApi.getArtwork(artworkId);
        addOrUpdateArtwork(refreshed);
        _invalidateShowcaseForArtwork(refreshed);
        return refreshed;
      } catch (_) {
        // Refresh failed. Check if we have a cached artwork and update it optimistically.
        final cached = getArtworkById(artworkId);
        if (cached != null) {
          // Return optimistically updated artwork (marked as not public)
          final optimistic = cached.copyWith(isPublic: false);
          addOrUpdateArtwork(optimistic);
          _invalidateShowcaseForArtwork(optimistic);
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

  /// Saves [updates] to an artwork and says precisely what happened.
  ///
  /// The result separates a confirmed write, a write the backend acknowledged
  /// without a usable payload, a failed write and a duplicate request, so a
  /// caller never has to guess success from "did I get an artwork back".
  /// A failed write never falls back to re-reading the old record: that read
  /// would succeed and be mistaken for a save.
  Future<ArtworkUpdateResult> saveArtwork(
    String artworkId,
    Map<String, dynamic> updates,
  ) async {
    final id = artworkId.trim();
    if (id.isEmpty) {
      return const ArtworkUpdateResult.failed(ArtworkUpdateFailure.rejected);
    }
    final operation = 'update_artwork_$id';
    if (isLoading(operation)) {
      return const ArtworkUpdateResult.alreadyInFlight();
    }
    _setLoading(operation, true);
    try {
      final updated = await _backendApi.updateArtwork(id, updates);
      if (updated != null) {
        _commitSavedArtwork(updated);
        return ArtworkUpdateResult.confirmed(updated);
      }
      // HTTP 200 with no usable artwork and no read-back: the write happened
      // but its result is unknown. Keep the user's edits visible locally; the
      // portfolio refresh that follows fetches the authoritative record.
      final cached = getArtworkById(id);
      final patched =
          cached == null ? null : _applyUpdatesLocally(cached, updates);
      if (patched != null) _commitSavedArtwork(patched);
      return ArtworkUpdateResult.acknowledged(patched);
    } catch (e) {
      final failure = classifyArtworkUpdateFailure(e);
      _setError('Failed to update artwork: $e');
      return ArtworkUpdateResult.failed(failure);
    } finally {
      _setLoading(operation, false);
    }
  }

  /// Legacy shape of [saveArtwork]: the saved artwork, or null on any failure.
  Future<Artwork?> updateArtwork(
    String artworkId,
    Map<String, dynamic> updates,
  ) async {
    final result = await saveArtwork(artworkId, updates);
    return result.succeeded ? result.artwork : null;
  }

  void _commitSavedArtwork(Artwork artwork) {
    addOrUpdateArtwork(artwork);
    final wallet = artwork.walletAddress;
    if (wallet != null && wallet.trim().isNotEmpty) {
      ProfilePackageMutationTracker.artworkChanged(artwork);
    }
  }

  Artwork _applyUpdatesLocally(Artwork base, Map<String, dynamic> updates) {
    double? number(Object? v) => v is num ? v.toDouble() : null;
    final lat = number(updates['latitude']);
    final lng = number(updates['longitude']);
    final tags = updates['tags'];
    return base.copyWith(
      title: updates['title'] as String?,
      artist: updates['artistName'] as String?,
      description: updates['description'] as String?,
      category: updates['category'] as String?,
      tags: tags is List ? tags.map((e) => e.toString()).toList() : null,
      imageUrl: updates['imageUrl'] as String?,
      model3DURL: updates['model3DURL'] as String?,
      model3DCID: updates['model3DCID'] as String?,
      arEnabled: updates['isAREnabled'] as bool?,
      price: number(updates['price']),
      arScale: number(updates['arScale']),
      clearPrice: updates.containsKey('price') && updates['price'] == null,
      clearArScale:
          updates.containsKey('arScale') && updates['arScale'] == null,
      position: (lat != null || lng != null)
          ? LatLng(
              lat ?? base.position.latitude,
              lng ?? base.position.longitude,
            )
          : null,
    );
  }

  /// Like/Unlike artwork
  Future<void> toggleLike(String artworkId) async {
    final artwork = getArtworkById(artworkId);
    if (artwork == null) return;
    await setLiked(artworkId, !artwork.isLikedByCurrentUser);
  }

  /// Drives the like state to [liked] and reports whether it now holds.
  ///
  /// Idempotent by design: a replayed action (for example one a visitor
  /// confirmed after signing up) must never flip a like the user already has.
  ///
  /// With [confirmOnServer] the cached flag is not trusted: the backend like is
  /// sent even when the cache already reads [liked]. A confirmed pending action
  /// uses this, so its success always means a server write happened, never a
  /// stale cache read left over from a previous account.
  Future<bool> setLiked(
    String artworkId,
    bool liked, {
    bool confirmOnServer = false,
  }) async {
    final id = artworkId.trim();
    if (id.isEmpty) return false;

    final artwork = getArtworkById(id);
    if (artwork == null) return false;
    if (!confirmOnServer && artwork.isLikedByCurrentUser == liked) return true;

    final alreadyInState = artwork.isLikedByCurrentUser == liked;
    _setLoading('like_$id', true);
    final original = artwork;
    try {
      addOrUpdateArtwork(
        artwork.copyWith(
          isLikedByCurrentUser: liked,
          likesCount: alreadyInState
              ? artwork.likesCount
              : (liked ? artwork.likesCount + 1 : artwork.likesCount - 1),
        ),
      );

      if (liked) {
        UserActionLogger.logArtworkLike(
          artworkId: artwork.id,
          artworkTitle: artwork.title,
          artistName: artwork.artist,
        );
      }

      // Sync with backend and reconcile count.
      try {
        final updatedCount = liked
            ? await _backendApi.likeArtwork(id)
            : await _backendApi.unlikeArtwork(id);

        if (confirmOnServer && liked) {
          // A like counts only once the server reports it. An offline write
          // queued in the outbox returns no body, and neither does a like the
          // server never accepted, so read the artwork back to tell them apart.
          final server = await _backendApi.getArtwork(id);
          if (!server.isLikedByCurrentUser) {
            addOrUpdateArtwork(original);
            return false;
          }
        }

        if (updatedCount != null) {
          final latest = getArtworkById(id);
          if (latest != null) {
            addOrUpdateArtwork(latest.copyWith(likesCount: updatedCount));
          }
        }
      } catch (e) {
        // Rollback optimistic state on failure.
        addOrUpdateArtwork(original);
        rethrow;
      }
      return true;
    } catch (e) {
      _setError('Failed to update like: $e');
      return false;
    } finally {
      _setLoading('like_$id', false);
    }
  }

  /// Toggle artwork bookmark state.
  Future<void> toggleArtworkSaved(String artworkId) async {
    final id = artworkId.trim();
    if (id.isEmpty) return;
    final previousSaved = _savedItemsProvider?.isArtworkSaved(id) ?? false;
    await setArtworkSavedState(id, !previousSaved);
  }

  /// Drives the bookmark state to [saved] and reports whether it now holds.
  ///
  /// Idempotent for the same reason as [setLiked]: confirming a pending save
  /// must not un-save an artwork the visitor saved in the meantime.
  Future<bool> setArtworkSavedState(String artworkId, bool saved) async {
    final id = artworkId.trim();
    if (id.isEmpty) return false;

    final savedProvider = _savedItemsProvider;
    if (savedProvider != null && savedProvider.isArtworkSaved(id) == saved) {
      return true;
    }

    _setLoading('save_$id', true);
    final artwork = getArtworkById(id);
    final nextTimestamp = DateTime.now();

    try {
      if (savedProvider != null) {
        await savedProvider.setArtworkSaved(
          id,
          saved,
          timestamp: saved ? nextTimestamp : null,
        );
      }

      if (artwork != null) {
        addOrUpdateArtwork(artwork.copyWith(isFavoriteByCurrentUser: saved));
      }

      if (saved) {
        UserActionLogger.logArtworkSave(
          artworkId: id,
          artworkTitle: artwork?.title ?? id,
          artistName: artwork?.artist,
        );
      }
      return true;
    } on SavedItemsAuthenticationRequired {
      // Surface the reason rather than flattening it to a generic failure —
      // callers (the pending-action executor) distinguish "not allowed" from
      // "try again", and report different copy for each.
      rethrow;
    } catch (e) {
      _setError('Failed to update artwork saved state: $e');
      return false;
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
          final serverCount = await _backendApi.discoverArtworkWithCount(
            artworkId,
          );
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
        artworkId: artworkId,
        page: 1,
        limit: 100,
      );
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
        commentId: commentId,
        content: content,
      );
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
    // Home + map both request this on startup; share one in-flight load so we
    // don't issue duplicate `/api/artworks` page-1 fetches.
    final inflight = _inFlightLoadArtworks;
    if (inflight != null) {
      return inflight;
    }
    // Non-refresh callers arriving moments after a successful load reuse it.
    final lastLoadAt = _lastArtworksLoadAt;
    if (!refresh &&
        _artworks.isNotEmpty &&
        lastLoadAt != null &&
        DateTime.now().difference(lastLoadAt) < _artworksFreshWindow) {
      return;
    }
    final future = _loadArtworksInternal(refresh: refresh);
    _inFlightLoadArtworks = future;
    try {
      await future;
    } finally {
      if (identical(_inFlightLoadArtworks, future)) {
        _inFlightLoadArtworks = null;
      }
    }
  }

  Future<void> _loadArtworksInternal({bool refresh = false}) async {
    _setLoading('load_artworks', true);
    final epoch = _accountEpoch;

    try {
      if (refresh) {
        _walletsWithPrivateArtworks.clear();
        _walletsWithPublicArtworks.clear();
      }
      final artworks = await _backendApi.getArtworks(limit: 100);
      if (epoch != _accountEpoch) return;
      final merged = artworks.map(_mergeSavedBookmarkState).toList();
      final listedArtworkIds = merged.map((artwork) => artwork.id).toSet();
      final supplementalArtworks = _supplementalArtworkIds
          .where((artworkId) => !listedArtworkIds.contains(artworkId))
          .map((artworkId) => _artworkById[artworkId])
          .whereType<Artwork>()
          .map(_mergeSavedBookmarkState)
          .toList(growable: false);
      _artworks
        ..clear()
        ..addAll(merged);
      _artworkById
        ..clear()
        ..addEntries(merged.map((a) => MapEntry(a.id, a)));
      for (final artwork in supplementalArtworks) {
        _upsertArtwork(artwork);
      }
      _supplementalArtworkIds.removeWhere(
        (artworkId) => !_artworkById.containsKey(artworkId),
      );
      _comments.clear();
      _lastArtworksLoadAt = DateTime.now();

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
    final epoch = _accountEpoch;
    try {
      final walletArtworks = await _backendApi.getArtworks(
        walletAddress: walletAddress,
        includePrivateForWallet: includePrivateForWallet,
        limit: 100,
      );
      if (epoch != _accountEpoch) return;
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
        ..addAll(
          raw.map((item) {
            try {
              final map = jsonDecode(item);
              if (map is Map<String, dynamic>) {
                return ViewHistoryEntry.fromJson(map);
              }
            } catch (_) {}
            return null;
          }).whereType<ViewHistoryEntry>(),
        );
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
    List<ArtworkComment> roots,
    String commentId,
  ) {
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

/// What an artwork save did. See [ArtworkProvider.saveArtwork].
enum ArtworkUpdateStatus {
  /// The backend returned the updated artwork.
  confirmed,

  /// The backend acknowledged the write (HTTP 200) but returned no usable
  /// artwork and the read-back failed. The write happened.
  acknowledged,

  /// The write did not happen.
  failed,

  /// Another save for the same artwork is still running; nothing was sent.
  alreadyInFlight,
}

/// Why a save failed, for choosing a contextual message.
enum ArtworkUpdateFailure {
  /// Transport failure: offline, DNS, connection reset.
  network,
  timeout,

  /// 401: the session is missing or expired.
  unauthorized,

  /// 403: signed in, but not allowed to edit this artwork.
  forbidden,

  /// 409: the record changed underneath the edit.
  conflict,

  /// 429
  rateLimited,

  /// 400/404/422: the backend refused these values.
  rejected,

  /// 5xx
  server,
  unknown,
}

ArtworkUpdateFailure classifyArtworkUpdateFailure(Object error) {
  if (error is TimeoutException) return ArtworkUpdateFailure.timeout;
  if (error is BackendApiRequestException) {
    final code = error.statusCode;
    if (code == 0) return ArtworkUpdateFailure.network;
    if (code == 504 || code == 408 || code == 524) {
      return ArtworkUpdateFailure.timeout;
    }
    if (code == 401) return ArtworkUpdateFailure.unauthorized;
    if (code == 403) return ArtworkUpdateFailure.forbidden;
    if (code == 409) return ArtworkUpdateFailure.conflict;
    if (code == 429) return ArtworkUpdateFailure.rateLimited;
    if (code == 400 || code == 404 || code == 422) {
      return ArtworkUpdateFailure.rejected;
    }
    if (code >= 500) return ArtworkUpdateFailure.server;
  }
  return ArtworkUpdateFailure.unknown;
}

class ArtworkUpdateResult {
  const ArtworkUpdateResult._(this.status, this.artwork, this.failure);

  const ArtworkUpdateResult.confirmed(Artwork artwork)
      : this._(ArtworkUpdateStatus.confirmed, artwork, null);

  const ArtworkUpdateResult.acknowledged(Artwork? artwork)
      : this._(ArtworkUpdateStatus.acknowledged, artwork, null);

  const ArtworkUpdateResult.failed(ArtworkUpdateFailure failure)
      : this._(ArtworkUpdateStatus.failed, null, failure);

  const ArtworkUpdateResult.alreadyInFlight()
      : this._(ArtworkUpdateStatus.alreadyInFlight, null, null);

  final ArtworkUpdateStatus status;

  /// The saved record. Always set when [status] is confirmed; for an
  /// acknowledged write it is the local cache with the edits applied.
  final Artwork? artwork;

  final ArtworkUpdateFailure? failure;

  /// True when the backend accepted the write.
  bool get succeeded =>
      status == ArtworkUpdateStatus.confirmed ||
      status == ArtworkUpdateStatus.acknowledged;
}
