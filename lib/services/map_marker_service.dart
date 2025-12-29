import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../providers/storage_provider.dart';
import 'art_marker_service.dart';
import 'backend_api_service.dart';
import 'socket_service.dart';

/// Service responsible for fetching and managing map-visible art markers.
class MapMarkerService {
  MapMarkerService._internal();
  static final MapMarkerService _instance = MapMarkerService._internal();
  factory MapMarkerService() => _instance;

  final BackendApiService _backendApi = BackendApiService();
  final ArtMarkerService _artMarkerService = ArtMarkerService();
  final List<ArtMarker> _cachedMarkers = [];
  final StreamController<ArtMarker> _markerStreamController =
      StreamController<ArtMarker>.broadcast();
  final StreamController<String> _markerDeletedController =
      StreamController<String>.broadcast();
  final SocketService _socket = SocketService();
  bool _socketRegistered = false;
  LatLng? _lastQueryCenter;
  double _lastQueryRadiusKm = 5.0;
  DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 15); // Increased from 10 to 15 minutes
  static const Duration _rateLimitBackoff = Duration(minutes: 30); // Increased from 15 to 30 minutes
  DateTime? _rateLimitUntil;
  final Distance _distance = const Distance();
  bool _isFetching = false; // Prevent concurrent fetches

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

    // More lenient cache reuse - 35% of radius instead of 25%
    final radiusDelta = (_lastQueryRadiusKm - radiusKm).abs();
    return centerDelta <= radiusKm * 0.35 && radiusDelta <= 2.0;
  }

  Future<List<ArtMarker>> loadMarkers({
    required LatLng center,
    double radiusKm = 5.0,
    bool forceRefresh = false,
  }) async {
    _ensureSocketBridge();

    // Prevent concurrent fetches
    if (_isFetching) {
      debugPrint('MapMarkerService: Already fetching, returning cached markers');
      return _filterValidMarkers(_cachedMarkers);
    }

    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      debugPrint(
          'MapMarkerService: using cache during rate-limit cooldown (until $_rateLimitUntil)');
      return _filterValidMarkers(_cachedMarkers);
    }

    if (!forceRefresh && _canReuseCache(center, radiusKm)) {
      debugPrint('MapMarkerService: using cached markers (${_cachedMarkers.length} items)');
      return _filterValidMarkers(_cachedMarkers);
    }

    try {
      _isFetching = true;
      debugPrint('MapMarkerService: Fetching markers from backend...');
      
      final markers = await _backendApi.getNearbyArtMarkers(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusKm: radiusKm,
      );

      _rateLimitUntil = null; // successful fetch resets any prior backoff
      _cachedMarkers
        ..clear()
        ..addAll(_filterValidMarkers(markers));
      _lastQueryCenter = center;
      _lastQueryRadiusKm = radiusKm;
      _lastFetchTime = DateTime.now();
      
      debugPrint('MapMarkerService: Successfully fetched ${markers.length} markers');
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('rate limit') || message.contains('429') || message.contains('too many')) {
        _rateLimitUntil = DateTime.now().add(_rateLimitBackoff);
        debugPrint(
            'MapMarkerService: rate-limited, backing off until $_rateLimitUntil');
      }
      debugPrint('MapMarkerService: falling back to cached markers after error: $e');
    } finally {
      _isFetching = false;
    }

    return _filterValidMarkers(_cachedMarkers);
  }

  double get lastQueryRadiusKm => _lastQueryRadiusKm;

  void clearCache() {
    _cachedMarkers.clear();
    _lastQueryCenter = null;
    _lastFetchTime = null;
  }

  /// Stream for real-time marker creations broadcast by the backend via sockets.
  Stream<ArtMarker> get onMarkerCreated => _markerStreamController.stream;

  Stream<String> get onMarkerDeleted => _markerDeletedController.stream;

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
      if (artworkId != null && artworkId.isNotEmpty) {
        // Local cache check
        final alreadyHasMarker = _cachedMarkers.any(
          (m) => (m.artworkId ?? '').isNotEmpty && m.artworkId == artworkId,
        );
        if (alreadyHasMarker) {
          throw StateError('Marker already exists for artwork $artworkId');
        }

        // Remote check (fetch nearby markers to ensure uniqueness)
        final nearby = await _artMarkerService.fetchMarkers(
          latitude: location.latitude,
          longitude: location.longitude,
          radiusKm: 25,
        );
        final remoteHas = nearby.any(
          (m) => (m.artworkId ?? '').isNotEmpty && m.artworkId == artworkId,
        );
        if (remoteHas) {
          throw StateError('Marker already exists for artwork $artworkId');
        }
      }

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

      final persistedMarker = await _artMarkerService.saveMarker(marker);
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

  void _ensureSocketBridge() {
    if (_socketRegistered) return;
    _socketRegistered = true;
    // Connect is idempotent; if chat/notifications already connected this will be a no-op.
    unawaited(_socket.connect());
    _socket.addMarkerListener(_handleSocketMarker);
  }

  void _handleSocketMarker(Map<String, dynamic> payload) {
    try {
      final event = payload['event']?.toString() ?? '';
      final deleted = payload['deleted'] == true || event == 'art-marker:deleted';
      if (deleted) {
        final id = (payload['id'] ?? payload['_id'] ?? '').toString();
        if (id.isEmpty) return;
        _cachedMarkers.removeWhere((m) => m.id == id);
        _markerDeletedController.add(id);
        return;
      }

      final marker = _markerFromSocketPayload(payload);
      if (marker == null || !_isValidPosition(marker.position)) return;
      // If we have an active cache window and the marker is nearby, merge it in-place.
      if (_lastQueryCenter != null &&
          _distance.as(LengthUnit.Kilometer, _lastQueryCenter!, marker.position) <=
              _lastQueryRadiusKm + 0.5) {
        final existingIndex =
            _cachedMarkers.indexWhere((m) => m.id == marker.id);
        if (existingIndex >= 0) {
          _cachedMarkers[existingIndex] = marker;
        } else {
          _cachedMarkers.add(marker);
        }
      } else {
        // New marker outside cache window; clear so next fetch pulls fresh data.
        clearCache();
      }
      _markerStreamController.add(marker);
    } catch (e) {
      debugPrint('MapMarkerService: failed to handle socket marker: $e');
    }
  }

  double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  List<ArtMarker> _filterValidMarkers(List<ArtMarker> markers) {
    return markers.where((m) => _isValidPosition(m.position)).toList();
  }

  bool _isValidPosition(LatLng position) {
    return position.latitude.abs() > 0.0001 || position.longitude.abs() > 0.0001;
  }

  ArtMarker? _markerFromSocketPayload(Map<String, dynamic> json) {
    try {
      final normalized = <String, dynamic>{
        'id': json['id'] ?? json['_id'] ?? '',
        'name': json['name'] ?? json['title'] ?? json['label'] ?? '',
        'description': json['description'] ?? json['summary'] ?? '',
        'latitude': _asDouble(json['latitude'] ?? json['lat'] ?? json['position']?['lat']),
        'longitude': _asDouble(json['longitude'] ?? json['lng'] ?? json['position']?['lng']),
        'artworkId': json['artworkId'] ?? json['artwork_id'],
        'modelCID': json['modelCID'] ?? json['model_cid'],
        'modelURL': json['modelURL'] ?? json['model_url'],
        'storageProvider': json['storageProvider'] ?? json['storage_provider'] ?? 'hybrid',
        'scale': _asDouble(json['scale'] ?? json['ar_scale'], 1.0),
        'rotation': json['rotation'] ?? {
          'x': _asDouble(json['rotation_x'] ?? json['ar_rotation_x']),
          'y': _asDouble(json['rotation_y'] ?? json['ar_rotation_y']),
          'z': _asDouble(json['rotation_z'] ?? json['ar_rotation_z']),
        },
        'enableAnimation': json['enableAnimation'] ?? json['enable_animation'] ?? false,
        'animationName': json['animationName'] ?? json['animation_name'],
        'enablePhysics': json['enablePhysics'] ?? false,
        'enableInteraction': json['enableInteraction'] ?? json['enable_interaction'] ?? true,
        'metadata': json['metadata'] ?? json['marker_data'] ?? json['meta'],
        'tags': json['tags'],
        'category': json['category'] ?? json['markerType'] ?? json['type'] ?? 'General',
        'createdAt': json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
        'createdBy': json['createdBy'] ?? json['created_by'] ?? 'system',
        'viewCount': json['viewCount'] ?? json['views'] ?? json['activation_count'] ?? 0,
        'interactionCount': json['interactionCount'] ?? json['interactions'] ?? 0,
        'activationRadius': json['activationRadius'] ?? json['activation_radius'] ?? 50.0,
        'requiresProximity': json['requiresProximity'] ?? json['requires_proximity'] ?? true,
        'isPublic': json['isPublic'] ?? json['is_public'] ?? true,
        'markerType': json['markerType'] ?? json['type'],
      };
      return ArtMarker.fromMap(normalized);
    } catch (e) {
      debugPrint('MapMarkerService: _markerFromSocketPayload failed: $e');
      return null;
    }
  }
}
