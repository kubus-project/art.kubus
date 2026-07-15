import 'dart:math' as math;

import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../filters/map_filter_state.dart';
import 'map_marker_filtering.dart';

/// Shared marker-aware filtering used by both mobile and desktop map screens.
class MapArtworkFiltering {
  const MapArtworkFiltering._();

  static Set<String> visibleArtworkIds({
    required List<ArtMarker> markers,
    required Set<ArtMarkerType> visibleContentLayers,
  }) {
    final ids = <String>{};
    for (final marker in markers) {
      if (!marker.hasValidPosition) continue;
      if (!visibleContentLayers.contains(marker.type)) continue;
      final artworkId = marker.artworkId?.trim();
      if (artworkId == null || artworkId.isEmpty) continue;
      ids.add(artworkId);
    }
    return ids;
  }

  /// Filters artworks using the same semantic dimensions as map markers.
  ///
  /// When [markers] is non-empty, marker-to-artwork links enforce content-layer
  /// visibility. With no loaded marker metadata there is no reliable artwork
  /// type to infer, so valid artworks remain eligible for the other filters.
  static List<Artwork> filter({
    required List<Artwork> artworks,
    required List<ArtMarker> markers,
    required KubusMapFilterContext context,
  }) {
    final state = context.state;
    final visibleIds = visibleArtworkIds(
      markers: markers,
      visibleContentLayers: state.visibleContentLayers,
    );
    final enforceMarkerScope = markers.isNotEmpty;
    final normalizedQuery = context.query.trim().toLowerCase();

    return artworks.where((artwork) {
      if (!artwork.hasValidLocation) return false;
      if (enforceMarkerScope && !visibleIds.contains(artwork.id)) return false;

      if (normalizedQuery.isNotEmpty &&
          !artwork.title.toLowerCase().contains(normalizedQuery) &&
          !artwork.artist.toLowerCase().contains(normalizedQuery) &&
          !artwork.category.toLowerCase().contains(normalizedQuery) &&
          !artwork.tags
              .any((tag) => tag.toLowerCase().contains(normalizedQuery))) {
        return false;
      }

      switch (state.scope) {
        case KubusMapScope.currentViewport:
        case KubusMapScope.travel:
          break;
        case KubusMapScope.nearMe:
          final base = context.basePosition;
          if (base == null) return !context.strictNearMeWithoutBase;
          final radiusMeters = math.max(0.0, state.nearMeRadiusKm) * 1000.0;
          if (artwork.getDistanceFrom(base) > radiusMeters) return false;
      }

      switch (state.discoveryStatus) {
        case KubusMapDiscoveryStatus.all:
          break;
        case KubusMapDiscoveryStatus.undiscovered:
          if (artwork.isDiscovered) return false;
        case KubusMapDiscoveryStatus.discovered:
          if (!artwork.isDiscovered) return false;
      }

      if (state.arOnly && !artwork.arEnabled) return false;
      if (state.favoritesOnly &&
          !artwork.isFavoriteByCurrentUser &&
          !artwork.isFavorite) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }
}
