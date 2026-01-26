import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../providers/artwork_provider.dart';
import '../services/map_marker_service.dart';

class MapMarkerLoadResult {
  const MapMarkerLoadResult({
    required this.markers,
    required this.center,
    required this.fetchedAt,
    this.bounds,
  });

  final List<ArtMarker> markers;
  final LatLng center;
  final DateTime fetchedAt;
  final LatLngBounds? bounds;
}

class MapMarkerHelper {
  static const Duration defaultRefreshInterval = Duration(minutes: 5);
  static const double defaultRefreshDistanceMeters = 1200;
  static const Duration defaultEmptyFallbackInterval = Duration(seconds: 30);

  /// Loads markers for a given center, filters invalid ones, and hydrates
  /// linked artworks so downstream UI can render metadata without null checks.
  static Future<MapMarkerLoadResult> loadAndHydrateMarkers({
    required ArtworkProvider artworkProvider,
    required MapMarkerService mapMarkerService,
    required LatLng center,
    required double radiusKm,
    int? limit,
    bool forceRefresh = false,
    int? zoomBucket,
    String? filtersKey,
    int maxArtworkHydration = 70,
  }) async {
    final markers = await mapMarkerService.loadMarkers(
      center: center,
      radiusKm: radiusKm,
      limit: limit,
      forceRefresh: forceRefresh,
      zoomBucket: zoomBucket,
      filtersKey: filtersKey,
    );

    final filteredMarkers = markers.where((marker) => marker.hasValidPosition).toList();
    unawaited(
      hydrateMarkersWithArtworks(
        artworkProvider,
        filteredMarkers,
        maxPrefetch: maxArtworkHydration,
      ),
    );

    return MapMarkerLoadResult(
      markers: filteredMarkers,
      center: center,
      fetchedAt: DateTime.now(),
      bounds: null,
    );
  }

  /// Loads markers inside the given [bounds], filters invalid ones, and hydrates
  /// linked artworks.
  static Future<MapMarkerLoadResult> loadAndHydrateMarkersInBounds({
    required ArtworkProvider artworkProvider,
    required MapMarkerService mapMarkerService,
    required LatLng center,
    required LatLngBounds bounds,
    int? limit,
    bool forceRefresh = false,
    int? zoomBucket,
    String? filtersKey,
    int maxArtworkHydration = 90,
  }) async {
    final markers = await mapMarkerService.loadMarkersInBounds(
      center: center,
      bounds: bounds,
      limit: limit,
      forceRefresh: forceRefresh,
      zoomBucket: zoomBucket,
      filtersKey: filtersKey,
    );

    final filteredMarkers = markers.where((marker) => marker.hasValidPosition).toList();
    unawaited(
      hydrateMarkersWithArtworks(
        artworkProvider,
        filteredMarkers,
        maxPrefetch: maxArtworkHydration,
      ),
    );

    return MapMarkerLoadResult(
      markers: filteredMarkers,
      center: center,
      fetchedAt: DateTime.now(),
      bounds: bounds,
    );
  }

  /// Determines whether markers should refresh based on movement and staleness.
  static bool shouldRefreshMarkers({
    required LatLng newCenter,
    LatLng? lastCenter,
    DateTime? lastFetchTime,
    required Distance distance,
    Duration refreshInterval = defaultRefreshInterval,
    double refreshDistanceMeters = defaultRefreshDistanceMeters,
    bool hasMarkers = false,
    bool force = false,
    Duration emptyFallbackInterval = defaultEmptyFallbackInterval,
  }) {
    if (force) return true;

    final now = DateTime.now();
    final timeElapsed = lastFetchTime == null || now.difference(lastFetchTime) >= refreshInterval;
    final movedEnough =
        lastCenter == null || distance.as(LengthUnit.Meter, newCenter, lastCenter) >= refreshDistanceMeters;
    final noMarkersYet =
        !hasMarkers && (lastFetchTime == null || now.difference(lastFetchTime) >= emptyFallbackInterval);

    return (movedEnough && timeElapsed) || noMarkersYet;
  }

  /// Ensures artworks linked to markers are present and backfilled with positions.
  static Future<void> hydrateMarkersWithArtworks(
    ArtworkProvider artworkProvider,
    List<ArtMarker> markers,
    {int maxPrefetch = 80}
  ) async {
    final missingIds = <String>{};

    for (final marker in markers) {
      if (marker.isExhibitionMarker) continue;
      final artworkId = marker.artworkId;
      if (artworkId == null || artworkId.isEmpty) continue;
      if (artworkProvider.getArtworkById(artworkId) == null) {
        missingIds.add(artworkId);
        if (missingIds.length >= maxPrefetch) break;
      }
    }

    for (final artworkId in missingIds) {
      try {
        await artworkProvider.fetchArtworkIfNeeded(artworkId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('MapMarkerHelper: failed to hydrate artwork $artworkId: $e');
        }
      }
    }

    for (final marker in markers) {
      if (marker.isExhibitionMarker) continue;
      final artworkId = marker.artworkId;
      if (artworkId == null || artworkId.isEmpty) continue;

      final artwork = artworkProvider.getArtworkById(artworkId);
      if (artwork != null && !artwork.hasValidLocation && marker.hasValidPosition) {
        artworkProvider.addOrUpdateArtwork(
          artwork.copyWith(
            position: marker.position,
            arMarkerId: marker.id,
            metadata: {
              ...?artwork.metadata,
              'linkedMarkerId': marker.id,
            },
          ),
        );
      }
    }
  }
}
