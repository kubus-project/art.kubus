import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/art_marker.dart';
import 'backend_api_service.dart';

@immutable
class MapDataControllerStats {
  const MapDataControllerStats({
    required this.markerByIdCalls,
    required this.markerByIdCacheHits,
    required this.markerByIdInFlightDedupes,
  });

  final int markerByIdCalls;
  final int markerByIdCacheHits;
  final int markerByIdInFlightDedupes;
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

  int _debugMarkerByIdCalls = 0;
  int _debugMarkerByIdCacheHits = 0;
  int _debugMarkerByIdInFlightDedupes = 0;

  @visibleForTesting
  MapDataControllerStats get debugStats => MapDataControllerStats(
        markerByIdCalls: _debugMarkerByIdCalls,
        markerByIdCacheHits: _debugMarkerByIdCacheHits,
        markerByIdInFlightDedupes: _debugMarkerByIdInFlightDedupes,
      );

  @visibleForTesting
  void resetDebugStats() {
    _debugMarkerByIdCalls = 0;
    _debugMarkerByIdCacheHits = 0;
    _debugMarkerByIdInFlightDedupes = 0;
  }

  Future<ArtMarker?> getArtMarkerById(String markerId) {
    final id = markerId.trim();
    if (id.isEmpty) return Future<ArtMarker?>.value(null);

    _debugMarkerByIdCalls += 1;

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

    final future = _backendApiService.getArtMarker(id).then((marker) {
      _markerByIdCache[id] = _MarkerByIdCacheEntry(
        marker: marker,
        fetchedAt: DateTime.now(),
      );
      return marker;
    }).catchError((Object e, StackTrace st) {
      // Best-effort: keep failures local and avoid poisoning caches.
      if (kDebugMode) {
        AppConfig.debugPrint(
            'MapDataController: getArtMarkerById($id) failed: $e');
        AppConfig.debugPrint('MapDataController: getArtMarkerById stack: $st');
      }
      return null;
    }).whenComplete(() {
      _inFlightMarkerById.remove(id);
    });

    _inFlightMarkerById[id] = future;
    return future;
  }

  void clearMarkerByIdCache() {
    _markerByIdCache.clear();
    _inFlightMarkerById.clear();
  }
}
