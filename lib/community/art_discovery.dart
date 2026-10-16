import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/artwork.dart';
import '../models/exhibition.dart';
import '../utils/wallet_utils.dart';
import 'community_interactions.dart';
import 'community_post_media.dart';

/// What an Art discovery entry is.
enum ArtDiscoveryKind { post, artwork, exhibition }

/// Why an entry is in the feed: the one grounded context label it shows.
/// Ordered by how strongly it speaks to the visitor, which is also the order
/// used to pick the label when several apply.
enum ArtDiscoveryReason {
  fromFollowed,
  nearby,
  exhibition,
  recentReview,
  newArtwork,
  communityDiscussion,
  forYou,
}

/// Where the discovery area comes from. The order of the values is the order
/// the sources are tried in.
enum ArtDiscoveryLocationSource { selected, mapCenter, device, saved }

@immutable
class ArtDiscoveryLocation {
  const ArtDiscoveryLocation({
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final ArtDiscoveryLocationSource source;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  LatLng get point => LatLng(latitude, longitude);
}

/// What the visitor has explicitly done. Nothing here is inferred from
/// telemetry: only follows, saves and likes they chose to make.
@immutable
class ArtDiscoverySignals {
  const ArtDiscoverySignals({
    this.followedWallets = const <String>{},
    this.savedArtworkIds = const <String>{},
    this.savedPostIds = const <String>{},
    this.savedExhibitionIds = const <String>{},
  });

  static const ArtDiscoverySignals none = ArtDiscoverySignals();

  /// Canonical wallets of followed artists, institutions and users.
  final Set<String> followedWallets;
  final Set<String> savedArtworkIds;
  final Set<String> savedPostIds;
  final Set<String> savedExhibitionIds;

  bool get isEmpty =>
      followedWallets.isEmpty &&
      savedArtworkIds.isEmpty &&
      savedPostIds.isEmpty &&
      savedExhibitionIds.isEmpty;

  bool follows(String? wallet) {
    final key = WalletUtils.canonical(wallet ?? '');
    return key.isNotEmpty && followedWallets.contains(key);
  }
}

@immutable
class ArtDiscoveryItem {
  const ArtDiscoveryItem({
    required this.kind,
    required this.id,
    required this.reason,
    required this.score,
    required this.createdAt,
    this.distanceKm,
    this.authorKey,
    this.artworkRefId,
    this.post,
    this.artwork,
    this.exhibition,
  });

  final ArtDiscoveryKind kind;
  final String id;
  final ArtDiscoveryReason reason;
  final double score;
  final DateTime createdAt;

  /// Distance from the discovery area; only set when the entry has its own
  /// coordinates and a located area exists.
  final double? distanceKm;

  /// Canonical author wallet, used to keep one voice from filling the feed.
  final String? authorKey;

  /// The artwork this entry is about, used to avoid near-duplicate entries.
  final String? artworkRefId;

  final CommunityPost? post;
  final Artwork? artwork;
  final Exhibition? exhibition;

  String get key => '${kind.name}:$id';
}

/// Candidate inputs for [ArtDiscoveryRanker.rank].
@immutable
class ArtDiscoveryCandidates {
  const ArtDiscoveryCandidates({
    this.nearbyPosts = const <CommunityPost>[],
    this.publicPosts = const <CommunityPost>[],
    this.artworks = const <Artwork>[],
    this.exhibitions = const <Exhibition>[],
  });

  /// Posts returned for the discovery area (the server already applied the
  /// radius), with or without a server-supplied distance.
  final List<CommunityPost> nearbyPosts;

  /// Public posts not tied to the area: recent cultural discussion and
  /// reviews. Never labelled as nearby unless they carry coordinates inside
  /// the radius.
  final List<CommunityPost> publicPosts;
  final List<Artwork> artworks;
  final List<Exhibition> exhibitions;
}

/// Deterministic ranking and composition of the Art discovery feed.
///
/// One policy, no hidden state: the same candidates, signals, location and
/// clock always produce the same order. Scores combine explicit follows and
/// saves, proximity to the discovery area, recency and genuine public
/// engagement; a greedy pass then keeps any one author, kind or artwork from
/// filling the feed.
abstract final class ArtDiscoveryRanker {
  static const double followedBoost = 40;
  static const double savedBoost = 18;
  static const double proximityMax = 30;
  static const double recencyMax = 20;
  static const double recencyHalfLifeDays = 7;
  static const double engagementMax = 10;
  static const double activeExhibitionBoost = 8;
  static const double upcomingExhibitionBoost = 4;

  /// Per-author damping applied for every entry of that author already placed.
  static const double authorRepeatDamping = 0.6;

  /// Damping when the last three placed entries were all of one kind.
  static const double kindStreakDamping = 0.85;

  /// Farthest an entry can be and still be called "nearby". The search radius
  /// may widen well past this to find content for a sparse area; that content
  /// is still shown, with its distance as a ranking signal, but never labelled
  /// as nearby.
  static const double nearbyMaxKm = 25;

  /// An artwork younger than this is a "new artwork".
  static const Duration newArtworkWindow = Duration(days: 14);

  static const Set<String> _reviewCategories = <String>{
    'review',
    'art_review',
  };

  static List<ArtDiscoveryItem> rank({
    required ArtDiscoveryCandidates candidates,
    required ArtDiscoverySignals signals,
    required DateTime now,
    ArtDiscoveryLocation? location,
    double radiusKm = 3,
    int limit = 80,
  }) {
    final scored = <String, ArtDiscoveryItem>{};
    void offer(ArtDiscoveryItem item) {
      final existing = scored[item.key];
      if (existing == null || item.score > existing.score) {
        scored[item.key] = item;
      }
    }

    for (final post in candidates.nearbyPosts) {
      final item = _postItem(
        post,
        signals: signals,
        now: now,
        location: location,
        radiusKm: radiusKm,
        server: true,
      );
      if (item != null) offer(item);
    }
    for (final post in candidates.publicPosts) {
      final item = _postItem(
        post,
        signals: signals,
        now: now,
        location: location,
        radiusKm: radiusKm,
        server: false,
      );
      if (item != null) offer(item);
    }
    for (final artwork in candidates.artworks) {
      final item = _artworkItem(
        artwork,
        signals: signals,
        now: now,
        location: location,
        radiusKm: radiusKm,
      );
      if (item != null) offer(item);
    }
    for (final exhibition in candidates.exhibitions) {
      final item = _exhibitionItem(
        exhibition,
        signals: signals,
        now: now,
        location: location,
        radiusKm: radiusKm,
      );
      if (item != null) offer(item);
    }

    return _compose(scored.values.toList(growable: false), limit: limit);
  }

  // ---------------------------------------------------------------------

  static ArtDiscoveryItem? _postItem(
    CommunityPost post, {
    required ArtDiscoverySignals signals,
    required DateTime now,
    required ArtDiscoveryLocation? location,
    required double radiusKm,
    required bool server,
  }) {
    if (post.id.trim().isEmpty) return null;
    // A repost is not a new voice; the original is what the feed should show.
    if ((post.postType ?? '') == 'repost' && post.content.trim().isEmpty) {
      return null;
    }
    final wallet = post.authorWallet ?? post.authorIdentityData.walletSeed;
    final followed = signals.follows(wallet);
    final saved = signals.savedPostIds.contains(post.id) ||
        (post.artwork?.id != null &&
            signals.savedArtworkIds.contains(post.artwork!.id));
    final distance = _postDistanceKm(post, location, trustServer: server);
    final inRadius = distance != null && distance <= radiusKm;
    final nearby =
        distance != null && distance <= radiusKm && distance <= nearbyMaxKm;
    final review = _reviewCategories.contains(post.category.toLowerCase());

    var score = _recency(post.timestamp, now) +
        _engagement(post.likeCount, post.commentCount);
    if (followed) score += followedBoost;
    if (saved) score += savedBoost;
    if (inRadius) score += _proximity(distance, radiusKm);
    if (review) score += 3;

    final reason = followed
        ? ArtDiscoveryReason.fromFollowed
        : nearby
            ? ArtDiscoveryReason.nearby
            : review
                ? ArtDiscoveryReason.recentReview
                : saved
                    ? ArtDiscoveryReason.forYou
                    : ArtDiscoveryReason.communityDiscussion;

    return ArtDiscoveryItem(
      kind: ArtDiscoveryKind.post,
      id: post.id,
      reason: reason,
      score: score,
      createdAt: post.timestamp,
      distanceKm: inRadius ? distance : null,
      authorKey: _authorKey(wallet),
      artworkRefId: post.artwork?.id,
      post: post,
    );
  }

  static ArtDiscoveryItem? _artworkItem(
    Artwork artwork, {
    required ArtDiscoverySignals signals,
    required DateTime now,
    required ArtDiscoveryLocation? location,
    required double radiusKm,
  }) {
    if (artwork.id.trim().isEmpty || !artwork.isPublic || !artwork.isActive) {
      return null;
    }
    final followed = signals.follows(artwork.walletAddress);
    final saved = signals.savedArtworkIds.contains(artwork.id) ||
        artwork.isLikedByCurrentUser;
    final distance = _pointDistanceKm(artwork.position, location);
    final inRadius = distance != null && distance <= radiusKm;
    final nearby =
        distance != null && distance <= radiusKm && distance <= nearbyMaxKm;
    final isNew = now.difference(artwork.createdAt) <= newArtworkWindow &&
        !artwork.createdAt.isAfter(now.add(const Duration(days: 1)));

    var score = _recency(artwork.createdAt, now) +
        _engagement(artwork.likesCount, artwork.commentsCount);
    if (followed) score += followedBoost;
    if (saved) score += savedBoost;
    if (inRadius) score += _proximity(distance, radiusKm);

    final reason = followed
        ? ArtDiscoveryReason.fromFollowed
        : nearby
            ? ArtDiscoveryReason.nearby
            : isNew
                ? ArtDiscoveryReason.newArtwork
                : ArtDiscoveryReason.forYou;

    return ArtDiscoveryItem(
      kind: ArtDiscoveryKind.artwork,
      id: artwork.id,
      reason: reason,
      score: score,
      createdAt: artwork.createdAt,
      distanceKm: inRadius ? distance : null,
      authorKey: _authorKey(artwork.walletAddress),
      artworkRefId: artwork.id,
      artwork: artwork,
    );
  }

  static ArtDiscoveryItem? _exhibitionItem(
    Exhibition exhibition, {
    required ArtDiscoverySignals signals,
    required DateTime now,
    required ArtDiscoveryLocation? location,
    required double radiusKm,
  }) {
    if (exhibition.id.trim().isEmpty || !exhibition.isPublished) return null;
    final ends = exhibition.endsAt;
    if (ends != null && ends.isBefore(now)) return null;
    final starts = exhibition.startsAt;
    final active = starts == null || !starts.isAfter(now);
    final soon = starts != null &&
        starts.isAfter(now) &&
        starts.difference(now) <= const Duration(days: 14);
    final lat = exhibition.lat;
    final lng = exhibition.lng;
    final distance = (lat != null && lng != null)
        ? _pointDistanceKm(LatLng(lat, lng), location)
        : null;
    final inRadius = distance != null && distance <= radiusKm;
    final nearby =
        distance != null && distance <= radiusKm && distance <= nearbyMaxKm;
    final saved = signals.savedExhibitionIds.contains(exhibition.id);
    final created = exhibition.createdAt ?? starts ?? now;

    var score = _recency(created, now) * 0.5;
    if (active) score += activeExhibitionBoost;
    if (soon) score += upcomingExhibitionBoost;
    if (saved) score += savedBoost;
    if (inRadius) score += _proximity(distance, radiusKm);
    if (!active && !soon && !nearby) return null;

    return ArtDiscoveryItem(
      kind: ArtDiscoveryKind.exhibition,
      id: exhibition.id,
      reason: nearby && !saved
          ? ArtDiscoveryReason.nearby
          : ArtDiscoveryReason.exhibition,
      score: score,
      createdAt: created,
      distanceKm: inRadius ? distance : null,
      authorKey: _authorKey(
        exhibition.host?.walletAddress ?? exhibition.host?.id,
      ),
      exhibition: exhibition,
    );
  }

  // ---------------------------------------------------------------------
  // Scoring helpers

  static double _recency(DateTime at, DateTime now) {
    final ageDays = math.max(0, now.difference(at).inMinutes) / (60 * 24);
    return recencyMax * math.pow(0.5, ageDays / recencyHalfLifeDays);
  }

  static double _engagement(int likes, int comments) {
    final raw = math.log(1 + math.max(0, likes) + 2 * math.max(0, comments));
    return math.min(engagementMax, 2 * raw);
  }

  static double _proximity(double? distanceKm, double radiusKm) {
    if (distanceKm == null || radiusKm <= 0) return 0;
    final share = 1 - (distanceKm / radiusKm);
    return proximityMax * share.clamp(0.0, 1.0);
  }

  static String? _authorKey(String? raw) {
    final key = WalletUtils.canonical(raw ?? '');
    return key.isEmpty ? null : key;
  }

  static double? _postDistanceKm(
    CommunityPost post,
    ArtDiscoveryLocation? location, {
    required bool trustServer,
  }) {
    if (trustServer && post.distanceKm != null && post.distanceKm!.isFinite) {
      return post.distanceKm;
    }
    final lat = post.location?.lat;
    final lng = post.location?.lng;
    if (lat == null || lng == null) return null;
    return _pointDistanceKm(LatLng(lat, lng), location);
  }

  static double? _pointDistanceKm(LatLng? point, ArtDiscoveryLocation? where) {
    if (point == null || where == null || !where.isValid) return null;
    if (!point.latitude.isFinite || !point.longitude.isFinite) return null;
    if (point.latitude == 0 && point.longitude == 0) return null;
    return haversineKm(point, where.point);
  }

  static double haversineKm(LatLng a, LatLng b) {
    const earthKm = 6371.0088;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLng = rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) *
            math.cos(rad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthKm * math.asin(math.min(1.0, math.sqrt(h)));
  }

  // ---------------------------------------------------------------------
  // Composition

  static List<ArtDiscoveryItem> _compose(
    List<ArtDiscoveryItem> items, {
    required int limit,
  }) {
    // Stable base order: score, then newest, then id.
    final pool = List<ArtDiscoveryItem>.of(items)
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byDate = b.createdAt.compareTo(a.createdAt);
        if (byDate != 0) return byDate;
        return a.key.compareTo(b.key);
      });

    final result = <ArtDiscoveryItem>[];
    final authorCounts = <String, int>{};
    final seenArtworkPosts = <String>{};
    final seenPostBodies = <String>{};
    final recentKinds = <ArtDiscoveryKind>[];

    while (pool.isNotEmpty && result.length < limit) {
      var bestIndex = -1;
      var bestScore = double.negativeInfinity;
      for (var i = 0; i < pool.length; i++) {
        final item = pool[i];
        var effective = item.score;
        final author = item.authorKey;
        if (author != null) {
          effective *= math.pow(authorRepeatDamping, authorCounts[author] ?? 0);
        }
        if (recentKinds.length >= 3 &&
            recentKinds.skip(recentKinds.length - 3).every(
                  (kind) => kind == item.kind,
                )) {
          effective *= kindStreakDamping;
        }
        if (effective > bestScore) {
          bestScore = effective;
          bestIndex = i;
        }
      }
      final chosen = pool.removeAt(bestIndex);

      // One post per artwork and no near-identical copies of the same text.
      if (chosen.kind == ArtDiscoveryKind.post) {
        final ref = chosen.artworkRefId;
        // A video of an artwork is a distinct media contribution from a still
        // post about it. Keep one of each; duplicate videos still collapse.
        final mediaKind =
            communityPostMediaUrls(chosen.post!).any(communityMediaUrlIsVideo)
                ? 'video'
                : 'still';
        if (ref != null &&
            ref.isNotEmpty &&
            !seenArtworkPosts.add('$ref:$mediaKind')) {
          continue;
        }
        final copyKey = _copyKey(chosen);
        if (copyKey != null && !seenPostBodies.add(copyKey)) continue;
      }

      result.add(chosen);
      final author = chosen.authorKey;
      if (author != null) {
        authorCounts[author] = (authorCounts[author] ?? 0) + 1;
      }
      recentKinds.add(chosen.kind);
    }
    return result;
  }

  /// Identity of a post for copy suppression: author, normalised text, the
  /// media it carries and the post it reposts. Posts with no known author, or
  /// with nothing to compare (no text, no media, not a repost), are never
  /// treated as copies, because a captionless picture from an author is not a
  /// duplicate of that author's next captionless picture.
  static String? _copyKey(ArtDiscoveryItem item) {
    final post = item.post;
    // Only a real wallet or account id identifies an author here: the item's
    // authorKey falls back to the display label, which unrelated posts share.
    final author = WalletUtils.canonical(
      post?.authorWallet ?? post?.authorIdentityData.userId ?? '',
    );
    if (author.isEmpty) return null;
    final body = _normalise(post?.content);
    final media = <String>{
      for (final url in <String?>[post?.imageUrl, ...?post?.mediaUrls])
        if (url != null && url.trim().isNotEmpty) url.trim(),
    }.toList()
      ..sort();
    final original = (post?.originalPostId ?? '').trim();
    if (body.isEmpty && media.isEmpty && original.isEmpty) return null;
    return '$author|$body|${media.join(',')}|$original';
  }

  static String _normalise(String? text) =>
      (text ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// The discovery area's radius ladder: widen only while the neighbourhood is
/// sparse, and never call content beyond the final radius "nearby".
const List<double> kArtDiscoveryRadiiKm = <double>[3, 15, 60, 250];

/// Fewest nearby entries that count as "enough" before the radius stops
/// widening.
const int kArtDiscoveryNearbyTarget = 6;
