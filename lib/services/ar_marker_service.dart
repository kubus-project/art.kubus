
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../providers/storage_provider.dart';
import 'ar_content_service.dart';

/// Dedicated service responsible for crafting AR-ready markers
/// for existing artworks. Handles model uploads and ensures the
/// backend receives the proper payload for the `art_markers` +
/// `ar_markers` tables without involving the generic map marker
/// creation flows.
class ARMarkerService {
  ARMarkerService._internal();
  static final ARMarkerService _instance = ARMarkerService._internal();
  factory ARMarkerService() => _instance;

  /// Uploads a 3D asset for the provided [artwork] and creates a new
  /// AR marker that is anchored to the artwork's geo position.
  ///
  /// Returns the persisted [ArtMarker] from the backend, or `null` if
  /// either the upload or save failed.
  Future<ArtMarker?> createMarkerForArtwork({
    required Artwork artwork,
    required Uint8List modelData,
    required String filename,
    double scale = 1.0,
    bool isPublic = true,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    String? createdBy,
    double activationRadiusMeters = 50.0,
    Map<String, double>? rotation,
  }) async {
    final LatLng location = artwork.position;
    if (location.latitude == 0 && location.longitude == 0) {
      debugPrint('ARMarkerService: Artwork ${artwork.id} has invalid coordinates');
      return null;
    }

    final uploadResults = await ARContentService.uploadContent(
      modelData,
      filename,
      metadata: {
        'artworkId': artwork.id,
        'artworkTitle': artwork.title,
        'artist': artwork.artist,
        if (metadata != null) ...metadata,
      },
      uploadToBoth: true,
    );

    final cid = uploadResults['cid'];
    final url = uploadResults['url'];
    if (cid == null && url == null) {
      debugPrint('ARMarkerService: Upload failed for $filename');
      return null;
    }

    final StorageProvider provider;
    if (cid != null && url != null) {
      provider = StorageProvider.hybrid;
    } else if (cid != null) {
      provider = StorageProvider.ipfs;
    } else {
      provider = StorageProvider.http;
    }

    final payloadMarker = ArtMarker(
      id: artwork.arMarkerId ?? 'pending_${artwork.id}',
      name: artwork.title,
      description: artwork.description,
      position: location,
      artworkId: artwork.id,
      type: ArtMarkerType.artwork,
      category: artwork.category,
      modelCID: cid,
      modelURL: url,
      storageProvider: provider,
      scale: scale,
      rotation: rotation ?? artwork.arRotation ?? const {'x': 0, 'y': 0, 'z': 0},
      enableAnimation: artwork.arEnableAnimation ?? false,
      animationName: artwork.arAnimationName,
      metadata: {
        'source': 'ar_marker_service',
        'subjectType': 'artwork',
        'artworkId': artwork.id,
        'artworkTitle': artwork.title,
        'artist': artwork.artist,
        'category': artwork.category,
        if (metadata != null) ...metadata,
      },
      tags: {
        ...artwork.tags,
        if (tags != null) ...tags,
        '#AR',
        '#art.kubus',
      }.toSet().toList(),
      createdAt: DateTime.now(),
      createdBy: createdBy ?? artwork.artist,
      viewCount: 0,
      interactionCount: 0,
      activationRadius: activationRadiusMeters,
      requiresProximity: true,
      isPublic: isPublic,
    );

    return ARContentService.saveARMarker(payloadMarker);
  }
}
