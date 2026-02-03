import 'package:latlong2/latlong.dart';

enum ArtworkStatus {
  undiscovered,
  discovered,
  favorite,
}

enum ArtworkPoapMode {
  none,
  existingPoap,
  kubusPoap,
}

extension ArtworkPoapModeApi on ArtworkPoapMode {
  String get apiValue {
    switch (this) {
      case ArtworkPoapMode.none:
        return 'NONE';
      case ArtworkPoapMode.existingPoap:
        return 'EXISTING_POAP';
      case ArtworkPoapMode.kubusPoap:
        return 'KUBUS_POAP';
    }
  }

  static ArtworkPoapMode fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    switch (normalized) {
      case 'KUBUS_POAP':
        return ArtworkPoapMode.kubusPoap;
      case 'EXISTING_POAP':
        return ArtworkPoapMode.existingPoap;
      case 'NONE':
      case '':
      default:
        return ArtworkPoapMode.none;
    }
  }
}

enum ArtworkArStatus {
  none,
  draft,
  ready,
  error,
}

extension ArtworkArStatusApi on ArtworkArStatus {
  String get apiValue {
    switch (this) {
      case ArtworkArStatus.none:
        return 'NONE';
      case ArtworkArStatus.draft:
        return 'DRAFT';
      case ArtworkArStatus.ready:
        return 'READY';
      case ArtworkArStatus.error:
        return 'ERROR';
    }
  }

  static ArtworkArStatus fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    switch (normalized) {
      case 'READY':
        return ArtworkArStatus.ready;
      case 'DRAFT':
        return ArtworkArStatus.draft;
      case 'ERROR':
        return ArtworkArStatus.error;
      case 'NONE':
      case '':
      default:
        return ArtworkArStatus.none;
    }
  }
}

class Artwork {
  final String id;
  final String? walletAddress;
  final String title;
  final String artist;
  final String description;
  final String? imageUrl;
  final List<String> galleryUrls;
  final List<Map<String, dynamic>> galleryMeta;
  final LatLng position;
  final ArtworkStatus status;
  final bool isPublic;
  final bool isActive;
  final bool isForSale;
  final double? price;
  final String? currency;
  final bool arEnabled;
  final int rewards; // KUB8 tokens
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? discoveredAt;
  final String? discoveryUserId;
  
  // AR-specific fields
  final String? arMarkerId;      // Reference to ArtMarker
  final String? arConfigId;      // Reference to AR config (printable marker / setup)
  final ArtworkArStatus arStatus;
  final String? model3DCID;      // IPFS CID for 3D model
  final String? model3DURL;      // HTTP URL for 3D model
  final double? arScale;         // Scale for AR display
  final Map<String, double>? arRotation; // AR rotation {x, y, z}
  final bool? arEnableAnimation;
  final String? arAnimationName;

  // POAP (attendance) configuration
  final ArtworkPoapMode poapMode;
  final bool poapEnabled;
  final String? poapEventId;
  final String? poapClaimUrl;
  final DateTime? poapValidFrom;
  final DateTime? poapValidTo;
  final int? poapRewardAmount;
  
  // Social metrics
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int discoveryCount;
  final bool isLikedByCurrentUser;
  final bool isFavoriteByCurrentUser;
  
  // Additional metadata
  final List<String> tags;
  final String category;
  final double? averageRating;
  final int ratingsCount;
  final Map<String, dynamic>? metadata;

  const Artwork({
    required this.id,
    this.walletAddress,
    required this.title,
    required this.artist,
    required this.description,
    this.imageUrl,
    this.galleryUrls = const [],
    this.galleryMeta = const [],
    required this.position,
    this.status = ArtworkStatus.undiscovered,
    this.isPublic = true,
    this.isActive = true,
    this.isForSale = false,
    this.price,
    this.currency,
    this.arEnabled = false,
    required this.rewards,
    required this.createdAt,
    this.updatedAt,
    this.discoveredAt,
    this.discoveryUserId,
    this.arMarkerId,
    this.arConfigId,
    this.arStatus = ArtworkArStatus.none,
    this.model3DCID,
    this.model3DURL,
    this.arScale,
    this.arRotation,
    this.arEnableAnimation,
    this.arAnimationName,
    this.poapMode = ArtworkPoapMode.none,
    this.poapEnabled = false,
    this.poapEventId,
    this.poapClaimUrl,
    this.poapValidFrom,
    this.poapValidTo,
    this.poapRewardAmount,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.discoveryCount = 0,
    this.isLikedByCurrentUser = false,
    this.isFavoriteByCurrentUser = false,
    this.tags = const [],
    this.category = 'General',
    this.averageRating,
    this.ratingsCount = 0,
    this.metadata,
  });

  /// Get distance from current position (in meters)
  double getDistanceFrom(LatLng currentPosition) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, currentPosition, position);
  }

  /// Check if artwork is nearby (within specified meters)
  bool isNearby(LatLng currentPosition, {double maxDistanceMeters = 50}) {
    return getDistanceFrom(currentPosition) <= maxDistanceMeters;
  }

  /// Whether the artwork has a meaningful location (filters out null-island defaults).
  bool get hasValidLocation {
    final nearNullIsland =
        position.latitude.abs() < 0.0001 && position.longitude.abs() < 0.0001;
    return !nearNullIsland;
  }

  /// Check if artwork is discovered
  bool get isDiscovered => status != ArtworkStatus.undiscovered;

  /// Check if artwork is favorite
  bool get isFavorite => status == ArtworkStatus.favorite;

  /// Backward-compatible alias used by legacy UI/widgets.
  ///
  /// Prefer reading `rewards` directly.
  int get actualRewards => rewards;

  /// Convert to Map for storage/API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'walletAddress': walletAddress,
      'title': title,
      'artist': artist,
      'description': description,
      'imageUrl': imageUrl,
      'galleryUrls': galleryUrls,
      'galleryMeta': galleryMeta,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'status': status.name,
      'isPublic': isPublic,
      'isActive': isActive,
      'isForSale': isForSale,
      'price': price,
      'currency': currency,
      'arEnabled': arEnabled,
      'rewards': rewards,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'discoveredAt': discoveredAt?.toIso8601String(),
      'discoveryUserId': discoveryUserId,
      'arMarkerId': arMarkerId,
      'arConfigId': arConfigId,
      'arStatus': arStatus.apiValue,
      'model3DCID': model3DCID,
      'model3DURL': model3DURL,
      'arScale': arScale,
      'arRotation': arRotation,
      'arEnableAnimation': arEnableAnimation,
      'arAnimationName': arAnimationName,
      'poapMode': poapMode.apiValue,
      'poapEnabled': poapEnabled,
      'poapEventId': poapEventId,
      'poapClaimUrl': poapClaimUrl,
      'poapValidFrom': poapValidFrom?.toIso8601String(),
      'poapValidTo': poapValidTo?.toIso8601String(),
      'poapRewardAmount': poapRewardAmount,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'viewsCount': viewsCount,
      'discoveryCount': discoveryCount,
      'isLikedByCurrentUser': isLikedByCurrentUser,
      'isFavoriteByCurrentUser': isFavoriteByCurrentUser,
      'tags': tags,
      'category': category,
      'averageRating': averageRating,
      'ratingsCount': ratingsCount,
      'metadata': metadata,
    };
  }

  /// Create from Map (from storage/API)
  factory Artwork.fromMap(Map<String, dynamic> map) {
    return Artwork(
      id: map['id'] ?? '',
      walletAddress: map['walletAddress']?.toString() ?? map['wallet_address']?.toString(),
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      position: LatLng(
        map['latitude']?.toDouble() ?? 0.0,
        map['longitude']?.toDouble() ?? 0.0,
      ),
      status: ArtworkStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ArtworkStatus.undiscovered,
      ),
      isPublic: map['isPublic'] ?? map['is_public'] ?? true,
      isActive: map['isActive'] ?? map['is_active'] ?? true,
      isForSale: map['isForSale'] ?? map['is_for_sale'] ?? false,
      price: map['price'] is num ? (map['price'] as num).toDouble() : double.tryParse('${map['price'] ?? ''}'),
      currency: map['currency']?.toString(),
      arEnabled: map['arEnabled'] ?? false,
      rewards: map['rewards']?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
      discoveredAt: map['discoveredAt'] != null 
          ? DateTime.tryParse(map['discoveredAt']) 
          : null,
      discoveryUserId: map['discoveryUserId'],
      arMarkerId: map['arMarkerId'],
      arConfigId: map['arConfigId'],
      arStatus: ArtworkArStatusApi.fromApiValue(map['arStatus']?.toString()),
      model3DCID: map['model3DCID'],
      model3DURL: map['model3DURL'],
      arScale: map['arScale']?.toDouble(),
      arRotation: map['arRotation'] != null 
          ? Map<String, double>.from(map['arRotation'])
          : null,
      arEnableAnimation: map['arEnableAnimation'],
      arAnimationName: map['arAnimationName'],
      galleryUrls: List<String>.from(map['galleryUrls'] ?? []),
      galleryMeta: map['galleryMeta'] is List
          ? (map['galleryMeta'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
      poapMode: ArtworkPoapModeApi.fromApiValue(map['poapMode']?.toString()),
      poapEnabled: map['poapEnabled'] == true,
      poapEventId: map['poapEventId']?.toString(),
      poapClaimUrl: map['poapClaimUrl']?.toString(),
      poapValidFrom: map['poapValidFrom'] != null ? DateTime.tryParse(map['poapValidFrom'].toString()) : null,
      poapValidTo: map['poapValidTo'] != null ? DateTime.tryParse(map['poapValidTo'].toString()) : null,
      poapRewardAmount: map['poapRewardAmount'] is num
          ? (map['poapRewardAmount'] as num).toInt()
          : int.tryParse(map['poapRewardAmount']?.toString() ?? ''),
      likesCount: map['likesCount']?.toInt() ?? 0,
      commentsCount: map['commentsCount']?.toInt() ?? 0,
      viewsCount: map['viewsCount']?.toInt() ?? 0,
      discoveryCount: map['discoveryCount']?.toInt() ?? 0,
      isLikedByCurrentUser: map['isLikedByCurrentUser'] ?? false,
      isFavoriteByCurrentUser: map['isFavoriteByCurrentUser'] ?? false,
      tags: List<String>.from(map['tags'] ?? []),
      category: map['category'] ?? 'General',
      averageRating: map['averageRating']?.toDouble(),
      ratingsCount: map['ratingsCount']?.toInt() ?? 0,
      metadata: map['metadata'],
    );
  }

  /// Create a copy with updated fields
  Artwork copyWith({
    String? id,
    String? walletAddress,
    String? title,
    String? artist,
    String? description,
    String? imageUrl,
    List<String>? galleryUrls,
    List<Map<String, dynamic>>? galleryMeta,
    LatLng? position,
    ArtworkStatus? status,
    bool? isPublic,
    bool? isActive,
    bool? isForSale,
    double? price,
    String? currency,
    bool? arEnabled,
    int? rewards,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? discoveredAt,
    String? discoveryUserId,
    String? arMarkerId,
    String? arConfigId,
    ArtworkArStatus? arStatus,
    String? model3DCID,
    String? model3DURL,
    double? arScale,
    Map<String, double>? arRotation,
    bool? arEnableAnimation,
    String? arAnimationName,
    ArtworkPoapMode? poapMode,
    bool? poapEnabled,
    String? poapEventId,
    String? poapClaimUrl,
    DateTime? poapValidFrom,
    DateTime? poapValidTo,
    int? poapRewardAmount,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    int? discoveryCount,
    bool? isLikedByCurrentUser,
    bool? isFavoriteByCurrentUser,
    List<String>? tags,
    String? category,
    double? averageRating,
    int? ratingsCount,
    Map<String, dynamic>? metadata,
  }) {
    return Artwork(
      id: id ?? this.id,
      walletAddress: walletAddress ?? this.walletAddress,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      galleryMeta: galleryMeta ?? this.galleryMeta,
      position: position ?? this.position,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      isActive: isActive ?? this.isActive,
      isForSale: isForSale ?? this.isForSale,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      arEnabled: arEnabled ?? this.arEnabled,
      rewards: rewards ?? this.rewards,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      discoveryUserId: discoveryUserId ?? this.discoveryUserId,
      arMarkerId: arMarkerId ?? this.arMarkerId,
      arConfigId: arConfigId ?? this.arConfigId,
      arStatus: arStatus ?? this.arStatus,
      model3DCID: model3DCID ?? this.model3DCID,
      model3DURL: model3DURL ?? this.model3DURL,
      arScale: arScale ?? this.arScale,
      arRotation: arRotation ?? this.arRotation,
      arEnableAnimation: arEnableAnimation ?? this.arEnableAnimation,
      arAnimationName: arAnimationName ?? this.arAnimationName,
      poapMode: poapMode ?? this.poapMode,
      poapEnabled: poapEnabled ?? this.poapEnabled,
      poapEventId: poapEventId ?? this.poapEventId,
      poapClaimUrl: poapClaimUrl ?? this.poapClaimUrl,
      poapValidFrom: poapValidFrom ?? this.poapValidFrom,
      poapValidTo: poapValidTo ?? this.poapValidTo,
      poapRewardAmount: poapRewardAmount ?? this.poapRewardAmount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      discoveryCount: discoveryCount ?? this.discoveryCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isFavoriteByCurrentUser: isFavoriteByCurrentUser ?? this.isFavoriteByCurrentUser,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      averageRating: averageRating ?? this.averageRating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Artwork && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Artwork(id: $id, title: $title, artist: $artist)';
  }
}
