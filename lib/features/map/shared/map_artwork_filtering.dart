import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';

/// Shared marker-aware filtering used by both mobile and desktop map screens.
class MapArtworkFiltering {
  const MapArtworkFiltering._();

  static Set<String> visibleArtworkIds({
    required List<ArtMarker> markers,
    required Map<ArtMarkerType, bool> markerLayerVisibility,
  }) {
    final ids = <String>{};
    for (final marker in markers) {
      if (!marker.hasValidPosition) continue;
      if (!(markerLayerVisibility[marker.type] ?? true)) continue;
      final artworkId = marker.artworkId?.trim();
      if (artworkId == null || artworkId.isEmpty) continue;
      ids.add(artworkId);
    }
    return ids;
  }

  /// Filters artworks using:
  /// - valid location
  /// - currently loaded marker scope (when markers are loaded)
  /// - search query
  /// - common filter keys used by mobile + desktop screens
  static List<Artwork> filter({
    required List<Artwork> artworks,
    required List<ArtMarker> markers,
    required Map<ArtMarkerType, bool> markerLayerVisibility,
    required String query,
    required String filterKey,
    required LatLng? basePosition,
    required double radiusKm,
    bool strictNearbyWithoutBase = true,
  }) {
    final visibleIds = visibleArtworkIds(
      markers: markers,
      markerLayerVisibility: markerLayerVisibility,
    );

    final enforceMarkerScope = markers.isNotEmpty;
    var filtered = artworks
        .where(
          (artwork) =>
              artwork.hasValidLocation &&
              (!enforceMarkerScope || visibleIds.contains(artwork.id)),
        )
        .toList(growable: false);

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      filtered = filtered.where((artwork) {
        return artwork.title.toLowerCase().contains(normalizedQuery) ||
            artwork.artist.toLowerCase().contains(normalizedQuery) ||
            artwork.category.toLowerCase().contains(normalizedQuery) ||
            artwork.tags
                .any((tag) => tag.toLowerCase().contains(normalizedQuery));
      }).toList(growable: false);
    }

    switch (filterKey) {
      case 'nearby':
        if (basePosition == null) {
          return strictNearbyWithoutBase
              ? const <Artwork>[]
              : List<Artwork>.from(filtered);
        }
        final radiusMeters = math.max(0.0, radiusKm) * 1000.0;
        filtered = filtered
            .where(
              (artwork) =>
                  artwork.getDistanceFrom(basePosition) <= radiusMeters,
            )
            .toList(growable: false);
        break;
      case 'discovered':
        filtered = filtered
            .where((artwork) => artwork.isDiscovered)
            .toList(growable: false);
        break;
      case 'undiscovered':
        filtered = filtered
            .where((artwork) => !artwork.isDiscovered)
            .toList(growable: false);
        break;
      case 'ar':
        filtered = filtered
            .where((artwork) => artwork.arEnabled)
            .toList(growable: false);
        break;
      case 'favorites':
        filtered = filtered
            .where(
              (artwork) =>
                  artwork.isFavoriteByCurrentUser || artwork.isFavorite,
            )
            .toList(growable: false);
        break;
      case 'all':
      default:
        break;
    }

    return filtered;
  }
}
