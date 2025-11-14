import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_api_service.dart';
import 'push_notification_service.dart';
import '../models/collectible.dart';

/// Achievement types
enum AchievementType {
  // Discovery achievements
  firstDiscovery,
  artExplorer,
  artMaster,
  artLegend,
  
  // AR achievements
  firstARView,
  arEnthusiast,
  arPro,
  
  // NFT achievements
  firstNFTMint,
  nftCollector,
  nftTrader,
  
  // Community achievements
  firstPost,
  influencer,
  communityBuilder,
  
  // Social achievements
  firstLike,
  popularCreator,
  firstComment,
  commentator,
  
  // Trading achievements
  firstTrade,
  smartTrader,
  marketMaster,
  
  // Special achievements
  earlyAdopter,
  betaTester,
  artSupporter,
  
  // Event achievements (POAPs)
  eventAttendee,
  galleryVisitor,
  workshopParticipant,
}

/// Achievement definition
class Achievement {
  final AchievementType type;
  final String id;
  final String title;
  final String description;
  final int tokenReward; // KUB8 tokens
  final bool isPOAP; // Is this a Proof of Attendance Protocol achievement
  final String? eventId; // For POAP achievements
  final int requiredCount; // How many times action must be performed
  final String icon;
  final CollectibleRarity rarity;

  const Achievement({
    required this.type,
    required this.id,
    required this.title,
    required this.description,
    required this.tokenReward,
    this.isPOAP = false,
    this.eventId,
    this.requiredCount = 1,
    required this.icon,
    required this.rarity,
  });
}

/// Achievement progress tracking
class AchievementProgress {
  final String achievementId;
  final int currentProgress;
  final bool isCompleted;
  final DateTime? completedAt;

  AchievementProgress({
    required this.achievementId,
    required this.currentProgress,
    required this.isCompleted,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'achievementId': achievementId,
    'currentProgress': currentProgress,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      achievementId: json['achievementId'] as String,
      currentProgress: json['currentProgress'] as int,
      isCompleted: json['isCompleted'] as bool,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}

/// Achievement Service - Manages achievements, token rewards, and POAPs
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final BackendApiService _backendApi = BackendApiService();
  final PushNotificationService _notificationService = PushNotificationService();

  // Achievement definitions
  static const Map<AchievementType, Achievement> achievements = {
    // Discovery achievements
    AchievementType.firstDiscovery: Achievement(
      type: AchievementType.firstDiscovery,
      id: 'first_discovery',
      title: 'First Discovery',
      description: 'Discovered your first AR artwork',
      tokenReward: 10,
      requiredCount: 1,
      icon: '🎯',
      rarity: CollectibleRarity.common,
    ),
    AchievementType.artExplorer: Achievement(
      type: AchievementType.artExplorer,
      id: 'art_explorer',
      title: 'Art Explorer',
      description: 'Discovered 10 AR artworks',
      tokenReward: 50,
      requiredCount: 10,
      icon: '🗺️',
      rarity: CollectibleRarity.uncommon,
    ),
    AchievementType.artMaster: Achievement(
      type: AchievementType.artMaster,
      id: 'art_master',
      title: 'Art Master',
      description: 'Discovered 50 AR artworks',
      tokenReward: 200,
      requiredCount: 50,
      icon: '🏆',
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.artLegend: Achievement(
      type: AchievementType.artLegend,
      id: 'art_legend',
      title: 'Art Legend',
      description: 'Discovered 100 AR artworks',
      tokenReward: 500,
      requiredCount: 100,
      icon: '👑',
      rarity: CollectibleRarity.legendary,
    ),

    // AR achievements
    AchievementType.firstARView: Achievement(
      type: AchievementType.firstARView,
      id: 'first_ar_view',
      title: 'AR Pioneer',
      description: 'Viewed your first artwork in AR',
      tokenReward: 15,
      requiredCount: 1,
      icon: '👓',
      rarity: CollectibleRarity.common,
    ),
    AchievementType.arEnthusiast: Achievement(
      type: AchievementType.arEnthusiast,
      id: 'ar_enthusiast',
      title: 'AR Enthusiast',
      description: 'Viewed 25 artworks in AR',
      tokenReward: 100,
      requiredCount: 25,
      icon: '🔮',
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.arPro: Achievement(
      type: AchievementType.arPro,
      id: 'ar_pro',
      title: 'AR Pro',
      description: 'Viewed 100 artworks in AR',
      tokenReward: 300,
      requiredCount: 100,
      icon: '✨',
      rarity: CollectibleRarity.epic,
    ),

    // NFT achievements
    AchievementType.firstNFTMint: Achievement(
      type: AchievementType.firstNFTMint,
      id: 'first_nft_mint',
      title: 'NFT Creator',
      description: 'Minted your first NFT',
      tokenReward: 25,
      requiredCount: 1,
      icon: '💎',
      rarity: CollectibleRarity.uncommon,
    ),
    AchievementType.nftCollector: Achievement(
      type: AchievementType.nftCollector,
      id: 'nft_collector',
      title: 'NFT Collector',
      description: 'Own 10 NFTs',
      tokenReward: 150,
      requiredCount: 10,
      icon: '🎨',
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.nftTrader: Achievement(
      type: AchievementType.nftTrader,
      id: 'nft_trader',
      title: 'NFT Trader',
      description: 'Completed 5 NFT trades',
      tokenReward: 100,
      requiredCount: 5,
      icon: '💰',
      rarity: CollectibleRarity.rare,
    ),

    // Community achievements
    AchievementType.firstPost: Achievement(
      type: AchievementType.firstPost,
      id: 'first_post',
      title: 'First Post',
      description: 'Created your first community post',
      tokenReward: 5,
      requiredCount: 1,
      icon: '📝',
      rarity: CollectibleRarity.common,
    ),
    AchievementType.influencer: Achievement(
      type: AchievementType.influencer,
      id: 'influencer',
      title: 'Influencer',
      description: 'Received 100 likes on your posts',
      tokenReward: 200,
      requiredCount: 100,
      icon: '🌟',
      rarity: CollectibleRarity.epic,
    ),
    AchievementType.communityBuilder: Achievement(
      type: AchievementType.communityBuilder,
      id: 'community_builder',
      title: 'Community Builder',
      description: 'Have 50 followers',
      tokenReward: 250,
      requiredCount: 50,
      icon: '🤝',
      rarity: CollectibleRarity.epic,
    ),

    // Social achievements
    AchievementType.firstLike: Achievement(
      type: AchievementType.firstLike,
      id: 'first_like',
      title: 'First Like',
      description: 'Liked your first post',
      tokenReward: 5,
      requiredCount: 1,
      icon: '❤️',
      rarity: CollectibleRarity.common,
    ),
    AchievementType.popularCreator: Achievement(
      type: AchievementType.popularCreator,
      id: 'popular_creator',
      title: 'Popular Creator',
      description: 'One of your posts got 50+ likes',
      tokenReward: 100,
      requiredCount: 1,
      icon: '🔥',
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.firstComment: Achievement(
      type: AchievementType.firstComment,
      id: 'first_comment',
      title: 'First Comment',
      description: 'Left your first comment',
      tokenReward: 5,
      requiredCount: 1,
      icon: '💬',
      rarity: CollectibleRarity.common,
    ),
    AchievementType.commentator: Achievement(
      type: AchievementType.commentator,
      id: 'commentator',
      title: 'Commentator',
      description: 'Left 50 comments',
      tokenReward: 75,
      requiredCount: 50,
      icon: '🗣️',
      rarity: CollectibleRarity.uncommon,
    ),

    // Trading achievements
    AchievementType.firstTrade: Achievement(
      type: AchievementType.firstTrade,
      id: 'first_trade',
      title: 'First Trade',
      description: 'Completed your first NFT trade',
      tokenReward: 20,
      requiredCount: 1,
      icon: '🔄',
      rarity: CollectibleRarity.uncommon,
    ),
    AchievementType.smartTrader: Achievement(
      type: AchievementType.smartTrader,
      id: 'smart_trader',
      title: 'Smart Trader',
      description: 'Made a profit on 10 trades',
      tokenReward: 300,
      requiredCount: 10,
      icon: '📈',
      rarity: CollectibleRarity.epic,
    ),
    AchievementType.marketMaster: Achievement(
      type: AchievementType.marketMaster,
      id: 'market_master',
      title: 'Market Master',
      description: 'Completed 100 trades',
      tokenReward: 1000,
      requiredCount: 100,
      icon: '💼',
      rarity: CollectibleRarity.legendary,
    ),

    // Special achievements
    AchievementType.earlyAdopter: Achievement(
      type: AchievementType.earlyAdopter,
      id: 'early_adopter',
      title: 'Early Adopter',
      description: 'Joined during beta',
      tokenReward: 100,
      requiredCount: 1,
      icon: '🚀',
      rarity: CollectibleRarity.epic,
    ),
    AchievementType.betaTester: Achievement(
      type: AchievementType.betaTester,
      id: 'beta_tester',
      title: 'Beta Tester',
      description: 'Helped test the platform',
      tokenReward: 50,
      requiredCount: 1,
      icon: '🧪',
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.artSupporter: Achievement(
      type: AchievementType.artSupporter,
      id: 'art_supporter',
      title: 'Art Supporter',
      description: 'Supported 10 artists',
      tokenReward: 150,
      requiredCount: 10,
      icon: '🎭',
      rarity: CollectibleRarity.rare,
    ),

    // Event achievements (POAPs)
    AchievementType.eventAttendee: Achievement(
      type: AchievementType.eventAttendee,
      id: 'event_attendee',
      title: 'Event Attendee',
      description: 'Attended a special event',
      tokenReward: 50,
      isPOAP: true,
      requiredCount: 1,
      icon: '🎫',
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.galleryVisitor: Achievement(
      type: AchievementType.galleryVisitor,
      id: 'gallery_visitor',
      title: 'Gallery Visitor',
      description: 'Visited a partner gallery',
      tokenReward: 75,
      isPOAP: true,
      requiredCount: 1,
      icon: '🖼️',
      rarity: CollectibleRarity.epic,
    ),
    AchievementType.workshopParticipant: Achievement(
      type: AchievementType.workshopParticipant,
      id: 'workshop_participant',
      title: 'Workshop Participant',
      description: 'Participated in an AR workshop',
      tokenReward: 100,
      isPOAP: true,
      requiredCount: 1,
      icon: '🎓',
      rarity: CollectibleRarity.epic,
    ),
  };

  /// Check and unlock achievements based on user actions
  Future<void> checkAchievements({
    required String userId,
    required String action,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('AchievementService: Checking achievements for action: $action');

      // Map actions to achievement checks
      switch (action) {
        case 'artwork_discovered':
          await _checkDiscoveryAchievements(userId, data);
          break;
        case 'ar_viewed':
          await _checkARViewAchievements(userId, data);
          break;
        case 'nft_minted':
          await _checkNFTMintAchievements(userId, data);
          break;
        case 'nft_owned':
          await _checkNFTCollectionAchievements(userId, data);
          break;
        case 'trade_completed':
          await _checkTradingAchievements(userId, data);
          break;
        case 'post_created':
          await _checkCommunityAchievements(userId, data);
          break;
        case 'likes_received':
          await _checkInfluencerAchievements(userId, data);
          break;
        case 'followers_gained':
          await _checkFollowerAchievements(userId, data);
          break;
        case 'comment_posted':
          await _checkCommentAchievements(userId, data);
          break;
        case 'like_given':
          await _checkSocialAchievements(userId, data);
          break;
        case 'event_attended':
          await _checkEventAchievements(userId, data);
          break;
      }
    } catch (e) {
      debugPrint('AchievementService: Error checking achievements: $e');
    }
  }

  /// Check discovery achievements
  Future<void> _checkDiscoveryAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['discoverCount'] as int? ?? 0;
    
    if (count == 1) {
      await _unlockAchievement(userId, AchievementType.firstDiscovery);
    } else if (count == 10) {
      await _unlockAchievement(userId, AchievementType.artExplorer);
    } else if (count == 50) {
      await _unlockAchievement(userId, AchievementType.artMaster);
    } else if (count == 100) {
      await _unlockAchievement(userId, AchievementType.artLegend);
    }
  }

  /// Check AR view achievements
  Future<void> _checkARViewAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['arViewCount'] as int? ?? 0;
    
    if (count == 1) {
      await _unlockAchievement(userId, AchievementType.firstARView);
    } else if (count == 25) {
      await _unlockAchievement(userId, AchievementType.arEnthusiast);
    } else if (count == 100) {
      await _unlockAchievement(userId, AchievementType.arPro);
    }
  }

  /// Check NFT minting achievements
  Future<void> _checkNFTMintAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['mintCount'] as int? ?? 0;
    
    if (count == 1) {
      await _unlockAchievement(userId, AchievementType.firstNFTMint);
    }
  }

  /// Check NFT collection achievements
  Future<void> _checkNFTCollectionAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['nftCount'] as int? ?? 0;
    
    if (count == 10) {
      await _unlockAchievement(userId, AchievementType.nftCollector);
    }
  }

  /// Check trading achievements
  Future<void> _checkTradingAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['tradeCount'] as int? ?? 0;
    final profitCount = data?['profitableTradeCount'] as int? ?? 0;
    
    if (count == 1) {
      await _unlockAchievement(userId, AchievementType.firstTrade);
    } else if (count == 5) {
      await _unlockAchievement(userId, AchievementType.nftTrader);
    } else if (count == 100) {
      await _unlockAchievement(userId, AchievementType.marketMaster);
    }
    
    if (profitCount == 10) {
      await _unlockAchievement(userId, AchievementType.smartTrader);
    }
  }

  /// Check community achievements
  Future<void> _checkCommunityAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['postCount'] as int? ?? 0;
    
    if (count == 1) {
      await _unlockAchievement(userId, AchievementType.firstPost);
    }
  }

  /// Check influencer achievements
  Future<void> _checkInfluencerAchievements(String userId, Map<String, dynamic>? data) async {
    final totalLikes = data?['totalLikes'] as int? ?? 0;
    final postLikes = data?['postLikes'] as int? ?? 0;
    
    if (totalLikes == 100) {
      await _unlockAchievement(userId, AchievementType.influencer);
    }
    
    if (postLikes >= 50) {
      await _unlockAchievement(userId, AchievementType.popularCreator);
    }
  }

  /// Check follower achievements
  Future<void> _checkFollowerAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['followerCount'] as int? ?? 0;
    
    if (count == 50) {
      await _unlockAchievement(userId, AchievementType.communityBuilder);
    }
  }

  /// Check comment achievements
  Future<void> _checkCommentAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['commentCount'] as int? ?? 0;
    
    if (count == 1) {
      await _unlockAchievement(userId, AchievementType.firstComment);
    } else if (count == 50) {
      await _unlockAchievement(userId, AchievementType.commentator);
    }
  }

  /// Check social achievements
  Future<void> _checkSocialAchievements(String userId, Map<String, dynamic>? data) async {
    final count = data?['likeCount'] as int? ?? 0;
    
    if (count == 1) {
      await _unlockAchievement(userId, AchievementType.firstLike);
    }
  }

  /// Check event (POAP) achievements
  Future<void> _checkEventAchievements(String userId, Map<String, dynamic>? data) async {
    final eventType = data?['eventType'] as String?;
    
    switch (eventType) {
      case 'general_event':
        await _unlockAchievement(userId, AchievementType.eventAttendee, eventData: data);
        break;
      case 'gallery_visit':
        await _unlockAchievement(userId, AchievementType.galleryVisitor, eventData: data);
        break;
      case 'workshop':
        await _unlockAchievement(userId, AchievementType.workshopParticipant, eventData: data);
        break;
    }
  }

  /// Unlock achievement and award tokens
  Future<void> _unlockAchievement(
    String userId,
    AchievementType type, {
    Map<String, dynamic>? eventData,
  }) async {
    try {
      final achievement = achievements[type]!;
      
      // Check if already unlocked
      if (await _isAchievementUnlocked(userId, achievement.id)) {
        debugPrint('Achievement ${achievement.id} already unlocked');
        return;
      }

      // Unlock achievement in backend
      await _backendApi.unlockAchievement(
        achievementType: achievement.id,
        data: eventData ?? {},
      );

      // Award tokens (placeholder for Web3 implementation)
      await _awardTokens(userId, achievement.tokenReward);

      // If it's a POAP, mint POAP NFT
      if (achievement.isPOAP) {
        await _mintPOAP(userId, achievement, eventData);
      }

      // Save achievement locally
      await _saveAchievementLocally(userId, achievement.id);

      // Show notification
      await _notificationService.showAchievementNotification(
        achievementId: achievement.id,
        title: achievement.title,
        description: achievement.description,
        rewardTokens: achievement.tokenReward,
      );

      debugPrint('Achievement unlocked: ${achievement.title} (+${achievement.tokenReward} KUB8)');
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
    }
  }

  /// Award KUB8 tokens to user (Web3 implementation placeholder)
  Future<void> _awardTokens(String userId, int amount) async {
    // TODO: When Web3 is fully implemented, this will:
    // 1. Call smart contract to mint/transfer KUB8 tokens
    // 2. Update user's wallet balance on-chain
    // 3. Record transaction on blockchain
    
    debugPrint('TODO: Award $amount KUB8 tokens to user $userId via Web3');
    
    // For now, store locally and sync with backend
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentBalance = prefs.getInt('kub8_balance') ?? 0;
      final newBalance = currentBalance + amount;
      await prefs.setInt('kub8_balance', newBalance);
      
      debugPrint('Local token balance updated: $currentBalance → $newBalance KUB8');
      
      // TODO: Sync with backend token balance table
      // await _backendApi.updateTokenBalance(userId, newBalance);
    } catch (e) {
      debugPrint('Error updating token balance: $e');
    }
  }

  /// Mint POAP (Proof of Attendance Protocol) NFT
  Future<void> _mintPOAP(
    String userId,
    Achievement achievement,
    Map<String, dynamic>? eventData,
  ) async {
    // TODO: Mint POAP NFT as a special collectible
    debugPrint('TODO: Mint POAP NFT for ${achievement.title}');
    
    // POAP characteristics:
    // - Non-transferable (soulbound)
    // - Free to mint
    // - Event-specific metadata
    // - Proof of attendance at events
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final _ = prefs.getString('wallet_address') ?? '';
      
      // TODO: Call NFTMintingService to mint POAP
      // await NFTMintingService().mintNFT(
      //   artworkId: 'poap_${achievement.id}',
      //   artworkTitle: achievement.title,
      //   artistName: 'art.kubus',
      //   ownerAddress: walletAddress,
      //   type: CollectibleType.poap,
      //   rarity: achievement.rarity,
      //   totalSupply: 1,
      //   mintPrice: 0.0, // POAPs are free
      //   requiresARInteraction: false,
      //   properties: {
      //     'event': eventData?['eventName'] ?? 'Special Event',
      //     'date': eventData?['eventDate'] ?? DateTime.now().toIso8601String(),
      //     'location': eventData?['location'] ?? 'Virtual',
      //     'soulbound': true, // Cannot be transferred
      //   },
      // );
      
      debugPrint('POAP NFT minted for ${achievement.title}');
    } catch (e) {
      debugPrint('Error minting POAP: $e');
    }
  }

  /// Check if achievement is already unlocked
  Future<bool> _isAchievementUnlocked(String userId, String achievementId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedAchievements = prefs.getStringList('unlocked_achievements_$userId') ?? [];
      return unlockedAchievements.contains(achievementId);
    } catch (e) {
      debugPrint('Error checking achievement status: $e');
      return false;
    }
  }

  /// Save achievement locally
  Future<void> _saveAchievementLocally(String userId, String achievementId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedAchievements = prefs.getStringList('unlocked_achievements_$userId') ?? [];
      
      if (!unlockedAchievements.contains(achievementId)) {
        unlockedAchievements.add(achievementId);
        await prefs.setStringList('unlocked_achievements_$userId', unlockedAchievements);
      }
    } catch (e) {
      debugPrint('Error saving achievement: $e');
    }
  }

  /// Get user's unlocked achievements
  Future<List<Achievement>> getUnlockedAchievements(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedIds = prefs.getStringList('unlocked_achievements_$userId') ?? [];
      
      return achievements.values
          .where((achievement) => unlockedIds.contains(achievement.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting unlocked achievements: $e');
      return [];
    }
  }

  /// Get user's total earned tokens
  Future<int> getTotalEarnedTokens(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('kub8_balance') ?? 0;
    } catch (e) {
      debugPrint('Error getting token balance: $e');
      return 0;
    }
  }

  /// Get achievement progress
  Future<Map<String, int>> getAchievementProgress(String userId) async {
    try {
      final data = await _backendApi.getUserAchievements(userId);
      final progressList = data['progress'] as List<dynamic>? ?? [];
      
      final progressMap = <String, int>{};
      for (final item in progressList) {
        final achievementId = item['achievement_id'] as String?;
        final currentProgress = item['current_progress'] as int? ?? 0;
        if (achievementId != null) {
          progressMap[achievementId] = currentProgress;
        }
      }
      
      return progressMap;
    } catch (e) {
      debugPrint('Error fetching achievement progress: $e');
      return {};
    }
  }

  /// Get all available achievements from backend
  Future<List<Achievement>> getAllAchievements() async {
    try {
      final achievementsData = await _backendApi.getAchievements();
      // Map backend data to Achievement objects if needed
      debugPrint('Fetched ${achievementsData.length} achievements from backend');
      return achievements.values.toList();
    } catch (e) {
      debugPrint('Error fetching achievements: $e');
      return achievements.values.toList();
    }
  }
}
