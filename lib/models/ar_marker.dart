import 'package:latlong2/latlong.dart';

/// Storage provider type for AR content
enum StorageProvider {
  ipfs,      // Decentralized IPFS storage
  http,      // Traditional HTTP/HTTPS hosting
  hybrid,    // IPFS with HTTP gateway fallback
}

/// AR marker that links physical locations to digital AR content
class ARMarker {
  final String id;
  final String name;
  final String description;
  final LatLng position;
  final String artworkId;  // Reference to Artwork
  
  // AR Content references
  final String? modelCID;        // IPFS CID for 3D model (if using IPFS)
  final String? modelURL;        // HTTP URL for 3D model (if using HTTP)
  final StorageProvider storageProvider;
  
  // AR Configuration
  final double scale;            // Model scale (1.0 = original size)
  final Map<String, double> rotation; // {x, y, z} rotation in degrees
  final bool enableAnimation;
  final String? animationName;
  final bool enablePhysics;
  final bool enableInteraction;  // Allow user to manipulate object
  
  // Metadata
  final Map<String, dynamic>? metadata;
  final List<String> tags;
  final String category;
  final DateTime createdAt;
  final String createdBy;
  final int viewCount;
  final int interactionCount;
  
  // Discovery settings
  final double activationRadius;  // Meters from marker to activate AR
  final bool requiresProximity;   // Must be near to activate
  final bool isPublic;           // Visible to all users
  
  const ARMarker({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.artworkId,
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
    this.category = 'General',
    required this.createdAt,
    required this.createdBy,
    this.viewCount = 0,
    this.interactionCount = 0,
    this.activationRadius = 50.0,
    this.requiresProximity = true,
    this.isPublic = true,
  });

  /// Get the appropriate content URL based on storage provider
  String? getContentURL({String ipfsGateway = 'https://ipfs.io/ipfs/'}) {
    switch (storageProvider) {
      case StorageProvider.ipfs:
        return modelCID != null ? '$ipfsGateway$modelCID' : null;
      case StorageProvider.http:
        return modelURL;
      case StorageProvider.hybrid:
        // Prefer IPFS with HTTP fallback
        if (modelCID != null) {
          return '$ipfsGateway$modelCID';
        }
        return modelURL;
    }
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
  factory ARMarker.fromMap(Map<String, dynamic> map) {
    return ARMarker(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      position: LatLng(
        map['latitude']?.toDouble() ?? 0.0,
        map['longitude']?.toDouble() ?? 0.0,
      ),
      artworkId: map['artworkId'] ?? '',
      modelCID: map['modelCID'],
      modelURL: map['modelURL'],
      storageProvider: StorageProvider.values.firstWhere(
        (e) => e.name == map['storageProvider'],
        orElse: () => StorageProvider.hybrid,
      ),
      scale: map['scale']?.toDouble() ?? 1.0,
      rotation: Map<String, double>.from(map['rotation'] ?? {'x': 0, 'y': 0, 'z': 0}),
      enableAnimation: map['enableAnimation'] ?? false,
      animationName: map['animationName'],
      enablePhysics: map['enablePhysics'] ?? false,
      enableInteraction: map['enableInteraction'] ?? true,
      metadata: map['metadata'],
      tags: List<String>.from(map['tags'] ?? []),
      category: map['category'] ?? 'General',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      viewCount: map['viewCount']?.toInt() ?? 0,
      interactionCount: map['interactionCount']?.toInt() ?? 0,
      activationRadius: map['activationRadius']?.toDouble() ?? 50.0,
      requiresProximity: map['requiresProximity'] ?? true,
      isPublic: map['isPublic'] ?? true,
    );
  }

  /// Create a copy with updated fields
  ARMarker copyWith({
    String? id,
    String? name,
    String? description,
    LatLng? position,
    String? artworkId,
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
    String? category,
    DateTime? createdAt,
    String? createdBy,
    int? viewCount,
    int? interactionCount,
    double? activationRadius,
    bool? requiresProximity,
    bool? isPublic,
  }) {
    return ARMarker(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      position: position ?? this.position,
      artworkId: artworkId ?? this.artworkId,
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
      category: category ?? this.category,
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
    return other is ARMarker && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ARMarker(id: $id, name: $name, storage: ${storageProvider.name})';
  }
}
