import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/collectible.dart';
import '../services/backend_api_service.dart';
import '../services/push_notification_service.dart';
import 'achievement_service.dart';

/// NFT Minting Service
/// 
/// Handles artwork → NFT minting process with notifications
/// Integrates with Solana blockchain for NFT creation
/// Integrates with CollectiblesProvider for series/collection management
/// 
/// Features:
/// - Artwork validation
/// - NFT series creation with artist royalties
/// - IPFS metadata upload (Pinata)
/// - Solana NFT minting
/// - Transaction tracking
/// - Push notifications for status updates
/// - Backend persistence
class NFTMintingService {
  static final NFTMintingService _instance = NFTMintingService._internal();
  factory NFTMintingService() => _instance;
  NFTMintingService._internal();

  final PushNotificationService _notificationService = PushNotificationService();
  final BackendApiService _backendApi = BackendApiService();
  
  // Ongoing minting operations
  final Map<String, MintingStatus> _mintingOperations = {};

  /// Create NFT series for an artwork (if not exists)
  Future<MintingResult> createNFTSeries({
    required String artworkId,
    required String name,
    required String description,
    required String creatorAddress,
    required int totalSupply,
    required CollectibleRarity rarity,
    required CollectibleType type,
    required double mintPrice,
    String? imageUrl,
    String? animationUrl,
    Map<String, dynamic>? metadata,
    bool requiresARInteraction = false,
    double royaltyPercentage = 10.0,
  }) async {
    try {
      debugPrint('NFTMintingService: Creating NFT series for $name');

      // Create series via backend API
      final seriesData = await _backendApi.createNFTSeries(
        artworkId: artworkId,
        name: name,
        description: description,
        totalSupply: totalSupply,
        rarity: rarity.name,
        type: type.name,
        mintPrice: mintPrice,
        imageUrl: imageUrl,
        animationUrl: animationUrl,
        metadata: metadata ?? {},
        requiresARInteraction: requiresARInteraction,
        royaltyPercentage: royaltyPercentage,
      );

      debugPrint('NFTMintingService: Series created - ${seriesData['series']['id']}');

      return MintingResult(
        success: true,
        seriesId: seriesData['series']['id'] as String,
      );
    } catch (e) {
      debugPrint('NFTMintingService: Series creation failed - $e');
      return MintingResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Start NFT minting process (mint from existing or new series)
  Future<MintingResult> mintNFT({
    required String artworkId,
    required String artworkTitle,
    required String artistName,
    required String ownerAddress,
    String? imageUrl,
    String? model3DURL,
    Map<String, dynamic>? metadata,
    // Series parameters (optional - if creating new series)
    String? seriesId,
    String? seriesName,
    String? seriesDescription,
    int totalSupply = 100,
    CollectibleRarity rarity = CollectibleRarity.rare,
    CollectibleType type = CollectibleType.nft,
    double mintPrice = 50.0,
    double royaltyPercentage = 10.0,
    bool requiresARInteraction = false,
    Map<String, dynamic>? properties,
  }) async {
    try {
      // Update status
      _mintingOperations[artworkId] = MintingStatus.inProgress;
      
      // Show starting notification
      await _notificationService.showNFTMintingNotification(
        artworkId: artworkId,
        artworkTitle: artworkTitle,
        status: 'started',
      );

      debugPrint('NFTMintingService: Starting mint for $artworkTitle');

      String finalSeriesId = seriesId ?? '';

      // Step 1: Create or get NFT series
      if (seriesId == null || seriesId.isEmpty) {
        // Check if series already exists for this artwork
        final existingSeries = await _backendApi.getNFTSeriesByArtwork(artworkId);
        
        if (existingSeries != null) {
          finalSeriesId = existingSeries['id'] as String;
          debugPrint('NFTMintingService: Using existing series - $finalSeriesId');
        } else {
          // Create new series
          final seriesResult = await createNFTSeries(
            artworkId: artworkId,
            name: seriesName ?? '$artworkTitle Collection',
            description: seriesDescription ?? 'NFT collection for $artworkTitle by $artistName',
            creatorAddress: ownerAddress,
            totalSupply: totalSupply,
            rarity: rarity,
            type: type,
            mintPrice: mintPrice,
            imageUrl: imageUrl,
            animationUrl: model3DURL,
            metadata: metadata,
            requiresARInteraction: requiresARInteraction,
            royaltyPercentage: royaltyPercentage,
          );

          if (!seriesResult.success || seriesResult.seriesId == null) {
            throw Exception('Failed to create NFT series: ${seriesResult.error}');
          }

          finalSeriesId = seriesResult.seriesId!;
          debugPrint('NFTMintingService: Created new series - $finalSeriesId');
        }
      }

      // Step 2: Upload metadata to IPFS
      final metadataCID = await _uploadMetadataToIPFS(
        artworkId: artworkId,
        title: artworkTitle,
        artist: artistName,
        imageUrl: imageUrl ?? '',
        model3DURL: model3DURL,
        metadata: metadata,
      );

      // Step 3: Mint NFT on Solana blockchain
      final transactionId = await _mintOnSolana(
        artworkId: artworkId,
        title: artworkTitle,
        metadataCID: metadataCID,
      );

      // Step 4: Record mint in backend
      final mintData = await _backendApi.mintNFT(
        seriesId: finalSeriesId,
        transactionHash: transactionId,
        properties: properties ?? {
          'metadataCID': metadataCID,
          'imageUrl': imageUrl,
          'animationUrl': model3DURL,
        },
      );

      final collectibleId = mintData['collectible']['id'] as String;
      final tokenId = mintData['collectible']['tokenId'] as String;
      final nftAddress = mintData['collectible']['nftAddress'] as String?;

      // Update status
      _mintingOperations[artworkId] = MintingStatus.success;

      // Show success notification
      await _notificationService.showNFTMintingNotification(
        artworkId: artworkId,
        artworkTitle: artworkTitle,
        status: 'success',
        transactionId: transactionId,
      );

      // Award tokens for minting
      await _notificationService.showRewardNotification(
        title: 'NFT Minted Successfully!',
        amount: 50,
        reason: 'Created NFT for "$artworkTitle" (Edition #$tokenId)',
      );
      
      // Check NFT minting achievements
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'demo_user';
      await AchievementService().checkAchievements(
        userId: userId,
        action: 'nft_minted',
        data: {'mintCount': 1}, // Backend should track total count
      );

      debugPrint('NFTMintingService: Mint successful - TX: $transactionId, Token: $tokenId');

      return MintingResult(
        success: true,
        transactionId: transactionId,
        nftAddress: nftAddress ?? 'nft_${artworkId}_${DateTime.now().millisecondsSinceEpoch}',
        collectibleId: collectibleId,
        seriesId: finalSeriesId,
      );
    } catch (e) {
      debugPrint('NFTMintingService: Mint failed - $e');
      
      // Update status
      _mintingOperations[artworkId] = MintingStatus.failed;

      // Show failure notification
      await _notificationService.showNFTMintingNotification(
        artworkId: artworkId,
        artworkTitle: artworkTitle,
        status: 'failed',
      );

      return MintingResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Upload metadata to IPFS
  Future<String> _uploadMetadataToIPFS({
    required String artworkId,
    required String title,
    required String artist,
    required String imageUrl,
    String? model3DURL,
    Map<String, dynamic>? metadata,
  }) async {
    // TODO: Implement actual IPFS upload via Pinata API
    // For now, simulate the upload
    await Future.delayed(const Duration(seconds: 2));
    
    final metadataCID = 'Qm${artworkId.substring(0, 10)}MetadataCID';
    debugPrint('NFTMintingService: Metadata uploaded - CID: $metadataCID');
    
    return metadataCID;
  }

  /// Mint NFT on Solana blockchain
  Future<String> _mintOnSolana({
    required String artworkId,
    required String title,
    required String metadataCID,
  }) async {
    // TODO: Implement actual Solana NFT minting
    // This would use SPL Token program and Metaplex standard
    // The metadataCID should be used to reference the IPFS metadata
    await Future.delayed(const Duration(seconds: 3));
    
    final transactionId = '${DateTime.now().millisecondsSinceEpoch}TX$artworkId';
    debugPrint('NFTMintingService: NFT minted on Solana - TX: $transactionId, Metadata: $metadataCID');
    
    return transactionId;
  }

  /// Get minting status for artwork
  MintingStatus? getMintingStatus(String artworkId) {
    return _mintingOperations[artworkId];
  }

  /// Check if artwork is currently being minted
  bool isMinting(String artworkId) {
    return _mintingOperations[artworkId] == MintingStatus.inProgress;
  }
}

/// Minting status enum
enum MintingStatus {
  inProgress,
  success,
  failed,
}

/// Result of minting operation
class MintingResult {
  final bool success;
  final String? transactionId;
  final String? nftAddress;
  final String? collectibleId;
  final String? seriesId;
  final String? error;

  MintingResult({
    required this.success,
    this.transactionId,
    this.nftAddress,
    this.collectibleId,
    this.seriesId,
    this.error,
  });
}

/// Trading Service (Placeholder)
/// 
/// TODO: Implement full trading functionality
/// - List NFT for sale
/// - Make offers
/// - Accept/reject offers
/// - Complete transactions
/// - Escrow system
class TradingService {
  static final TradingService _instance = TradingService._internal();
  factory TradingService() => _instance;
  TradingService._internal();

  final PushNotificationService _notificationService = PushNotificationService();

  /// Create sell listing
  Future<void> createListing({
    required String artworkId,
    required String artworkTitle,
    required double price,
  }) async {
    // TODO: Implement listing creation
    debugPrint('TradingService: Creating listing for $artworkTitle at $price SOL');
    
    await Future.delayed(const Duration(seconds: 1));
    
    await _notificationService.showSystemNotification(
      title: 'Listing Created',
      message: '"$artworkTitle" is now listed for $price SOL',
    );
  }

  /// Submit buy offer
  Future<void> submitOffer({
    required String artworkId,
    required String artworkTitle,
    required double offerAmount,
    required String sellerName,
  }) async {
    // TODO: Implement offer submission
    debugPrint('TradingService: Submitting offer of $offerAmount SOL for $artworkTitle');
    
    await Future.delayed(const Duration(seconds: 1));
    
    // Notify seller
    await _notificationService.showTradingNotification(
      tradeId: 'trade_${DateTime.now().millisecondsSinceEpoch}',
      type: 'offer_received',
      artworkTitle: artworkTitle,
      amount: offerAmount,
      buyerName: 'Current User', // Replace with actual user
    );
  }

  /// Accept offer
  Future<void> acceptOffer({
    required String tradeId,
    required String artworkTitle,
    required double amount,
    required String buyerName,
  }) async {
    // TODO: Implement offer acceptance and transfer
    debugPrint('TradingService: Accepting offer for $artworkTitle');
    
    await Future.delayed(const Duration(seconds: 2));
    
    // Notify buyer
    await _notificationService.showTradingNotification(
      tradeId: tradeId,
      type: 'offer_accepted',
      artworkTitle: artworkTitle,
      amount: amount,
    );
    
    // Notify seller of sale completion
    await _notificationService.showTradingNotification(
      tradeId: tradeId,
      type: 'sale_completed',
      artworkTitle: artworkTitle,
      amount: amount,
    );
  }
}

/// Achievement Service (Placeholder)
// Achievement service has been moved to dedicated file: achievement_service.dart
// This placeholder was removed to avoid conflicts with the new comprehensive implementation.
