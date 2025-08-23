import 'package:latlong2/latlong.dart';

enum ArtworkRarity {
  common,
  rare,
  epic,
  legendary,
}

enum ArtworkStatus {
  undiscovered,
  discovered,
  favorite,
}

class Artwork {
  final String id;
  final String title;
  final String artist;
  final String description;
  final String? imageUrl;
  final LatLng position;
  final ArtworkRarity rarity;
  final ArtworkStatus status;
  final bool arEnabled;
  final int rewards; // KUB8 tokens
  final DateTime createdAt;
  final DateTime? discoveredAt;
  final String? discoveryUserId;
  
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
    required this.title,
    required this.artist,
    required this.description,
    this.imageUrl,
    required this.position,
    required this.rarity,
    this.status = ArtworkStatus.undiscovered,
    this.arEnabled = false,
    required this.rewards,
    required this.createdAt,
    this.discoveredAt,
    this.discoveryUserId,
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

  /// Check if artwork is discovered
  bool get isDiscovered => status != ArtworkStatus.undiscovered;

  /// Check if artwork is favorite
  bool get isFavorite => status == ArtworkStatus.favorite;

  /// Get rarity color
  static int getRarityColor(ArtworkRarity rarity) {
    switch (rarity) {
      case ArtworkRarity.common:
        return 0xFF9E9E9E; // Grey
      case ArtworkRarity.rare:
        return 0xFF2196F3; // Blue
      case ArtworkRarity.epic:
        return 0xFF9C27B0; // Purple
      case ArtworkRarity.legendary:
        return 0xFFFF9800; // Orange
    }
  }

  /// Get rarity multiplier for rewards
  static double getRarityMultiplier(ArtworkRarity rarity) {
    switch (rarity) {
      case ArtworkRarity.common:
        return 1.0;
      case ArtworkRarity.rare:
        return 1.5;
      case ArtworkRarity.epic:
        return 2.0;
      case ArtworkRarity.legendary:
        return 3.0;
    }
  }

  /// Calculate actual rewards with rarity multiplier
  int get actualRewards => (rewards * getRarityMultiplier(rarity)).round();

  /// Convert to Map for storage/API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'rarity': rarity.name,
      'status': status.name,
      'arEnabled': arEnabled,
      'rewards': rewards,
      'createdAt': createdAt.toIso8601String(),
      'discoveredAt': discoveredAt?.toIso8601String(),
      'discoveryUserId': discoveryUserId,
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
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      position: LatLng(
        map['latitude']?.toDouble() ?? 0.0,
        map['longitude']?.toDouble() ?? 0.0,
      ),
      rarity: ArtworkRarity.values.firstWhere(
        (e) => e.name == map['rarity'],
        orElse: () => ArtworkRarity.common,
      ),
      status: ArtworkStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ArtworkStatus.undiscovered,
      ),
      arEnabled: map['arEnabled'] ?? false,
      rewards: map['rewards']?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      discoveredAt: map['discoveredAt'] != null 
          ? DateTime.tryParse(map['discoveredAt']) 
          : null,
      discoveryUserId: map['discoveryUserId'],
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
    String? title,
    String? artist,
    String? description,
    String? imageUrl,
    LatLng? position,
    ArtworkRarity? rarity,
    ArtworkStatus? status,
    bool? arEnabled,
    int? rewards,
    DateTime? createdAt,
    DateTime? discoveredAt,
    String? discoveryUserId,
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
      title: title ?? this.title,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      position: position ?? this.position,
      rarity: rarity ?? this.rarity,
      status: status ?? this.status,
      arEnabled: arEnabled ?? this.arEnabled,
      rewards: rewards ?? this.rewards,
      createdAt: createdAt ?? this.createdAt,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      discoveryUserId: discoveryUserId ?? this.discoveryUserId,
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
    return 'Artwork(id: $id, title: $title, artist: $artist, rarity: $rarity)';
  }
}
