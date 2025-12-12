import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/artwork.dart';
import '../models/art_marker.dart';
import '../providers/storage_provider.dart';
import '../community/community_interactions.dart';
import './ar_manager.dart';
import './ar_content_service.dart';
import './art_content_service.dart';
import './art_marker_service.dart';

/// Integration service orchestrating AR experiences and physical marker flows
class ARIntegrationService {
  static final ARIntegrationService _instance =
      ARIntegrationService._internal();
  factory ARIntegrationService() => _instance;
  ARIntegrationService._internal();

  final ARManager _arManager = ARManager();
  final ArtMarkerService _artMarkerService = ArtMarkerService();
  final List<ArtMarker> _nearbyMarkers = [];
  LatLng? _currentLocation;
  DateTime? _lastMarkerRefresh;
  LatLng? _lastMarkerLocation;
  bool _isFetchingMarkers = false;
  static const Duration _markerRefreshInterval = Duration(seconds: 25);
  static const double _markerRefreshDistanceMeters = 40;
  final Distance _distanceCalculator = const Distance();

  // Callbacks for UI updates
  Function(ArtMarker)? onMarkerActivated;
  Function(Artwork)? onArtworkDiscovered;
  Function(String)? onARInteractionComplete;

  /// Initialize the integration service
  Future<void> initialize() async {
    await _arManager.initialize();
    debugPrint('ARIntegrationService: Initialized');
  }

  /// Update current location and check for nearby markers
  Future<void> updateLocation(LatLng location) async {
    _currentLocation = location;
    if (_shouldRefreshMarkers(location)) {
      if (_isFetchingMarkers) return;
      _isFetchingMarkers = true;
      try {
        await _checkNearbyMarkers(location);
      } finally {
        _isFetchingMarkers = false;
      }
    }
  }

  bool _shouldRefreshMarkers(LatLng location) {
    if (_lastMarkerRefresh == null || _lastMarkerLocation == null) {
      return true;
    }

    final double movedMeters = _distanceCalculator.as(
      LengthUnit.Meter,
      _lastMarkerLocation!,
      location,
    );
    final bool movedEnough = movedMeters >= _markerRefreshDistanceMeters;
    final bool intervalElapsed =
        DateTime.now().difference(_lastMarkerRefresh!) >=
            _markerRefreshInterval;
    return movedEnough || intervalElapsed;
  }

  /// Check for nearby AR markers
  Future<void> _checkNearbyMarkers(LatLng location) async {
    try {
      _lastMarkerRefresh = DateTime.now();
      _lastMarkerLocation = location;
      // Fetch markers from backend
      final markers = await _artMarkerService.fetchMarkers(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: 1.0, // 1km radius
      );

      _nearbyMarkers.clear();
      _nearbyMarkers.addAll(markers);

      // Check which markers are currently active
      for (final marker in markers) {
        if (marker.isActiveAt(location)) {
          debugPrint('ARIntegrationService: Marker ${marker.name} is active');
          onMarkerActivated?.call(marker);
        }
      }
    } catch (e) {
      debugPrint('ARIntegrationService: Error checking markers: $e');
    }
  }

  /// Trigger AR experience for an artwork
  Future<void> launchARExperience(Artwork artwork) async {
    if (!artwork.arEnabled) {
      debugPrint('ARIntegrationService: AR not enabled for ${artwork.title}');
      return;
    }

    try {
      // Find associated AR marker
      ArtMarker? marker;
      if (artwork.arMarkerId != null) {
        marker = _nearbyMarkers.firstWhere(
          (m) => m.id == artwork.arMarkerId,
          orElse: () => _createMarkerFromArtwork(artwork),
        );
      } else {
        marker = _createMarkerFromArtwork(artwork);
      }

      // Load AR content
      final contentUrl = await ARContentService.loadARContent(marker);
      if (contentUrl == null) {
        debugPrint('ARIntegrationService: Failed to load AR content');
        return;
      }

      // Launch AR with the model
      await _displayARContent(marker, contentUrl);

      // Track interaction
      await _trackARInteraction(artwork, marker);
    } catch (e) {
      debugPrint('ARIntegrationService: Error launching AR: $e');
    }
  }

  /// Create AR marker from artwork data
  ArtMarker _createMarkerFromArtwork(Artwork artwork) {
    return ArtMarker(
      id: artwork.arMarkerId ?? 'temp_${artwork.id}',
      name: artwork.title,
      description: artwork.description,
      position: artwork.position,
      artworkId: artwork.id,
      type: ArtMarkerType.artwork,
      category: artwork.category,
      modelCID: artwork.model3DCID,
      modelURL: artwork.model3DURL,
      storageProvider: artwork.model3DCID != null
          ? StorageProvider.hybrid
          : StorageProvider.http,
      scale: artwork.arScale ?? 1.0,
      rotation: artwork.arRotation ?? {'x': 0, 'y': 0, 'z': 0},
      enableAnimation: artwork.arEnableAnimation ?? false,
      animationName: artwork.arAnimationName,
      metadata: {
        'source': 'artwork_sync',
        'artworkTitle': artwork.title,
        'artist': artwork.artist,
      },
      tags: artwork.tags,
      createdAt: artwork.createdAt,
      createdBy: artwork.artist,
    );
  }

  /// Display AR content using ARManager
  Future<void> _displayARContent(ArtMarker marker, String contentUrl) async {
    if (!_arManager.isInitialized) {
      await _arManager.initialize();
    }

    // Add 3D model to AR scene
    await _arManager.addModel(
      modelPath: contentUrl,
      position: vector.Vector3(0, 0, -1.5), // 1.5m in front of user
      scale: vector.Vector3.all(marker.scale),
      name: marker.id,
    );

    debugPrint('ARIntegrationService: AR content displayed for ${marker.name}');
  }

  /// Track AR interaction
  Future<void> _trackARInteraction(Artwork artwork, ArtMarker marker) async {
    try {
      // Update local marker stats
      final updatedMarker = marker.copyWith(
        interactionCount: marker.interactionCount + 1,
        viewCount: marker.viewCount + 1,
      );

      // Save to backend
      await _artMarkerService.saveMarker(updatedMarker);

      // Notify callbacks
      onARInteractionComplete?.call(artwork.id);

      debugPrint(
          'ARIntegrationService: Interaction tracked for ${artwork.title}');
    } catch (e) {
      debugPrint('ARIntegrationService: Error tracking interaction: $e');
    }
  }

  /// Discover artwork (when user is near and views in AR)
  Future<void> discoverArtwork(Artwork artwork) async {
    if (_currentLocation == null) return;

    // Check if user is actually near the artwork
    if (!artwork.isNearby(_currentLocation!, maxDistanceMeters: 50)) {
      debugPrint('ARIntegrationService: User not close enough to discover');
      return;
    }

    try {
      // Update artwork status
      final discoveredArtwork = artwork.copyWith(
        status: ArtworkStatus.discovered,
        discoveryCount: artwork.discoveryCount + 1,
        discoveredAt: DateTime.now(),
      );

      // Notify callback
      onArtworkDiscovered?.call(discoveredArtwork);

      debugPrint('ARIntegrationService: Artwork discovered: ${artwork.title}');
    } catch (e) {
      debugPrint('ARIntegrationService: Error discovering artwork: $e');
    }
  }

  /// Share AR experience to community
  Future<CommunityPost?> shareARExperience({
    required Artwork artwork,
    required String content,
    String? imageUrl,
    required String authorName,
  }) async {
    try {
      final post = CommunityPost(
        id: 'post_${DateTime.now().millisecondsSinceEpoch}',
        authorId: 'current_user',
        authorName: authorName,
        content:
            '$content\n\n🎨 Artwork: ${artwork.title}\n📍 ${artwork.position.latitude.toStringAsFixed(4)}, ${artwork.position.longitude.toStringAsFixed(4)}',
        imageUrl: imageUrl ?? artwork.imageUrl,
        timestamp: DateTime.now(),
        tags: ['#AR', '#${artwork.category}', '#art.kubus'],
      );

      debugPrint('ARIntegrationService: AR experience shared to community');
      return post;
    } catch (e) {
      debugPrint('ARIntegrationService: Error sharing experience: $e');
      return null;
    }
  }

  /// Get nearby artworks with AR enabled
  List<Artwork> getNearbyARArtworks(List<Artwork> allArtworks,
      {double radiusKm = 1.0}) {
    if (_currentLocation == null) return [];

    return allArtworks.where((artwork) {
      if (!artwork.arEnabled) return false;

      final distanceMeters = artwork.getDistanceFrom(_currentLocation!);
      return distanceMeters <= (radiusKm * 1000);
    }).toList()
      ..sort((a, b) {
        final distA = a.getDistanceFrom(_currentLocation!);
        final distB = b.getDistanceFrom(_currentLocation!);
        return distA.compareTo(distB);
      });
  }

  /// Get active AR markers
  List<ArtMarker> getActiveMarkers() {
    if (_currentLocation == null) return [];

    return _nearbyMarkers
        .where((marker) => marker.isActiveAt(_currentLocation!))
        .toList();
  }

  /// Get AR marker for artwork
  ArtMarker? getMarkerForArtwork(String artworkId) {
    try {
      return _nearbyMarkers.firstWhere(
        (marker) => marker.artworkId == artworkId,
      );
    } catch (e) {
      return null;
    }
  }

  // Marker creation/upload handled by MapMarkerService

  /// Get storage configuration info
  Future<Map<String, dynamic>> getStorageInfo() async {
    final provider = await ARContentService.getPreferredStorageProvider();
    final gateway = await ARContentService.getPreferredIPFSGateway();
    final stats = await ArtContentService.getStorageStats();

    return {
      'provider': provider.name,
      'ipfsGateway': gateway,
      'stats': stats,
      'nearbyMarkers': _nearbyMarkers.length,
      'activeMarkers': getActiveMarkers().length,
    };
  }

  /// Switch storage provider
  Future<void> setStorageProvider(StorageProvider provider) async {
    await ARContentService.setPreferredStorageProvider(provider);
    debugPrint(
        'ARIntegrationService: Storage provider set to ${provider.name}');
  }

  /// Dispose resources
  void dispose() {
    _arManager.dispose();
    _nearbyMarkers.clear();
    _currentLocation = null;
    _lastMarkerRefresh = null;
    _lastMarkerLocation = null;
    debugPrint('ARIntegrationService: Disposed');
  }

  /// Get current location
  LatLng? get currentLocation => _currentLocation;

  /// Get AR manager instance
  ARManager get arManager => _arManager;

  /// Get nearby markers count
  int get nearbyMarkersCount => _nearbyMarkers.length;
}
