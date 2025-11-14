import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ar_marker.dart';

/// Push notification service for AR proximity alerts and community updates
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = false;
  
  // Callbacks for notification actions
  Function(String)? onNotificationTap;
  Function(String, Map<String, dynamic>)? onNotificationReceived;

  /// Initialize push notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    await _checkPermission();
    debugPrint('PushNotificationService: Initialized');
  }

  /// Check notification permission status
  Future<bool> _checkPermission() async {
    if (!_initialized) await initialize();

    final prefs = await SharedPreferences.getInstance();
    _permissionGranted = prefs.getBool('notification_permission_granted') ?? false;
    
    return _permissionGranted;
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();

    // Request permission on iOS
    final bool? granted = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permission on Android 13+
    final bool? grantedAndroid = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _permissionGranted = granted ?? grantedAndroid ?? false;

    // Store permission status
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_permission_granted', _permissionGranted);

    debugPrint('PushNotificationService: Permission granted: $_permissionGranted');
    return _permissionGranted;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final type = data['type'] as String?;
        onNotificationTap?.call(payload);
        
        if (type != null) {
          onNotificationReceived?.call(type, data);
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Show AR proximity notification
  Future<void> showARProximityNotification({
    required ARMarker marker,
    required double distance,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ar_proximity',
      'AR Proximity',
      channelDescription: 'Notifications for nearby AR artworks',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF9C27B0),
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'ar_proximity',
      'markerId': marker.id,
      'artworkId': marker.artworkId,
      'distance': distance,
    });

    await _flutterLocalNotificationsPlugin.show(
      marker.id.hashCode,
      'AR Artwork Nearby! 🎨',
      '${marker.name} is ${distance.round()}m away',
      details,
      payload: payload,
    );
  }

  /// Show community post notification
  Future<void> showCommunityNotification({
    required String postId,
    required String authorName,
    required String content,
    String? imageUrl,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'community',
      'Community',
      channelDescription: 'Notifications for community posts and interactions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4ECDC4),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'community_post',
      'postId': postId,
      'authorName': authorName,
    });

    await _flutterLocalNotificationsPlugin.show(
      postId.hashCode,
      'New post from $authorName',
      content.length > 60 ? '${content.substring(0, 60)}...' : content,
      details,
      payload: payload,
    );
  }

  /// Show artwork discovery notification
  Future<void> showArtworkDiscoveryNotification({
    required String artworkId,
    required String title,
    required String artist,
    required int rewards,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'artwork_discovery',
      'Artwork Discovery',
      channelDescription: 'Notifications for discovered artworks',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFFBE0B),
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'artwork_discovery',
      'artworkId': artworkId,
    });

    await _flutterLocalNotificationsPlugin.show(
      artworkId.hashCode,
      'Art Discovered! 🎉',
      '$title by $artist (+$rewards KUB8)',
      details,
      payload: payload,
    );
  }

  /// Show token reward notification
  Future<void> showRewardNotification({
    required String title,
    required int amount,
    required String reason,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rewards',
      'Rewards',
      channelDescription: 'Notifications for token rewards',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFFD93D),
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'reward',
      'amount': amount,
    });

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch,
      title,
      '+$amount KUB8 - $reason',
      details,
      payload: payload,
    );
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Show NFT minting notification
  Future<void> showNFTMintingNotification({
    required String artworkId,
    required String artworkTitle,
    required String status, // 'started', 'success', 'failed'
    String? transactionId,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'nft_minting',
      'NFT Minting',
      channelDescription: 'Notifications for NFT minting process',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF9C27B0),
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'nft_minting',
      'artworkId': artworkId,
      'status': status,
      if (transactionId != null) 'transactionId': transactionId,
    });

    String title = '';
    String body = '';
    
    switch (status) {
      case 'started':
        title = 'Minting NFT... ⏳';
        body = 'Creating NFT for "$artworkTitle"';
        break;
      case 'success':
        title = 'NFT Minted! 🎉';
        body = '"$artworkTitle" is now on the blockchain';
        break;
      case 'failed':
        title = 'Minting Failed ❌';
        body = 'Could not mint "$artworkTitle". Please try again.';
        break;
    }

    await _flutterLocalNotificationsPlugin.show(
      artworkId.hashCode + status.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show trading notification
  Future<void> showTradingNotification({
    required String tradeId,
    required String type, // 'offer_received', 'offer_accepted', 'sale_completed'
    required String artworkTitle,
    required double amount,
    String? buyerName,
    String? sellerName,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trading',
      'Trading',
      channelDescription: 'Notifications for artwork trading activities',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'trading',
      'tradeId': tradeId,
      'tradeType': type,
      'artworkTitle': artworkTitle,
    });

    String title = '';
    String body = '';
    
    switch (type) {
      case 'offer_received':
        title = 'New Offer! 💰';
        body = '${buyerName ?? 'Someone'} offered $amount SOL for "$artworkTitle"';
        break;
      case 'offer_accepted':
        title = 'Offer Accepted! ✅';
        body = 'Your offer for "$artworkTitle" was accepted';
        break;
      case 'sale_completed':
        title = 'Sale Complete! 🎊';
        body = 'You sold "$artworkTitle" for $amount SOL';
        break;
    }

    await _flutterLocalNotificationsPlugin.show(
      tradeId.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show achievement notification
  Future<void> showAchievementNotification({
    required String achievementId,
    required String title,
    required String description,
    required int rewardTokens,
    String? badgeIcon,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'achievements',
      'Achievements',
      channelDescription: 'Notifications for unlocked achievements',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFFD93D),
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'achievement',
      'achievementId': achievementId,
    });

    await _flutterLocalNotificationsPlugin.show(
      achievementId.hashCode,
      '🏆 Achievement Unlocked!',
      '$title - $description (+$rewardTokens KUB8)',
      details,
      payload: payload,
    );
  }

  /// Show community interaction notification (likes, comments, shares)
  Future<void> showCommunityInteractionNotification({
    required String postId,
    required String type, // 'like', 'comment', 'share', 'mention'
    required String userName,
    String? comment,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'community_interactions',
      'Community Interactions',
      channelDescription: 'Notifications for likes, comments, and shares',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4ECDC4),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'community_interaction',
      'interactionType': type,
      'postId': postId,
      'userName': userName,
    });

    String title = '';
    String body = '';
    
    switch (type) {
      case 'like':
        title = '❤️ New Like';
        body = '$userName liked your post';
        break;
      case 'comment':
        title = '💬 New Comment';
        body = '$userName: ${comment ?? "commented on your post"}';
        break;
      case 'share':
        title = '🔄 Post Shared';
        body = '$userName shared your post';
        break;
      case 'mention':
        title = '📢 You were mentioned';
        body = '$userName mentioned you in a post';
        break;
    }

    await _flutterLocalNotificationsPlugin.show(
      '$postId-$type-${DateTime.now().millisecondsSinceEpoch}'.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show follower notification
  Future<void> showFollowerNotification({
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'followers',
      'Followers',
      channelDescription: 'Notifications for new followers',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF9C27B0),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'follower',
      'userId': userId,
    });

    await _flutterLocalNotificationsPlugin.show(
      userId.hashCode,
      '👥 New Follower',
      '$userName started following you',
      details,
      payload: payload,
    );
  }

  /// Show collection notification (added to collection, collection milestone)
  Future<void> showCollectionNotification({
    required String type, // 'added', 'milestone'
    required String artworkTitle,
    String? collectorName,
    int? collectionCount,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'collections',
      'Collections',
      channelDescription: 'Notifications for collection activities',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFF6B6B),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'collection',
      'collectionType': type,
    });

    String title = '';
    String body = '';
    
    switch (type) {
      case 'added':
        title = '⭐ Added to Collection';
        body = '${collectorName ?? 'Someone'} added "$artworkTitle" to their collection';
        break;
      case 'milestone':
        title = '🎯 Collection Milestone!';
        body = 'You\'ve collected $collectionCount artworks!';
        break;
    }

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show system notification (updates, maintenance, announcements)
  Future<void> showSystemNotification({
    required String title,
    required String message,
    String? actionUrl,
  }) async {
    if (!_permissionGranted) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'system',
      'System',
      channelDescription: 'Important system notifications',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF2196F3),
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'system',
      if (actionUrl != null) 'actionUrl': actionUrl,
    });

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch,
      title,
      message,
      details,
      payload: payload,
    );
  }

  // ============ PLACEHOLDER METHODS FOR FUTURE IMPLEMENTATIONS ============

  /// TODO: Implement push notification for auction events
  /// Will notify users about auction start, bid updates, and auction end
  Future<void> showAuctionNotification({
    required String auctionId,
    required String type, // 'started', 'bid_placed', 'outbid', 'won', 'ended'
    required String artworkTitle,
    double? currentBid,
    String? bidderName,
  }) async {
    // Placeholder for auction notifications
    debugPrint('TODO: Implement auction notification - type: $type, artwork: $artworkTitle');
  }

  /// TODO: Implement push notification for collaborative art projects
  /// Will notify users about invitations, contributions, and project updates
  Future<void> showCollaborationNotification({
    required String projectId,
    required String type, // 'invited', 'contribution', 'completed'
    required String projectTitle,
    String? collaboratorName,
  }) async {
    // Placeholder for collaboration notifications
    debugPrint('TODO: Implement collaboration notification - type: $type, project: $projectTitle');
  }

  /// TODO: Implement push notification for AR events
  /// Will notify users about AR exhibitions, virtual galleries, and live AR events
  Future<void> showAREventNotification({
    required String eventId,
    required String eventTitle,
    required String type, // 'starting_soon', 'live', 'reminder', 'ended'
    DateTime? startTime,
  }) async {
    // Placeholder for AR event notifications
    debugPrint('TODO: Implement AR event notification - type: $type, event: $eventTitle');
  }

  /// TODO: Implement push notification for challenge completion
  /// Will notify users about daily/weekly challenges and rewards
  Future<void> showChallengeNotification({
    required String challengeId,
    required String challengeTitle,
    required String type, // 'available', 'progress', 'completed'
    int? progress,
    int? total,
  }) async {
    // Placeholder for challenge notifications
    debugPrint('TODO: Implement challenge notification - type: $type, challenge: $challengeTitle');
  }

  /// TODO: Implement push notification for token staking
  /// Will notify users about staking rewards, unstaking, and pool updates
  Future<void> showStakingNotification({
    required String type, // 'reward', 'unstake_ready', 'pool_update'
    double? rewardAmount,
    String? poolName,
  }) async {
    // Placeholder for staking notifications
    debugPrint('TODO: Implement staking notification - type: $type');
  }

  /// Dispose service
  void dispose() {
    onNotificationTap = null;
    onNotificationReceived = null;
  }
}
