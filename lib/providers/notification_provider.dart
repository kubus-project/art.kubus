import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/socket_service.dart';
import '../services/push_notification_service.dart';

// Note: NotificationProvider will automatically attach to SocketService when created.
// It listens for incoming messages and increments the unread badge when appropriate.

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  bool _hasNew = false;
  int _lastNotifVersion = 0;
  int _lastGlobalVersion = 0;
  String? _lastNotifHash;
  DateTime? _lastNotifTimestamp;

  int get unreadCount => _unreadCount;

  Future<void> refresh() async {
    try {
      final backend = BackendApiService();
      try { await backend.loadAuthToken(); } catch (_) {}
      final count = await backend.getUnreadNotificationCount();
      _unreadCount = count;
      _hasNew = count > 0;
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  NotificationProvider() {
    _initSocketListener();
  }

  void _initSocketListener() async {
    try {
      final socket = SocketService();
      final backend = BackendApiService();
      // Ensure auth token loaded so socket can authenticate
      try { await backend.loadAuthToken(); } catch (_) {}

      // Try to determine current wallet and subscribe to user room if possible
      String? wallet;
      try {
        final me = await backend.getMyProfile();
        if (me['success'] == true && me['data'] != null) {
          final m = me['data'] as Map<String, dynamic>;
          wallet = (m['wallet_address'] ?? m['walletAddress'] ?? m['wallet'])?.toString();
        }
      } catch (_) {}

      if (wallet != null && wallet.isNotEmpty) {
        // connect and subscribe to user room
        try {
          await socket.connectAndSubscribe(backend.baseUrl, wallet);
        } catch (_) {
          // fallback: connect without subscribe
          await socket.connect(backend.baseUrl);
          try { socket.subscribeUser(wallet); } catch (_) {}
        }
      } else {
        await socket.connect(backend.baseUrl);
      }

      socket.onMessageReceived.listen((msg) {
        try {
          // Always refresh from backend for authoritative unread count
          refresh();
        } catch (e) {
          // ignore
        }
      });

      // Listen for generic notifications from the server
      socket.onNotification.listen((payload) async {
        try {
          // Delegate all handling to centralized method
          await handleIncomingNotification(payload);
        } catch (e) {
          // ignore
        }
      });

      socket.onMessageRead.listen((payload) {
        // Recompute unread count by refreshing from backend to stay authoritative
        refresh();
      });

      socket.onConversationMemberRead.listen((payload) {
        // A member read update likely affects unread counts — refresh authoritative value
        refresh();
      });
    } catch (e) {
      // ignore failures; socket will be attempted again later
    }
  }

  /// Bind to the AppRefreshProvider to receive global or specific refresh triggers.
  void bindToRefresh(dynamic appRefresh) {
    try {
      // appRefresh is AppRefreshProvider but avoid importing to keep decoupling for now
      if (appRefresh == null) return;
      _lastNotifVersion = appRefresh.notificationsVersion ?? 0;
      _lastGlobalVersion = appRefresh.globalVersion ?? 0;
      appRefresh.addListener(() {
        try {
          if ((appRefresh.notificationsVersion ?? 0) != _lastNotifVersion) {
            _lastNotifVersion = appRefresh.notificationsVersion ?? 0;
            refresh();
          } else if ((appRefresh.globalVersion ?? 0) != _lastGlobalVersion) {
            _lastGlobalVersion = appRefresh.globalVersion ?? 0;
            refresh();
          }
        } catch (e) { /* ignore */ }
      });
    } catch (e) {
      // ignore
    }
  }

  void increment([int by = 1]) {
    _unreadCount += by;
    _hasNew = true;
    notifyListeners();
  }

  void reset() {
    _unreadCount = 0;
    _hasNew = false;
    notifyListeners();
  }

  void markViewed() {
    _unreadCount = 0;
    _hasNew = false;
    notifyListeners();
  }

  bool get hasNew => _hasNew;

  /// Centralized handler for incoming socket `notification:new` events.
  /// - Performs dedup checks, increments immediate unread count, refreshes authoritative value,
  ///   and shows a local notification when appropriate.
  Future<void> handleIncomingNotification(Map<String, dynamic> payload) async {
    try {
      // Refresh authoritative data (non-blocking)
      try { refresh(); } catch (_) {}

      // Parse notification type and relevant payload fields
      final type = (payload['type'] ?? payload['interactionType'] ?? payload['data']?['type'] ?? '').toString();
      final data = (payload['data'] is Map) ? Map<String, dynamic>.from(payload['data']) : <String, dynamic>{};
      final postId = (data['postId'] ?? data['targetId'] ?? payload['postId'])?.toString();
      final userName = (payload['sender'] is Map && (payload['sender']['displayName'] ?? payload['sender']['username']) != null)
          ? (payload['sender']['displayName'] ?? payload['sender']['username']).toString()
          : (payload['userName'] ?? payload['authorName'] ?? '')?.toString();
      final comment = (data['commentPreview'] ?? payload['comment'])?.toString();

      // Deduplicate repeated events within a short time window
      final dedupeType = (payload['type'] ?? payload['interactionType'] ?? payload['data']?['type'] ?? '').toString();
      final dataMap = (payload['data'] is Map) ? Map<String, dynamic>.from(payload['data']) : <String, dynamic>{};
      final dedupePostId = (dataMap['postId'] ?? dataMap['targetId'] ?? payload['postId'])?.toString() ?? '';
      final dedupeSender = (payload['sender'] is Map && (payload['sender']['displayName'] ?? payload['sender']['username']) != null)
          ? (payload['sender']['displayName'] ?? payload['sender']['username']).toString()
          : (payload['userName'] ?? payload['authorName'] ?? '')?.toString();
      final dedupeHash = [dedupeType, dedupePostId, dedupeSender].join('|');
      if (_lastNotifHash == dedupeHash && _lastNotifTimestamp != null && DateTime.now().difference(_lastNotifTimestamp!).inSeconds < 3) {
        // Skip duplicate
        return;
      }
      _lastNotifHash = dedupeHash;
      _lastNotifTimestamp = DateTime.now();

      // Increment unread count to provide immediate UI feedback
      increment(1);

      // Show local notification for community interactions and other types
      try {
        final pn = PushNotificationService();
        await pn.initialize();
        switch (type) {
          case 'comment':
            await pn.showCommunityInteractionNotification(postId: postId ?? '', type: 'comment', userName: userName ?? 'Someone', comment: comment);
            break;
          case 'like':
            await pn.showCommunityInteractionNotification(postId: postId ?? '', type: 'like', userName: userName ?? 'Someone');
            break;
          case 'share':
            await pn.showCommunityInteractionNotification(postId: postId ?? '', type: 'share', userName: userName ?? 'Someone');
            break;
          case 'mention':
            await pn.showCommunityInteractionNotification(postId: postId ?? '', type: 'mention', userName: userName ?? 'Someone');
            break;
          case 'follower':
            await pn.showFollowerNotification(userId: payload['userId']?.toString() ?? '', userName: userName ?? 'Someone', userAvatar: payload['avatar']);
            break;
          case 'reward':
            await pn.showRewardNotification(title: 'You got a reward!', amount: payload['amount'] ?? 0, reason: payload['reason'] ?? '');
            break;
          case 'artwork_discovery':
            await pn.showArtworkDiscoveryNotification(artworkId: payload['artworkId']?.toString() ?? '', title: payload['title'] ?? '', artist: payload['artist'] ?? '', rewards: payload['rewards'] ?? 0);
            break;
          case 'nft_minting':
            await pn.showNFTMintingNotification(artworkId: payload['artworkId']?.toString() ?? '', artworkTitle: payload['artworkTitle'] ?? '', status: payload['status'] ?? '', transactionId: payload['transactionId']?.toString());
            break;
          case 'trading':
            await pn.showTradingNotification(tradeId: payload['tradeId']?.toString() ?? '', type: payload['tradeType'] ?? 'sale', artworkTitle: payload['artworkTitle'] ?? '', amount: (payload['amount'] is num) ? (payload['amount'] as num).toDouble() : 0.0, buyerName: payload['buyerName'], sellerName: payload['sellerName']);
            break;
          case 'achievement':
            await pn.showAchievementNotification(achievementId: payload['achievementId']?.toString() ?? '', title: payload['title'] ?? 'Achievement', description: payload['description'] ?? '', rewardTokens: payload['rewardTokens'] ?? 0);
            break;
          default:
            // For other types, do not show a local notification but we already updated UI counters
            break;
        }
      } catch (e) {
        debugPrint('NotificationProvider: failed to show local notification: $e');
      }
    } catch (e) {
      // ignore
    }
  }
}
