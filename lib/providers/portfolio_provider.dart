import 'package:flutter/foundation.dart';

import '../models/artwork.dart';
import '../models/collection_record.dart';
import '../models/exhibition.dart';
import '../models/portfolio_entry.dart';
import '../providers/artwork_provider.dart';
import '../services/backend_api_service.dart';

class PortfolioProvider extends ChangeNotifier {
  final BackendApiService _api;

  PortfolioProvider({BackendApiService? api}) : _api = api ?? BackendApiService();

  String _walletAddress = '';
  ArtworkProvider? _artworkProvider;

  bool _loading = false;
  String? _error;

  List<Artwork> _artworks = const <Artwork>[];
  List<CollectionRecord> _collections = const <CollectionRecord>[];
  List<Exhibition> _exhibitions = const <Exhibition>[];

  String get walletAddress => _walletAddress;
  bool get isLoading => _loading;
  String? get error => _error;

  List<Artwork> get artworks => _artworks;
  List<CollectionRecord> get collections => _collections;
  List<Exhibition> get exhibitions => _exhibitions;

  void bindArtworkProvider(ArtworkProvider? artworkProvider) {
    if (identical(_artworkProvider, artworkProvider)) return;
    _artworkProvider = artworkProvider;
  }

  List<PortfolioEntry> get entries {
    final result = <PortfolioEntry>[
      ..._artworks.where((a) => a.isActive).map(PortfolioEntry.fromArtwork),
      ..._collections.map(PortfolioEntry.fromCollection),
      ..._exhibitions.map(PortfolioEntry.fromExhibition),
    ];

    DateTime sortKey(PortfolioEntry e) {
      return e.updatedAt ?? e.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    result.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
    return result;
  }

  Artwork? artworkById(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    try {
      return _artworks.firstWhere((a) => a.id == needle);
    } catch (_) {
      return null;
    }
  }

  CollectionRecord? collectionById(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    try {
      return _collections.firstWhere((c) => c.id == needle);
    } catch (_) {
      return null;
    }
  }

  Exhibition? exhibitionById(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    try {
      return _exhibitions.firstWhere((e) => e.id == needle);
    } catch (_) {
      return null;
    }
  }

  void setWalletAddress(String? walletAddress) {
    final next = (walletAddress ?? '').trim();
    if (next == _walletAddress) return;
    _walletAddress = next;
    _error = null;
    _artworks = const <Artwork>[];
    _collections = const <CollectionRecord>[];
    _exhibitions = const <Exhibition>[];
    notifyListeners();

    if (_walletAddress.isNotEmpty) {
      // Avoid doing work in widget build; schedule microtask.
      Future.microtask(() => refresh(force: true));
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    if (_walletAddress.isEmpty) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      Object? firstError;

      final artworksFuture = _loadAllArtworksForWallet(_walletAddress).catchError((e) {
        firstError ??= e;
        return const <Artwork>[];
      });
      final collectionsFuture = _loadAllCollectionsForWallet(_walletAddress).catchError((e) {
        firstError ??= e;
        return const <CollectionRecord>[];
      });
      final exhibitionsFuture = _api
          .listExhibitions(mine: true, limit: 50, offset: 0)
          .catchError((e) {
        firstError ??= e;
        return const <Exhibition>[];
      });

      final results = await Future.wait<dynamic>([
        artworksFuture,
        collectionsFuture,
        exhibitionsFuture,
      ]);

      _artworks = (results[0] as List<Artwork>);
      _collections = (results[1] as List<CollectionRecord>);
      _exhibitions = (results[2] as List<Exhibition>);

      if (firstError != null) {
        _error = firstError.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<Artwork>> _loadAllArtworksForWallet(String walletAddress) async {
    const pageSize = 50;
    const maxPages = 10;
    final results = <Artwork>[];

    for (var page = 1; page <= maxPages; page++) {
      final batch = await _api.getArtworks(
        page: page,
        limit: pageSize,
        walletAddress: walletAddress,
        includePrivateForWallet: true,
      );
      results.addAll(batch);
      if (batch.length < pageSize) break;
    }

    return results;
  }

  Future<List<CollectionRecord>> _loadAllCollectionsForWallet(String walletAddress) async {
    const pageSize = 50;
    const maxPages = 10;
    final results = <CollectionRecord>[];

    for (var page = 1; page <= maxPages; page++) {
      final batch = await _api.getCollections(
        walletAddress: walletAddress,
        page: page,
        limit: pageSize,
      );
      results.addAll(batch.map(CollectionRecord.fromMap));
      if (batch.length < pageSize) break;
    }

    return results;
  }

  // -------------------- Artwork lifecycle actions --------------------

  Future<Artwork?> publishArtwork(String artworkId) async {
    final id = artworkId.trim();
    if (id.isEmpty) return null;

    final updated = await _api.publishArtwork(id);
    if (updated != null) {
      _upsertArtwork(updated);
    }
    return updated;
  }

  Future<Artwork?> unpublishArtwork(String artworkId) async {
    final id = artworkId.trim();
    if (id.isEmpty) return null;

    final updated = await _api.unpublishArtwork(id);
    if (updated != null) {
      _upsertArtwork(updated);
    }
    return updated;
  }

  Future<Artwork?> updateArtwork(String artworkId, Map<String, dynamic> updates) async {
    final id = artworkId.trim();
    if (id.isEmpty) return null;

    final updated = await _api.updateArtwork(id, updates);
    if (updated != null) {
      _upsertArtwork(updated);
    }
    return updated;
  }

  Future<void> deleteArtwork(String artworkId) async {
    final id = artworkId.trim();
    if (id.isEmpty) return;

    await _api.deleteArtwork(id);
    _artworks = _artworks.where((a) => a.id != id).toList(growable: false);
    _artworkProvider?.removeArtwork(id);
    notifyListeners();
  }

  void _upsertArtwork(Artwork artwork) {
    final idx = _artworks.indexWhere((a) => a.id == artwork.id);
    if (idx >= 0) {
      final next = _artworks.toList(growable: false);
      next[idx] = artwork;
      _artworks = next;
    } else {
      _artworks = <Artwork>[artwork, ..._artworks];
    }
    _artworkProvider?.addOrUpdateArtwork(artwork);
    notifyListeners();
  }
}
