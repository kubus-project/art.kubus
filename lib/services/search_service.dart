import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../community/community_interactions.dart';
import '../l10n/app_localizations.dart';
import '../models/artwork.dart';
import '../models/institution.dart';
import '../providers/artwork_provider.dart';
import '../providers/community_hub_provider.dart';
import '../providers/institution_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/artwork_media_resolver.dart';
import '../utils/search_suggestions.dart';
import '../utils/wallet_utils.dart';
import '../widgets/search/kubus_search_config.dart';
import '../widgets/search/kubus_search_result.dart';
import 'backend_api_service.dart';

class SearchScreenRecord {
  const SearchScreenRecord({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

@immutable
class SearchContextSnapshot {
  const SearchContextSnapshot({
    this.artworkProvider,
    this.communityProvider,
    this.institutionProvider,
    this.screenRecords = const <SearchScreenRecord>[],
  });

  final ArtworkProvider? artworkProvider;
  final CommunityHubProvider? communityProvider;
  final InstitutionProvider? institutionProvider;
  final List<SearchScreenRecord> screenRecords;

  factory SearchContextSnapshot.capture(
    BuildContext context, {
    required KubusSearchConfig config,
  }) {
    ArtworkProvider? artworkProvider;
    CommunityHubProvider? communityProvider;
    InstitutionProvider? institutionProvider;
    var screenRecords = const <SearchScreenRecord>[];

    try {
      artworkProvider = context.read<ArtworkProvider>();
    } catch (_) {}

    try {
      if (config.scope == KubusSearchScope.community ||
          config.scope == KubusSearchScope.home) {
        communityProvider = context.read<CommunityHubProvider>();
      }
    } catch (_) {}

    try {
      institutionProvider = context.read<InstitutionProvider>();
    } catch (_) {}

    if (config.effectiveKinds.contains(KubusSearchResultKind.screen)) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        screenRecords = NavigationProvider.screenDefinitions.entries
            .map(
              (entry) => SearchScreenRecord(
                key: entry.key,
                label: entry.value.labelKey.resolve(l10n),
                icon: entry.value.icon,
              ),
            )
            .toList(growable: false);
      }
    }

    return SearchContextSnapshot(
      artworkProvider: artworkProvider,
      communityProvider: communityProvider,
      institutionProvider: institutionProvider,
      screenRecords: screenRecords,
    );
  }
}

class SearchService {
  SearchService({BackendApiService? backendApi})
      : _backendApi = backendApi ?? BackendApiService();

  final BackendApiService _backendApi;

  Future<List<KubusSearchResult>> fetchResults({
    required SearchContextSnapshot snapshot,
    required String query,
    required KubusSearchConfig config,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < config.minChars) return const <KubusSearchResult>[];

    final remoteTasks = <Future<List<KubusSearchResult>>>[
      _fetchBackendSuggestions(trimmed, config),
    ];
    if (config.scope == KubusSearchScope.community &&
        config.effectiveKinds.contains(KubusSearchResultKind.post)) {
      remoteTasks.add(_fetchCommunityPostResults(trimmed, config.limit));
    }

    final remoteParts = await Future.wait(remoteTasks);
    final merged = <KubusSearchResult>[];
    for (final part in remoteParts) {
      merged.addAll(part);
    }
    merged.addAll(_localFallback(trimmed, snapshot, config));

    return _dedupeAndRank(
      merged,
      query: trimmed,
      config: config,
    ).take(config.limit).toList(growable: false);
  }

  Future<List<KubusSearchResult>> _fetchBackendSuggestions(
    String query,
    KubusSearchConfig config,
  ) async {
    try {
      final raw = await _backendApi.getSearchSuggestions(
        query: query,
        limit: config.limit,
      );
      final normalized = _backendApi.normalizeSearchSuggestions(raw);
      return normalized
          .map(KubusSearchResult.fromMap)
          .where((result) => _includeResult(result, config))
          .toList(growable: false);
    } catch (_) {
      return const <KubusSearchResult>[];
    }
  }

  Future<List<KubusSearchResult>> _fetchCommunityPostResults(
    String query,
    int limit,
  ) async {
    try {
      final response = await _backendApi.search(
        query: query,
        type: 'posts',
        limit: limit,
        page: 1,
      );
      final rows = _extractSearchResults(response, 'posts');
      return rows
          .map(_communityPostResultFromMap)
          .whereType<KubusSearchResult>()
          .toList(growable: false);
    } catch (_) {
      return const <KubusSearchResult>[];
    }
  }

  List<KubusSearchResult> _localFallback(
    String query,
    SearchContextSnapshot snapshot,
    KubusSearchConfig config,
  ) {
    final normalized = query.toLowerCase();
    final results = <KubusSearchResult>[];
    final kinds = config.effectiveKinds;

    if (kinds.contains(KubusSearchResultKind.artwork)) {
      results.addAll(_localArtworkResults(normalized, snapshot.artworkProvider));
    }
    if (kinds.contains(KubusSearchResultKind.institution)) {
      results.addAll(
        _localInstitutionResults(normalized, snapshot.institutionProvider),
      );
    }
    if (kinds.contains(KubusSearchResultKind.event)) {
      results.addAll(_localEventResults(normalized, snapshot.institutionProvider));
    }
    if (kinds.contains(KubusSearchResultKind.screen)) {
      results.addAll(_localScreenResults(normalized, snapshot.screenRecords));
    }
    if (kinds.contains(KubusSearchResultKind.profile) &&
        (config.scope == KubusSearchScope.community ||
            config.scope == KubusSearchScope.home)) {
      results.addAll(_localProfileResults(normalized, snapshot.communityProvider));
    }
    if (kinds.contains(KubusSearchResultKind.post) &&
        config.scope == KubusSearchScope.community) {
      results.addAll(_localPostResults(normalized, snapshot.communityProvider));
    }

    return results.where((result) => _includeResult(result, config)).toList();
  }

  List<KubusSearchResult> _localArtworkResults(
    String query,
    ArtworkProvider? artworkProvider,
  ) {
    final artworks = artworkProvider?.artworks ?? const <Artwork>[];
    return artworks
        .where(
          (artwork) =>
              artwork.title.toLowerCase().contains(query) ||
              artwork.artist.toLowerCase().contains(query) ||
              artwork.category.toLowerCase().contains(query),
        )
        .map(
          (artwork) => KubusSearchResult(
            label: artwork.title,
            kind: KubusSearchResultKind.artwork,
            detail: !WalletUtils.looksLikeWallet(artwork.artist)
                ? artwork.artist
                : null,
            id: artwork.id,
            position: artwork.hasValidLocation ? artwork.position : null,
            data: <String, dynamic>{
              'artist': artwork.artist,
              'category': artwork.category,
              'artworkId': artwork.id,
              'subjectType': 'artwork',
              'subjectId': artwork.id,
              'walletAddress': artwork.walletAddress,
              'imageUrl': ArtworkMediaResolver.resolveCover(artwork: artwork),
            },
          ),
        )
        .toList(growable: false);
  }

  List<KubusSearchResult> _localInstitutionResults(
    String query,
    InstitutionProvider? institutionProvider,
  ) {
    final institutions =
        institutionProvider?.institutions ?? const <Institution>[];
    return institutions
        .where(
          (institution) =>
              institution.name.toLowerCase().contains(query) ||
              institution.description.toLowerCase().contains(query) ||
              institution.address.toLowerCase().contains(query),
        )
        .map(
          (institution) => KubusSearchResult(
            label: institution.name,
            kind: KubusSearchResultKind.institution,
            detail: institution.address.isNotEmpty
                ? institution.address
                : (institution.type.isNotEmpty ? institution.type : null),
            id: institution.id,
            position: LatLng(institution.latitude, institution.longitude),
            data: <String, dynamic>{
              'type': institution.type,
              'address': institution.address,
              'subjectType': 'institution',
              'subjectId': institution.id,
              if (institution.imageUrls.isNotEmpty)
                'imageUrl': institution.imageUrls.first,
            },
          ),
        )
        .toList(growable: false);
  }

  List<KubusSearchResult> _localEventResults(
    String query,
    InstitutionProvider? institutionProvider,
  ) {
    final events = institutionProvider?.events ?? const <Event>[];
    return events
        .where(
          (event) =>
              event.title.toLowerCase().contains(query) ||
              event.description.toLowerCase().contains(query) ||
              event.location.toLowerCase().contains(query),
        )
        .map(
          (event) => KubusSearchResult(
            label: event.title,
            kind: KubusSearchResultKind.event,
            detail: event.location.isNotEmpty ? event.location : null,
            id: event.id,
            position: event.latitude != null && event.longitude != null
                ? LatLng(event.latitude!, event.longitude!)
                : null,
            data: <String, dynamic>{
              'type': event.type.name,
              'location': event.location,
              'subjectType': 'event',
              'subjectId': event.id,
              if (event.imageUrls.isNotEmpty) 'imageUrl': event.imageUrls.first,
            },
          ),
        )
        .toList(growable: false);
  }

  List<KubusSearchResult> _localScreenResults(
    String query,
    List<SearchScreenRecord> screenRecords,
  ) {
    return screenRecords
        .where((screen) => screen.label.toLowerCase().contains(query))
        .map(
          (screen) => KubusSearchResult(
            label: screen.label,
            kind: KubusSearchResultKind.screen,
            id: screen.key,
            iconOverride: screen.icon,
            data: <String, dynamic>{'screenKey': screen.key},
          ),
        )
        .toList(growable: false);
  }

  List<KubusSearchResult> _localProfileResults(
    String query,
    CommunityHubProvider? communityProvider,
  ) {
    final results = <KubusSearchResult>[];
    final seen = <String>{};
    for (final post in communityProvider?.artFeedPosts ?? const <CommunityPost>[]) {
      final authorName = post.authorName.trim();
      final authorUsername = post.authorUsername?.trim();
      final authorWallet = WalletUtils.canonical(post.authorWallet);
      final matches = authorName.toLowerCase().contains(query) ||
          (authorUsername?.toLowerCase().contains(query) ?? false) ||
          authorWallet.contains(query);
      if (!matches) continue;

      final id = post.authorId.trim().isNotEmpty
          ? post.authorId.trim()
          : (authorWallet.isNotEmpty ? authorWallet : null);
      if (id == null || id.isEmpty || !seen.add(id)) continue;

      final detail = (authorUsername != null && authorUsername.isNotEmpty)
          ? '@${authorUsername.startsWith('@') ? authorUsername.substring(1) : authorUsername}'
          : (authorWallet.isNotEmpty ? maskWallet(authorWallet) : null);

      results.add(
        KubusSearchResult(
          label: authorName.isNotEmpty ? authorName : 'Unknown artist',
          kind: KubusSearchResultKind.profile,
          detail: detail,
          id: id,
          data: <String, dynamic>{
            'authorWallet': authorWallet,
            'authorUsername': authorUsername,
            'wallet': authorWallet,
            if (post.authorAvatar != null && post.authorAvatar!.trim().isNotEmpty)
              'avatarUrl': post.authorAvatar!.trim(),
          },
        ),
      );
    }
    return results;
  }

  List<KubusSearchResult> _localPostResults(
    String query,
    CommunityHubProvider? communityProvider,
  ) {
    final normalizedTagQuery = query.startsWith('#') ? query.substring(1) : query;
    final posts = communityProvider?.artFeedPosts ?? const <CommunityPost>[];
    return posts
        .where(
          (post) =>
              post.content.toLowerCase().contains(query) ||
              post.tags.any(
                (tag) => tag.toLowerCase().contains(normalizedTagQuery),
              ) ||
              post.authorName.toLowerCase().contains(query),
        )
        .map((post) => _communityPostResultFromPost(post))
        .whereType<KubusSearchResult>()
        .toList(growable: false);
  }

  bool _includeResult(KubusSearchResult result, KubusSearchConfig config) {
    if (result.label.trim().isEmpty) return false;
    if (!config.effectiveKinds.contains(result.kind)) return false;
    final resolvedId = (result.id ?? '').trim();
    switch (config.scope) {
      case KubusSearchScope.home:
        switch (result.kind) {
          case KubusSearchResultKind.artwork:
          case KubusSearchResultKind.profile:
            return resolvedId.isNotEmpty;
          case KubusSearchResultKind.institution:
            return result.position != null;
          case KubusSearchResultKind.event:
          case KubusSearchResultKind.marker:
            return result.position != null;
          case KubusSearchResultKind.post:
          case KubusSearchResultKind.screen:
            return resolvedId.isNotEmpty;
        }
      case KubusSearchScope.community:
        switch (result.kind) {
          case KubusSearchResultKind.institution:
            return result.position != null;
          case KubusSearchResultKind.event:
          case KubusSearchResultKind.marker:
            return result.position != null;
          case KubusSearchResultKind.artwork:
          case KubusSearchResultKind.profile:
          case KubusSearchResultKind.post:
          case KubusSearchResultKind.screen:
            return resolvedId.isNotEmpty;
        }
      case KubusSearchScope.map:
        if (result.kind == KubusSearchResultKind.artwork ||
            result.kind == KubusSearchResultKind.profile) {
          return resolvedId.isNotEmpty;
        }
        return result.position != null || resolvedId.isNotEmpty;
    }
  }

  List<KubusSearchResult> _dedupeAndRank(
    List<KubusSearchResult> results, {
    required String query,
    required KubusSearchConfig config,
  }) {
    final deduped = <String, KubusSearchResult>{};
    for (final result in results) {
      deduped.putIfAbsent(result.stableKey, () => result);
    }

    final sorted = deduped.values.toList(growable: false);
    sorted.sort((left, right) {
      final leftRank = _matchRank(left, query);
      final rightRank = _matchRank(right, query);
      if (leftRank != rightRank) return leftRank.compareTo(rightRank);

      final leftPriority = _kindPriority(left.kind, config.scope);
      final rightPriority = _kindPriority(right.kind, config.scope);
      if (leftPriority != rightPriority) {
        return leftPriority.compareTo(rightPriority);
      }

      return left.label.toLowerCase().compareTo(right.label.toLowerCase());
    });
    return sorted;
  }

  int _matchRank(KubusSearchResult result, String query) {
    final normalized = query.toLowerCase();
    final label = result.label.toLowerCase();
    final detail = (result.detail ?? '').toLowerCase();

    if (label == normalized) return 0;
    if (label.startsWith(normalized)) return 1;
    if (label.contains(normalized)) return 2;
    if (detail == normalized) return 3;
    if (detail.startsWith(normalized)) return 4;
    if (detail.contains(normalized)) return 5;
    return 6;
  }

  int _kindPriority(KubusSearchResultKind kind, KubusSearchScope scope) {
    final order = switch (scope) {
      KubusSearchScope.home => const [
          KubusSearchResultKind.artwork,
          KubusSearchResultKind.profile,
          KubusSearchResultKind.institution,
          KubusSearchResultKind.event,
          KubusSearchResultKind.marker,
          KubusSearchResultKind.post,
          KubusSearchResultKind.screen,
        ],
      KubusSearchScope.community => const [
          KubusSearchResultKind.profile,
          KubusSearchResultKind.post,
          KubusSearchResultKind.artwork,
          KubusSearchResultKind.institution,
          KubusSearchResultKind.screen,
          KubusSearchResultKind.event,
          KubusSearchResultKind.marker,
        ],
      KubusSearchScope.map => const [
          KubusSearchResultKind.artwork,
          KubusSearchResultKind.profile,
          KubusSearchResultKind.institution,
          KubusSearchResultKind.event,
          KubusSearchResultKind.marker,
          KubusSearchResultKind.post,
          KubusSearchResultKind.screen,
        ],
    };
    final index = order.indexOf(kind);
    return index == -1 ? order.length : index;
  }

  List<Map<String, dynamic>> _extractSearchResults(
    Map<String, dynamic> response,
    String type,
  ) {
    final rows = <Map<String, dynamic>>[];

    void addEntries(dynamic items) {
      if (items is! List) return;
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          rows.add(item);
        } else if (item is Map) {
          rows.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final results = response['results'];
    if (results is Map<String, dynamic>) {
      addEntries(results[type]);
      addEntries(results['results']);
    } else {
      addEntries(results);
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      addEntries(data[type]);
      addEntries(data['results']);
    } else {
      addEntries(data);
    }

    return rows;
  }

  KubusSearchResult? _communityPostResultFromMap(Map<String, dynamic> map) {
    final id = _stringValue(map, const ['id', 'postId', 'post_id']);
    if (id == null || id.isEmpty) return null;

    final content =
        _stringValue(map, const ['content', 'text', 'message']) ?? 'Post';
    final trimmedContent = content.trim();
    final author = _stringValue(
          map,
          const ['authorName', 'author_name', 'author'],
        ) ??
        _stringValue(map['author'], const ['displayName', 'display_name']) ??
        _stringValue(map['author'], const ['username']) ??
        'Post';

    final label = trimmedContent.isEmpty ? 'Post' : trimmedContent;
    return KubusSearchResult(
      label: label,
      kind: KubusSearchResultKind.post,
      detail: author,
      id: id,
      data: <String, dynamic>{
        ...Map<String, dynamic>.from(map),
        if ((_stringValue(
                  map,
                  const ['imageUrl', 'image_url', 'coverUrl', 'cover_url'],
                ) ??
                _stringValue(map['artwork'], const ['imageUrl', 'image_url']) ??
                '')
            .isNotEmpty)
          'imageUrl': _stringValue(
                map,
                const ['imageUrl', 'image_url', 'coverUrl', 'cover_url'],
              ) ??
              _stringValue(map['artwork'], const ['imageUrl', 'image_url']),
        if ((_stringValue(
                  map,
                  const ['authorAvatar', 'author_avatar', 'avatarUrl', 'avatar_url'],
                ) ??
                _stringValue(
                  map['author'],
                  const ['avatarUrl', 'avatar_url', 'profileImageUrl'],
                ) ??
                '')
            .isNotEmpty)
          'avatarUrl': _stringValue(
                map,
                const ['authorAvatar', 'author_avatar', 'avatarUrl', 'avatar_url'],
              ) ??
              _stringValue(
                map['author'],
                const ['avatarUrl', 'avatar_url', 'profileImageUrl'],
              ),
        if ((_stringValue(
                  map,
                  const ['authorWallet', 'author_wallet', 'wallet', 'walletAddress'],
                ) ??
                _stringValue(map['author'], const ['wallet', 'walletAddress']) ??
                '')
            .isNotEmpty)
          'wallet': _stringValue(
                map,
                const ['authorWallet', 'author_wallet', 'wallet', 'walletAddress'],
              ) ??
              _stringValue(map['author'], const ['wallet', 'walletAddress']),
        if (map['mediaUrls'] is List &&
            (map['mediaUrls'] as List)
                .map((item) => item?.toString().trim() ?? '')
                .any((item) => item.isNotEmpty))
          'imageUrls': (map['mediaUrls'] as List)
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
      },
    );
  }

  KubusSearchResult? _communityPostResultFromPost(CommunityPost post) {
    final id = post.id.trim();
    if (id.isEmpty) return null;
    final label = post.content.trim().isEmpty ? 'Post' : post.content.trim();
    return KubusSearchResult(
      label: label,
      kind: KubusSearchResultKind.post,
      detail: post.authorName.trim().isEmpty ? null : post.authorName.trim(),
      id: id,
      data: <String, dynamic>{
        'postId': id,
        'authorName': post.authorName,
        if (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty)
          'imageUrl': post.imageUrl!.trim()
        else if (post.mediaUrls.isNotEmpty)
          'imageUrl': post.mediaUrls.first,
        if (post.authorAvatar != null && post.authorAvatar!.trim().isNotEmpty)
          'avatarUrl': post.authorAvatar!.trim(),
        if ((post.authorWallet ?? '').trim().isNotEmpty)
          'wallet': post.authorWallet!.trim(),
        if (post.mediaUrls.isNotEmpty) 'imageUrls': post.mediaUrls,
      },
    );
  }

  String? _stringValue(dynamic source, List<String> keys) {
    if (source is! Map) return null;
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
