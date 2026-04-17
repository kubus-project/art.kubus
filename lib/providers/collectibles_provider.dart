import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/artwork.dart';
import '../models/collectible.dart';
import '../services/collectibles_storage.dart';
import '../utils/artwork_media_resolver.dart';
import 'artwork_provider.dart';

class CollectiblesProvider with ChangeNotifier {
  final List<CollectibleSeries> _series = [];
  final List<Collectible> _collectibles = [];
  final CollectiblesStorage _storage = CollectiblesStorage();
  ArtworkProvider? _artworkProvider;

  bool _isLoading = false;
  String? _error;

  // Getters
  List<CollectibleSeries> get allSeries => List.unmodifiable(_series);
  List<Collectible> get allCollectibles => List.unmodifiable(_collectibles);
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

  String _nextSeriesId() =>
      'series_${DateTime.now().microsecondsSinceEpoch}_${_series.length + 1}';

  String _nextCollectibleId() =>
      'collectible_${DateTime.now().microsecondsSinceEpoch}_${_collectibles.length + 1}';

  Future<void> initialize({bool loadMockIfEmpty = false}) async {
    _setLoading(true);

    try {
      final loadedSeries = await _storage.loadSeries();
      final loadedCollectibles = await _storage.loadCollectibles();

      _series
        ..clear()
        ..addAll(loadedSeries);
      _collectibles
        ..clear()
        ..addAll(loadedCollectibles);

      if (loadMockIfEmpty && _series.isEmpty) {
        await initializeMockData();
      } else {
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load collectibles: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get series by artwork ID
  CollectibleSeries? getSeriesByArtworkId(String artworkId) {
    try {
      return _series.firstWhere((series) => series.artworkId == artworkId);
    } catch (e) {
      return null;
    }
  }

  // Get all series for AR-enabled artworks
  List<CollectibleSeries> getARSeries() {
    return _series.where((series) => series.requiresARInteraction).toList();
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
    CollectibleSeries? series;
    for (final candidate in _series) {
      if (candidate.id == collectible.seriesId) {
        series = candidate;
        break;
      }
    }
    if (series == null) return null;

    final artwork = _resolveArtworkForSeries(
      series,
      allowFallback: true,
      includeNonPublic: true,
    );
    if (artwork == null) return null;
    final seriesId = series.id;

    final linkedCollectibles = _collectibles
        .where((candidate) =>
            candidate.seriesId == seriesId &&
            candidate.status != CollectibleStatus.burned)
        .toList(growable: false);

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
    for (final candidate in _collectibles) {
      final sameIdentity = candidate.id == collectible.id ||
          (candidate.seriesId == collectible.seriesId &&
              candidate.tokenId == collectible.tokenId);
      if (sameIdentity) {
        resolvedCollectible = candidate;
        break;
      }
    }

    CollectibleSeries? series;
    for (final candidate in _series) {
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
    return _collectibles
        .where((collectible) => collectible.ownerAddress == ownerAddress)
        .toList();
  }

  // Get collectibles for sale
  List<Collectible> getCollectiblesForSale() {
    return _collectibles.where((collectible) => collectible.isForSale).toList();
  }

  // Get trending series (most recent activity)
  List<CollectibleSeries> getTrendingSeries({int limit = 10}) {
    final sortedSeries = List<CollectibleSeries>.from(_series);
    sortedSeries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedSeries.take(limit).toList();
  }

  // Get featured series (high activity, limited edition, etc.)
  List<CollectibleSeries> getFeaturedSeries({int limit = 6}) {
    final featuredSeries = _series
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
    _setLoading(true);

    try {
      final series = CollectibleSeries(
        id: _nextSeriesId(),
        name: name,
        description: description,
        artworkId: artworkId,
        creatorAddress: creatorAddress,
        totalSupply: totalSupply,
        rarity: rarity,
        type: CollectibleType.nft,
        mintPrice: mintPrice,
        imageUrl: imageUrl,
        animationUrl: animationUrl,
        metadata: metadata,
        createdAt: DateTime.now(),
        requiresARInteraction: requiresARInteraction,
        royaltyPercentage: royaltyPercentage,
      );

      _series.add(series);
      notifyListeners();
      await _persist();

      return series;
    } catch (e) {
      _setError('Failed to create NFT series: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Mint a new collectible from a series
  Future<Collectible> mintCollectible({
    required String seriesId,
    required String ownerAddress,
    required String transactionHash,
    Map<String, dynamic> properties = const {},
  }) async {
    _setLoading(true);

    try {
      final series = _series.firstWhere((s) => s.id == seriesId);

      if (series.isSoldOut) {
        throw Exception('Series is sold out');
      }

      final collectible = Collectible(
        id: _nextCollectibleId(),
        seriesId: seriesId,
        tokenId: '${series.mintedCount + 1}',
        ownerAddress: ownerAddress,
        status: CollectibleStatus.minted,
        mintedAt: DateTime.now(),
        properties: properties,
        transactionHash: transactionHash,
      );

      _collectibles.add(collectible);

      // Update series minted count
      final updatedSeries =
          series.copyWith(mintedCount: series.mintedCount + 1);
      final seriesIndex = _series.indexWhere((s) => s.id == seriesId);
      _series[seriesIndex] = updatedSeries;

      notifyListeners();
      await _persist();

      return collectible;
    } catch (e) {
      _setError('Failed to mint collectible: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // List collectible for sale
  Future<void> listCollectibleForSale({
    required String collectibleId,
    required String price,
  }) async {
    _setLoading(true);

    try {
      final collectibleIndex =
          _collectibles.indexWhere((c) => c.id == collectibleId);
      if (collectibleIndex == -1) {
        throw Exception('Collectible not found');
      }

      final updatedCollectible = _collectibles[collectibleIndex].copyWith(
        status: CollectibleStatus.listed,
        currentListingPrice: price,
        listedAt: DateTime.now(),
      );

      _collectibles[collectibleIndex] = updatedCollectible;
      notifyListeners();
      await _persist();
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
      final collectibleIndex =
          _collectibles.indexWhere((c) => c.id == collectibleId);
      if (collectibleIndex == -1) {
        throw Exception('Collectible not found');
      }

      final collectible = _collectibles[collectibleIndex];
      final updatedCollectible = Collectible(
        id: collectible.id,
        seriesId: collectible.seriesId,
        tokenId: collectible.tokenId,
        ownerAddress: collectible.ownerAddress,
        status: CollectibleStatus.minted,
        mintedAt: collectible.mintedAt,
        lastSalePrice: collectible.lastSalePrice,
        lastSaleAt: collectible.lastSaleAt,
        properties: collectible.properties,
        transactionHash: collectible.transactionHash,
        isAuthentic: collectible.isAuthentic,
        lastTransferAt: collectible.lastTransferAt,
      );

      _collectibles[collectibleIndex] = updatedCollectible;
      notifyListeners();
      await _persist();
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
    _setLoading(true);

    try {
      final collectibleIndex =
          _collectibles.indexWhere((c) => c.id == collectibleId);
      if (collectibleIndex == -1) {
        throw Exception('Collectible not found');
      }

      final updatedCollectible = _collectibles[collectibleIndex].copyWith(
        ownerAddress: buyerAddress,
        status: CollectibleStatus.sold,
        lastSalePrice: salePrice,
        lastSaleAt: DateTime.now(),
        currentListingPrice: null,
        listedAt: null,
        lastTransferAt: DateTime.now(),
      );

      _collectibles[collectibleIndex] = updatedCollectible;
      notifyListeners();
      await _persist();
    } catch (e) {
      _setError('Failed to purchase collectible: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Initialize with mock data
  Future<void> initializeMockData() async {
    _setLoading(true);

    try {
      _series.clear();
      _collectibles.clear();
      // Create some mock NFT series for AR artworks
      await _createMockSeries();
      await _createMockCollectibles();
      await _persist();
    } catch (e) {
      _setError('Failed to initialize mock data: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _persist() async {
    try {
      await _storage.saveSeries(_series);
      await _storage.saveCollectibles(_collectibles);
    } catch (e) {
      debugPrint('CollectiblesProvider: persist failed: $e');
    }
  }

  Future<void> _createMockSeries() async {
    final mockSeries = [
      CollectibleSeries(
        id: 'series_1',
        name: 'Digital Echoes Collection',
        description:
            'Interactive AR sculptures that respond to viewer presence',
        artworkId: 'artwork_1',
        creatorAddress: '0x1234...5678',
        totalSupply: 100,
        mintedCount: 45,
        rarity: CollectibleRarity.rare,
        type: CollectibleType.nft,
        mintPrice: 50.0,
        imageUrl: 'https://example.com/digital_echoes.jpg',
        animationUrl: 'https://example.com/digital_echoes.glb',
        metadata: {
          'artist': 'Maya Chen',
          'medium': 'Digital AR Sculpture',
          'year': '2025',
          'interactive': true,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        requiresARInteraction: true,
        royaltyPercentage: 10.0,
      ),
      CollectibleSeries(
        id: 'series_2',
        name: 'Urban Metamorphosis',
        description: 'Street art that transforms through AR overlay',
        artworkId: 'artwork_2',
        creatorAddress: '0xabcd...efgh',
        totalSupply: 50,
        mintedCount: 50,
        rarity: CollectibleRarity.legendary,
        type: CollectibleType.nft,
        mintPrice: 150.0,
        imageUrl: 'https://example.com/urban_meta.jpg',
        animationUrl: 'https://example.com/urban_meta.mp4',
        metadata: {
          'artist': 'Street Vision Collective',
          'medium': 'AR Street Art',
          'year': '2025',
          'location': 'Downtown District',
        },
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        requiresARInteraction: true,
        royaltyPercentage: 7.5,
      ),
      CollectibleSeries(
        id: 'series_3',
        name: 'Quantum Gardens',
        description: 'Botanical AR installations that bloom over time',
        artworkId: 'artwork_3',
        creatorAddress: '0x9876...5432',
        totalSupply: 25,
        mintedCount: 12,
        rarity: CollectibleRarity.mythic,
        type: CollectibleType.nft,
        mintPrice: 300.0,
        imageUrl: 'https://example.com/quantum_gardens.jpg',
        animationUrl: 'https://example.com/quantum_gardens.glb',
        metadata: {
          'artist': 'Bio-Digital Labs',
          'medium': 'Living AR Installation',
          'year': '2025',
          'interactive': true,
          'evolving': true,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        requiresARInteraction: true,
        royaltyPercentage: 15.0,
      ),
    ];

    _series.addAll(mockSeries);
  }

  Future<void> _createMockCollectibles() async {
    final mockCollectibles = [
      Collectible(
        id: 'collectible_1',
        seriesId: 'series_1',
        tokenId: '1',
        ownerAddress: '0xuser1...1234',
        status: CollectibleStatus.minted,
        mintedAt: DateTime.now().subtract(const Duration(days: 5)),
        properties: {
          'color_scheme': 'Cosmic Blue',
          'interaction_level': 'High',
          'rarity_trait': 'First Edition',
        },
        transactionHash: '0xtx1...hash',
      ),
      Collectible(
        id: 'collectible_2',
        seriesId: 'series_1',
        tokenId: '15',
        ownerAddress: '0xuser2...5678',
        status: CollectibleStatus.listed,
        mintedAt: DateTime.now().subtract(const Duration(days: 3)),
        currentListingPrice: '75.0',
        listedAt: DateTime.now().subtract(const Duration(hours: 12)),
        properties: {
          'color_scheme': 'Sunset Orange',
          'interaction_level': 'Medium',
          'rarity_trait': 'Animated Variant',
        },
        transactionHash: '0xtx2...hash',
      ),
      Collectible(
        id: 'collectible_3',
        seriesId: 'series_2',
        tokenId: '1',
        ownerAddress: '0xuser3...9999',
        status: CollectibleStatus.minted,
        mintedAt: DateTime.now().subtract(const Duration(days: 2)),
        lastSalePrice: 200.0,
        lastSaleAt: DateTime.now().subtract(const Duration(hours: 6)),
        properties: {
          'transformation': 'Day/Night Cycle',
          'location': 'Main Street Corner',
          'rarity_trait': 'Genesis Edition',
        },
        transactionHash: '0xtx3...hash',
      ),
    ];

    _collectibles.addAll(mockCollectibles);
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

    final artworksById = <String, Artwork>{
      for (final artwork in artworkProvider.artworks) artwork.id: artwork,
    };

    final publicArtworksById = <String, Artwork>{
      for (final artwork in artworksById.values)
        if (artwork.isActive && artwork.isPublic) artwork.id: artwork,
    };

    final collectiblesBySeriesId = <String, List<Collectible>>{};
    for (final collectible in _collectibles) {
      if (collectible.status == CollectibleStatus.burned) continue;
      collectiblesBySeriesId
          .putIfAbsent(collectible.seriesId, () => <Collectible>[])
          .add(collectible);
    }

    final entries = <MarketplaceArtworkEntry>[];
    final artworkIdsWithSeriesEntries = <String>{};

    for (final series in _series) {
      final artwork = publicArtworksById[series.artworkId];
      if (artwork == null) continue;

      final linkedCollectibles = List<Collectible>.unmodifiable(
        collectiblesBySeriesId[series.id] ?? const <Collectible>[],
      );
      final hasMintedProof =
          _hasBackendMintedProof(artwork) || linkedCollectibles.isNotEmpty;
      if (!hasMintedProof) continue;

      artworkIdsWithSeriesEntries.add(artwork.id);
      entries.add(
        _createMarketplaceEntry(
          artwork: artwork,
          series: series,
          linkedCollectibles: linkedCollectibles,
          hasMintedProof: hasMintedProof,
        ),
      );
    }

    for (final artwork in publicArtworksById.values) {
      if (artworkIdsWithSeriesEntries.contains(artwork.id) ||
          !_hasBackendMintedProof(artwork)) {
        continue;
      }

      entries.add(
        _createMarketplaceEntry(
          artwork: artwork,
          series: null,
          linkedCollectibles: const <Collectible>[],
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

  Artwork? _resolveArtworkForSeries(
    CollectibleSeries series, {
    bool allowFallback = false,
    bool includeNonPublic = false,
  }) {
    final artwork = _artworkProvider?.getArtworkById(series.artworkId);
    if (artwork != null) {
      if (includeNonPublic || (artwork.isActive && artwork.isPublic)) {
        return artwork;
      }
    }

    if (!allowFallback) return null;

    return Artwork(
      id: series.artworkId,
      title: series.name,
      artist: series.creatorAddress.isNotEmpty
          ? series.creatorAddress
          : 'Unknown artist',
      description: series.description,
      imageUrl: series.imageUrl,
      position: const LatLng(0, 0),
      rewards: 0,
      createdAt: series.createdAt,
      isActive: series.isActive,
      isPublic: includeNonPublic,
      currency: 'KUB8',
    );
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
