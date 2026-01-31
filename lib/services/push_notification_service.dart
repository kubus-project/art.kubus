import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'notification_helper.dart';
import 'notification_show_helper.dart' as webshow;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/art_marker.dart';

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

  final List<Function(String)> _notificationTapListeners = <Function(String)>[];
  final List<Function(String, Map<String, dynamic>)> _notificationReceivedListeners =
      <Function(String, Map<String, dynamic>)>[];

  void addOnNotificationTapListener(Function(String) listener) {
    if (_notificationTapListeners.contains(listener)) return;
    _notificationTapListeners.add(listener);
  }

  void removeOnNotificationTapListener(Function(String) listener) {
    _notificationTapListeners.remove(listener);
  }

  void addOnNotificationReceivedListener(Function(String, Map<String, dynamic>) listener) {
    if (_notificationReceivedListeners.contains(listener)) return;
    _notificationReceivedListeners.add(listener);
  }

  void removeOnNotificationReceivedListener(Function(String, Map<String, dynamic>) listener) {
    _notificationReceivedListeners.remove(listener);
  }

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
      settings: initializationSettings,
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
    if (kIsWeb) {
      // On web (including Chromium), rely on the browser's Notification permission
      // instead of plugin/shared pref state.
      _permissionGranted = await isWebNotificationPermissionGranted();
      await prefs.setBool('notification_permission_granted', _permissionGranted);
      return _permissionGranted;
    }

    _permissionGranted = prefs.getBool('notification_permission_granted') ?? false;
    
    return _permissionGranted;
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();
    // Web: use browser Permission API + fallback
    if (kIsWeb) {
      try {
        final granted = await requestWebNotificationPermission();
        _permissionGranted = granted;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notification_permission_granted', _permissionGranted);
        debugPrint('PushNotificationService (web): Permission granted: $_permissionGranted');
        return _permissionGranted;
      } catch (e) {
        debugPrint('PushNotificationService (web) requestPermission failed: $e');
        return false;
      }
    }

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

        for (final listener in List<Function(String)>.from(_notificationTapListeners)) {
          try {
            listener(payload);
          } catch (_) {
            // Ignore listener errors.
          }
        }
        
        if (type != null) {
          onNotificationReceived?.call(type, data);

          for (final listener in List<Function(String, Map<String, dynamic>)>.from(_notificationReceivedListeners)) {
            try {
              listener(type, data);
            } catch (_) {
              // Ignore listener errors.
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Show AR proximity notification
  Future<void> showARProximityNotification({
    required ArtMarker marker,
    required double distance,
  }) async {
    if (!_permissionGranted) return;
    if (kIsWeb) {
      try {
        final mapData = {'type': 'ar_proximity', 'markerId': marker.id, 'artworkId': marker.artworkId, 'distance': distance, 'actionUrl': 'app://artwork/${marker.artworkId}'};
        await webshow.showNotification('AR Artwork Nearby! 🎨', '${marker.name} is ${distance.round()}m away', mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showARProximityNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ar_proximity',
      'AR Proximity',
      channelDescription: 'Notifications for nearby AR artworks',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      'actionUrl': 'app://artwork/${marker.artworkId}',
    });

    await _flutterLocalNotificationsPlugin.show(
      id: marker.id.hashCode,
      title: 'AR Artwork Nearby! 🎨',
      body: '${marker.name} is ${distance.round()}m away',
      notificationDetails: details,
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
      'actionUrl': 'app://posts/$postId',
    });
    if (kIsWeb) {
      try {
        final mapData = {
          'type': 'community_post',
          'postId': postId,
          'authorName': authorName,
          'content': content,
          if (imageUrl != null) 'imageUrl': imageUrl,
          'actionUrl': 'app://posts/$postId'
        };
        await webshow.showNotification('New post from $authorName', content.length > 60 ? '${content.substring(0, 60)}...' : content, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showCommunityNotification failed: $e');
      }
    }

    await _flutterLocalNotificationsPlugin.show(
      id: postId.hashCode,
      title: 'New post from $authorName',
      body: content.length > 60 ? '${content.substring(0, 60)}...' : content,
      notificationDetails: details,
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
    if (kIsWeb) {
      try {
        final mapData = {'type': 'artwork_discovery', 'artworkId': artworkId, 'title': title, 'artist': artist, 'rewards': rewards, 'actionUrl': 'app://artwork/$artworkId'};
        await webshow.showNotification('Art Discovered! 🎉', '$title by $artist (+$rewards KUB8)', mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showArtworkDiscoveryNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'artwork_discovery',
      'Artwork Discovery',
      channelDescription: 'Notifications for discovered artworks',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      'actionUrl': 'app://artwork/$artworkId',
    });

    await _flutterLocalNotificationsPlugin.show(
      id: artworkId.hashCode,
      title: 'Art Discovered! 🎉',
      body: '$title by $artist (+$rewards KUB8)',
      notificationDetails: details,
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
    if (kIsWeb) {
      try {
        final mapData = {'type': 'reward', 'amount': amount, 'reason': reason, 'actionUrl': 'app://rewards'};
        await webshow.showNotification(title, '+$amount KUB8 - $reason', mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showRewardNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rewards',
      'Rewards',
      channelDescription: 'Notifications for token rewards',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      'actionUrl': 'app://rewards',
    });

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: '+$amount KUB8 - $reason',
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id);
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
    if (kIsWeb) {
      try {
        final mapData = {'type': 'nft_minting', 'artworkId': artworkId, 'artworkTitle': artworkTitle, 'status': status, 'transactionId': transactionId, 'actionUrl': 'app://artwork/$artworkId'};
        String titleText = '';
        String bodyText = '';
        switch (status) {
          case 'started':
            titleText = 'Minting NFT... ⏳';
            bodyText = 'Creating NFT for "$artworkTitle"';
            break;
          case 'success':
            titleText = 'NFT Minted! 🎉';
            bodyText = '"$artworkTitle" is now on the blockchain';
            break;
          case 'failed':
            titleText = 'Minting Failed ❌';
            bodyText = 'Could not mint "$artworkTitle". Please try again.';
            break;
        }
        await webshow.showNotification(titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showNFTMintingNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'nft_minting',
      'NFT Minting',
      channelDescription: 'Notifications for NFT minting process',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      'actionUrl': 'app://artwork/$artworkId',
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
      id: artworkId.hashCode + status.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
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
    if (kIsWeb) {
      try {
        final mapData = {'type': 'trading', 'tradeId': tradeId, 'tradeType': type, 'artworkTitle': artworkTitle, 'amount': amount, 'buyerName': buyerName, 'sellerName': sellerName, 'actionUrl': 'app://trade/$tradeId'};
        String titleText = '';
        String bodyText = '';
        switch (type) {
          case 'offer_received':
            titleText = 'New Offer! 💰';
            bodyText = '${buyerName ?? 'Someone'} offered $amount SOL for "$artworkTitle"';
            break;
          case 'offer_accepted':
            titleText = 'Offer Accepted! ✅';
            bodyText = 'Your offer for "$artworkTitle" was accepted';
            break;
          case 'sale_completed':
            titleText = 'Sale Complete! 🎊';
            bodyText = 'You sold "$artworkTitle" for $amount SOL';
            break;
        }
        await webshow.showNotification(titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showTradingNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trading',
      'Trading',
      channelDescription: 'Notifications for artwork trading activities',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      'actionUrl': 'app://trade/$tradeId',
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
      id: tradeId.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
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
    if (kIsWeb) {
      try {
        final mapData = {'type': 'achievement', 'achievementId': achievementId, 'title': title, 'description': description, 'rewardTokens': rewardTokens, 'actionUrl': 'app://achievement/$achievementId'};
        await webshow.showNotification('🏆 Achievement Unlocked!', '$title - $description (+$rewardTokens KUB8)', mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showAchievementNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'achievements',
      'Achievements',
      channelDescription: 'Notifications for unlocked achievements',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      'actionUrl': 'app://achievement/$achievementId',
    });

    await _flutterLocalNotificationsPlugin.show(
      id: achievementId.hashCode,
      title: '🏆 Achievement Unlocked!',
      body: '$title - $description (+$rewardTokens KUB8)',
      notificationDetails: details,
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
      'actionUrl': 'app://posts/$postId',
    });

    final formatted = _formatCommunityMessage(type, userName, comment);
    final title = formatted['title'] ?? 'New Activity';
    final body = formatted['body'] ?? ''; 

    if (kIsWeb) {
      // For web, use the browser/unified notification helper to show a notification via service worker or Notification API
      try {
        final mapData = {'type': 'community_interaction', 'interactionType': type, 'postId': postId, 'userName': userName, 'comment': comment, 'actionUrl': 'app://posts/$postId'};
        await webshow.showNotification(title, body, mapData);
        return;
      } catch (e) {
        // fallback to native/local notifications if show fails
        debugPrint('PushNotificationService (web) show failed: $e');
      }
    }

    await _flutterLocalNotificationsPlugin.show(
      id: '$postId-$type-${DateTime.now().millisecondsSinceEpoch}'.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  // Local helper for consistent community message formatting
  Map<String, String> _formatCommunityMessage(String type, String userName, [String? comment]) {
    switch (type) {
      case 'like':
        return {'title': '❤️ New Like', 'body': '$userName liked your post'};
      case 'comment':
        final b = comment != null && comment.isNotEmpty ? comment.length > 60 ? '${comment.substring(0, 60)}...' : comment : 'commented on your post';
        return {'title': '💬 New Comment', 'body': '$userName: $b'};
      case 'share':
        return {'title': '🔄 Post Shared', 'body': '$userName shared your post'};
      case 'mention':
        return {'title': '📢 You were mentioned', 'body': '$userName mentioned you in a post'};
      default:
        return {'title': 'New activity', 'body': '$userName interacted with your post'};
    }
  }

  /// Show follower notification
  Future<void> showFollowerNotification({
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    if (!_permissionGranted) return;
    if (kIsWeb) {
      try {
        final mapData = {'type': 'follower', 'userId': userId, 'userName': userName, 'userAvatar': userAvatar, 'actionUrl': 'app://user/$userId'};
        await webshow.showNotification('👥 New Follower', '$userName started following you', mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showFollowerNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'followers',
      'Followers',
      channelDescription: 'Notifications for new followers',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      'actionUrl': 'app://user/$userId',
    });

    await _flutterLocalNotificationsPlugin.show(
      id: userId.hashCode,
      title: '👥 New Follower',
      body: '$userName started following you',
      notificationDetails: details,
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
    if (kIsWeb) {
      try {
        final mapData = {'type': 'collection', 'collectionType': type, 'artworkTitle': artworkTitle, 'collectorName': collectorName, 'collectionCount': collectionCount, 'actionUrl': 'app://collections'};
        String titleText = '';
        String bodyText = '';
        switch (type) {
          case 'added':
            titleText = '⭐ Added to Collection';
            bodyText = '${collectorName ?? 'Someone'} added "$artworkTitle" to their collection';
            break;
          case 'milestone':
            titleText = '🎯 Collection Milestone!';
            bodyText = 'You\'ve collected $collectionCount artworks!';
            break;
        }
        await webshow.showNotification(titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showCollectionNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'collections',
      'Collections',
      channelDescription: 'Notifications for collection activities',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      'actionUrl': 'app://collections',
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
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: details,
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
    if (kIsWeb) {
      try {
        final mapData = {'type': 'system', 'actionUrl': actionUrl};
        await webshow.showNotification(title, message, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showSystemNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'system',
      'System',
      channelDescription: 'Important system notifications',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: message,
      notificationDetails: details,
      payload: payload,
    );
  }

  // ============ Extended notification types ============

  /// Push notification for auction events
  /// Notifies users about auction start, bid updates, and auction end.
  Future<void> showAuctionNotification({
    required String auctionId,
    required String type, // 'started', 'bid_placed', 'outbid', 'won', 'ended'
    required String artworkTitle,
    double? currentBid,
    String? bidderName,
  }) async {
    if (!_permissionGranted) return;

    String titleText = 'Auction Update';
    String bodyText = '';
    switch (type) {
      case 'started':
        bodyText = 'Auction started for "$artworkTitle"';
        break;
      case 'bid_placed':
        bodyText = '${bidderName ?? 'Someone'} placed a bid of ${currentBid ?? 0}';
        break;
      case 'outbid':
        bodyText = 'You were outbid for "$artworkTitle"';
        break;
      case 'won':
        bodyText = 'You won the auction for "$artworkTitle"';
        break;
      case 'ended':
        bodyText = 'Auction ended for "$artworkTitle"';
        break;
    }

    if (kIsWeb) {
      try {
        final mapData = {'type': 'auction', 'auctionId': auctionId, 'eventType': type, 'artworkTitle': artworkTitle, 'currentBid': currentBid, 'bidderName': bidderName, 'actionUrl': 'app://auction/$auctionId'};
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification('auction', titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showAuctionNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'auction',
      'Auctions',
      channelDescription: 'Notifications for auction activity',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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

    final payloadData = {
      'type': 'auction',
      'auctionId': auctionId,
      'eventType': type,
      'artworkTitle': artworkTitle,
      if (currentBid != null) 'currentBid': currentBid,
      if (bidderName != null) 'bidderName': bidderName,
      'actionUrl': 'app://auction/$auctionId',
    };

    await _flutterLocalNotificationsPlugin.show(
      id: auctionId.hashCode,
      title: titleText,
      body: bodyText,
      notificationDetails: details,
      payload: jsonEncode(payloadData),
    );

    await _storeInAppNotification('auction', titleText, bodyText, payloadData);
  }

  /// Push notification for collaborative art projects
  /// Notifies users about invitations, contributions, and project updates.
  Future<void> showCollaborationNotification({
    required String projectId,
    required String type, // 'invited', 'contribution', 'completed'
    required String projectTitle,
    String? collaboratorName,
  }) async {
    if (!_permissionGranted) return;

    String titleText = 'Collaboration';
    String bodyText = '';
    switch (type) {
      case 'invited':
        bodyText = '${collaboratorName ?? 'Someone'} invited you to collaborate on "$projectTitle"';
        break;
      case 'contribution':
        bodyText = '${collaboratorName ?? 'Someone'} contributed to "$projectTitle"';
        break;
      case 'completed':
        bodyText = 'Your project "$projectTitle" was completed';
        break;
    }

    if (kIsWeb) {
      try {
        final mapData = {'type': 'collaboration', 'projectId': projectId, 'eventType': type, 'projectTitle': projectTitle, 'collaboratorName': collaboratorName, 'actionUrl': 'app://project/$projectId'};
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification('collaboration', titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showCollaborationNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'collaboration',
      'Collaborations',
      channelDescription: 'Notifications for collaborative projects',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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

    final payloadData = {
      'type': 'collaboration',
      'projectId': projectId,
      'eventType': type,
      'projectTitle': projectTitle,
      if (collaboratorName != null) 'collaboratorName': collaboratorName,
      'actionUrl': 'app://project/$projectId',
    };

    await _flutterLocalNotificationsPlugin.show(
      id: projectId.hashCode,
      title: titleText,
      body: bodyText,
      notificationDetails: details,
      payload: jsonEncode(payloadData),
    );

    await _storeInAppNotification('collaboration', titleText, bodyText, payloadData);
  }

  /// Push notification for collaboration invites on events/exhibitions.
  /// Payload type: `collab_invite`
  Future<void> showCollabInviteNotification({
    required String inviteId,
    required String entityType,
    required String entityId,
    required String role,
    String? inviterName,
    String? entityTitle,
  }) async {
    if (!_permissionGranted) return;

    final normalizedType = entityType.trim().toLowerCase();
    final itemLabel = (normalizedType == 'events' || normalizedType == 'event')
        ? 'event'
        : ((normalizedType == 'exhibitions' || normalizedType == 'exhibition') ? 'exhibition' : 'item');

    final safeInviter = (inviterName ?? '').trim().isNotEmpty ? inviterName!.trim() : 'Someone';
    final safeTitle = (entityTitle ?? '').trim();

    const titleText = 'New invite';
    final bodyText = safeTitle.isNotEmpty
        ? '$safeInviter invited you to help manage "$safeTitle" ($itemLabel).'
        : '$safeInviter invited you to help manage an $itemLabel.';

    final payloadData = {
      'type': 'collab_invite',
      'inviteId': inviteId,
      'entityType': entityType,
      'entityId': entityId,
      'role': role,
      if (inviterName != null) 'inviterName': inviterName,
      if (entityTitle != null) 'entityTitle': entityTitle,
      'actionUrl': 'app://collab/invite/$inviteId',
    };

    if (kIsWeb) {
      try {
        await webshow.showNotification(titleText, bodyText, payloadData);
        await _storeInAppNotification('collab_invite', titleText, bodyText, payloadData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showCollabInviteNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'collab_invites',
      'Collaboration Invites',
      channelDescription: 'Invites to collaborate on events and exhibitions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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

    await _flutterLocalNotificationsPlugin.show(
      id: inviteId.hashCode,
      title: titleText,
      body: bodyText,
      notificationDetails: details,
      payload: jsonEncode(payloadData),
    );

    await _storeInAppNotification('collab_invite', titleText, bodyText, payloadData);
  }

  /// Push notification for AR events
  /// Notifies users about AR exhibitions, virtual galleries, and live AR events.
  Future<void> showAREventNotification({
    required String eventId,
    required String eventTitle,
    required String type, // 'starting_soon', 'live', 'reminder', 'ended'
    DateTime? startTime,
  }) async {
    if (!_permissionGranted) return;

    String titleText = 'AR Event';
    String bodyText = '';
    switch (type) {
      case 'starting_soon':
        bodyText = 'AR event starting soon: $eventTitle';
        break;
      case 'live':
        bodyText = 'AR event live: $eventTitle';
        break;
      case 'reminder':
        bodyText = 'Reminder: $eventTitle';
        break;
      case 'ended':
        bodyText = 'AR event ended: $eventTitle';
        break;
    }

    if (kIsWeb) {
      try {
        final mapData = {'type': 'ar_event', 'eventId': eventId, 'eventTitle': eventTitle, 'eventType': type, 'startTime': startTime?.toIso8601String(), 'actionUrl': 'app://ar_event/$eventId'};
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification('ar_event', titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showAREventNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ar_events',
      'AR Events',
      channelDescription: 'Notifications for AR events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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

    final payloadData = {
      'type': 'ar_event',
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventType': type,
      if (startTime != null) 'startTime': startTime.toIso8601String(),
      'actionUrl': 'app://ar_event/$eventId',
    };

    await _flutterLocalNotificationsPlugin.show(
      id: eventId.hashCode,
      title: titleText,
      body: bodyText,
      notificationDetails: details,
      payload: jsonEncode(payloadData),
    );

    await _storeInAppNotification('ar_event', titleText, bodyText, payloadData);
  }

  /// Push notification for challenges
  /// Notifies users about new challenges, progress, and completion.
  Future<void> showChallengeNotification({
    required String challengeId,
    required String challengeTitle,
    required String type, // 'available', 'progress', 'completed'
    int? progress,
    int? total,
  }) async {
    if (!_permissionGranted) return;

    String titleText = 'Challenge';
    String bodyText = '';
    switch (type) {
      case 'available':
        bodyText = 'New challenge available: $challengeTitle';
        break;
      case 'progress':
        bodyText = 'Challenge progress: ${progress ?? 0}/${total ?? 0}';
        break;
      case 'completed':
        bodyText = 'Challenge completed: $challengeTitle';
        break;
    }

    if (kIsWeb) {
      try {
        final mapData = {'type': 'challenge', 'challengeId': challengeId, 'eventType': type, 'challengeTitle': challengeTitle, 'progress': progress, 'total': total, 'actionUrl': 'app://challenge/$challengeId'};
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification('challenge', titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showChallengeNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'challenges',
      'Challenges',
      channelDescription: 'Notifications for challenges',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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

    final payloadData = {
      'type': 'challenge',
      'challengeId': challengeId,
      'eventType': type,
      'challengeTitle': challengeTitle,
      if (progress != null) 'progress': progress,
      if (total != null) 'total': total,
      'actionUrl': 'app://challenge/$challengeId',
    };

    await _flutterLocalNotificationsPlugin.show(
      id: challengeId.hashCode,
      title: titleText,
      body: bodyText,
      notificationDetails: details,
      payload: jsonEncode(payloadData),
    );

    await _storeInAppNotification('challenge', titleText, bodyText, payloadData);
  }

  /// Push notification for token staking updates
  /// Notifies users about rewards, unstaking, and pool updates.
  Future<void> showStakingNotification({
    required String type, // 'reward', 'unstake_ready', 'pool_update'
    double? rewardAmount,
    String? poolName,
  }) async {
    if (!_permissionGranted) return;

    String titleText = 'Staking Update';
    String bodyText = '';
    switch (type) {
      case 'reward':
        bodyText = 'You earned ${rewardAmount ?? 0} from staking in ${poolName ?? 'the pool'}';
        break;
      case 'unstake_ready':
        bodyText = 'Your staked tokens are ready to withdraw from ${poolName ?? 'the pool'}';
        break;
      case 'pool_update':
        bodyText = 'Pool update: ${poolName ?? ''}';
        break;
    }

    if (kIsWeb) {
      try {
        final mapData = {'type': 'staking', 'eventType': type, 'rewardAmount': rewardAmount, 'poolName': poolName, 'actionUrl': 'app://staking'};
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification('staking', titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint('PushNotificationService (web) showStakingNotification failed: $e');
      }
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'staking',
      'Staking',
      channelDescription: 'Notifications for staking activity',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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

    final payloadData = {
      'type': 'staking',
      'eventType': type,
      if (rewardAmount != null) 'rewardAmount': rewardAmount,
      if (poolName != null) 'poolName': poolName,
      'actionUrl': 'app://staking',
    };

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch,
      title: titleText,
      body: bodyText,
      notificationDetails: details,
      payload: jsonEncode(payloadData),
    );

    await _storeInAppNotification('staking', titleText, bodyText, payloadData);
  }

  /// Dispose service
  void dispose() {
    onNotificationTap = null;
    onNotificationReceived = null;
  }

  Future<void> _storeInAppNotification(
    String type,
    String title,
    String body,
    Map<String, dynamic> payload,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('in_app_notifications') ?? <String>[];
      final entry = <String, dynamic>{
        'type': type,
        'title': title,
        'body': body,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      };
      existing.insert(0, jsonEncode(entry));
      if (existing.length > 100) {
        existing.removeRange(100, existing.length);
      }
      await prefs.setStringList('in_app_notifications', existing);
    } catch (e) {
      debugPrint('PushNotificationService: failed to store in-app notification: $e');
    }
  }

  /// Return in-app notifications stored locally.
  /// Stored as a JSON-encoded list of notification objects under key 'in_app_notifications'.
  Future<List<Map<String, dynamic>>> getInAppNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('in_app_notifications') ?? [];
    final List<Map<String, dynamic>> out = [];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        out.add(decoded);
      } catch (e) {
        debugPrint('PushNotificationService.getInAppNotifications: failed to decode item: $e');
      }
    }
    return out;
  }
}
