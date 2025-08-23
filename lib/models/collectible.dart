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
