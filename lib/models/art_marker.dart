import 'package:latlong2/latlong.dart';

import '../providers/storage_provider.dart';

/// High-level category for an art marker shown on the map
enum ArtMarkerType {
  artwork,
  institution,
  event,
  residency,
  drop,
  experience,
  other,
}

/// Signal tier helps the UI decide how vivid the cube should render
enum ArtMarkerSignal {
  subtle,
  active,
  featured,
  legendary,
}

/// Art marker that links physical locations to digital/AR content
class ArtMarker {
  final String id;
  final String name;
  final String description;
  final LatLng position;
  final String? artworkId; // Reference to Artwork when applicable
  final ArtMarkerType type;
  final String category;

  // AR Content references
  final String? modelCID; // IPFS CID for 3D model (if using IPFS)
  final String? modelURL; // HTTP URL for 3D model (if using HTTP)
  final StorageProvider storageProvider;

  // AR Configuration
  final double scale; // Model scale (1.0 = original size)
  final Map<String, double> rotation; // {x, y, z} rotation in degrees
  final bool enableAnimation;
  final String? animationName;
  final bool enablePhysics;
  final bool enableInteraction; // Allow user to manipulate object

  // Metadata
  final Map<String, dynamic>? metadata;
  final List<String> tags;
  final DateTime createdAt;
  final String createdBy;
  final int viewCount;
  final int interactionCount;

  // Discovery settings
  final double activationRadius; // Meters from marker to activate AR
  final bool requiresProximity; // Must be near to activate
  final bool isPublic; // Visible to all users

  const ArtMarker({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.type,
    this.artworkId,
    this.category = 'General',
    this.modelCID,
    this.modelURL,
    this.storageProvider = StorageProvider.hybrid,
    this.scale = 1.0,
    this.rotation = const {'x': 0, 'y': 0, 'z': 0},
    this.enableAnimation = false,
    this.animationName,
    this.enablePhysics = false,
    this.enableInteraction = true,
    this.metadata,
    this.tags = const [],
    required this.createdAt,
    required this.createdBy,
    this.viewCount = 0,
    this.interactionCount = 0,
    this.activationRadius = 50.0,
    this.requiresProximity = true,
    this.isPublic = true,
  });

  /// Convenience getter for map visuals
  ArtMarkerSignal get signalTier {
    final explicitTier = metadata?["signalTier"];
    if (explicitTier is String) {
      final normalized = explicitTier.toLowerCase();
      if (normalized == 'legendary') return ArtMarkerSignal.legendary;
      if (normalized == 'featured') return ArtMarkerSignal.featured;
      if (normalized == 'active') return ArtMarkerSignal.active;
      if (normalized == 'subtle') return ArtMarkerSignal.subtle;
    }

    final score = _popularityScore;
    if (score >= 75) return ArtMarkerSignal.legendary;
    if (score >= 45) return ArtMarkerSignal.featured;
    if (score >= 20) return ArtMarkerSignal.active;
    return ArtMarkerSignal.subtle;
  }

  double get _popularityScore {
    final metaScoreRaw = metadata?["popularityScore"];
    if (metaScoreRaw is num) return metaScoreRaw.toDouble();
    final views = viewCount.toDouble();
    final interactions = interactionCount.toDouble();
    final boost = metadata?["boost"] is num ? (metadata?["boost"] as num).toDouble() : 0;
    return (views * 0.35) + (interactions * 0.65) + boost;
  }

  /// Get the appropriate content URL based on storage provider
  String? getContentURL({String ipfsGateway = 'https://ipfs.io/ipfs/'}) {
    if (storageProvider == StorageProvider.ipfs) {
      return modelCID != null ? '$ipfsGateway$modelCID' : null;
    }
    if (storageProvider == StorageProvider.http) {
      return modelURL;
    }
    // Hybrid: Prefer IPFS with HTTP fallback
    if (modelCID != null) {
      return '$ipfsGateway$modelCID';
    }
    return modelURL;
  }

  /// Get fallback URL if primary fails
  String? getFallbackURL({String ipfsGateway = 'https://ipfs.io/ipfs/'}) {
    if (storageProvider == StorageProvider.hybrid) {
      // If we tried IPFS first, fallback to HTTP
      if (modelCID != null && modelURL != null) {
        return modelURL;
      }
    }
    return null;
  }

  /// Check if marker is active at given position
  bool isActiveAt(LatLng currentPosition) {
    if (!requiresProximity) return true;

    const distance = Distance();
    final distanceMeters = distance.as(
      LengthUnit.Meter,
      currentPosition,
      position,
    );

    return distanceMeters <= activationRadius;
  }

  /// Get distance from current position (in meters)
  double getDistanceFrom(LatLng currentPosition) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, currentPosition, position);
  }

  /// Convert to Map for storage/API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'artworkId': artworkId,
      'markerType': type.name,
      'type': type.name,
      'modelCID': modelCID,
      'modelURL': modelURL,
      'storageProvider': storageProvider.name,
      'scale': scale,
      'rotation': rotation,
      'enableAnimation': enableAnimation,
      'animationName': animationName,
      'enablePhysics': enablePhysics,
      'enableInteraction': enableInteraction,
      'metadata': metadata,
      'tags': tags,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'viewCount': viewCount,
      'interactionCount': interactionCount,
      'activationRadius': activationRadius,
      'requiresProximity': requiresProximity,
      'isPublic': isPublic,
    };
  }

  /// Create from Map (from storage/API)
  factory ArtMarker.fromMap(Map<String, dynamic> map) {
    final markerType = _parseMarkerType(map['markerType'] ?? map['type'] ?? map['category']);
    return ArtMarker(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      position: LatLng(
        (map['latitude'] ?? map['lat'] ?? 0).toDouble(),
        (map['longitude'] ?? map['lng'] ?? 0).toDouble(),
      ),
      artworkId: map['artworkId']?.toString(),
      type: markerType,
      category: map['category']?.toString() ?? 'General',
      modelCID: map['modelCID']?.toString(),
      modelURL: map['modelURL']?.toString(),
      storageProvider: StorageProvider.values.firstWhere(
        (e) => e.name == map['storageProvider'],
        orElse: () => StorageProvider.hybrid,
      ),
      scale: (map['scale'] ?? 1.0).toDouble(),
      rotation: Map<String, double>.from(map['rotation'] ?? {'x': 0, 'y': 0, 'z': 0}),
      enableAnimation: map['enableAnimation'] == true,
      animationName: map['animationName']?.toString(),
      enablePhysics: map['enablePhysics'] == true,
      enableInteraction: map['enableInteraction'] != false,
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['metadata'])
          : map['metadata'] is Map
              ? Map<String, dynamic>.from(map['metadata'] as Map)
              : null,
      tags: List<String>.from(map['tags'] ?? const []),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      createdBy: map['createdBy']?.toString() ?? 'system',
      viewCount: (map['viewCount'] ?? 0).toInt(),
      interactionCount: (map['interactionCount'] ?? 0).toInt(),
      activationRadius: (map['activationRadius'] ?? 50.0).toDouble(),
      requiresProximity: map['requiresProximity'] != false,
      isPublic: map['isPublic'] != false,
    );
  }

  /// Create a copy with updated fields
  ArtMarker copyWith({
    String? id,
    String? name,
    String? description,
    LatLng? position,
    String? artworkId,
    ArtMarkerType? type,
    String? category,
    String? modelCID,
    String? modelURL,
    StorageProvider? storageProvider,
    double? scale,
    Map<String, double>? rotation,
    bool? enableAnimation,
    String? animationName,
    bool? enablePhysics,
    bool? enableInteraction,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    DateTime? createdAt,
    String? createdBy,
    int? viewCount,
    int? interactionCount,
    double? activationRadius,
    bool? requiresProximity,
    bool? isPublic,
  }) {
    return ArtMarker(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      position: position ?? this.position,
      artworkId: artworkId ?? this.artworkId,
      type: type ?? this.type,
      category: category ?? this.category,
      modelCID: modelCID ?? this.modelCID,
      modelURL: modelURL ?? this.modelURL,
      storageProvider: storageProvider ?? this.storageProvider,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      enableAnimation: enableAnimation ?? this.enableAnimation,
      animationName: animationName ?? this.animationName,
      enablePhysics: enablePhysics ?? this.enablePhysics,
      enableInteraction: enableInteraction ?? this.enableInteraction,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      viewCount: viewCount ?? this.viewCount,
      interactionCount: interactionCount ?? this.interactionCount,
      activationRadius: activationRadius ?? this.activationRadius,
      requiresProximity: requiresProximity ?? this.requiresProximity,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArtMarker && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ArtMarker(id: $id, type: ${type.name}, name: $name)';
  }

  static ArtMarkerType _parseMarkerType(dynamic raw) {
    final value = raw?.toString().toLowerCase() ?? '';
    if (value.contains('institution') || value.contains('museum') || value.contains('gallery')) {
      return ArtMarkerType.institution;
    }
    if (value.contains('event')) {
      return ArtMarkerType.event;
    }
    if (value.contains('residency')) {
      return ArtMarkerType.residency;
    }
    if (value.contains('drop') || value.contains('airdrop')) {
      return ArtMarkerType.drop;
    }
    if (value.contains('experience') || value.contains('ar')) {
      return ArtMarkerType.experience;
    }
    if (value.contains('artwork') || value.contains('art') || value.isEmpty) {
      return ArtMarkerType.artwork;
    }
    return ArtMarkerType.other;
  }
}
