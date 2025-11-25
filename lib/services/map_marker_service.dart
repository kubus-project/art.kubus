import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../providers/storage_provider.dart';
import 'ar_content_service.dart';
import 'backend_api_service.dart';

/// Service responsible for fetching and managing map-visible art markers.
class MapMarkerService {
  MapMarkerService._internal();
  static final MapMarkerService _instance = MapMarkerService._internal();
  factory MapMarkerService() => _instance;

  final BackendApiService _backendApi = BackendApiService();
  final List<ArtMarker> _cachedMarkers = [];
  LatLng? _lastQueryCenter;
  double _lastQueryRadiusKm = 5.0;
  DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(seconds: 30);
  final Distance _distance = const Distance();

  bool _canReuseCache(LatLng center, double radiusKm) {
    if (_cachedMarkers.isEmpty ||
        _lastFetchTime == null ||
        _lastQueryCenter == null) {
      return false;
    }

    if (DateTime.now().difference(_lastFetchTime!) > _cacheTtl) {
      return false;
    }

    final centerDelta = _distance.as(
      LengthUnit.Kilometer,
      _lastQueryCenter!,
      center,
    );

    final radiusDelta = (_lastQueryRadiusKm - radiusKm).abs();
    return centerDelta <= radiusKm * 0.25 && radiusDelta <= 1.0;
  }

  Future<List<ArtMarker>> loadMarkers({
    required LatLng center,
    double radiusKm = 5.0,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _canReuseCache(center, radiusKm)) {
      return List<ArtMarker>.from(_cachedMarkers);
    }

    final markers = await _backendApi.getNearbyArtMarkers(
      latitude: center.latitude,
      longitude: center.longitude,
      radiusKm: radiusKm,
    );

    _cachedMarkers
      ..clear()
      ..addAll(markers);
    _lastQueryCenter = center;
    _lastQueryRadiusKm = radiusKm;
    _lastFetchTime = DateTime.now();
    return List<ArtMarker>.from(_cachedMarkers);
  }

  void clearCache() {
    _cachedMarkers.clear();
    _lastQueryCenter = null;
    _lastFetchTime = null;
  }

  Future<ArtMarker?> createMarker({
    required LatLng location,
    required String title,
    required String description,
    required ArtMarkerType type,
    String category = 'User Created',
    String? artworkId,
    Map<String, dynamic>? metadata,
    List<String> tags = const [],
    bool isPublic = true,
    double scale = 1.0,
    String? modelCID,
    String? modelURL,
  }) async {
    try {
      final hasCid = modelCID?.isNotEmpty ?? false;
      final hasUrl = modelURL?.isNotEmpty ?? false;
      final storageProvider = hasCid && hasUrl
          ? StorageProvider.hybrid
          : hasCid
              ? StorageProvider.ipfs
              : StorageProvider.http;

      final marker = ArtMarker(
        id: 'marker_${DateTime.now().millisecondsSinceEpoch}',
        name: title,
        description: description,
        position: location,
        artworkId: artworkId,
        type: type,
        category: category,
        modelCID: modelCID,
        modelURL: modelURL,
        storageProvider: storageProvider,
        scale: scale,
        metadata: {
          'source': 'user_created',
          'createdFrom': 'map_marker_service',
          'isPublic': isPublic,
          if (metadata != null) ...metadata,
        },
        tags: tags,
        createdAt: DateTime.now(),
        createdBy: 'current_user',
        isPublic: isPublic,
      );

      final persistedMarker = await ARContentService.saveARMarker(marker);
      if (persistedMarker != null) {
        _cachedMarkers.add(persistedMarker);
        return persistedMarker;
      }
    } catch (e) {
      debugPrint('MapMarkerService: Error creating marker - $e');
    }
    return null;
  }

  /// Map markers are metadata containers on the map; AR uploads are handled by
  /// [ARMarkerService]. This method is intentionally removed to prevent
  /// accidental model uploads through the map layer.
}
