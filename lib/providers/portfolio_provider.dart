import 'package:flutter/foundation.dart';

import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../models/collection_record.dart';
import '../models/exhibition.dart';
import '../models/portfolio_entry.dart';
import '../models/profile_artworks_page.dart';
import '../providers/artwork_provider.dart';
import '../providers/app_refresh_provider.dart';
import '../services/backend_api_service.dart';
import '../services/profile_package_mutation_tracker.dart';

/// The studio's sections. Authored artworks and public art come from separate
/// backend relationship scopes and are never mixed into one list.
enum PortfolioStudioSection {
  authoredArtworks,
  publicArt,
  collectionsAndExhibitions,
}

/// Read-only load state of one studio section.
@immutable
class PortfolioSectionStatus {
  const PortfolioSectionStatus({
    required this.loaded,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.honoured,
    required this.total,
    required this.error,
  });

  /// True once a first page, or a failure, for this section has arrived.
  final bool loaded;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// False when the backend did not honour the requested relationship scope.
  /// Such a section shows an explicit unsupported state, never a mixed list.
  final bool honoured;

  /// Full backend total for the section, or null when it is unknown.
  final int? total;

  /// A failure message for the section. Null when the section is healthy.
  final String? error;
}

/// One backend relationship scope (`authored` or `documented`) of the studio.
class _ProfileArtworkScope {
  _ProfileArtworkScope(this.relationship);

  final String relationship;
  final List<PortfolioEntry> items = <PortfolioEntry>[];
  final Set<String> _ids = <String>{};

  /// Raw server rows consumed so far: the next page offset.
  int _consumed = 0;

  bool loaded = false;
  bool loading = false;
  bool loadingMore = false;
  bool honoured = false;
  int? total;
  String? error;

  bool get hasMore => honoured && total != null && _consumed < total!;

  int get nextOffset => _consumed;

  PortfolioSectionStatus get status => PortfolioSectionStatus(
        loaded: loaded,
        isLoading: loading,
        isLoadingMore: loadingMore,
        hasMore: hasMore,
        honoured: honoured,
        total: total,
        error: error,
      );

  void reset() {
    items.clear();
    _ids.clear();
    _consumed = 0;
    loaded = false;
    loading = false;
    loadingMore = false;
    honoured = false;
    total = null;
    error = null;
  }

  /// Applies one page. A page that does not honour the scope is discarded: its
  /// rows are a legacy mixed list and must never be shown as this scope.
  void apply(ProfileArtworksPage page, {required bool replace}) {
    loaded = true;
    error = null;
    if (replace) {
      items.clear();
      _ids.clear();
      _consumed = 0;
    }
    honoured = page.relationshipHonoured;
    if (!honoured) {
      items.clear();
      _ids.clear();
      _consumed = 0;
      total = null;
      return;
    }
    total = page.total;
    _consumed += page.items.length;
    for (final json in page.items) {
      final declared = json['relationship']?.toString().trim();
      if (declared != null && declared.isNotEmpty && declared != relationship) {
        continue;
      }
      final entry = PortfolioEntry.fromProfileArtwork(json);
      if (entry.id.isEmpty || !_ids.add(entry.id)) continue;
      items.add(entry);
    }
  }

  /// Records a failed request. A first-page failure clears the rows, so an
  /// error never reads as a stale list; a follow-up page keeps what loaded.
  void fail(Object error, {required bool replace}) {
    loaded = true;
    this.error = error.toString();
    if (replace) {
      items.clear();
      _ids.clear();
      _consumed = 0;
      honoured = false;
      total = null;
    }
  }

  void removeId(String id) {
    if (!_ids.remove(id)) return;
    items.removeWhere((entry) => entry.id == id);
    if (_consumed > 0) _consumed -= 1;
    if (total != null && total! > 0) total = total! - 1;
  }
}

class PortfolioProvider extends ChangeNotifier {
  /// Rows per page for a profile-scoped section.
  static const int scopePageSize = 24;

  final BackendApiService _api;

  PortfolioProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  String _walletAddress = '';
  ArtworkProvider? _artworkProvider;
  AppRefreshProvider? _appRefreshProvider;
  int _lastPortfolioRefreshVersion = -1;

  /// Bumped on every wallet switch. A response from an older epoch is dropped,
  /// so a slow request for the previous account never reaches this one.
  int _epoch = 0;

  bool _loading = false;
  String? _error;

  /// The owner's wallet-managed artworks, drafts included. This is the source
  /// for publication state and for the management actions.
  List<Artwork> _artworks = const <Artwork>[];
  List<CollectionRecord> _collections = const <CollectionRecord>[];
  List<Exhibition> _exhibitions = const <Exhibition>[];
  bool _collectionsLoaded = false;

  final _ProfileArtworkScope _authored = _ProfileArtworkScope('authored');
  final _ProfileArtworkScope _documented = _ProfileArtworkScope('documented');

  List<PortfolioEntry> _publicArtMarkers = const <PortfolioEntry>[];
  bool _markersLoaded = false;
  bool _markersLoading = false;
  String? _markersError;

  PortfolioStudioSection _section = PortfolioStudioSection.authoredArtworks;
  PortfolioPublishState? _statusFilter;
  PortfolioEntryType? _typeFilter;

  String get walletAddress => _walletAddress;
  bool get isLoading => _loading;
  String? get error => _error;

  List<Artwork> get artworks => _artworks;
  List<CollectionRecord> get collections => _collections;
  List<Exhibition> get exhibitions => _exhibitions;

  PortfolioStudioSection get section => _section;
  PortfolioPublishState? get statusFilter => _statusFilter;
  PortfolioEntryType? get typeFilter => _typeFilter;

  void bindArtworkProvider(ArtworkProvider? artworkProvider) {
    if (identical(_artworkProvider, artworkProvider)) return;
    _artworkProvider = artworkProvider;
  }

  void bindAppRefreshProvider(AppRefreshProvider? appRefreshProvider) {
    if (identical(_appRefreshProvider, appRefreshProvider)) return;
    _appRefreshProvider?.removeListener(_handleAppRefreshChanged);
    _appRefreshProvider = appRefreshProvider;
    _lastPortfolioRefreshVersion = _appRefreshProvider?.portfolioVersion ?? -1;
    _appRefreshProvider?.addListener(_handleAppRefreshChanged);
    _handleAppRefreshChanged();
  }

  /// The view state survives the studio being rebuilt: opening a detail from
  /// the desktop studio replaces the studio in the shell, so a widget-local
  /// selection would be lost on Back.
  void setSection(PortfolioStudioSection value) {
    if (_section == value) return;
    _section = value;
    notifyListeners();
  }

  void setStatusFilter(PortfolioPublishState? value) {
    if (_statusFilter == value) return;
    _statusFilter = value;
    notifyListeners();
  }

  void setTypeFilter(PortfolioEntryType? value) {
    if (_typeFilter == value) return;
    _typeFilter = value;
    notifyListeners();
  }

  /// The rows of one section, newest first where the section is merged.
  List<PortfolioEntry> entriesFor(PortfolioStudioSection section) {
    switch (section) {
      case PortfolioStudioSection.authoredArtworks:
        return _withPublishState(_authored.items);
      case PortfolioStudioSection.publicArt:
        final merged = <PortfolioEntry>[
          ..._withPublishState(_documented.items),
          ..._publicArtMarkers,
        ];
        merged.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        return merged;
      case PortfolioStudioSection.collectionsAndExhibitions:
        final merged = <PortfolioEntry>[
          ..._collections.map(PortfolioEntry.fromCollection),
          ..._exhibitions.map(PortfolioEntry.fromExhibition),
        ];
        merged.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        return merged;
    }
  }

  PortfolioSectionStatus statusFor(PortfolioStudioSection section) {
    switch (section) {
      case PortfolioStudioSection.authoredArtworks:
        return _authored.status;
      case PortfolioStudioSection.publicArt:
        final documented = _documented.status;
        final markerCount = _publicArtMarkers.length;
        return PortfolioSectionStatus(
          loaded: documented.loaded && _markersLoaded,
          isLoading: documented.isLoading || _markersLoading,
          isLoadingMore: documented.isLoadingMore,
          hasMore: documented.hasMore,
          honoured: documented.honoured,
          total:
              documented.total == null ? null : documented.total! + markerCount,
          error: documented.error ?? _markersError,
        );
      case PortfolioStudioSection.collectionsAndExhibitions:
        return PortfolioSectionStatus(
          loaded: _collectionsLoaded,
          isLoading: _loading,
          isLoadingMore: false,
          hasMore: false,
          honoured: true,
          total: _collections.length + _exhibitions.length,
          error: _error,
        );
    }
  }

  /// Full owner record by id, or null when this session has not loaded it.
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

  List<PortfolioEntry> _withPublishState(List<PortfolioEntry> items) {
    final byId = <String, Artwork>{for (final a in _artworks) a.id: a};
    return items.map((entry) {
      final artwork = byId[entry.id];
      if (artwork == null) return entry;
      return entry.withPublishState(
        artwork.isPublic
            ? PortfolioPublishState.published
            : PortfolioPublishState.draft,
      );
    }).toList(growable: false);
  }

  void setWalletAddress(String? walletAddress) {
    final next = (walletAddress ?? '').trim();

    if (next == _walletAddress) {
      // Wallet didn't change, but ensure we have data if this is the first time.
      if (_walletAddress.isNotEmpty && !_authored.loaded && !_loading) {
        Future.microtask(() => refresh(force: true));
      }
      _handleAppRefreshChanged();
      return;
    }

    _walletAddress = next;
    _epoch += 1;
    _loading = false;
    _lastPortfolioRefreshVersion = _appRefreshProvider?.portfolioVersion ?? -1;
    _error = null;
    _artworks = const <Artwork>[];
    _collections = const <CollectionRecord>[];
    _exhibitions = const <Exhibition>[];
    _collectionsLoaded = false;
    _authored.reset();
    _documented.reset();
    _publicArtMarkers = const <PortfolioEntry>[];
    _markersLoaded = false;
    _markersLoading = false;
    _markersError = null;
    notifyListeners();

    if (_walletAddress.isNotEmpty) {
      // Avoid doing work in widget build; schedule microtask.
      Future.microtask(() => refresh(force: true));
    }
  }

  @override
  void dispose() {
    _appRefreshProvider?.removeListener(_handleAppRefreshChanged);
    super.dispose();
  }

  void _handleAppRefreshChanged() {
    final appRefreshProvider = _appRefreshProvider;
    if (appRefreshProvider == null || _walletAddress.isEmpty) return;
    final currentVersion = appRefreshProvider.portfolioVersion;
    if (currentVersion > _lastPortfolioRefreshVersion) {
      _lastPortfolioRefreshVersion = currentVersion;
      Future.microtask(() => refresh(force: true));
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    final wallet = _walletAddress;
    if (wallet.isEmpty) return;
    final epoch = _epoch;

    _loading = true;
    _error = null;
    _authored.loading = true;
    _documented.loading = true;
    _markersLoading = true;
    notifyListeners();

    try {
      Object? firstError;

      final artworksFuture = _loadAllArtworksForWallet(wallet).catchError((e) {
        firstError ??= e;
        return const <Artwork>[];
      });
      final collectionsFuture =
          _loadAllCollectionsForWallet(wallet).catchError((e) {
        firstError ??= e;
        return const <CollectionRecord>[];
      });
      final exhibitionsFuture = _api
          .listExhibitions(mine: true, limit: 50, offset: 0)
          .catchError((e) {
        firstError ??= e;
        return const <Exhibition>[];
      });

      final authoredFuture =
          _loadScopePage(_authored, wallet, epoch, replace: true);
      final documentedFuture =
          _loadScopePage(_documented, wallet, epoch, replace: true);
      final markersFuture = _loadPublicArtMarkers(wallet, epoch);

      final results = await Future.wait<dynamic>([
        artworksFuture,
        collectionsFuture,
        exhibitionsFuture,
      ]);
      await Future.wait<void>(
          [authoredFuture, documentedFuture, markersFuture]);
      if (epoch != _epoch) return;

      _artworks = (results[0] as List<Artwork>);
      _collections = (results[1] as List<CollectionRecord>);
      _exhibitions = (results[2] as List<Exhibition>);
      _collectionsLoaded = true;

      if (firstError != null) {
        _error = firstError.toString();
      }
      _seedArtworkCache(_artworks);
    } finally {
      // A superseded refresh must not touch the flags of the current account.
      if (epoch == _epoch) {
        _loading = false;
        _authored.loading = false;
        _documented.loading = false;
        _markersLoading = false;
        notifyListeners();
      }
    }
  }

  /// Loads the next page of an artwork section. Markers are not paged: they are
  /// the owner's own contributions and come back whole.
  Future<void> loadMore(PortfolioStudioSection section) async {
    final scope = switch (section) {
      PortfolioStudioSection.authoredArtworks => _authored,
      PortfolioStudioSection.publicArt => _documented,
      PortfolioStudioSection.collectionsAndExhibitions => null,
    };
    if (scope == null || !scope.hasMore || scope.loadingMore || scope.loading) {
      return;
    }
    final wallet = _walletAddress;
    if (wallet.isEmpty) return;
    final epoch = _epoch;

    scope.loadingMore = true;
    notifyListeners();
    try {
      await _loadScopePage(scope, wallet, epoch, replace: false);
    } finally {
      if (epoch == _epoch) {
        scope.loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadScopePage(
    _ProfileArtworkScope scope,
    String wallet,
    int epoch, {
    required bool replace,
  }) async {
    try {
      final page = await _api.getProfileArtworks(
        wallet,
        relationship: scope.relationship,
        limit: scopePageSize,
        offset: replace ? 0 : scope.nextOffset,
        includeAuth: true,
      );
      if (epoch != _epoch) return;
      scope.apply(page, replace: replace);
      if (epoch == _epoch) notifyListeners();
    } catch (e) {
      if (epoch != _epoch) return;
      scope.fail(e, replace: replace);
      notifyListeners();
    }
  }

  /// Public-art markers the owner created with no artwork record. A marker that
  /// has an artwork is represented by that artwork, so it is not listed twice.
  Future<void> _loadPublicArtMarkers(String wallet, int epoch) async {
    try {
      final markers = await _api.getMyArtMarkers();
      if (epoch != _epoch) return;
      _publicArtMarkers = markers
          .where((marker) => _isPublicArtContribution(marker, wallet))
          .map(PortfolioEntry.fromMarker)
          .toList(growable: false);
      _markersError = null;
    } catch (e) {
      if (epoch != _epoch) return;
      _publicArtMarkers = const <PortfolioEntry>[];
      _markersError = e.toString();
    }
    if (epoch == _epoch) _markersLoaded = true;
  }

  static bool _isPublicArtContribution(ArtMarker marker, String wallet) {
    if ((marker.artworkId ?? '').trim().isNotEmpty) return false;
    if (marker.type != ArtMarkerType.streetArt &&
        marker.type != ArtMarkerType.artwork) {
      return false;
    }
    final owner = (marker.ownerWalletAddress ?? '').trim().toLowerCase();
    if (owner.isNotEmpty && owner != wallet.trim().toLowerCase()) {
      return false;
    }
    return true;
  }

  /// Makes the owner's artworks openable from the studio. The detail and editor
  /// resolve artworks through this cache, and an unauthenticated detail read
  /// cannot return a private draft.
  void _seedArtworkCache(List<Artwork> artworks) {
    final provider = _artworkProvider;
    if (provider == null) return;
    for (final artwork in artworks) {
      provider.addOrUpdateArtwork(artwork, retainWhenListRefresh: true);
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

  Future<List<CollectionRecord>> _loadAllCollectionsForWallet(
      String walletAddress) async {
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
      _invalidateShowcaseForArtwork(updated);
    }
    return updated;
  }

  Future<Artwork?> unpublishArtwork(String artworkId) async {
    final id = artworkId.trim();
    if (id.isEmpty) return null;

    final updated = await _api.unpublishArtwork(id);
    if (updated != null) {
      _upsertArtwork(updated);
      _invalidateShowcaseForArtwork(updated);
    }
    return updated;
  }

  Future<Artwork?> updateArtwork(
      String artworkId, Map<String, dynamic> updates) async {
    final id = artworkId.trim();
    if (id.isEmpty) return null;

    final updated = await _api.updateArtwork(id, updates);
    if (updated != null) {
      _upsertArtwork(updated);
      final wallet = updated.walletAddress;
      if (wallet != null && wallet.trim().isNotEmpty) {
        ProfilePackageMutationTracker.showcaseChanged(wallet);
      }
    }
    return updated;
  }

  Future<void> deleteArtwork(String artworkId) async {
    final id = artworkId.trim();
    if (id.isEmpty) return;

    final previous = artworkById(id);
    await _api.deleteArtwork(id);
    _artworks = _artworks.where((a) => a.id != id).toList(growable: false);
    _authored.removeId(id);
    _documented.removeId(id);
    _artworkProvider?.removeArtwork(id);
    final wallet = previous?.walletAddress ?? _walletAddress;
    if (wallet.trim().isNotEmpty) {
      ProfilePackageMutationTracker.showcaseChanged(wallet);
    }
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

  void _invalidateShowcaseForArtwork(Artwork artwork) {
    final wallet = artwork.walletAddress;
    if (wallet != null && wallet.trim().isNotEmpty) {
      ProfilePackageMutationTracker.showcaseChanged(wallet);
    }
  }
}
