import 'dart:convert';
import 'package:flutter/material.dart';
import 'push_notification_service.dart';

/// Centralized notification handler for routing notification taps
/// 
/// This service handles all notification tap events and routes users
/// to the appropriate screens based on notification type.
class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  final PushNotificationService _notificationService = PushNotificationService();
  
  // Navigation callback - set by the app shell to route taps.
  // Signature avoids requiring a BuildContext so this handler stays platform-agnostic.
  void Function(String route, Map<String, dynamic> params)? onNavigate;

  /// Initialize notification handler
  void initialize() {
    _notificationService.onNotificationTap = _handleNotificationTap;
    debugPrint('NotificationHandler: Initialized');
  }

  /// Handle notification tap events
  void _handleNotificationTap(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == null) return;

      debugPrint('NotificationHandler: Handling tap for type: $type');
      
      // Route based on notification type
      switch (type) {
        case 'ar_proximity':
          _handleARProximityTap(data);
          break;
        case 'community_post':
          _handleCommunityPostTap(data);
          break;
        case 'artwork_discovery':
          _handleArtworkDiscoveryTap(data);
          break;
        case 'reward':
          _handleRewardTap(data);
          break;
        case 'nft_minting':
          _handleNFTMintingTap(data);
          break;
        case 'trading':
          _handleTradingTap(data);
          break;
        case 'achievement':
          _handleAchievementTap(data);
          break;
        case 'community_interaction':
          _handleCommunityInteractionTap(data);
          break;
        case 'follower':
          _handleFollowerTap(data);
          break;
        case 'collection':
          _handleCollectionTap(data);
          break;
        case 'system':
          _handleSystemTap(data);
          break;
        default:
          debugPrint('NotificationHandler: Unknown notification type: $type');
      }
    } catch (e) {
      debugPrint('NotificationHandler: Error handling tap: $e');
    }
  }

  /// Handle AR proximity notification tap
  void _handleARProximityTap(Map<String, dynamic> data) {
    final markerId = data['markerId'] as String?;
    final artworkId = data['artworkId'] as String?;
    
    debugPrint('Navigating to AR marker: $markerId');
    
    // Navigate to map screen with marker focused
    // onNavigate will be implemented by the app
    _navigate('/map', {
      'markerId': markerId,
      'artworkId': artworkId,
      'action': 'focus',
    });
  }

  /// Handle community post notification tap
  void _handleCommunityPostTap(Map<String, dynamic> data) {
    final postId = data['postId'] as String?;
    
    debugPrint('Navigating to community post: $postId');
    
    _navigate('/community', {
      'postId': postId,
      'action': 'view',
    });
  }

  /// Handle artwork discovery notification tap
  void _handleArtworkDiscoveryTap(Map<String, dynamic> data) {
    final artworkId = data['artworkId'] as String?;
    
    debugPrint('Navigating to artwork: $artworkId');
    
    _navigate('/artwork', {
      'artworkId': artworkId,
      'action': 'view',
    });
  }

  /// Handle reward notification tap
  void _handleRewardTap(Map<String, dynamic> data) {
    debugPrint('Navigating to rewards/wallet screen');
    
    _navigate('/wallet', {
      'tab': 'rewards',
    });
  }

  /// Handle NFT minting notification tap
  void _handleNFTMintingTap(Map<String, dynamic> data) {
    final artworkId = data['artworkId'] as String?;
    final status = data['status'] as String?;
    final transactionId = data['transactionId'] as String?;
    
    debugPrint('Navigating to NFT minting: $artworkId, status: $status');
    
    if (status == 'success' && transactionId != null) {
      _navigate('/transaction', {
        'transactionId': transactionId,
        'artworkId': artworkId,
      });
    } else {
      _navigate('/artwork', {
        'artworkId': artworkId,
        'tab': 'nft',
      });
    }
  }

  /// Handle trading notification tap
  void _handleTradingTap(Map<String, dynamic> data) {
    final tradeId = data['tradeId'] as String?;
    final tradeType = data['tradeType'] as String?;
    
    debugPrint('Navigating to trade: $tradeId, type: $tradeType');
    
    _navigate('/marketplace', {
      'tradeId': tradeId,
      'tab': 'trades',
    });
  }

  /// Handle achievement notification tap
  void _handleAchievementTap(Map<String, dynamic> data) {
    final achievementId = data['achievementId'] as String?;
    
    debugPrint('Navigating to achievement: $achievementId');
    
    _navigate('/profile', {
      'tab': 'achievements',
      'achievementId': achievementId,
    });
  }

  /// Handle community interaction notification tap
  void _handleCommunityInteractionTap(Map<String, dynamic> data) {
    final postId = data['postId'] as String?;
    final interactionType = data['interactionType'] as String?;
    
    debugPrint('Navigating to post interaction: $postId, type: $interactionType');
    
    _navigate('/community', {
      'postId': postId,
      'action': 'view',
      'highlightInteraction': interactionType,
    });
  }

  /// Handle follower notification tap
  void _handleFollowerTap(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    
    debugPrint('Navigating to user profile: $userId');
    
    _navigate('/profile', {
      'userId': userId,
    });
  }

  /// Handle collection notification tap
  void _handleCollectionTap(Map<String, dynamic> data) {
    final collectionType = data['collectionType'] as String?;
    
    debugPrint('Navigating to collection, type: $collectionType');
    
    _navigate('/profile', {
      'tab': 'collection',
    });
  }

  /// Handle system notification tap
  void _handleSystemTap(Map<String, dynamic> data) {
    final actionUrl = data['actionUrl'] as String?;
    
    debugPrint('Handling system notification, action: $actionUrl');
    
    if (actionUrl != null) {
      _navigate(actionUrl, {});
    }
  }

  /// Navigate to route with parameters
  void _navigate(String route, Map<String, dynamic> params) {
    final navigator = onNavigate;
    if (navigator != null) {
      try {
        navigator(route, params);
      } catch (e) {
        debugPrint('NotificationHandler: onNavigate failed for $route: $e');
      }
      return;
    }

    debugPrint('NotificationHandler: Navigate to $route with params: $params');
  }

  /// Dispose handler
  void dispose() {
    _notificationService.onNotificationTap = null;
  }
}
