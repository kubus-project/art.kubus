import 'dart:convert';
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
class AchievementDefinition {
  final AchievementType type;
  final String id;
  final String title;
  final String description;
  final int tokenReward; // KUB8 tokens
  final bool isPOAP; // Is this a Proof of Attendance Protocol achievement
  final String? eventId; // For POAP achievements
  final int requiredCount; // How many times action must be performed
  final CollectibleRarity rarity;

  const AchievementDefinition({
    required this.type,
    required this.id,
    required this.title,
    required this.description,
    required this.tokenReward,
    this.isPOAP = false,
    this.eventId,
    this.requiredCount = 1,
    required this.rarity,
  });
}

/// Achievement Service - Manages achievements, token rewards, and POAPs
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final BackendApiService _backendApi = BackendApiService();
  final PushNotificationService _notificationService = PushNotificationService();

  // Achievement definitions
  static const Map<AchievementType, AchievementDefinition> achievementDefinitions = {
    // Discovery achievements
    AchievementType.firstDiscovery: AchievementDefinition(
      type: AchievementType.firstDiscovery,
      id: 'first_discovery',
      title: 'First Discovery',
      description: 'Discovered your first AR artwork',
      tokenReward: 10,
      requiredCount: 1,
      rarity: CollectibleRarity.common,
    ),
    AchievementType.artExplorer: AchievementDefinition(
      type: AchievementType.artExplorer,
      id: 'art_explorer',
      title: 'Art Explorer',
      description: 'Discovered 10 AR artworks',
      tokenReward: 50,
      requiredCount: 10,
      rarity: CollectibleRarity.uncommon,
    ),
    AchievementType.artMaster: AchievementDefinition(
      type: AchievementType.artMaster,
      id: 'art_master',
      title: 'Art Master',
      description: 'Discovered 50 AR artworks',
      tokenReward: 200,
      requiredCount: 50,
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.artLegend: AchievementDefinition(
      type: AchievementType.artLegend,
      id: 'art_legend',
      title: 'Art Legend',
      description: 'Discovered 100 AR artworks',
      tokenReward: 500,
      requiredCount: 100,
      rarity: CollectibleRarity.legendary,
    ),

    // AR achievements
    AchievementType.firstARView: AchievementDefinition(
      type: AchievementType.firstARView,
      id: 'first_ar_view',
      title: 'AR Pioneer',
      description: 'Viewed your first artwork in AR',
      tokenReward: 15,
      requiredCount: 1,
      rarity: CollectibleRarity.common,
    ),
    AchievementType.arEnthusiast: AchievementDefinition(
      type: AchievementType.arEnthusiast,
      id: 'ar_enthusiast',
      title: 'AR Enthusiast',
      description: 'Viewed 25 artworks in AR',
      tokenReward: 100,
      requiredCount: 25,
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.arPro: AchievementDefinition(
      type: AchievementType.arPro,
      id: 'ar_pro',
      title: 'AR Pro',
      description: 'Viewed 100 artworks in AR',
      tokenReward: 300,
      requiredCount: 100,
      rarity: CollectibleRarity.epic,
    ),

    // NFT achievements
    AchievementType.firstNFTMint: AchievementDefinition(
      type: AchievementType.firstNFTMint,
      id: 'first_nft_mint',
      title: 'NFT Creator',
      description: 'Minted your first NFT',
      tokenReward: 25,
      requiredCount: 1,
      rarity: CollectibleRarity.uncommon,
    ),
    AchievementType.nftCollector: AchievementDefinition(
      type: AchievementType.nftCollector,
      id: 'nft_collector',
      title: 'NFT Collector',
      description: 'Own 10 NFTs',
      tokenReward: 150,
      requiredCount: 10,
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.nftTrader: AchievementDefinition(
      type: AchievementType.nftTrader,
      id: 'nft_trader',
      title: 'NFT Trader',
      description: 'Completed 5 NFT trades',
      tokenReward: 100,
      requiredCount: 5,
      rarity: CollectibleRarity.rare,
    ),

    // Community achievements
    AchievementType.firstPost: AchievementDefinition(
      type: AchievementType.firstPost,
      id: 'first_post',
      title: 'First Post',
      description: 'Created your first community post',
      tokenReward: 5,
      requiredCount: 1,
      rarity: CollectibleRarity.common,
    ),
    AchievementType.influencer: AchievementDefinition(
      type: AchievementType.influencer,
      id: 'influencer',
      title: 'Influencer',
      description: 'Received 100 likes on your posts',
      tokenReward: 200,
      requiredCount: 100,
      rarity: CollectibleRarity.epic,
    ),
    AchievementType.communityBuilder: AchievementDefinition(
      type: AchievementType.communityBuilder,
      id: 'community_builder',
      title: 'Community Builder',
      description: 'Have 50 followers',
      tokenReward: 250,
      requiredCount: 50,
      rarity: CollectibleRarity.epic,
    ),

    // Social achievements
    AchievementType.firstLike: AchievementDefinition(
      type: AchievementType.firstLike,
      id: 'first_like',
      title: 'First Like',
      description: 'Liked your first post',
      tokenReward: 5,
      requiredCount: 1,
      rarity: CollectibleRarity.common,
    ),
    AchievementType.popularCreator: AchievementDefinition(
      type: AchievementType.popularCreator,
      id: 'popular_creator',
      title: 'Popular Creator',
      description: 'One of your posts got 50+ likes',
      tokenReward: 100,
      requiredCount: 1,
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.firstComment: AchievementDefinition(
      type: AchievementType.firstComment,
      id: 'first_comment',
      title: 'First Comment',
      description: 'Left your first comment',
      tokenReward: 5,
      requiredCount: 1,
      rarity: CollectibleRarity.common,
    ),
    AchievementType.commentator: AchievementDefinition(
      type: AchievementType.commentator,
      id: 'commentator',
      title: 'Commentator',
      description: 'Left 50 comments',
      tokenReward: 75,
      requiredCount: 50,
      rarity: CollectibleRarity.uncommon,
    ),

    // Trading achievements
    AchievementType.firstTrade: AchievementDefinition(
      type: AchievementType.firstTrade,
      id: 'first_trade',
      title: 'First Trade',
      description: 'Completed your first NFT trade',
      tokenReward: 20,
      requiredCount: 1,
      rarity: CollectibleRarity.uncommon,
    ),
    AchievementType.smartTrader: AchievementDefinition(
      type: AchievementType.smartTrader,
      id: 'smart_trader',
      title: 'Smart Trader',
      description: 'Made a profit on 10 trades',
      tokenReward: 300,
      requiredCount: 10,
      rarity: CollectibleRarity.epic,
    ),
    AchievementType.marketMaster: AchievementDefinition(
      type: AchievementType.marketMaster,
      id: 'market_master',
      title: 'Market Master',
      description: 'Completed 100 trades',
      tokenReward: 1000,
      requiredCount: 100,
      rarity: CollectibleRarity.legendary,
    ),

    // Special achievements
    AchievementType.earlyAdopter: AchievementDefinition(
      type: AchievementType.earlyAdopter,
      id: 'early_adopter',
      title: 'Early Adopter',
      description: 'Joined during beta',
      tokenReward: 100,
      requiredCount: 1,
      rarity: CollectibleRarity.epic,
    ),
    AchievementType.betaTester: AchievementDefinition(
      type: AchievementType.betaTester,
      id: 'beta_tester',
      title: 'Beta Tester',
      description: 'Helped test the platform',
      tokenReward: 50,
      requiredCount: 1,
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.artSupporter: AchievementDefinition(
      type: AchievementType.artSupporter,
      id: 'art_supporter',
      title: 'Art Supporter',
      description: 'Supported 10 artists',
      tokenReward: 150,
      requiredCount: 10,
      rarity: CollectibleRarity.rare,
    ),

    // Event achievements (POAPs)
    AchievementType.eventAttendee: AchievementDefinition(
      type: AchievementType.eventAttendee,
      id: 'event_attendee',
      title: 'Event Attendee',
      description: 'Attended a special event',
      tokenReward: 50,
      isPOAP: true,
      requiredCount: 1,
      rarity: CollectibleRarity.rare,
    ),
    AchievementType.galleryVisitor: AchievementDefinition(
      type: AchievementType.galleryVisitor,
      id: 'gallery_visitor',
      title: 'Gallery Visitor',
      description: 'Visited a partner gallery',
      tokenReward: 75,
      isPOAP: true,
      requiredCount: 1,
      rarity: CollectibleRarity.epic,
    ),
    AchievementType.workshopParticipant: AchievementDefinition(
      type: AchievementType.workshopParticipant,
      id: 'workshop_participant',
      title: 'Workshop Participant',
      description: 'Participated in an AR workshop',
      tokenReward: 100,
      isPOAP: true,
      requiredCount: 1,
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
    final raw = data?['viewCount'] ?? data?['arViewCount'];
    final count = raw is int
        ? raw
        : raw is num
            ? raw.toInt()
            : int.tryParse(raw?.toString() ?? '') ?? 0;
    
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
      final achievement = achievementDefinitions[type]!;
      
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

      // Award tokens (local balance; on-chain wiring can be layered later)
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

  /// Award KUB8 tokens to user.
  Future<void> _awardTokens(String userId, int amount) async {
    try {
      if (amount <= 0) return;
      final prefs = await SharedPreferences.getInstance();
      final currentBalance = prefs.getInt('kub8_balance') ?? 0;
      final newBalance = currentBalance + amount;
      await prefs.setInt('kub8_balance', newBalance);
      
      debugPrint('AchievementService: local KUB8 balance $currentBalance -> $newBalance');
    } catch (e) {
      debugPrint('AchievementService: failed to update local KUB8 balance: $e');
    }
  }

  /// Mint POAP (Proof of Attendance Protocol) NFT
  Future<void> _mintPOAP(
    String userId,
    AchievementDefinition achievement,
    Map<String, dynamic>? eventData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletAddress = prefs.getString('wallet_address') ?? '';

      final poapKey = 'poap_collectibles_$userId';
      final existingRaw = prefs.getStringList(poapKey) ?? <String>[];

      bool alreadyMinted = false;
      for (final item in existingRaw) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          if (decoded['achievementId'] == achievement.id) {
            alreadyMinted = true;
            break;
          }
        } catch (_) {}
      }
      if (alreadyMinted) return;

      final entry = <String, dynamic>{
        'achievementId': achievement.id,
        'title': achievement.title,
        'description': achievement.description,
        'walletAddress': walletAddress,
        'event': eventData?['eventName'] ?? eventData?['event'] ?? 'Event',
        'date': eventData?['eventDate'] ?? DateTime.now().toIso8601String(),
        'location': eventData?['location'] ?? 'Virtual',
        'soulbound': true,
        'mintedAt': DateTime.now().toIso8601String(),
      };

      existingRaw.insert(0, jsonEncode(entry));
      if (existingRaw.length > 50) {
        existingRaw.removeRange(50, existingRaw.length);
      }

      await prefs.setStringList(poapKey, existingRaw);
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
  Future<List<AchievementDefinition>> getUnlockedAchievements(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedIds = prefs.getStringList('unlocked_achievements_$userId') ?? [];
      
      return achievementDefinitions.values
          .where((achievement) => unlockedIds.contains(achievement.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting unlocked achievements: $e');
      return [];
    }
  }

  /// Get user's total earned tokens
  Future<int> getTotalEarnedTokens() async {
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
  Future<List<AchievementDefinition>> getAllAchievements() async {
    try {
      final achievementsData = await _backendApi.getAchievements();
      // Map backend data to Achievement objects if needed
      debugPrint('Fetched ${achievementsData.length} achievements from backend');
      return achievementDefinitions.values.toList();
    } catch (e) {
      debugPrint('Error fetching achievements: $e');
      return achievementDefinitions.values.toList();
    }
  }
}
