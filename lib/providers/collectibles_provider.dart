import 'package:flutter/foundation.dart';
import '../models/artwork.dart';
import '../models/collectible.dart';
import '../services/backend_api_service.dart';
import '../services/collectibles_storage.dart';
import '../utils/artwork_media_resolver.dart';
import 'artwork_provider.dart';

class CollectiblesProvider with ChangeNotifier {
  CollectiblesProvider({BackendApiService? backendApiService})
      : _backendApiService = backendApiService ?? BackendApiService();

  final List<CollectibleSeries> _legacySeries = [];
  final List<Collectible> _legacyCollectibles = [];
  final CollectiblesStorage _storage = CollectiblesStorage();
  final BackendApiService _backendApiService;
  ArtworkProvider? _artworkProvider;
  final Map<String, List<Map<String, dynamic>>> _walletCollectibleIndex = {};

  bool _isLoading = false;
  String? _error;

  // Getters
  List<CollectibleSeries> get allSeries =>
      List.unmodifiable(_buildCanonicalSeries());
  List<Collectible> get allCollectibles => List.unmodifiable(
      _applyWalletCollectibleIndex(_buildCanonicalCollectibles()));
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<MarketplaceArtworkEntry> get marketplaceEntries =>
      _buildMarketplaceEntries();

  void bindArtworkProvider(ArtworkProvider? artworkProvider) {
    if (identical(_artworkProvider, artworkProvider)) return;
    _artworkProvider?.removeListener(_handleArtworkProviderChanged);
    _artworkProvider = artworkProvider;
    _artworkProvider?.addListener(_handleArtworkProviderChanged);
    notifyListeners();
  }

  void _handleArtworkProviderChanged() {
    notifyListeners();
  }

  static const String _ownershipStatusCreatorIndexedUnverified =
      'creator_wallet_indexed_unverified_transfer_history';

  String _seriesIdForArtwork(String artworkId) => 'artwork_series_$artworkId';

  String _collectibleIdForArtwork(String artworkId) =>
      'artwork_collectible_$artworkId';

  String _canonicalWallet(String raw) => raw.trim().toLowerCase();

  Future<void> initialize({bool loadMockIfEmpty = false}) async {
    _setLoading(true);

    try {
      final loadedSeries = await _storage.loadSeries();
      final loadedCollectibles = await _storage.loadCollectibles();

      _legacySeries
        ..clear()
        ..addAll(loadedSeries);
      _legacyCollectibles
        ..clear()
        ..addAll(loadedCollectibles);

      if (loadMockIfEmpty && kDebugMode) {
        debugPrint(
          'CollectiblesProvider: mock collectible mode is disabled; using canonical indexed artwork truth only.',
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load collectibles: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshWalletCollectibleIndex(
    String walletAddress, {
    bool force = false,
  }) async {
    final normalized = _canonicalWallet(walletAddress);
    if (normalized.isEmpty) return;
    if (!force && _walletCollectibleIndex.containsKey(normalized)) return;

    try {
      final response = await _backendApiService.getWalletCollectibleIndex(
        normalized,
      );
      final payload = response['data'];
      final rawCollectibles = payload is Map<String, dynamic>
          ? payload['collectibles']
          : response['collectibles'];
      final records = _normalizeBackendCollectibleRecords(rawCollectibles);
      _walletCollectibleIndex[normalized] = records;
      notifyListeners();
    } catch (_) {
      // The provider must keep working when the dedicated index is unavailable.
    }
  }

  // Get series by artwork ID
  CollectibleSeries? getSeriesByArtworkId(String artworkId) {
    for (final series in allSeries) {
      if (series.artworkId == artworkId) {
        return series;
      }
    }
    return null;
  }

  // Get all series for AR-enabled artworks
  List<CollectibleSeries> getARSeries() {
    return allSeries.where((series) => series.requiresARInteraction).toList();
  }

  List<MarketplaceArtworkEntry> getFeaturedMarketplaceEntries({int limit = 6}) {
    final featured = marketplaceEntries.where((entry) {
      final series = entry.series;
      return entry.requiresArInteraction ||
          entry.isListed ||
          (series?.isLimitedEdition ?? false) ||
          entry.rarity == CollectibleRarity.legendary ||
          entry.rarity == CollectibleRarity.mythic;
    }).toList();

    featured.sort((a, b) {
      final listedCompare = (b.isListed ? 1 : 0).compareTo(a.isListed ? 1 : 0);
      if (listedCompare != 0) return listedCompare;
      final soldOutCompare =
          (a.isSoldOut ? 1 : 0).compareTo(b.isSoldOut ? 1 : 0);
      if (soldOutCompare != 0) return soldOutCompare;
      return b.sortTimestamp.compareTo(a.sortTimestamp);
    });
    return featured.take(limit).toList(growable: false);
  }

  List<MarketplaceArtworkEntry> getTrendingMarketplaceEntries(
      {int limit = 10}) {
    final trending = marketplaceEntries.toList();
    trending.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
    return trending.take(limit).toList(growable: false);
  }

  MarketplaceArtworkEntry? getMarketplaceEntryForCollectible(
      Collectible collectible) {
    final artworkId = _resolveArtworkIdForCollectible(collectible);
    if (artworkId == null || artworkId.isEmpty) return null;
    final artwork = _artworkProvider?.getArtworkById(artworkId);
    if (artwork == null) return null;

    final linkedCollectibles = allCollectibles.where((candidate) {
      final candidateArtworkId = _resolveArtworkIdForCollectible(candidate);
      return candidateArtworkId == artworkId &&
          candidate.status != CollectibleStatus.burned;
    }).toList(growable: false);

    final series = getSeriesByArtworkId(artworkId);

    final hasMintedProof =
        _hasBackendMintedProof(artwork) || linkedCollectibles.isNotEmpty;
    if (!hasMintedProof) return null;

    return _createMarketplaceEntry(
      artwork: artwork,
      series: series,
      linkedCollectibles: linkedCollectibles,
      hasMintedProof: hasMintedProof,
    );
  }

  MarketplaceDisplayValue? getDisplayValueForCollectible(
    Collectible collectible,
  ) {
    var resolvedCollectible = collectible;
    for (final candidate in allCollectibles) {
      final sameIdentity = candidate.id == collectible.id ||
          (candidate.seriesId == collectible.seriesId &&
              candidate.tokenId == collectible.tokenId);
      if (sameIdentity) {
        resolvedCollectible = candidate;
        break;
      }
    }

    CollectibleSeries? series;
    for (final candidate in allSeries) {
      if (candidate.id == resolvedCollectible.seriesId) {
        series = candidate;
        break;
      }
    }

    final artwork = series == null
        ? null
        : _artworkProvider?.getArtworkById(series.artworkId);

    return _resolveDisplayValue(
      artwork: artwork,
      series: series,
      collectibles: const <Collectible>[],
      preferredCollectible: resolvedCollectible,
    );
  }

  // Get collectibles by owner
  List<Collectible> getCollectiblesByOwner(String ownerAddress) {
    final normalized = _canonicalWallet(ownerAddress);
    if (normalized.isEmpty) return const <Collectible>[];
    return allCollectibles
        .where((collectible) =>
            _canonicalWallet(collectible.ownerAddress) == normalized)
        .toList(growable: false);
  }

  // Get collectibles for sale
  List<Collectible> getCollectiblesForSale() {
    return allCollectibles
        .where((collectible) => collectible.isForSale)
        .toList(growable: false);
  }

  // Get trending series (most recent activity)
  List<CollectibleSeries> getTrendingSeries({int limit = 10}) {
    final sortedSeries = List<CollectibleSeries>.from(allSeries);
    sortedSeries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedSeries.take(limit).toList();
  }

  // Get featured series (high activity, limited edition, etc.)
  List<CollectibleSeries> getFeaturedSeries({int limit = 6}) {
    final featuredSeries = allSeries
        .where((series) =>
            series.isLimitedEdition ||
            series.rarity == CollectibleRarity.legendary ||
            series.rarity == CollectibleRarity.mythic ||
            series.requiresARInteraction)
        .toList();

    featuredSeries.sort((a, b) => b.mintProgress.compareTo(a.mintProgress));
    return featuredSeries.take(limit).toList();
  }

  // Create a new NFT series for an artwork
  Future<CollectibleSeries> createNFTSeries({
    required String artworkId,
    required String name,
    required String description,
    required String creatorAddress,
    required int totalSupply,
    required CollectibleRarity rarity,
    required double mintPrice,
    String? imageUrl,
    String? animationUrl,
    Map<String, dynamic> metadata = const {},
    bool requiresARInteraction = false,
    double? royaltyPercentage,
  }) async {
    // Allow local test/dev seeding when running in debug mode to support
    // widget tests that need mock series/collectibles. Production/canonical
    // mode still throws to enforce on-chain flows.
    if (!kDebugMode) {
      throw UnsupportedError(
        'Create series is disabled in canonical mode. Minting must happen through wallet-native on-chain flow and backend indexing.',
      );
    }

    final id = 'legacy_series_${artworkId}_${DateTime.now().microsecondsSinceEpoch}';
    final createdAt = DateTime.now();
    final series = CollectibleSeries(
      id: id,
      name: name,
      description: description,
      artworkId: artworkId,
      creatorAddress: creatorAddress,
      totalSupply: totalSupply,
      mintedCount: 0,
      rarity: rarity,
      type: CollectibleType.nft,
      mintPrice: mintPrice,
      imageUrl: imageUrl,
      animationUrl: animationUrl,
      metadata: metadata,
      createdAt: createdAt,
      requiresARInteraction: requiresARInteraction,
    );

    _legacySeries.add(series);
    notifyListeners();
    return series;
  }

  // Mint a new collectible from a series
  Future<Collectible> mintCollectible({
    required String seriesId,
    required String ownerAddress,
    required String transactionHash,
    Map<String, dynamic> properties = const {},
  }) async {
    if (!kDebugMode) {
      throw UnsupportedError(
        'Local mint simulation is disabled in canonical mode. Use wallet-native minting and wait for backend-indexed mint proof.',
      );
    }

    final series = _legacySeries.firstWhere(
      (s) => s.id == seriesId,
      orElse: () => throw StateError('Series not found'),
    );

    final tokenId = (series.mintedCount + 1).toString();
    final collectible = Collectible(
      id: 'legacy_collectible_${seriesId}_$tokenId',
      seriesId: seriesId,
      tokenId: tokenId,
      ownerAddress: ownerAddress,
      status: CollectibleStatus.minted,
      mintedAt: DateTime.now(),
      currentListingPrice: null,
      listedAt: null,
      properties: {
        'artwork_id': series.artworkId,
        ...properties,
      },
      transactionHash: transactionHash,
    );

    _legacyCollectibles.add(collectible);
    // update minted count on the legacy series
    final idx = _legacySeries.indexWhere((s) => s.id == seriesId);
    if (idx != -1) {
      final updated = _legacySeries[idx].copyWith(mintedCount: _legacySeries[idx].mintedCount + 1);
      _legacySeries[idx] = updated;
    }

    notifyListeners();
    return collectible;
  }

  // List collectible for sale
  Future<void> listCollectibleForSale({
    required String collectibleId,
    required String price,
  }) async {
    _setLoading(true);

    try {
      final collectible = allCollectibles.firstWhere(
        (c) => c.id == collectibleId,
        orElse: () => throw StateError('Collectible not found'),
      );

      final artworkId = _resolveArtworkIdForCollectible(collectible);
      if (artworkId == null || artworkId.isEmpty) {
        throw Exception('Collectible not found');
      }

      final parsed = double.tryParse(price.trim());
      if (parsed == null || parsed <= 0) {
        throw Exception('Invalid listing price');
      }

      final artworkProvider = _artworkProvider;
      if (artworkProvider == null) {
        throw Exception('Artwork provider is unavailable');
      }

      final updated = await artworkProvider.updateArtwork(artworkId, {
        'price': parsed,
        'currency': 'KUB8',
      });

      if (updated == null) {
        throw Exception('Failed to update listing on canonical artwork record');
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to list collectible: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeCollectibleFromSale({
    required String collectibleId,
  }) async {
    _setLoading(true);

    try {
      final collectible = allCollectibles.firstWhere(
        (c) => c.id == collectibleId,
        orElse: () => throw StateError('Collectible not found'),
      );

      final artworkId = _resolveArtworkIdForCollectible(collectible);
      if (artworkId == null || artworkId.isEmpty) {
        throw Exception('Collectible not found');
      }

      final artworkProvider = _artworkProvider;
      if (artworkProvider == null) {
        throw Exception('Artwork provider is unavailable');
      }

      final updated = await artworkProvider.updateArtwork(artworkId, {
        'price': null,
      });

      if (updated == null) {
        throw Exception('Failed to update listing on canonical artwork record');
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to remove collectible from sale: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Purchase collectible
  Future<void> purchaseCollectible({
    required String collectibleId,
    required String buyerAddress,
    required double salePrice,
    required String transactionHash,
  }) async {
    if (!kDebugMode) {
      throw UnsupportedError(
        'Purchase transfer simulation is disabled in canonical mode. Ownership transfer must come from indexed on-chain settlement.',
      );
    }

    final idx = _legacyCollectibles.indexWhere((c) => c.id == collectibleId);
    if (idx == -1) throw StateError('Collectible not found');

    final existing = _legacyCollectibles[idx];
    final updated = existing.copyWith(
      ownerAddress: buyerAddress,
      status: CollectibleStatus.sold,
      transactionHash: transactionHash,
      lastSalePrice: salePrice,
      lastSaleAt: DateTime.now(),
    );

    _legacyCollectibles[idx] = updated;
    notifyListeners();
  }

  // Initialize with mock data
  Future<void> initializeMockData() async {
    if (!kDebugMode) {
      _setError(
        'Mock collectible data is disabled in canonical mode. Use indexed artwork mint records.',
      );
      return;
    }

    // populate legacy lists from bundled fixtures or keep empty for tests to seed
    _legacySeries.clear();
    _legacyCollectibles.clear();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _artworkProvider?.removeListener(_handleArtworkProviderChanged);
    super.dispose();
  }

  List<MarketplaceArtworkEntry> _buildMarketplaceEntries() {
    final artworkProvider = _artworkProvider;
    if (artworkProvider == null) return const <MarketplaceArtworkEntry>[];

    final canonicalCollectibles = _buildCanonicalCollectibles();
    final entries = <MarketplaceArtworkEntry>[];
    for (final artwork in artworkProvider.artworks) {
      if (!artwork.isActive ||
          !artwork.isPublic ||
          !_hasBackendMintedProof(artwork)) {
        continue;
      }

      final series = getSeriesByArtworkId(artwork.id);
      final linkedCollectibles = canonicalCollectibles.where((candidate) {
        final candidateArtworkId = _resolveArtworkIdForCollectible(candidate);
        return candidateArtworkId == artwork.id;
      }).toList(growable: false);

      entries.add(
        _createMarketplaceEntry(
          artwork: artwork,
          series: series,
          linkedCollectibles: linkedCollectibles,
          hasMintedProof: true,
        ),
      );
    }

    entries.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
    return List<MarketplaceArtworkEntry>.unmodifiable(entries);
  }

  MarketplaceArtworkEntry _createMarketplaceEntry({
    required Artwork artwork,
    required CollectibleSeries? series,
    required List<Collectible> linkedCollectibles,
    required bool hasMintedProof,
  }) {
    return MarketplaceArtworkEntry(
      artwork: artwork,
      series: series,
      collectibles: linkedCollectibles,
      coverUrl: ArtworkMediaResolver.resolveCover(
        artwork: artwork,
        metadata: series?.metadata,
        fallbackUrl: series?.imageUrl,
      ),
      displayValue: _resolveDisplayValue(
        artwork: artwork,
        series: series,
        collectibles: linkedCollectibles,
      ),
      hasMintedProof: hasMintedProof,
      isListed: linkedCollectibles.any((candidate) => candidate.isForSale),
      requiresArInteraction:
          (series?.requiresARInteraction ?? false) || artwork.arEnabled,
    );
  }

  bool _hasBackendMintedProof(Artwork artwork) {
    final mintAddress = artwork.nftMintAddress?.trim() ?? '';
    return mintAddress.isNotEmpty;
  }

  List<CollectibleSeries> _buildCanonicalSeries() {
    final artworkProvider = _artworkProvider;
    if (artworkProvider == null) return const <CollectibleSeries>[];

    final series = <CollectibleSeries>[];
    for (final artwork in artworkProvider.artworks) {
      if (!artwork.isActive || !_hasBackendMintedProof(artwork)) continue;
      final walletAddress = (artwork.walletAddress ?? '').trim();
      final mintedAt = artwork.updatedAt ?? artwork.createdAt;
      series.add(
        CollectibleSeries(
          id: _seriesIdForArtwork(artwork.id),
          name: artwork.title,
          description: artwork.description,
          artworkId: artwork.id,
          creatorAddress: walletAddress,
          totalSupply: 1,
          mintedCount: 1,
          rarity: _inferRarity(artwork),
          type: CollectibleType.nft,
          mintPrice: artwork.price ?? 0,
          imageUrl: artwork.imageUrl,
          animationUrl: artwork.model3DURL,
          metadata: {
            'mintAddress': artwork.nftMintAddress,
            'metadataUri': artwork.nftMetadataUri,
            'ownershipStatus': _ownershipStatusCreatorIndexedUnverified,
            'collectionIds': _extractStringListFromMetadata(
              artwork,
              const ['collectionIds', 'collection_ids'],
            ),
            'exhibitionIds': _extractStringListFromMetadata(
              artwork,
              const ['exhibitionIds', 'exhibition_ids'],
            ),
            'eventIds': _extractStringListFromMetadata(
              artwork,
              const ['eventIds', 'event_ids'],
            ),
          },
          createdAt: mintedAt,
          requiresARInteraction: artwork.arEnabled,
        ),
      );
    }
    return series;
  }

  List<Collectible> _buildCanonicalCollectibles() {
    final artworkProvider = _artworkProvider;
    if (artworkProvider == null) return const <Collectible>[];

    final collectibles = <Collectible>[];
    for (final artwork in artworkProvider.artworks) {
      if (!artwork.isActive || !_hasBackendMintedProof(artwork)) continue;
      final walletAddress = (artwork.walletAddress ?? '').trim();
      final mintedAt = artwork.updatedAt ?? artwork.createdAt;
      collectibles.add(
        Collectible(
          id: _collectibleIdForArtwork(artwork.id),
          seriesId: _seriesIdForArtwork(artwork.id),
          tokenId: '1',
          ownerAddress: walletAddress,
          status: artwork.isForSale
              ? CollectibleStatus.listed
              : CollectibleStatus.minted,
          mintedAt: mintedAt,
          currentListingPrice: artwork.isForSale && artwork.price != null
              ? '${artwork.price}'
              : null,
          listedAt: artwork.isForSale
              ? (artwork.updatedAt ?? artwork.createdAt)
              : null,
          properties: {
            'artwork_id': artwork.id,
            'mint_address': artwork.nftMintAddress,
            'metadata_uri': artwork.nftMetadataUri,
            'ownership_status': _ownershipStatusCreatorIndexedUnverified,
            'collection_ids': _extractStringListFromMetadata(
              artwork,
              const ['collectionIds', 'collection_ids'],
            ),
            'exhibition_ids': _extractStringListFromMetadata(
              artwork,
              const ['exhibitionIds', 'exhibition_ids'],
            ),
            'event_ids': _extractStringListFromMetadata(
              artwork,
              const ['eventIds', 'event_ids'],
            ),
          },
          transactionHash: null,
        ),
      );
    }

    collectibles.sort((a, b) => b.mintedAt.compareTo(a.mintedAt));
    return collectibles;
  }

  List<Collectible> _applyWalletCollectibleIndex(
      List<Collectible> collectibles) {
    if (_walletCollectibleIndex.isEmpty) return collectibles;

    final overrides = <String, Map<String, dynamic>>{};
    for (final records in _walletCollectibleIndex.values) {
      for (final record in records) {
        final collectibleId = _resolveCollectibleIdFromIndexRecord(record);
        if (collectibleId == null || collectibleId.isEmpty) continue;
        overrides[collectibleId] = record;
      }
    }

    if (overrides.isEmpty) return collectibles;

    return collectibles.map((collectible) {
      final record = overrides[collectible.id];
      if (record == null) return collectible;
      return _overlayCollectibleWithIndex(collectible, record);
    }).toList(growable: false);
  }

  Collectible _overlayCollectibleWithIndex(
    Collectible collectible,
    Map<String, dynamic> record,
  ) {
    final ownershipState = _normalizeOwnershipState(
      record['ownershipState'] ?? record['ownership_state'],
    );
    final ownershipEvidence = _mapOrNull(record['ownershipEvidence']) ??
        _mapOrNull(record['ownership_evidence']);
    final provenance = _mapOrNull(record['provenance']) ??
        _mapOrNull(record['provenanceContext']);

    final mergedProperties = Map<String, dynamic>.from(collectible.properties)
      ..addAll({
        if (record['artworkId'] != null) 'artwork_id': record['artworkId'],
        if (record['artwork_id'] != null) 'artwork_id': record['artwork_id'],
        if (record['mintAddress'] != null)
          'mint_address': record['mintAddress'],
        if (record['mint_address'] != null)
          'mint_address': record['mint_address'],
        if (record['metadataUri'] != null)
          'metadata_uri': record['metadataUri'],
        if (record['metadata_uri'] != null)
          'metadata_uri': record['metadata_uri'],
        if (ownershipState != null) 'ownership_state': ownershipState,
        if (ownershipEvidence != null) 'ownership_evidence': ownershipEvidence,
        if (provenance != null) 'provenance': provenance,
      });

    final status =
        _parseCollectibleStatus(record['status']) ?? collectible.status;
    final mintedAt = _parseDateTime(record['mintedAt']) ??
        _parseDateTime(record['minted_at']) ??
        collectible.mintedAt;
    final listedAt = _parseDateTime(record['listedAt']) ??
        _parseDateTime(record['listed_at']) ??
        collectible.listedAt;
    final lastSaleAt = _parseDateTime(record['lastSaleAt']) ??
        _parseDateTime(record['last_sale_at']) ??
        collectible.lastSaleAt;
    final lastTransferAt = _parseDateTime(record['lastTransferAt']) ??
        _parseDateTime(record['last_transfer_at']) ??
        collectible.lastTransferAt;
    final currentListingPrice = (record['currentListingPrice'] ??
            record['current_listing_price'] ??
            collectible.currentListingPrice)
        ?.toString();

    return collectible.copyWith(
      ownerAddress: (record['ownerAddress'] ??
              record['owner_address'] ??
              collectible.ownerAddress)
          .toString(),
      status: status,
      mintedAt: mintedAt,
      currentListingPrice: currentListingPrice,
      listedAt: listedAt,
      properties: mergedProperties,
      transactionHash: (record['transactionHash'] ??
              record['transaction_hash'] ??
              collectible.transactionHash)
          ?.toString(),
      lastSalePrice: _parseNullableDouble(
              record['lastSalePrice'] ?? record['last_sale_price']) ??
          collectible.lastSalePrice,
      lastSaleAt: lastSaleAt,
      lastTransferAt: lastTransferAt,
    );
  }

  List<Map<String, dynamic>> _normalizeBackendCollectibleRecords(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _normalizeOwnershipState(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    final status = value?.toString().trim();
    if (status == null || status.isEmpty) return null;
    return {
      'status': status,
      'currentOwnerVerified': status == 'verified_onchain_owner',
      'transferHistoryIndexed': status == 'verified_onchain_owner' ||
          status == 'indexed_owner_unverified_transfer_history',
    };
  }

  String? _resolveCollectibleIdFromIndexRecord(Map<String, dynamic> record) {
    final collectibleId =
        (record['collectibleId'] ?? record['collectible_id'] ?? '')
            .toString()
            .trim();
    if (collectibleId.isNotEmpty) return collectibleId;

    final artworkId =
        (record['artworkId'] ?? record['artwork_id'] ?? '').toString().trim();
    if (artworkId.isNotEmpty) {
      return _collectibleIdForArtwork(artworkId);
    }

    return null;
  }

  CollectibleStatus? _parseCollectibleStatus(dynamic raw) {
    if (raw == null) return null;
    final normalized = raw.toString().trim().toLowerCase();
    switch (normalized) {
      case 'listed':
        return CollectibleStatus.listed;
      case 'sold':
        return CollectibleStatus.sold;
      case 'burned':
        return CollectibleStatus.burned;
      case 'minted':
      default:
        return CollectibleStatus.minted;
    }
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _parseNullableDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  CollectibleRarity _inferRarity(Artwork artwork) {
    if (artwork.likesCount >= 200) return CollectibleRarity.legendary;
    if (artwork.likesCount >= 100) return CollectibleRarity.epic;
    if (artwork.likesCount >= 50) return CollectibleRarity.rare;
    if (artwork.likesCount >= 20) return CollectibleRarity.uncommon;
    return CollectibleRarity.common;
  }

  String? _resolveArtworkIdForCollectible(Collectible collectible) {
    final rawFromProps =
        collectible.properties['artwork_id']?.toString().trim();
    if (rawFromProps != null && rawFromProps.isNotEmpty) {
      return rawFromProps;
    }

    const seriesPrefix = 'artwork_series_';
    if (collectible.seriesId.startsWith(seriesPrefix)) {
      final artworkId = collectible.seriesId.substring(seriesPrefix.length);
      if (artworkId.trim().isNotEmpty) {
        return artworkId;
      }
    }

    const collectiblePrefix = 'artwork_collectible_';
    if (collectible.id.startsWith(collectiblePrefix)) {
      final artworkId = collectible.id.substring(collectiblePrefix.length);
      if (artworkId.trim().isNotEmpty) {
        return artworkId;
      }
    }

    return null;
  }

  List<String> _extractStringListFromMetadata(
    Artwork artwork,
    List<String> keys,
  ) {
    final metadata = artwork.metadata;
    if (metadata == null) return const <String>[];

    for (final key in keys) {
      final raw = metadata[key];
      if (raw is List) {
        return raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) {
          return trimmed
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
        }
      }
    }
    return const <String>[];
  }

  MarketplaceDisplayValue? _resolveDisplayValue({
    Artwork? artwork,
    required CollectibleSeries? series,
    required List<Collectible> collectibles,
    Collectible? preferredCollectible,
  }) {
    final fallbackCurrency = _normalizeCurrency(artwork?.currency);
    if (preferredCollectible != null && preferredCollectible.isForSale) {
      final price =
          _parseNumericPrice(preferredCollectible.currentListingPrice);
      if (price != null) {
        return MarketplaceDisplayValue(
          source: MarketplaceValueSource.listing,
          label: 'Listed for',
          amount: price,
          currency: fallbackCurrency,
        );
      }
    }

    final listedCollectibles = collectibles
        .where((candidate) => candidate.isForSale)
        .toList(growable: false)
      ..sort((a, b) {
        final aListedAt = a.listedAt ?? a.mintedAt;
        final bListedAt = b.listedAt ?? b.mintedAt;
        return bListedAt.compareTo(aListedAt);
      });

    if (listedCollectibles.isNotEmpty) {
      final price =
          _parseNumericPrice(listedCollectibles.first.currentListingPrice);
      if (price != null) {
        return MarketplaceDisplayValue(
          source: MarketplaceValueSource.listing,
          label: 'Listed for',
          amount: price,
          currency: fallbackCurrency,
        );
      }
    }

    if (artwork != null && artwork.isForSale && artwork.price != null) {
      return MarketplaceDisplayValue(
        source: MarketplaceValueSource.artworkListing,
        label: 'Listed for',
        amount: artwork.price,
        currency: fallbackCurrency,
      );
    }

    if (preferredCollectible?.lastSalePrice != null) {
      return MarketplaceDisplayValue(
        source: MarketplaceValueSource.lastSale,
        label: 'Last sale',
        amount: preferredCollectible!.lastSalePrice,
        currency: fallbackCurrency,
      );
    }

    final soldCollectibles = collectibles
        .where((candidate) => candidate.lastSalePrice != null)
        .toList(growable: false)
      ..sort((a, b) {
        final aSoldAt = a.lastSaleAt ?? a.mintedAt;
        final bSoldAt = b.lastSaleAt ?? b.mintedAt;
        return bSoldAt.compareTo(aSoldAt);
      });
    if (soldCollectibles.isNotEmpty) {
      return MarketplaceDisplayValue(
        source: MarketplaceValueSource.lastSale,
        label: 'Last sale',
        amount: soldCollectibles.first.lastSalePrice,
        currency: fallbackCurrency,
      );
    }

    if (series != null) {
      return MarketplaceDisplayValue(
        source: MarketplaceValueSource.mint,
        label: 'Mint price',
        amount: series.mintPrice,
        currency: fallbackCurrency,
      );
    }

    return null;
  }

  double? _parseNumericPrice(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  String _normalizeCurrency(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'KUB8';
    return trimmed;
  }
}
