import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../providers/storage_provider.dart';
import '../utils/geo_bounds.dart';
import 'art_marker_service.dart';
import 'backend_api_service.dart';
import 'socket_service.dart';

@immutable
class _MarkerCacheEntry {
  const _MarkerCacheEntry({
    required this.markers,
    required this.fetchedAt,
  });

  final List<ArtMarker> markers;
  final DateTime fetchedAt;
}

/// Service responsible for fetching and managing map-visible art markers.
class MapMarkerService {
  MapMarkerService._internal({
    BackendApiService? backendApiService,
    ArtMarkerService? artMarkerService,
    SocketService? socketService,
    bool enableSocketBridge = true,
  })  : _backendApi = backendApiService ?? BackendApiService(),
        _artMarkerService = artMarkerService ?? ArtMarkerService(),
        _socket = socketService ?? SocketService(),
        _enableSocketBridge = enableSocketBridge;

  static final MapMarkerService _instance = MapMarkerService._internal();
  factory MapMarkerService() => _instance;

  @visibleForTesting
  static MapMarkerService createForTest({
    BackendApiService? backendApiService,
    ArtMarkerService? artMarkerService,
  }) {
    return MapMarkerService._internal(
      backendApiService: backendApiService,
      artMarkerService: artMarkerService,
      enableSocketBridge: false,
    );
  }

  final BackendApiService _backendApi;
  final ArtMarkerService _artMarkerService;
  final List<ArtMarker> _cachedMarkers = [];
  final StreamController<ArtMarker> _markerStreamController =
      StreamController<ArtMarker>.broadcast();
  final StreamController<String> _markerDeletedController =
      StreamController<String>.broadcast();
  final SocketService _socket;
  final bool _enableSocketBridge;
  bool _socketRegistered = false;
  LatLng? _lastQueryCenter;
  double _lastQueryRadiusKm = 5.0;
  GeoBounds? _lastQueryBounds;
  bool _lastQueryWasBounds = false;

  // Query cache (LRU) to keep Travel Mode panning smooth.
  // - Bounds queries: short TTL to avoid staleness while moving quickly.
  // - Radius queries: longer TTL since they are used when exploring a fixed area.
  static const Duration _boundsCacheTtl = Duration(seconds: 90);
  static const Duration _radiusCacheTtl = Duration(minutes: 10);
  static const int _maxQueryCacheEntries = 24;
  final LinkedHashMap<String, _MarkerCacheEntry> _queryCache =
      LinkedHashMap<String, _MarkerCacheEntry>();
  final Map<String, Future<List<ArtMarker>>> _inFlightByKey =
      <String, Future<List<ArtMarker>>>{};

  static const Duration _rateLimitBackoff = Duration(minutes: 30); // Increased from 15 to 30 minutes
  DateTime? _rateLimitUntil;
  final Distance _distance = const Distance();

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  static int _decimalsForZoomBucket(int? zoomBucket) {
    final bucket = zoomBucket ?? 13;
    if (bucket <= 9) return 1; // ~11km
    if (bucket <= 11) return 2; // ~1.1km
    return 3; // ~110m
  }

  static String _q(double value, int decimals) =>
      value.toStringAsFixed(decimals);

  static String _filtersKeyOrEmpty(String? filtersKey) {
    final key = (filtersKey ?? '').trim();
    return key.isEmpty ? '-' : key;
  }

  @visibleForTesting
  static String buildRadiusQueryKey({
    required LatLng center,
    required double radiusKm,
    required int limit,
    int? zoomBucket,
    String? filtersKey,
  }) {
    final decimals = _decimalsForZoomBucket(zoomBucket);
    final fKey = _filtersKeyOrEmpty(filtersKey);
    final radiusKey = radiusKm.toStringAsFixed(2);
    return [
      'r',
      'zb=${zoomBucket ?? '-'}',
      'lim=$limit',
      'f=$fKey',
      'lat=${_q(center.latitude, decimals)}',
      'lng=${_q(center.longitude, decimals)}',
      'rad=$radiusKey',
    ].join('|');
  }

  @visibleForTesting
  static String buildBoundsQueryKey({
    required GeoBounds bounds,
    required int limit,
    int? zoomBucket,
    String? filtersKey,
  }) {
    final decimals = _decimalsForZoomBucket(zoomBucket);
    final fKey = _filtersKeyOrEmpty(filtersKey);
    final crossesDateline = bounds.crossesDateline;
    return [
      'b',
      'zb=${zoomBucket ?? '-'}',
      'lim=$limit',
      'f=$fKey',
      'xdl=${crossesDateline ? '1' : '0'}',
      's=${_q(bounds.south, decimals)}',
      'n=${_q(bounds.north, decimals)}',
      'w=${_q(bounds.west, decimals)}',
      'e=${_q(bounds.east, decimals)}',
    ].join('|');
  }

  _MarkerCacheEntry? _touchCacheEntry(String key) {
    final entry = _queryCache.remove(key);
    if (entry == null) return null;
    _queryCache[key] = entry;
    return entry;
  }

  List<ArtMarker>? _getFreshCachedMarkers(String key, Duration ttl) {
    final entry = _touchCacheEntry(key);
    if (entry == null) return null;
    if (DateTime.now().difference(entry.fetchedAt) > ttl) {
      _queryCache.remove(key);
      return null;
    }
    return entry.markers;
  }

  List<ArtMarker>? _peekCachedMarkers(String key) => _queryCache[key]?.markers;

  void _putCacheEntry(String key, List<ArtMarker> markers) {
    _queryCache.remove(key);
    _queryCache[key] = _MarkerCacheEntry(
      markers: List<ArtMarker>.unmodifiable(markers),
      fetchedAt: DateTime.now(),
    );
    while (_queryCache.length > _maxQueryCacheEntries) {
      _queryCache.remove(_queryCache.keys.first);
    }
  }

  Future<List<ArtMarker>> _dedupeInFlight(
    String key,
    Future<List<ArtMarker>> Function() task,
  ) {
    final existing = _inFlightByKey[key];
    if (existing != null) return existing;

    final future = task().whenComplete(() {
      _inFlightByKey.remove(key);
    });
    _inFlightByKey[key] = future;
    return future;
  }

  bool _boundsContains(GeoBounds bounds, LatLng point) {
    final south = bounds.south;
    final north = bounds.north;
    final west = bounds.west;
    final east = bounds.east;

    if (point.latitude < south || point.latitude > north) return false;

    // Dateline-crossing support: when west > east, the bounds wrap around.
    if (west <= east) {
      return point.longitude >= west && point.longitude <= east;
    }
    return point.longitude >= west || point.longitude <= east;
  }

  Future<List<ArtMarker>> loadMarkers({
    required LatLng center,
    double radiusKm = 5.0,
    int? limit,
    bool forceRefresh = false,
    int? zoomBucket,
    String? filtersKey,
  }) async {
    _ensureSocketBridge();

    final requestedLimit = limit ?? 100;
    final key = buildRadiusQueryKey(
      center: center,
      radiusKm: radiusKm,
      limit: requestedLimit,
      zoomBucket: zoomBucket,
      filtersKey: filtersKey,
    );

    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      final cached = _peekCachedMarkers(key) ?? _cachedMarkers;
      return _filterValidMarkers(cached);
    }

    if (!forceRefresh) {
      final cached = _getFreshCachedMarkers(key, _radiusCacheTtl);
      if (cached != null) {
        _cachedMarkers
          ..clear()
          ..addAll(cached);
        _lastQueryCenter = center;
        _lastQueryRadiusKm = radiusKm;
        _lastQueryBounds = null;
        _lastQueryWasBounds = false;
        return _filterValidMarkers(cached);
      }
    }

    return _dedupeInFlight(key, () async {
      try {
        final markers = await _backendApi.getNearbyArtMarkers(
          latitude: center.latitude,
          longitude: center.longitude,
          radiusKm: radiusKm,
          limit: requestedLimit,
        );

        _rateLimitUntil = null;
        final filtered = _filterValidMarkers(markers);
        _putCacheEntry(key, filtered);
        _cachedMarkers
          ..clear()
          ..addAll(filtered);
        _lastQueryCenter = center;
        _lastQueryRadiusKm = radiusKm;
        _lastQueryBounds = null;
        _lastQueryWasBounds = false;
        return filtered;
      } catch (e) {
        final message = e.toString().toLowerCase();
        if (message.contains('rate limit') ||
            message.contains('429') ||
            message.contains('too many')) {
          _rateLimitUntil = DateTime.now().add(_rateLimitBackoff);
        }
        final cached = _peekCachedMarkers(key) ?? _cachedMarkers;
        return _filterValidMarkers(cached);
      }
    });
  }

  Future<List<ArtMarker>> loadMarkersInBounds({
    required LatLng center,
    required GeoBounds bounds,
    int? limit,
    bool forceRefresh = false,
    int? zoomBucket,
    String? filtersKey,
  }) async {
    _ensureSocketBridge();

    final requestedLimit = limit ?? 100;
    final key = buildBoundsQueryKey(
      bounds: bounds,
      limit: requestedLimit,
      zoomBucket: zoomBucket,
      filtersKey: filtersKey,
    );

    if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
      final cached = _peekCachedMarkers(key) ?? _cachedMarkers;
      return _filterValidMarkers(cached);
    }

    if (!forceRefresh) {
      final cached = _getFreshCachedMarkers(key, _boundsCacheTtl);
      if (cached != null) {
        _cachedMarkers
          ..clear()
          ..addAll(cached);
        _lastQueryCenter = center;
        _lastQueryBounds = bounds;
        _lastQueryWasBounds = true;
        return _filterValidMarkers(cached);
      }
    }

    return _dedupeInFlight(key, () async {
      try {
        final markers = await _backendApi.getArtMarkersInBounds(
          latitude: center.latitude,
          longitude: center.longitude,
          minLat: bounds.south,
          maxLat: bounds.north,
          minLng: bounds.west,
          maxLng: bounds.east,
          limit: requestedLimit,
        );

        _rateLimitUntil = null;
        final filtered = _filterValidMarkers(markers);
        _putCacheEntry(key, filtered);
        _cachedMarkers
          ..clear()
          ..addAll(filtered);
        _lastQueryCenter = center;
        _lastQueryBounds = bounds;
        _lastQueryWasBounds = true;
        return filtered;
      } catch (e) {
        final message = e.toString().toLowerCase();
        if (message.contains('rate limit') ||
            message.contains('429') ||
            message.contains('too many')) {
          _rateLimitUntil = DateTime.now().add(_rateLimitBackoff);
        }
        final cached = _peekCachedMarkers(key) ?? _cachedMarkers;
        return _filterValidMarkers(cached);
      }
    });
  }

  double get lastQueryRadiusKm => _lastQueryRadiusKm;

  void clearCache() {
    _cachedMarkers.clear();
    _queryCache.clear();
    _inFlightByKey.clear();
    _lastQueryCenter = null;
    _lastQueryBounds = null;
    _lastQueryWasBounds = false;
  }

  void notifyMarkerDeleted(String markerId) {
    final id = markerId.trim();
    if (id.isEmpty) return;
    _cachedMarkers.removeWhere((m) => m.id == id);
    for (final key in _queryCache.keys.toList(growable: false)) {
      final entry = _queryCache[key];
      if (entry == null) continue;
      final nextMarkers = entry.markers.where((m) => m.id != id).toList();
      if (nextMarkers.length == entry.markers.length) continue;
      _queryCache[key] = _MarkerCacheEntry(
        markers: List<ArtMarker>.unmodifiable(nextMarkers),
        fetchedAt: entry.fetchedAt,
      );
    }
    _markerDeletedController.add(id);
  }

  void notifyMarkerUpserted(ArtMarker marker) {
    if (!_isValidPosition(marker.position)) return;

    final shouldKeep = _lastQueryWasBounds
        ? (_lastQueryBounds != null &&
            _boundsContains(_lastQueryBounds!, marker.position))
        : (_lastQueryCenter != null &&
            _distance.as(LengthUnit.Kilometer, _lastQueryCenter!, marker.position) <=
                _lastQueryRadiusKm + 0.5);

    if (shouldKeep) {
      final existingIndex = _cachedMarkers.indexWhere((m) => m.id == marker.id);
      if (existingIndex >= 0) {
        _cachedMarkers[existingIndex] = marker;
      } else {
        _cachedMarkers.add(marker);
      }
    }

    _markerStreamController.add(marker);
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
      _log('MapMarkerService: Error creating marker - $e');
    }
    return null;
  }

  /// Map markers are metadata containers on the map; AR uploads are handled by
  /// [ARMarkerService]. This method is intentionally removed to prevent
  /// accidental model uploads through the map layer.

  void _ensureSocketBridge() {
    if (_socketRegistered) return;
    if (!_enableSocketBridge) return;
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
        notifyMarkerDeleted(id);
        return;
      }

      final marker = _markerFromSocketPayload(payload);
      if (marker == null || !_isValidPosition(marker.position)) return;
      final shouldKeep = _lastQueryWasBounds
          ? (_lastQueryBounds != null &&
              _boundsContains(_lastQueryBounds!, marker.position))
          : (_lastQueryCenter != null &&
              _distance.as(
                    LengthUnit.Kilometer,
                    _lastQueryCenter!,
                    marker.position,
                  ) <=
                  _lastQueryRadiusKm + 0.5);

      // If we have an active cache window and the marker is nearby, merge it in-place.
      if (shouldKeep) {
        final existingIndex =
            _cachedMarkers.indexWhere((m) => m.id == marker.id);
        if (existingIndex >= 0) {
          _cachedMarkers[existingIndex] = marker;
        } else {
          _cachedMarkers.add(marker);
        }
      }
      _markerStreamController.add(marker);
    } catch (e) {
      _log('MapMarkerService: failed to handle socket marker: $e');
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
      _log('MapMarkerService: _markerFromSocketPayload failed: $e');
      return null;
    }
  }
}
