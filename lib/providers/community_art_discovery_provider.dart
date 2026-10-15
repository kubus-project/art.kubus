import 'dart:async';

import 'package:flutter/foundation.dart';

import '../community/art_discovery.dart';
import '../community/community_interactions.dart';
import '../models/artwork.dart';
import '../models/exhibition.dart';

/// Where the Art discovery feed gets everything. Injected so the provider is
/// testable without a backend, a map or a device.
class ArtDiscoverySources {
  const ArtDiscoverySources({
    required this.artFeed,
    required this.publicPosts,
    required this.artworks,
    required this.exhibitions,
    required this.signals,
    required this.selectedArea,
    required this.mapCenter,
    required this.deviceLocation,
    required this.savedLocation,
    required this.saveLocation,
    this.now = DateTime.now,
  });

  /// Art-related community posts inside [radiusKm] of a point.
  final Future<List<CommunityPost>> Function(
    double latitude,
    double longitude,
    double radiusKm, {
    int limit,
  }) artFeed;

  /// Recent public community posts, not tied to the area.
  final Future<List<CommunityPost>> Function({int limit}) publicPosts;

  /// Public artworks the app can already see or fetch.
  final Future<List<Artwork>> Function() artworks;

  /// Published exhibitions, around [location] when there is one.
  final Future<List<Exhibition>> Function(
    ArtDiscoveryLocation? location,
    double radiusKm,
  ) exhibitions;

  /// The visitor's explicit follows and saves; empty for guests.
  final Future<ArtDiscoverySignals> Function() signals;

  /// An area the visitor picked, if any.
  final ArtDiscoveryLocation? Function() selectedArea;

  /// Where the map is currently centred, if it has been opened.
  final ArtDiscoveryLocation? Function() mapCenter;

  /// The device position. With `prompt: false` this must never open a
  /// permission dialog.
  final Future<ArtDiscoveryLocation?> Function({required bool prompt})
      deviceLocation;

  /// The last area this visitor used.
  final Future<ArtDiscoveryLocation?> Function() savedLocation;
  final Future<void> Function(ArtDiscoveryLocation location) saveLocation;

  final DateTime Function() now;
}

/// State and loading for the Community Art tab: one feed composed from
/// personalised, nearby and new-and-noteworthy sources.
///
/// The feed never depends on one source. A sparse neighbourhood widens the
/// radius, a missing location falls back to public discovery, and a source
/// that fails only removes its own entries.
class CommunityArtDiscoveryProvider extends ChangeNotifier {
  CommunityArtDiscoveryProvider({this.pageSize = 12});

  final int pageSize;

  List<ArtDiscoveryItem> _items = const <ArtDiscoveryItem>[];
  int _visibleCount = 0;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  ArtDiscoveryLocation? _location;
  double _radiusKm = kArtDiscoveryRadiiKm.first;
  int _generation = 0;
  final Set<String> _removedPostIds = <String>{};
  int _failedSources = 0;

  /// Everything ranked, in order.
  List<ArtDiscoveryItem> get allItems => _items;

  /// The slice shown now; grows by one page per [loadMore].
  List<ArtDiscoveryItem> get items =>
      _items.take(_visibleCount).toList(growable: false);

  /// The slice shown now when only entries accepted by [matches] count.
  ///
  /// The predicate is applied to the whole ranked feed before the page is cut,
  /// so a lower-ranked match is never hidden behind a page of non-matches. A
  /// null predicate is the unfiltered [items].
  List<ArtDiscoveryItem> visibleItems(
    bool Function(ArtDiscoveryItem item)? matches,
  ) {
    if (matches == null) return items;
    return _items.where(matches).take(_visibleCount).toList(growable: false);
  }

  /// Whether another page exists once [matches] has been applied.
  bool hasMoreMatching(bool Function(ArtDiscoveryItem item)? matches) {
    if (matches == null) return hasMore;
    var seen = 0;
    for (final item in _items) {
      if (!matches(item)) continue;
      seen += 1;
      if (seen > _visibleCount) return true;
    }
    return false;
  }

  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get hasMore => _visibleCount < _items.length;

  /// Set only when nothing could be loaded at all.
  String? get error => _error;

  /// The area the feed is built around, or null for public discovery.
  ArtDiscoveryLocation? get location => _location;

  /// The radius the neighbourhood needed, after widening.
  double get radiusKm => _radiusKm;

  String? _boundAccount;
  bool _accountBound = false;

  /// Ties the feed to the signed-in account. A different account must never
  /// see the previous one's personalised order, so a change empties the feed
  /// and the next visit to the tab loads it afresh.
  void bindAccount(String? walletAddress) {
    final next = (walletAddress ?? '').trim();
    if (_accountBound && next == (_boundAccount ?? '')) return;
    final changed = _accountBound;
    _accountBound = true;
    _boundAccount = next;
    if (!changed) return;
    _generation += 1;
    _items = const <ArtDiscoveryItem>[];
    _visibleCount = 0;
    _loaded = false;
    _loading = false;
    _error = null;
    _removedPostIds.clear();
    notifyListeners();
  }

  /// Revealing the next page of the already ranked feed.
  void loadMore() {
    if (!hasMore) return;
    _visibleCount = (_visibleCount + pageSize).clamp(0, _items.length);
    notifyListeners();
  }

  /// A deleted post must leave the feed and never come back on refresh.
  void removePost(String postId) {
    _removedPostIds.add(postId);
    final next = _items
        .where((i) => !(i.kind == ArtDiscoveryKind.post && i.id == postId))
        .toList(growable: false);
    if (next.length == _items.length) return;
    _items = next;
    _visibleCount = _visibleCount.clamp(0, _items.length);
    notifyListeners();
  }

  Future<void> refresh(
    ArtDiscoverySources sources, {
    bool promptForLocation = false,
  }) async {
    final generation = ++_generation;
    _failedSources = 0;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final location = await _resolveLocation(
        sources,
        prompt: promptForLocation,
      );
      final signalsFuture = _guard(sources.signals, ArtDiscoverySignals.none);
      final publicFuture = _guard(
        () => sources.publicPosts(limit: 30),
        const <CommunityPost>[],
      );
      final artworksFuture = _guard(sources.artworks, const <Artwork>[]);

      var radius = kArtDiscoveryRadiiKm.first;
      var nearby = const <CommunityPost>[];
      var nearbyFailed = false;
      if (location != null) {
        final ladder = await _widenUntilEnough(sources, location);
        radius = ladder.radiusKm;
        nearby = ladder.posts;
        nearbyFailed = ladder.failed;
      }
      final exhibitions = await _guard(
        () => sources.exhibitions(location, radius),
        const <Exhibition>[],
      );
      final signals = await signalsFuture;
      final publicPosts = await publicFuture;
      final artworks = await artworksFuture;
      if (generation != _generation) return;

      final ranked = ArtDiscoveryRanker.rank(
        candidates: ArtDiscoveryCandidates(
          nearbyPosts: nearby
              .where((p) => !_removedPostIds.contains(p.id))
              .toList(growable: false),
          publicPosts: publicPosts
              .where((p) => !_removedPostIds.contains(p.id))
              .toList(growable: false),
          artworks: artworks,
          exhibitions: exhibitions,
        ),
        signals: signals,
        now: sources.now(),
        location: location,
        radiusKm: radius,
      );

      _location = location;
      _radiusKm = radius;
      _items = ranked;
      _visibleCount = ranked.length < pageSize ? ranked.length : pageSize;
      if (ranked.isEmpty && (nearbyFailed || _failedSources > 0)) {
        _error = 'community-art-discovery-unavailable';
      }
      _loaded = true;
      if (location != null) {
        unawaited(sources.saveLocation(location).catchError((Object _) {}));
      }
    } catch (e) {
      if (generation != _generation) return;
      _error = e.toString();
      _loaded = true;
      if (kDebugMode) debugPrint('CommunityArtDiscoveryProvider.refresh: $e');
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<ArtDiscoveryLocation?> _resolveLocation(
    ArtDiscoverySources sources, {
    required bool prompt,
  }) async {
    final selected = sources.selectedArea();
    if (selected != null && selected.isValid) return selected;
    final map = sources.mapCenter();
    if (map != null && map.isValid && !prompt) return map;
    final device = await _guard<ArtDiscoveryLocation?>(
      () => sources.deviceLocation(prompt: prompt),
      null,
    );
    if (device != null && device.isValid) return device;
    if (map != null && map.isValid) return map;
    final saved = await _guard<ArtDiscoveryLocation?>(
      sources.savedLocation,
      null,
    );
    if (saved != null && saved.isValid) return saved;
    return null;
  }

  Future<({double radiusKm, List<CommunityPost> posts, bool failed})>
      _widenUntilEnough(
    ArtDiscoverySources sources,
    ArtDiscoveryLocation location,
  ) async {
    var radius = kArtDiscoveryRadiiKm.first;
    var posts = const <CommunityPost>[];
    var failed = false;
    for (final candidate in kArtDiscoveryRadiiKm) {
      radius = candidate;
      try {
        posts = await sources.artFeed(
          location.latitude,
          location.longitude,
          candidate,
          limit: 30,
        );
        failed = false;
      } catch (e) {
        failed = true;
        if (kDebugMode) debugPrint('art feed radius $candidate failed: $e');
        break;
      }
      if (posts.length >= kArtDiscoveryNearbyTarget) break;
    }
    return (radiusKm: radius, posts: posts, failed: failed);
  }

  Future<T> _guard<T>(Future<T> Function() run, T fallback) async {
    try {
      return await run();
    } catch (e) {
      _failedSources += 1;
      if (kDebugMode) debugPrint('art discovery source failed: $e');
      return fallback;
    }
  }
}
