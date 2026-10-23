import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/art_marker.dart';
import 'backend_api_service.dart';
import 'public_fallback_service.dart';

@immutable
class MapDataControllerStats {
  const MapDataControllerStats({
    required this.markerByIdCalls,
    required this.markerByIdCacheHits,
    required this.markerByIdInFlightDedupes,
    required this.markersByArtworkCalls,
    required this.markersByArtworkCacheHits,
    required this.markersByArtworkInFlightDedupes,
  });

  final int markerByIdCalls;
  final int markerByIdCacheHits;
  final int markerByIdInFlightDedupes;
  final int markersByArtworkCalls;
  final int markersByArtworkCacheHits;
  final int markersByArtworkInFlightDedupes;
}

@immutable
class _MarkerByIdCacheEntry {
  const _MarkerByIdCacheEntry({
    required this.marker,
    required this.fetchedAt,
  });

  final ArtMarker? marker;
  final DateTime fetchedAt;
}

@immutable
class _MarkersByArtworkCacheEntry {
  const _MarkersByArtworkCacheEntry({
    required this.markers,
    required this.fetchedAt,
  });

  final List<ArtMarker> markers;
  final DateTime fetchedAt;
}

/// Map-focused data coordinator that dedupes in-flight requests and caches
/// low-churn reads used by both mobile and desktop map screens.
class MapDataController {
  MapDataController._internal({
    BackendApiService? backendApiService,
  }) : _backendApiService = backendApiService ?? BackendApiService();

  static final MapDataController _instance = MapDataController._internal();
  factory MapDataController() => _instance;

  final BackendApiService _backendApiService;

  static const Duration _markerByIdTtl = Duration(minutes: 5);
  final Map<String, _MarkerByIdCacheEntry> _markerByIdCache =
      <String, _MarkerByIdCacheEntry>{};
  final Map<String, Future<ArtMarker?>> _inFlightMarkerById =
      <String, Future<ArtMarker?>>{};
  final Map<String, _MarkersByArtworkCacheEntry> _markersByArtworkCache =
      <String, _MarkersByArtworkCacheEntry>{};
  final Map<String, Future<List<ArtMarker>>> _inFlightMarkersByArtwork =
      <String, Future<List<ArtMarker>>>{};

  int _debugMarkerByIdCalls = 0;
  int _debugMarkerByIdCacheHits = 0;
  int _debugMarkerByIdInFlightDedupes = 0;
  int _debugMarkersByArtworkCalls = 0;
  int _debugMarkersByArtworkCacheHits = 0;
  int _debugMarkersByArtworkInFlightDedupes = 0;

  @visibleForTesting
  MapDataControllerStats get debugStats => MapDataControllerStats(
        markerByIdCalls: _debugMarkerByIdCalls,
        markerByIdCacheHits: _debugMarkerByIdCacheHits,
        markerByIdInFlightDedupes: _debugMarkerByIdInFlightDedupes,
        markersByArtworkCalls: _debugMarkersByArtworkCalls,
        markersByArtworkCacheHits: _debugMarkersByArtworkCacheHits,
        markersByArtworkInFlightDedupes: _debugMarkersByArtworkInFlightDedupes,
      );

  @visibleForTesting
  void resetDebugStats() {
    _debugMarkerByIdCalls = 0;
    _debugMarkerByIdCacheHits = 0;
    _debugMarkerByIdInFlightDedupes = 0;
    _debugMarkersByArtworkCalls = 0;
    _debugMarkersByArtworkCacheHits = 0;
    _debugMarkersByArtworkInFlightDedupes = 0;
  }

  /// Null when the marker is absent or its lookup failed. Public-entry direct
  /// targets use [getArtMarkerForDirectTarget] so a failure is not mistaken for
  /// a missing marker.
  Future<ArtMarker?> getArtMarkerById(String markerId) {
    return _loadArtMarkerById(markerId).catchError((Object e, StackTrace st) {
      // Best-effort: keep failures local and avoid poisoning caches.
      if (kDebugMode) {
        AppConfig.debugPrint(
            'MapDataController: getArtMarkerById($markerId) failed: $e');
        AppConfig.debugPrint('MapDataController: getArtMarkerById stack: $st');
      }
      return null;
    });
  }

  /// Throws when the lookup fails (rate limit, outage, transport), so the map
  /// target coordinator can report a transient failure instead of "not found".
  /// Resolves to null only when the marker does not exist.
  Future<ArtMarker?> getArtMarkerForDirectTarget(String markerId) =>
      _loadArtMarkerById(markerId);

  Future<ArtMarker?> _loadArtMarkerById(String markerId) {
    final id = markerId.trim();
    if (id.isEmpty) return Future<ArtMarker?>.value(null);

    _debugMarkerByIdCalls += 1;
    // Do not let an in-memory live result bypass the public fallback contract.
    if (PublicFallbackService().isIpfsFallbackMode) {
      return Future<ArtMarker?>.value(null);
    }

    final cached = _markerByIdCache[id];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <= _markerByIdTtl) {
      _debugMarkerByIdCacheHits += 1;
      return Future<ArtMarker?>.value(cached.marker);
    }

    final inFlight = _inFlightMarkerById[id];
    if (inFlight != null) {
      _debugMarkerByIdInFlightDedupes += 1;
      return inFlight;
    }

    // A failed lookup throws and caches nothing (the cache is written only on
    // an answer).
    final future = _backendApiService.getArtMarkerOrThrow(id).then((marker) {
      if (PublicFallbackService().isIpfsFallbackMode) return null;
      _markerByIdCache[id] = _MarkerByIdCacheEntry(
        marker: marker,
        fetchedAt: DateTime.now(),
      );
      return marker;
    }).whenComplete(() {
      _inFlightMarkerById.remove(id);
    });

    _inFlightMarkerById[id] = future;
    return future;
  }

  Future<List<ArtMarker>> getArtMarkersByArtwork(String artworkId) {
    final id = artworkId.trim();
    if (id.isEmpty) return Future<List<ArtMarker>>.value(const <ArtMarker>[]);

    _debugMarkersByArtworkCalls += 1;
    if (PublicFallbackService().isIpfsFallbackMode) {
      return Future<List<ArtMarker>>.value(const <ArtMarker>[]);
    }

    final cached = _markersByArtworkCache[id];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <= _markerByIdTtl) {
      _debugMarkersByArtworkCacheHits += 1;
      return Future<List<ArtMarker>>.value(cached.markers);
    }

    final inFlight = _inFlightMarkersByArtwork[id];
    if (inFlight != null) {
      _debugMarkersByArtworkInFlightDedupes += 1;
      return inFlight;
    }

    final future = _backendApiService.getArtMarkersByArtwork(id).then((items) {
      if (PublicFallbackService().isIpfsFallbackMode) {
        return const <ArtMarker>[];
      }
      final markers = List<ArtMarker>.unmodifiable(items);
      _markersByArtworkCache[id] = _MarkersByArtworkCacheEntry(
        markers: markers,
        fetchedAt: DateTime.now(),
      );
      return markers;
    }).catchError((Object e, StackTrace st) {
      if (kDebugMode) {
        AppConfig.debugPrint(
          'MapDataController: getArtMarkersByArtwork($id) failed: $e',
        );
        AppConfig.debugPrint(
          'MapDataController: getArtMarkersByArtwork stack: $st',
        );
      }
      return const <ArtMarker>[];
    }).whenComplete(() {
      _inFlightMarkersByArtwork.remove(id);
    });

    _inFlightMarkersByArtwork[id] = future;
    return future;
  }

  void clearMarkerByIdCache() {
    _markerByIdCache.clear();
    _inFlightMarkerById.clear();
    _markersByArtworkCache.clear();
    _inFlightMarkersByArtwork.clear();
  }
}
