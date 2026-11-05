import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'notification_helper.dart';
import 'notification_show_helper.dart' as webshow;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../l10n/app_localizations_sl.dart';
import '../models/art_marker.dart';
import '../utils/reward_semantics.dart';
import 'account_cache_store.dart';

/// Push notification service for AR proximity alerts and community updates
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = false;
  bool _permissionRequestInProgress = false;
  Completer<void>? _permissionRequestCompleter;
  String? _pendingLaunchTapPayload;

  AppLocalizations get _l10n {
    final languageCode =
        ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return languageCode == 'sl' ? AppLocalizationsSl() : AppLocalizationsEn();
  }

  // Callbacks for notification actions
  Function(String)? onNotificationTap;
  Function(String, Map<String, dynamic>)? onNotificationReceived;

  final List<Function(String)> _notificationTapListeners = <Function(String)>[];
  final List<Function(String, Map<String, dynamic>)>
      _notificationReceivedListeners =
      <Function(String, Map<String, dynamic>)>[];

  void addOnNotificationTapListener(Function(String) listener) {
    if (_notificationTapListeners.contains(listener)) return;
    _notificationTapListeners.add(listener);
    _dispatchPendingLaunchTapIfReady();
  }

  void removeOnNotificationTapListener(Function(String) listener) {
    _notificationTapListeners.remove(listener);
  }

  void addOnNotificationReceivedListener(
    Function(String, Map<String, dynamic>) listener,
  ) {
    if (_notificationReceivedListeners.contains(listener)) return;
    _notificationReceivedListeners.add(listener);
  }

  void removeOnNotificationReceivedListener(
    Function(String, Map<String, dynamic>) listener,
  ) {
    _notificationReceivedListeners.remove(listener);
  }

  /// Initialize push notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    try {
      final launchDetails = await _flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      final payload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.trim().isNotEmpty) {
        _pendingLaunchTapPayload = payload;
        _dispatchPendingLaunchTapIfReady();
      }
    } catch (e) {
      debugPrint(
        'PushNotificationService: launch notification lookup failed: $e',
      );
    }

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
      await prefs.setBool(
        'notification_permission_granted',
        _permissionGranted,
      );
      return _permissionGranted;
    }

    if (_permissionRequestInProgress) {
      await waitForPermissionSettlement(timeout: const Duration(seconds: 3));
    }

    try {
      final permissionStatus = await Permission.notification.status;
      _permissionGranted = permissionStatus.isGranted;
      await prefs.setBool(
        'notification_permission_granted',
        _permissionGranted,
      );
      return _permissionGranted;
    } catch (e) {
      debugPrint(
        'PushNotificationService: Runtime permission check failed: $e',
      );
    }

    _permissionGranted =
        prefs.getBool('notification_permission_granted') ?? false;

    return _permissionGranted;
  }

  /// Returns current runtime permission state and updates internal cache.
  Future<bool> refreshPermissionStatus() async {
    return _checkPermission();
  }

  /// Waits briefly for an in-flight permission request to settle.
  Future<void> waitForPermissionSettlement({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final pending = _permissionRequestCompleter;
    if (pending == null) return;
    try {
      await pending.future.timeout(timeout);
    } catch (_) {
      // Ignore timeout/errors; caller can continue with current state.
    }
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    _permissionRequestInProgress = true;
    _permissionRequestCompleter = Completer<void>();
    try {
      // Web: use browser Permission API + fallback
      if (kIsWeb) {
        // Important: keep this as "directly called from a user gesture" with no
        // extra async initialization before Notification.requestPermission(),
        // otherwise the browser may suppress the prompt.
        final granted = await requestWebNotificationPermission();
        _permissionGranted = granted;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'notification_permission_granted',
          _permissionGranted,
        );
        debugPrint(
          'PushNotificationService (web): Permission granted: $_permissionGranted',
        );
        return _permissionGranted;
      }

      if (!_initialized) await initialize();

      // Request permission on iOS
      final bool? granted = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // Request permission on Android 13+
      final bool? grantedAndroid = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      var resolvedPermission = granted ?? grantedAndroid ?? false;
      try {
        final runtimeStatus = await Permission.notification.status;
        resolvedPermission = runtimeStatus.isGranted;
      } catch (_) {
        // Fall back to plugin result when runtime status isn't available.
      }

      _permissionGranted = resolvedPermission;

      // Store permission status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'notification_permission_granted',
        _permissionGranted,
      );

      debugPrint(
        'PushNotificationService: Permission granted: $_permissionGranted',
      );
      return _permissionGranted;
    } catch (e) {
      debugPrint('PushNotificationService requestPermission failed: $e');
      return false;
    } finally {
      _permissionRequestInProgress = false;
      _permissionRequestCompleter?.complete();
      _permissionRequestCompleter = null;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final type = data['type'] as String?;
        _dispatchNotificationTap(payload);

        if (type != null) {
          onNotificationReceived?.call(type, data);

          for (final listener
              in List<Function(String, Map<String, dynamic>)>.from(
            _notificationReceivedListeners,
          )) {
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

  void _dispatchPendingLaunchTapIfReady() {
    final payload = _pendingLaunchTapPayload;
    if (payload == null || _notificationTapListeners.isEmpty) return;
    _pendingLaunchTapPayload = null;
    scheduleMicrotask(() => _dispatchNotificationTap(payload));
  }

  @visibleForTesting
  void queueLaunchTapForTesting(String payload) {
    _pendingLaunchTapPayload = payload;
    _dispatchPendingLaunchTapIfReady();
  }

  void _dispatchNotificationTap(String payload) {
    try {
      onNotificationTap?.call(payload);
    } catch (_) {}
    for (final listener in List<Function(String)>.from(
      _notificationTapListeners,
    )) {
      try {
        listener(payload);
      } catch (_) {
        // Ignore listener errors.
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
        final mapData = {
          'type': 'ar_proximity',
          'markerId': marker.id,
          'artworkId': marker.artworkId,
          'distance': distance,
          'actionUrl': 'app://artwork/${marker.artworkId}',
        };
        await webshow.showNotification(
          'AR Artwork Nearby! 🎨',
          '${marker.name} is ${distance.round()}m away',
          mapData,
        );
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showARProximityNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ar_proximity',
      'AR Proximity',
      channelDescription: 'Notifications for nearby AR artworks',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'community',
      'Community',
      channelDescription: 'Notifications for community posts and interactions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@drawable/ic_notification',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
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
          'actionUrl': 'app://posts/$postId',
        };
        await webshow.showNotification(
          'New post from $authorName',
          content.length > 60 ? '${content.substring(0, 60)}...' : content,
          mapData,
        );
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showCommunityNotification failed: $e',
        );
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

  /// Show one localized direct-message alert. The stable message event ID is
  /// used as the platform notification ID so duplicate socket aliases replace
  /// the same alert instead of creating duplicates.
  Future<void> showDirectMessageNotification({
    required String eventId,
    required String conversationId,
    required String senderName,
    required String content,
  }) async {
    if (!_permissionGranted) return;
    final l10n = _l10n;
    final safeSender = senderName.trim().isEmpty
        ? l10n.notificationDirectMessageFallbackSender
        : senderName.trim();
    final preview = content.trim().isEmpty
        ? l10n.notificationDirectMessageEmptyBody
        : content.trim().length > 160
            ? '${content.trim().substring(0, 157)}…'
            : content.trim();
    final actionUrl = 'app://messages/${Uri.encodeComponent(conversationId)}';
    final payload = jsonEncode(<String, Object?>{
      'type': 'direct_message',
      'eventId': eventId,
      'conversationId': conversationId,
      'actionUrl': actionUrl,
    });
    final title = l10n.notificationDirectMessageTitle(safeSender);

    if (kIsWeb) {
      try {
        await webshow.showNotification(title, preview, <String, dynamic>{
          'type': 'direct_message',
          'eventId': eventId,
          'conversationId': conversationId,
          'actionUrl': actionUrl,
        });
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) direct-message notification failed: $e',
        );
      }
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'messages',
        l10n.notificationMessagesChannelName,
        channelDescription: l10n.notificationMessagesChannelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        icon: '@drawable/ic_notification',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _flutterLocalNotificationsPlugin.show(
      id: eventId.hashCode,
      title: title,
      body: preview,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Show artwork discovery notification
  Future<void> showArtworkDiscoveryNotification({
    required String artworkId,
    required String title,
    required String artist,
  }) async {
    if (!_permissionGranted) return;
    final l10n = _l10n;
    final body = artist.trim().isEmpty
        ? l10n.notificationArtworkDiscoveredTitleOnlyBody(title)
        : l10n.notificationArtworkDiscoveredBody(title, artist);
    if (kIsWeb) {
      try {
        final mapData = {
          'type': 'artwork_discovery',
          'artworkId': artworkId,
          'title': title,
          'artist': artist,
          'actionUrl': 'app://artwork/$artworkId',
        };
        await webshow.showNotification(
          l10n.notificationArtworkDiscoveredTitle,
          body,
          mapData,
        );
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showArtworkDiscoveryNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'artwork_discovery',
      'Artwork Discovery',
      channelDescription: 'Notifications for discovered artworks',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
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
      title: l10n.notificationArtworkDiscoveredTitle,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Show token reward notification
  Future<void> showRewardNotification({
    required String title,
    required int amount,
    required String reason,
    String? currency,
  }) async {
    if (!_permissionGranted) return;
    final l10n = _l10n;
    final hasKub8Unit = isExplicitKub8Currency(currency);
    final reasonText = reason.trim();
    final body = hasKub8Unit
        ? '+$amount KUB8${reasonText.isEmpty ? '' : ' - $reasonText'}'
        : (reasonText.isEmpty
            ? l10n.recentActivityNewRecognitionDescription
            : reasonText);
    if (kIsWeb) {
      try {
        final mapData = {
          'type': 'reward',
          if (hasKub8Unit) 'amount': amount,
          if (hasKub8Unit) 'currency': 'KUB8',
          'reason': reason,
          'actionUrl': 'app://rewards',
        };
        await webshow.showNotification(title, body, mapData);
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showRewardNotification failed: $e',
        );
      }
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'rewards',
      l10n.pushRecognitionChannelName,
      channelDescription: l10n.pushRecognitionChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'reward',
      if (hasKub8Unit) 'amount': amount,
      if (hasKub8Unit) 'currency': 'KUB8',
      'actionUrl': 'app://rewards',
    });

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
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
    final l10n = _l10n;
    if (kIsWeb) {
      try {
        final mapData = {
          'type': 'nft_minting',
          'artworkId': artworkId,
          'artworkTitle': artworkTitle,
          'status': status,
          'transactionId': transactionId,
          'actionUrl': 'app://artwork/$artworkId',
        };
        String titleText = '';
        String bodyText = '';
        switch (status) {
          case 'started':
            titleText = l10n.pushArchiveObjectCreatingTitle;
            bodyText = l10n.pushArchiveObjectCreatingBody(artworkTitle);
            break;
          case 'success':
            titleText = l10n.pushArchiveObjectCreatedTitle;
            bodyText = l10n.pushArchiveObjectCreatedBody(artworkTitle);
            break;
          case 'failed':
            titleText = l10n.pushArchiveObjectCreationFailedTitle;
            bodyText = l10n.pushArchiveObjectCreationFailedBody(artworkTitle);
            break;
        }
        await webshow.showNotification(titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showNFTMintingNotification failed: $e',
        );
      }
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'nft_minting',
      l10n.pushArchiveObjectCreationChannelName,
      channelDescription: l10n.pushArchiveObjectCreationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
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
        title = l10n.pushArchiveObjectCreatingTitle;
        body = l10n.pushArchiveObjectCreatingBody(artworkTitle);
        break;
      case 'success':
        title = l10n.pushArchiveObjectCreatedTitle;
        body = l10n.pushArchiveObjectCreatedBody(artworkTitle);
        break;
      case 'failed':
        title = l10n.pushArchiveObjectCreationFailedTitle;
        body = l10n.pushArchiveObjectCreationFailedBody(artworkTitle);
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
    required String
        type, // 'offer_received', 'offer_accepted', 'sale_completed'
    required String artworkTitle,
    required double amount,
    String? buyerName,
    String? sellerName,
  }) async {
    if (!_permissionGranted) return;
    if (kIsWeb) {
      try {
        final mapData = {
          'type': 'trading',
          'tradeId': tradeId,
          'tradeType': type,
          'artworkTitle': artworkTitle,
          'amount': amount,
          'buyerName': buyerName,
          'sellerName': sellerName,
          'actionUrl': 'app://trade/$tradeId',
        };
        String titleText = '';
        String bodyText = '';
        switch (type) {
          case 'offer_received':
            titleText = 'New Offer! 💰';
            bodyText =
                '${buyerName ?? 'Someone'} offered $amount SOL for "$artworkTitle"';
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
        debugPrint(
          'PushNotificationService (web) showTradingNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'trading',
      'Trading',
      channelDescription: 'Notifications for artwork trading activities',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
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
        body =
            '${buyerName ?? 'Someone'} offered $amount SOL for "$artworkTitle"';
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
        final mapData = {
          'type': 'achievement',
          'achievementId': achievementId,
          'title': title,
          'description': description,
          'rewardTokens': rewardTokens,
          'actionUrl': 'app://achievement/$achievementId',
        };
        await webshow.showNotification(
          '🏆 Achievement Unlocked!',
          '$title - $description (+$rewardTokens KUB8)',
          mapData,
        );
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showAchievementNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'achievements',
      'Achievements',
      channelDescription: 'Notifications for unlocked achievements',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'community_interactions',
      'Community Interactions',
      channelDescription: 'Notifications for likes, comments, and shares',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@drawable/ic_notification',
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

    final copy = communityInteractionCopy(
      _l10n,
      type: type,
      actorName: userName,
      comment: comment,
    );
    final title = copy.title;
    final body = copy.body;

    if (kIsWeb) {
      // For web, use the browser/unified notification helper to show a notification via service worker or Notification API
      try {
        final mapData = {
          'type': 'community_interaction',
          'interactionType': type,
          'postId': postId,
          'userName': userName,
          'comment': comment,
          'actionUrl': 'app://posts/$postId',
        };
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

  /// Localized title/body for community interactions. Titles carry no emoji,
  /// the actor is always named, and a missing actor falls back to the
  /// localized "Someone" label. Unknown types use the generic activity copy.
  @visibleForTesting
  static ({String title, String body}) communityInteractionCopy(
    AppLocalizations l10n, {
    required String type,
    String? actorName,
    String? comment,
  }) {
    final trimmedName = actorName?.trim() ?? '';
    final name =
        trimmedName.isNotEmpty ? trimmedName : l10n.notificationSomeoneFallback;
    switch (type) {
      case 'like':
        return (
          title: l10n.notificationCommunityLikeTitle,
          body: l10n.notificationCommunityLikeBody(name),
        );
      case 'comment':
        final text = _truncateNotificationText(comment?.trim() ?? '', 60);
        return (
          title: l10n.notificationCommunityCommentTitle,
          body: text.isEmpty
              ? l10n.notificationCommunityCommentBody(name)
              : l10n.notificationCommunityCommentWithTextBody(name, text),
        );
      case 'share':
        return (
          title: l10n.notificationCommunityShareTitle,
          body: l10n.notificationCommunityShareBody(name),
        );
      case 'repost':
        return (
          title: l10n.notificationCommunityRepostTitle,
          body: l10n.notificationCommunityRepostBody(name),
        );
      case 'mention':
        return (
          title: l10n.notificationCommunityMentionTitle,
          body: l10n.notificationCommunityMentionBody(name),
        );
      default:
        return (
          title: l10n.notificationCommunityActivityTitle,
          body: l10n.notificationCommunityActivityBody(name),
        );
    }
  }

  /// Localized title/body for a new follower.
  @visibleForTesting
  static ({String title, String body}) followerNotificationCopy(
    AppLocalizations l10n, {
    required String userName,
  }) {
    final trimmedName = userName.trim();
    final name =
        trimmedName.isNotEmpty ? trimmedName : l10n.notificationSomeoneFallback;
    return (
      title: l10n.notificationFollowerTitle,
      body: l10n.notificationFollowerBody(name),
    );
  }

  static String _truncateNotificationText(String text, int maxRunes) {
    if (text.runes.length <= maxRunes) return text;
    return '${String.fromCharCodes(text.runes.take(maxRunes))}...';
  }

  /// Show follower notification
  Future<void> showFollowerNotification({
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    if (!_permissionGranted) return;
    final copy = followerNotificationCopy(_l10n, userName: userName);
    if (kIsWeb) {
      try {
        final mapData = {
          'type': 'follower',
          'userId': userId,
          'userName': userName,
          'userAvatar': userAvatar,
          'actionUrl': 'app://user/$userId',
        };
        await webshow.showNotification(
          copy.title,
          copy.body,
          mapData,
        );
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showFollowerNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'followers',
      'Followers',
      channelDescription: 'Notifications for new followers',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@drawable/ic_notification',
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
      title: copy.title,
      body: copy.body,
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
        final mapData = {
          'type': 'collection',
          'collectionType': type,
          'artworkTitle': artworkTitle,
          'collectorName': collectorName,
          'collectionCount': collectionCount,
          'actionUrl': 'app://collections',
        };
        String titleText = '';
        String bodyText = '';
        switch (type) {
          case 'added':
            titleText = '⭐ Added to Collection';
            bodyText =
                '${collectorName ?? 'Someone'} added "$artworkTitle" to their collection';
            break;
          case 'milestone':
            titleText = '🎯 Collection Milestone!';
            bodyText = 'You\'ve collected $collectionCount artworks!';
            break;
        }
        await webshow.showNotification(titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showCollectionNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'collections',
      'Collections',
      channelDescription: 'Notifications for collection activities',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@drawable/ic_notification',
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
        body =
            '${collectorName ?? 'Someone'} added "$artworkTitle" to their collection';
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
        debugPrint(
          'PushNotificationService (web) showSystemNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'system',
      'System',
      channelDescription: 'Important system notifications',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@drawable/ic_notification',
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
    final cacheAccount = AccountCacheStore.owner;
    final cacheGeneration = AccountCacheStore.generation;
    if (!_permissionGranted) return;

    String titleText = 'Auction Update';
    String bodyText = '';
    switch (type) {
      case 'started':
        bodyText = 'Auction started for "$artworkTitle"';
        break;
      case 'bid_placed':
        bodyText =
            '${bidderName ?? 'Someone'} placed a bid of ${currentBid ?? 0}';
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
        final mapData = {
          'type': 'auction',
          'auctionId': auctionId,
          'eventType': type,
          'artworkTitle': artworkTitle,
          'currentBid': currentBid,
          'bidderName': bidderName,
          'actionUrl': 'app://auction/$auctionId',
        };
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification(cacheAccount, cacheGeneration, 'auction',
            titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showAuctionNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'auction',
      'Auctions',
      channelDescription: 'Notifications for auction activity',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
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

    await _storeInAppNotification(cacheAccount, cacheGeneration, 'auction',
        titleText, bodyText, payloadData);
  }

  /// Push notification for collaborative art projects
  /// Notifies users about invitations, contributions, and project updates.
  Future<void> showCollaborationNotification({
    required String projectId,
    required String type, // 'invited', 'contribution', 'completed'
    required String projectTitle,
    String? collaboratorName,
  }) async {
    final cacheAccount = AccountCacheStore.owner;
    final cacheGeneration = AccountCacheStore.generation;
    if (!_permissionGranted) return;

    String titleText = 'Collaboration';
    String bodyText = '';
    switch (type) {
      case 'invited':
        bodyText =
            '${collaboratorName ?? 'Someone'} invited you to collaborate on "$projectTitle"';
        break;
      case 'contribution':
        bodyText =
            '${collaboratorName ?? 'Someone'} contributed to "$projectTitle"';
        break;
      case 'completed':
        bodyText = 'Your project "$projectTitle" was completed';
        break;
    }

    if (kIsWeb) {
      try {
        final mapData = {
          'type': 'collaboration',
          'projectId': projectId,
          'eventType': type,
          'projectTitle': projectTitle,
          'collaboratorName': collaboratorName,
          'actionUrl': 'app://project/$projectId',
        };
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification(
          cacheAccount,
          cacheGeneration,
          'collaboration',
          titleText,
          bodyText,
          mapData,
        );
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showCollaborationNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'collaboration',
      'Collaborations',
      channelDescription: 'Notifications for collaborative projects',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@drawable/ic_notification',
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

    await _storeInAppNotification(
      cacheAccount,
      cacheGeneration,
      'collaboration',
      titleText,
      bodyText,
      payloadData,
    );
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
    final cacheAccount = AccountCacheStore.owner;
    final cacheGeneration = AccountCacheStore.generation;
    if (!_permissionGranted) return;

    final normalizedType = entityType.trim().toLowerCase();
    final itemLabel = (normalizedType == 'events' || normalizedType == 'event')
        ? 'event'
        : ((normalizedType == 'exhibitions' || normalizedType == 'exhibition')
            ? 'exhibition'
            : 'item');

    final safeInviter =
        (inviterName ?? '').trim().isNotEmpty ? inviterName!.trim() : 'Someone';
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
        await _storeInAppNotification(
          cacheAccount,
          cacheGeneration,
          'collab_invite',
          titleText,
          bodyText,
          payloadData,
        );
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showCollabInviteNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'collab_invites',
      'Collaboration Invites',
      channelDescription: 'Invites to collaborate on events and exhibitions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@drawable/ic_notification',
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

    await _storeInAppNotification(
      cacheAccount,
      cacheGeneration,
      'collab_invite',
      titleText,
      bodyText,
      payloadData,
    );
  }

  /// Push notification for AR events
  /// Notifies users about AR exhibitions, virtual galleries, and live AR events.
  Future<void> showAREventNotification({
    required String eventId,
    required String eventTitle,
    required String type, // 'starting_soon', 'live', 'reminder', 'ended'
    DateTime? startTime,
  }) async {
    final cacheAccount = AccountCacheStore.owner;
    final cacheGeneration = AccountCacheStore.generation;
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
        final mapData = {
          'type': 'ar_event',
          'eventId': eventId,
          'eventTitle': eventTitle,
          'eventType': type,
          'startTime': startTime?.toIso8601String(),
          'actionUrl': 'app://ar_event/$eventId',
        };
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification(cacheAccount, cacheGeneration, 'ar_event',
            titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showAREventNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ar_events',
      'AR Events',
      channelDescription: 'Notifications for AR events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
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

    await _storeInAppNotification(cacheAccount, cacheGeneration, 'ar_event',
        titleText, bodyText, payloadData);
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
    final cacheAccount = AccountCacheStore.owner;
    final cacheGeneration = AccountCacheStore.generation;
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
        final mapData = {
          'type': 'challenge',
          'challengeId': challengeId,
          'eventType': type,
          'challengeTitle': challengeTitle,
          'progress': progress,
          'total': total,
          'actionUrl': 'app://challenge/$challengeId',
        };
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification(
          cacheAccount,
          cacheGeneration,
          'challenge',
          titleText,
          bodyText,
          mapData,
        );
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showChallengeNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'challenges',
      'Challenges',
      channelDescription: 'Notifications for challenges',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@drawable/ic_notification',
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

    await _storeInAppNotification(
      cacheAccount,
      cacheGeneration,
      'challenge',
      titleText,
      bodyText,
      payloadData,
    );
  }

  /// Push notification for token staking updates
  /// Notifies users about rewards, unstaking, and pool updates.
  Future<void> showStakingNotification({
    required String type, // 'reward', 'unstake_ready', 'pool_update'
    double? rewardAmount,
    String? poolName,
  }) async {
    final cacheAccount = AccountCacheStore.owner;
    final cacheGeneration = AccountCacheStore.generation;
    if (!_permissionGranted) return;

    String titleText = 'Staking Update';
    String bodyText = '';
    switch (type) {
      case 'reward':
        bodyText =
            'You earned ${rewardAmount ?? 0} from staking in ${poolName ?? 'the pool'}';
        break;
      case 'unstake_ready':
        bodyText =
            'Your staked tokens are ready to withdraw from ${poolName ?? 'the pool'}';
        break;
      case 'pool_update':
        bodyText = 'Pool update: ${poolName ?? ''}';
        break;
    }

    if (kIsWeb) {
      try {
        final mapData = {
          'type': 'staking',
          'eventType': type,
          'rewardAmount': rewardAmount,
          'poolName': poolName,
          'actionUrl': 'app://staking',
        };
        await webshow.showNotification(titleText, bodyText, mapData);
        await _storeInAppNotification(cacheAccount, cacheGeneration, 'staking',
            titleText, bodyText, mapData);
        return;
      } catch (e) {
        debugPrint(
          'PushNotificationService (web) showStakingNotification failed: $e',
        );
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'staking',
      'Staking',
      channelDescription: 'Notifications for staking activity',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@drawable/ic_notification',
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

    await _storeInAppNotification(cacheAccount, cacheGeneration, 'staking',
        titleText, bodyText, payloadData);
  }

  /// Dispose service
  void dispose() {
    onNotificationTap = null;
    onNotificationReceived = null;
  }

  @visibleForTesting
  Future<void> storeInAppNotificationForTesting(String title) =>
      _storeInAppNotification(
          AccountCacheStore.owner,
          AccountCacheStore.generation,
          'synthetic',
          title,
          'Synthetic body', <String, dynamic>{});

  Future<void> _storeInAppNotification(
    String account,
    int generation,
    String type,
    String title,
    String body,
    Map<String, dynamic> payload,
  ) async {
    if (account.isEmpty) {
      return;
    }
    final existing = await getInAppNotifications();
    if (account != AccountCacheStore.owner ||
        generation != AccountCacheStore.generation) {
      return;
    }
    existing.insert(0, <String, dynamic>{
      'type': type,
      'title': title,
      'body': body,
      'payload': payload,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
    await AccountCacheStore.write(
        'in_app_notifications', existing.take(100).toList(),
        account: account, generation: generation, ttl: const Duration(days: 7));
  }

  /// Only the authenticated account's recent local notifications are visible.
  Future<List<Map<String, dynamic>>> getInAppNotifications() async {
    final account = AccountCacheStore.owner;
    final generation = AccountCacheStore.generation;
    final raw = await AccountCacheStore.read('in_app_notifications');
    if (account.isEmpty ||
        account != AccountCacheStore.owner ||
        generation != AccountCacheStore.generation) {
      return <Map<String, dynamic>>[];
    }
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
      final timestamp = DateTime.tryParse(item['timestamp']?.toString() ?? '');
      return timestamp != null &&
          timestamp.isAfter(cutoff) &&
          !timestamp.isAfter(DateTime.now());
    }).toList();
  }
}
