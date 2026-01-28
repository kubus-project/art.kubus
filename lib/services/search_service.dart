import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/artwork.dart';
import '../providers/artwork_provider.dart';
import '../providers/community_hub_provider.dart';
import '../services/backend_api_service.dart';
import '../utils/map_search_suggestion.dart';

enum SearchScope {
  home,
  community,
  map,
}

/// Centralized search helper that normalizes backend payloads, applies scope-based
/// filtering, and falls back to local provider data when the backend returns
/// nothing or is unavailable.
class SearchService {
  SearchService({BackendApiService? backendApi})
      : _backendApi = backendApi ?? BackendApiService();

  final BackendApiService _backendApi;
  
  /// Request versioning to cancel stale results when user types fast.
  int _requestVersion = 0;

  Future<List<MapSearchSuggestion>> fetchSuggestions({
    required BuildContext context,
    required String query,
    required SearchScope scope,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    // Increment version for this request
    final myVersion = ++_requestVersion;

    // Capture providers before async gaps to avoid context-after-await lints.
    ArtworkProvider? artworkProvider;
    CommunityHubProvider? communityProvider;
    try {
      artworkProvider = context.read<ArtworkProvider>();
      if (scope == SearchScope.community || scope == SearchScope.home) {
        communityProvider = context.read<CommunityHubProvider>();
      }
    } catch (_) {}

    List<Map<String, dynamic>> normalized = [];
    try {
      final raw = await _backendApi.getSearchSuggestions(query: trimmed, limit: limit);
      
      // Check if this request is still current (user may have typed more)
      if (myVersion != _requestVersion) return const [];
      
      normalized = _backendApi.normalizeSearchSuggestions(raw);
    } catch (_) {
      // Check staleness even on error path
      if (myVersion != _requestVersion) return const [];
      normalized = <Map<String, dynamic>>[];
    }

    // Final staleness check before returning
    if (myVersion != _requestVersion) return const [];

    // Apply scope filters
    final allowedTypes = _allowedTypesForScope(scope);
    final fromBackend = normalized
        .map((m) => MapSearchSuggestion.fromMap(m))
        .where((s) =>
            s.label.isNotEmpty &&
            (allowedTypes.isEmpty || allowedTypes.contains(s.type.toLowerCase())))
        .toList();

    if (fromBackend.isNotEmpty) return fromBackend.take(limit).toList();

    // Fallback to local providers when backend is empty or fails.
    final fallback = _localFallback(
      trimmed,
      scope,
      artworkProvider: artworkProvider,
      communityProvider: communityProvider,
    );
    return fallback.take(limit).toList();
  }

  Set<String> _allowedTypesForScope(SearchScope scope) {
    switch (scope) {
      case SearchScope.home:
        return const {}; // allow all normalized types
      case SearchScope.community:
        return const {'profile', 'user', 'group', 'community'};
      case SearchScope.map:
        return const {'artwork', 'profile', 'institution', 'event', 'marker'};
    }
  }

  List<MapSearchSuggestion> _localFallback(
    String query,
    SearchScope scope, {
    ArtworkProvider? artworkProvider,
    CommunityHubProvider? communityProvider,
  }) {
    final normalizedQuery = query.toLowerCase();
    final results = <MapSearchSuggestion>[];

    // Artworks are safe to surface for home/map scopes.
    if (scope == SearchScope.home || scope == SearchScope.map) {
      try {
        for (final art in artworkProvider?.artworks ?? const <Artwork>[]) {
          if (art.title.toLowerCase().contains(normalizedQuery) ||
              art.artist.toLowerCase().contains(normalizedQuery) ||
              art.category.toLowerCase().contains(normalizedQuery)) {
            results.add(MapSearchSuggestion(
              label: art.title,
              subtitle: art.artist,
              id: art.id,
              type: 'artwork',
              position: art.hasValidLocation ? art.position : null,
            ));
          }
        }
      } catch (_) {}
    }

    // Community profiles/groups for community scope.
    if (scope == SearchScope.community || scope == SearchScope.home) {
      try {
        for (final group in communityProvider?.groups ?? const []) {
          if (group.name.toLowerCase().contains(normalizedQuery)) {
            results.add(MapSearchSuggestion(
              label: group.name,
              subtitle: 'Group',
              id: group.id,
              type: 'group',
            ));
          }
        }
        for (final post in communityProvider?.artFeedPosts ?? const []) {
          if (post.authorName.toLowerCase().contains(normalizedQuery)) {
            results.add(MapSearchSuggestion(
              label: post.authorName,
              subtitle: post.authorUsername != null ? '@${post.authorUsername}' : null,
              id: post.authorId,
              type: 'profile',
            ));
          }
        }
      } catch (_) {}
    }

    return results;
  }
}
