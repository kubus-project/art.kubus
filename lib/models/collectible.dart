import 'artwork.dart';

enum CollectibleType {
  nft,
  poap, // Proof of Attendance Protocol
  achievement,
  limitedEdition,
}

enum CollectibleRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  mythic,
}

enum CollectibleStatus {
  minted,
  listed,
  sold,
  transferred,
  burned,
}

class CollectibleSeries {
  final String id;
  final String name;
  final String description;
  final String artworkId; // Links to the original artwork
  final String creatorAddress;
  final int totalSupply;
  final int mintedCount;
  final CollectibleRarity rarity;
  final CollectibleType type;
  final double mintPrice; // In KUB8 tokens
  final String? imageUrl;
  final String? animationUrl; // For AR/3D content
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool isActive;
  final bool requiresARInteraction; // Must interact with AR to mint
  final double? royaltyPercentage;

  const CollectibleSeries({
    required this.id,
    required this.name,
    required this.description,
    required this.artworkId,
    required this.creatorAddress,
    required this.totalSupply,
    this.mintedCount = 0,
    required this.rarity,
    required this.type,
    required this.mintPrice,
    this.imageUrl,
    this.animationUrl,
    this.metadata = const {},
    required this.createdAt,
    this.isActive = true,
    this.requiresARInteraction = false,
    this.royaltyPercentage,
  });

  bool get isSoldOut => mintedCount >= totalSupply;
  bool get isLimitedEdition => totalSupply <= 100;
  double get mintProgress => mintedCount / totalSupply;

  CollectibleSeries copyWith({
    String? id,
    String? name,
    String? description,
    String? artworkId,
    String? creatorAddress,
    int? totalSupply,
    int? mintedCount,
    CollectibleRarity? rarity,
    CollectibleType? type,
    double? mintPrice,
    String? imageUrl,
    String? animationUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    bool? isActive,
    bool? requiresARInteraction,
    double? royaltyPercentage,
  }) {
    return CollectibleSeries(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      artworkId: artworkId ?? this.artworkId,
      creatorAddress: creatorAddress ?? this.creatorAddress,
      totalSupply: totalSupply ?? this.totalSupply,
      mintedCount: mintedCount ?? this.mintedCount,
      rarity: rarity ?? this.rarity,
      type: type ?? this.type,
      mintPrice: mintPrice ?? this.mintPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      animationUrl: animationUrl ?? this.animationUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      requiresARInteraction: requiresARInteraction ?? this.requiresARInteraction,
      royaltyPercentage: royaltyPercentage ?? this.royaltyPercentage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'artworkId': artworkId,
      'creatorAddress': creatorAddress,
      'totalSupply': totalSupply,
      'mintedCount': mintedCount,
      'rarity': rarity.name,
      'type': type.name,
      'mintPrice': mintPrice,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (animationUrl != null) 'animationUrl': animationUrl,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'requiresARInteraction': requiresARInteraction,
      if (royaltyPercentage != null) 'royaltyPercentage': royaltyPercentage,
    };
  }

  factory CollectibleSeries.fromJson(Map<String, dynamic> json) {
    CollectibleRarity parseRarity(dynamic value) {
      final name = value?.toString();
      if (name == null) return CollectibleRarity.common;
      return CollectibleRarity.values.firstWhere(
        (e) => e.name == name,
        orElse: () => CollectibleRarity.common,
      );
    }

    CollectibleType parseType(dynamic value) {
      final name = value?.toString();
      if (name == null) return CollectibleType.nft;
      return CollectibleType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => CollectibleType.nft,
      );
    }

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    double parseDouble(dynamic value, {double fallback = 0}) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(metadataRaw)
        : <String, dynamic>{};

    return CollectibleSeries(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      artworkId: json['artworkId']?.toString() ?? json['artwork_id']?.toString() ?? '',
      creatorAddress: json['creatorAddress']?.toString() ?? json['creator_address']?.toString() ?? '',
      totalSupply: parseInt(json['totalSupply'] ?? json['total_supply']),
      mintedCount: parseInt(json['mintedCount'] ?? json['minted_count']),
      rarity: parseRarity(json['rarity']),
      type: parseType(json['type']),
      mintPrice: parseDouble(json['mintPrice'] ?? json['mint_price']),
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
      animationUrl: json['animationUrl']?.toString() ?? json['animation_url']?.toString(),
      metadata: metadata,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      isActive: json['isActive'] == null ? true : json['isActive'] == true,
      requiresARInteraction: json['requiresARInteraction'] == true || json['requires_ar_interaction'] == true,
      royaltyPercentage: parseNullableDouble(json['royaltyPercentage'] ?? json['royalty_percentage']),
    );
  }
}

class Collectible {
  final String id;
  final String seriesId;
  final String tokenId;
  final String ownerAddress;
  final CollectibleStatus status;
  final DateTime mintedAt;
  final double? lastSalePrice;
  final DateTime? lastSaleAt;
  final String? currentListingPrice;
  final DateTime? listedAt;
  final Map<String, dynamic> properties; // Unique traits for this specific NFT
  final String? transactionHash;
  final bool isAuthentic;
  final DateTime? lastTransferAt;

  const Collectible({
    required this.id,
    required this.seriesId,
    required this.tokenId,
    required this.ownerAddress,
    required this.status,
    required this.mintedAt,
    this.lastSalePrice,
    this.lastSaleAt,
    this.currentListingPrice,
    this.listedAt,
    this.properties = const {},
    this.transactionHash,
    this.isAuthentic = true,
    this.lastTransferAt,
  });

  bool get isForSale => status == CollectibleStatus.listed && currentListingPrice != null;
  bool get isOwnedByUser => status == CollectibleStatus.minted || status == CollectibleStatus.listed;

  Collectible copyWith({
    String? id,
    String? seriesId,
    String? tokenId,
    String? ownerAddress,
    CollectibleStatus? status,
    DateTime? mintedAt,
    double? lastSalePrice,
    DateTime? lastSaleAt,
    String? currentListingPrice,
    DateTime? listedAt,
    Map<String, dynamic>? properties,
    String? transactionHash,
    bool? isAuthentic,
    DateTime? lastTransferAt,
  }) {
    return Collectible(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      tokenId: tokenId ?? this.tokenId,
      ownerAddress: ownerAddress ?? this.ownerAddress,
      status: status ?? this.status,
      mintedAt: mintedAt ?? this.mintedAt,
      lastSalePrice: lastSalePrice ?? this.lastSalePrice,
      lastSaleAt: lastSaleAt ?? this.lastSaleAt,
      currentListingPrice: currentListingPrice ?? this.currentListingPrice,
      listedAt: listedAt ?? this.listedAt,
      properties: properties ?? this.properties,
      transactionHash: transactionHash ?? this.transactionHash,
      isAuthentic: isAuthentic ?? this.isAuthentic,
      lastTransferAt: lastTransferAt ?? this.lastTransferAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seriesId': seriesId,
      'tokenId': tokenId,
      'ownerAddress': ownerAddress,
      'status': status.name,
      'mintedAt': mintedAt.toIso8601String(),
      if (lastSalePrice != null) 'lastSalePrice': lastSalePrice,
      if (lastSaleAt != null) 'lastSaleAt': lastSaleAt!.toIso8601String(),
      if (currentListingPrice != null) 'currentListingPrice': currentListingPrice,
      if (listedAt != null) 'listedAt': listedAt!.toIso8601String(),
      'properties': properties,
      if (transactionHash != null) 'transactionHash': transactionHash,
      'isAuthentic': isAuthentic,
      if (lastTransferAt != null) 'lastTransferAt': lastTransferAt!.toIso8601String(),
    };
  }

  factory Collectible.fromJson(Map<String, dynamic> json) {
    CollectibleStatus parseStatus(dynamic value) {
      final name = value?.toString();
      if (name == null) return CollectibleStatus.minted;
      return CollectibleStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => CollectibleStatus.minted,
      );
    }

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final propertiesRaw = json['properties'];
    final properties = propertiesRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(propertiesRaw)
        : <String, dynamic>{};

    return Collectible(
      id: json['id']?.toString() ?? '',
      seriesId: json['seriesId']?.toString() ?? json['series_id']?.toString() ?? '',
      tokenId: json['tokenId']?.toString() ?? json['token_id']?.toString() ?? '',
      ownerAddress: json['ownerAddress']?.toString() ?? json['owner_address']?.toString() ?? '',
      status: parseStatus(json['status']),
      mintedAt: parseDate(json['mintedAt'] ?? json['minted_at']),
      lastSalePrice: parseNullableDouble(json['lastSalePrice'] ?? json['last_sale_price']),
      lastSaleAt: json['lastSaleAt'] == null && json['last_sale_at'] == null
          ? null
          : parseDate(json['lastSaleAt'] ?? json['last_sale_at']),
      currentListingPrice: json['currentListingPrice']?.toString() ?? json['current_listing_price']?.toString(),
      listedAt: json['listedAt'] == null && json['listed_at'] == null ? null : parseDate(json['listedAt'] ?? json['listed_at']),
      properties: properties,
      transactionHash: json['transactionHash']?.toString() ?? json['transaction_hash']?.toString(),
      isAuthentic: json['isAuthentic'] == null ? true : json['isAuthentic'] == true,
      lastTransferAt: json['lastTransferAt'] == null && json['last_transfer_at'] == null
          ? null
          : parseDate(json['lastTransferAt'] ?? json['last_transfer_at']),
    );
  }
}

// Helper class to combine artwork and collectible data
class ArtworkCollectible {
  final Artwork artwork;
  final CollectibleSeries? series;
  final List<Collectible> collectibles;

  const ArtworkCollectible({
    required this.artwork,
    this.series,
    this.collectibles = const [],
  });

  bool get hasNFTSeries => series != null;
  bool get canMintNFT => hasNFTSeries && !series!.isSoldOut && series!.isActive;
  bool get requiresARForMinting => series?.requiresARInteraction ?? false;
  int get totalMinted => series?.mintedCount ?? 0;
  int get availableToMint => (series?.totalSupply ?? 0) - totalMinted;
}
