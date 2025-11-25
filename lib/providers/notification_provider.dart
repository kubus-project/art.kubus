import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backend_api_service.dart';
import '../services/socket_service.dart';
import '../services/push_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final BackendApiService _backend = BackendApiService();
  final SocketService _socket = SocketService();
  final PushNotificationService _pushService = PushNotificationService();

  // Community notifications (likes, comments, follows)
  int _communityUnreadCount = 0;
  
  bool _hasNew = false;
  int _lastNotifVersion = 0;
  int _lastGlobalVersion = 0;
  String? _lastNotifHash;
  DateTime? _lastNotifTimestamp;
  bool _initialized = false;
  bool _initializing = false;
  bool _refreshInFlight = false;
  bool _socketListenersRegistered = false;
  bool _connectListenerRegistered = false;
  String? _currentWallet;
  Timer? _subscriptionMonitorTimer;
  Timer? _scheduledServerSync;
  Timer? _autoRefreshTimer;
  DateTime? _lastServerSync;
  static const String _prefsUnreadPrefix = 'notifications_unread_count_';
  final Duration _minServerSyncInterval = const Duration(seconds: 8);
  final Duration _autoRefreshInterval = const Duration(seconds: 45);

  // Only community notifications (messages handled by ChatProvider)
  int get unreadCount => _communityUnreadCount;
  bool get hasNew => _hasNew;

  NotificationProvider() {
    debugPrint('NotificationProvider: Constructor called');
    // Defer heavy work until the widget tree is ready; initialization is invoked
    // explicitly from ArtKubus after providers mount. This constructor only logs
    // so unit tests/builds without Material bindings do not start async work.
  }

  Future<void> initialize({String? walletOverride, bool force = false}) async {
    if (_initializing) return;
    _initializing = true;
    
    debugPrint('NotificationProvider.initialize: START force=$force');
    
    try {
      try {
        await _backend.loadAuthToken();
      } catch (e) {
        debugPrint('NotificationProvider.initialize: loadAuthToken failed: $e');
      }

      final resolvedWallet = await _resolveWallet(walletOverride);
      final normalizedWallet = resolvedWallet?.trim();
      final walletChanged = normalizedWallet != null && normalizedWallet.isNotEmpty &&
          (normalizedWallet.toLowerCase() != (_currentWallet ?? '').toLowerCase());

      debugPrint('NotificationProvider.initialize: wallet=$normalizedWallet, changed=$walletChanged');

      // Always register listeners (idempotent)
      _registerSocketListeners();
      
      if (_initialized && !force && !walletChanged) {
        debugPrint('NotificationProvider.initialize: already initialized, skipping');
        return;
      }

      if (normalizedWallet == null || normalizedWallet.isEmpty) {
        debugPrint('NotificationProvider.initialize: wallet not available yet, listeners registered');
        _initialized = false;
        return;
      }

      _stopAutoRefreshLoop();
      _scheduledServerSync?.cancel();
      _currentWallet = normalizedWallet;
      _initialized = true;

      // Hydrate immediate unread count from cache for snappy UI updates
      try {
        await _hydrateUnreadFromCache(_currentWallet!);
      } catch (e) {
        debugPrint('NotificationProvider.initialize: hydrate cache failed: $e');
      }

      // Ensure socket connection is alive. ChatProvider already connects, but
      // calling connect() again is safe and will no-op when already connected.
      try {
        await _socket.connect(_backend.baseUrl);
        // Ensure we are subscribed to user's room so incoming notifications are delivered
        try {
          if (_currentWallet != null && _currentWallet!.isNotEmpty) {
            var ok = await _socket.connectAndSubscribe(_backend.baseUrl, _currentWallet!);
            debugPrint('NotificationProvider.initialize: connectAndSubscribe result: $ok');
             debugPrint('NotificationProvider.initialize: socket currentSubscribedWallet=${_socket.currentSubscribedWallet}');
            if (!ok) {
              debugPrint('NotificationProvider.initialize: connectAndSubscribe failed, falling back to subscribeUser');
              _socket.subscribeUser(_currentWallet!);
            }
          }
        } catch (e) {
          debugPrint('NotificationProvider.initialize: subscribe to user room failed: $e');
        }
        debugPrint('NotificationProvider.initialize: socket connected');
      } catch (e) {
        debugPrint('NotificationProvider.initialize: socket connect failed: $e');
      }

      // Refresh unread count immediately so UI reflects backend state.
      await refresh(force: true);
      _startAutoRefreshLoop();
      // Start subscription monitor to ensure we remain subscribed to user's socket room
      _startSubscriptionMonitor();
      debugPrint('NotificationProvider.initialize: COMPLETE, unread=$_communityUnreadCount');
    } finally {
      _initializing = false;
    }
  }

  Future<String?> _resolveWallet(String? override) async {
    if (override != null && override.isNotEmpty) return override;
    try {
      final me = await _backend.getMyProfile();
      if (me['success'] == true && me['data'] != null) {
        final data = me['data'] as Map<String, dynamic>;
        final wallet = (data['wallet_address'] ?? data['walletAddress'] ?? data['wallet'])?.toString();
        if (wallet != null && wallet.isNotEmpty) return wallet;
      }
    } catch (e) {
      debugPrint('NotificationProvider._resolveWallet: getMyProfile failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('wallet_address') ?? prefs.getString('wallet');
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (e) {
      debugPrint('NotificationProvider._resolveWallet: prefs read failed: $e');
    }
    return null;
  }

  void _registerSocketListeners() {
    if (!_socketListenersRegistered) {
      _socket.addNotificationListener(_handleSocketNotification);
      _socketListenersRegistered = true;
      debugPrint('NotificationProvider: notification listener registered');
    }
    if (!_connectListenerRegistered) {
      _socket.addConnectListener(_handleSocketReconnect);
      _connectListenerRegistered = true;
    }
  }

  void _handleSocketReconnect() {
    // When socket reconnects (after background or connectivity issues), refresh
    // the unread count so badges remain accurate without waiting for the next
    // server push event.
    unawaited(refresh(force: true));
  }

  void _startSubscriptionMonitor() {
    try {
      _subscriptionMonitorTimer?.cancel();
      _subscriptionMonitorTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
        try {
          if (_currentWallet == null || _currentWallet!.isEmpty) return;
          final subscribed = _socket.currentSubscribedWallet;
          if (subscribed == null || subscribed.toLowerCase() != _currentWallet!.toLowerCase()) {
            debugPrint('NotificationProvider: subscription monitor detected mismatch (subscribed=$subscribed expected=$_currentWallet), attempting resubscribe');
            var ok = false;
            try {
              ok = await _socket.connectAndSubscribe(_backend.baseUrl, _currentWallet!);
            } catch (e) {
              debugPrint('NotificationProvider: subscription monitor connectAndSubscribe threw: $e');
            }
            debugPrint('NotificationProvider: subscription monitor connectAndSubscribe -> $ok');
            if (!ok) {
              debugPrint('NotificationProvider: subscription monitor fallback to subscribeUser');
              _socket.subscribeUser(_currentWallet!);
            }
              // extra reconnect logic handled by connectAndSubscribe above and fallback to subscribeUser
          }
        } catch (e) {
          debugPrint('NotificationProvider._startSubscriptionMonitor check failed: $e');
        }
      });
    } catch (e) {
      debugPrint('NotificationProvider._startSubscriptionMonitor failed to start: $e');
    }
  }

  void _startAutoRefreshLoop() {
    try {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
        if (!_initialized) return;
        if (_currentWallet == null || _currentWallet!.isEmpty) return;
        _scheduleServerSync();
      });
    } catch (e) {
      debugPrint('NotificationProvider._startAutoRefreshLoop failed: $e');
    }
  }

  void _stopAutoRefreshLoop() {
    try {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    } catch (_) {}
  }

  void _scheduleServerSync({Duration? delay, bool force = false}) {
    if ((_currentWallet == null || _currentWallet!.isEmpty) && !_initializing) {
      return;
    }
    final computedDelay = force
        ? (delay ?? Duration.zero)
        : _computeSyncDelay(delay);
    _scheduledServerSync?.cancel();
    _scheduledServerSync = Timer(computedDelay, () {
      _scheduledServerSync = null;
      unawaited(_syncUnreadCount(force: force));
    });
  }

  Duration _computeSyncDelay(Duration? requested) {
    if (requested != null) return requested;
    if (_lastServerSync == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastServerSync!);
    if (elapsed >= _minServerSyncInterval) return Duration.zero;
    return _minServerSyncInterval - elapsed;
  }

  Future<void> _hydrateUnreadFromCache(String wallet) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt('$_prefsUnreadPrefix${wallet.toLowerCase()}');
      if (cached != null) {
        final changed = cached != _communityUnreadCount || _hasNew != (cached > 0);
        _communityUnreadCount = cached;
        _hasNew = cached > 0;
        if (changed) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('NotificationProvider: failed to hydrate unread cache: $e');
    }
  }

  Future<void> _persistUnreadCount(int count) async {
    if (_currentWallet == null || _currentWallet!.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefsUnreadPrefix${_currentWallet!.toLowerCase()}', count);
    } catch (e) {
      debugPrint('NotificationProvider: failed to persist unread cache: $e');
    }
  }

  Future<void> refresh({bool force = false}) async {
    if ((_currentWallet == null || _currentWallet!.isEmpty) && !_initializing) {
      debugPrint('NotificationProvider.refresh: no wallet, attempting rehydrate');
      try {
        final resolved = await _resolveWallet(null);
        if (resolved != null && resolved.isNotEmpty) {
          await initialize(walletOverride: resolved, force: true);
          if (_initialized) {
            return;
          }
        }
      } catch (e) {
        debugPrint('NotificationProvider.refresh: wallet rehydrate failed: $e');
      }
    }

    if (force) {
      _scheduledServerSync?.cancel();
      await _syncUnreadCount(force: true);
      return;
    }

    _scheduleServerSync();
  }

  Future<void> _syncUnreadCount({bool force = false}) async {
    if ((_currentWallet == null || _currentWallet!.isEmpty) && !_initializing) {
      return;
    }

    if (_refreshInFlight && !force) {
      debugPrint('NotificationProvider.refresh: already in flight, skipping');
      return;
    }

    _refreshInFlight = true;
    try {
      try {
        await _backend.loadAuthToken();
      } catch (_) {}
      final token = _backend.getAuthToken();
      if (token == null || token.isEmpty) {
        debugPrint('NotificationProvider.refresh: skipping unread fetch — no auth token available');
        if (_communityUnreadCount != 0 || _hasNew) {
          _communityUnreadCount = 0;
          _hasNew = false;
          await _persistUnreadCount(0);
          notifyListeners();
        }
        return;
      }

      final count = await _backend.getUnreadNotificationCount();
      final oldCount = _communityUnreadCount;
      _communityUnreadCount = count;
      _hasNew = count > 0;
      _lastServerSync = DateTime.now();
      await _persistUnreadCount(count);

      debugPrint('NotificationProvider.refresh: count=$count (was $oldCount)');

      if (count != oldCount || (_hasNew != (oldCount > 0))) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NotificationProvider.refresh error: $e');
    } finally {
      _refreshInFlight = false;
    }
  }

  void _handleSocketNotification(Map<String, dynamic> data) {
    try {
      final typeRaw = (data['type'] ?? data['event'] ?? data['action'])?.toString().toLowerCase() ?? '';
      debugPrint('NotificationProvider._handleSocketNotification: type=$typeRaw, data=$data');
      
      final isReadEvent = typeRaw.contains('read') && !typeRaw.contains('new');

      if (isReadEvent) {
        debugPrint('NotificationProvider: read-all event received');
        _communityUnreadCount = 0;
        _hasNew = false;
        notifyListeners();
        unawaited(_persistUnreadCount(0));
        _scheduleServerSync(delay: const Duration(seconds: 1));
        return;
      }

      // Increment for new notification
      _communityUnreadCount++;
      _hasNew = true;
      debugPrint('NotificationProvider: new notification, count now $_communityUnreadCount');
      
      // Force immediate UI update
      notifyListeners();
      unawaited(_persistUnreadCount(_communityUnreadCount));

      // Show local push notification
      unawaited(handleIncomingNotification(data));
      
      // Sync with backend
      _scheduleServerSync(delay: const Duration(milliseconds: 600));
    } catch (e) {
      debugPrint('NotificationProvider._handleSocketNotification error: $e');
    }
  }

  /// Bind to the AppRefreshProvider to receive global or specific refresh triggers.
  void bindToRefresh(dynamic appRefresh) {
    try {
      if (appRefresh == null) return;
      _lastNotifVersion = appRefresh.notificationsVersion ?? 0;
      _lastGlobalVersion = appRefresh.globalVersion ?? 0;
      appRefresh.addListener(() {
        try {
          if ((appRefresh.notificationsVersion ?? 0) != _lastNotifVersion) {
            _lastNotifVersion = appRefresh.notificationsVersion ?? 0;
            refresh(force: true);
          } else if ((appRefresh.globalVersion ?? 0) != _lastGlobalVersion) {
            _lastGlobalVersion = appRefresh.globalVersion ?? 0;
            refresh(force: true);
          }
        } catch (e) { /* ignore */ }
      });
    } catch (e) {
      // ignore
    }
  }

  void increment([int by = 1]) {
    _communityUnreadCount += by;
    _hasNew = true;
    debugPrint('NotificationProvider.increment: by=$by, total=$_communityUnreadCount');
    notifyListeners();
    _scheduleServerSync(delay: const Duration(seconds: 1));
    unawaited(_persistUnreadCount(_communityUnreadCount));
  }

  void reset() {
    _communityUnreadCount = 0;
    _hasNew = false;
    debugPrint('NotificationProvider.reset');
    notifyListeners();
    unawaited(_persistUnreadCount(0));
  }

  Future<void> markViewed({bool syncServer = true}) async {
    _communityUnreadCount = 0;
    _hasNew = false;
    debugPrint('NotificationProvider.markViewed');
    notifyListeners();
    unawaited(_persistUnreadCount(0));
    if (syncServer) {
      try {
        await _backend.markAllNotificationsAsRead();
      } catch (e) {
        debugPrint('NotificationProvider.markViewed: backend sync failed: $e');
      }
    }
  }

  /// Centralized handler for incoming socket `notification:new` events.
  /// - Performs dedup checks, increments immediate unread count, refreshes authoritative value,
  ///   and shows a local notification when appropriate.
  Future<void> handleIncomingNotification(Map<String, dynamic> payload) async {
    try {
      // Refresh authoritative data (non-blocking)
      _scheduleServerSync(delay: const Duration(milliseconds: 600));

      // Parse notification type and relevant payload fields
      // Work on a mutable copy for potential raw wrappers
      var parsedPayload = Map<String, dynamic>.from(payload);
      String resolvedType = (parsedPayload['type'] ?? parsedPayload['interactionType'] ?? parsedPayload['data']?['type'] ?? '').toString();
      if (resolvedType.isEmpty && parsedPayload['raw'] != null) {
        try {
          final raw = parsedPayload['raw'];
          if (raw is String) {
            final parsed = jsonDecode(raw) as Map<String, dynamic>?;
            if (parsed != null) {
              parsedPayload = Map<String, dynamic>.from(parsed);
            }
          } else if (raw is Map) {
            parsedPayload = Map<String, dynamic>.from(raw);
          }
        } catch (_) {}
        resolvedType = (parsedPayload['type'] ?? parsedPayload['interactionType'] ?? parsedPayload['data']?['type'] ?? '').toString();
      }

      final normalizedType = resolvedType.toLowerCase();
      final data = (parsedPayload['data'] is Map)
          ? Map<String, dynamic>.from(parsedPayload['data'] as Map)
          : <String, dynamic>{};
      final postId = (data['postId'] ?? data['targetId'] ?? parsedPayload['postId'])?.toString();
      final comment = (data['commentPreview'] ?? parsedPayload['comment'])?.toString();

      String? userName;
      String? userAvatar;
      final sender = parsedPayload['sender'];
      if (sender is Map) {
        userName = (sender['displayName'] ?? sender['username'] ?? sender['name'])?.toString();
        userAvatar = sender['avatar']?.toString() ?? sender['avatarUrl']?.toString();
      }
      userName ??= (parsedPayload['userName'] ?? parsedPayload['authorName'])?.toString();
      userAvatar ??= parsedPayload['avatar']?.toString();

      final followerWallet = (data['followerWallet'] ?? data['walletAddress'] ?? data['wallet'] ?? parsedPayload['followerWallet'] ?? parsedPayload['userId'])?.toString();

      // Deduplicate repeated events within a short time window
      final dedupeSource = followerWallet?.isNotEmpty == true ? followerWallet : (userName ?? '');
      final dedupeHash = [normalizedType, postId ?? '', dedupeSource ?? ''].join('|');
      if (_lastNotifHash == dedupeHash && _lastNotifTimestamp != null && DateTime.now().difference(_lastNotifTimestamp!).inSeconds < 3) {
        // Skip duplicate
        return;
      }
      _lastNotifHash = dedupeHash;
      _lastNotifTimestamp = DateTime.now();

      // Show local notification for community interactions and other types
      try {
        await _pushService.initialize();
        switch (normalizedType) {
          case 'comment':
            await _pushService.showCommunityInteractionNotification(postId: postId ?? '', type: 'comment', userName: userName ?? 'Someone', comment: comment);
            break;
          case 'like':
            await _pushService.showCommunityInteractionNotification(postId: postId ?? '', type: 'like', userName: userName ?? 'Someone');
            break;
          case 'share':
            await _pushService.showCommunityInteractionNotification(postId: postId ?? '', type: 'share', userName: userName ?? 'Someone');
            break;
          case 'mention':
            await _pushService.showCommunityInteractionNotification(postId: postId ?? '', type: 'mention', userName: userName ?? 'Someone');
            break;
          case 'follow':
          case 'follower':
          case 'followed':
            final followerId = (followerWallet ?? '').isNotEmpty
                ? followerWallet!
                : (parsedPayload['userId']?.toString() ?? '');
            if (followerId.isNotEmpty) {
              await _pushService.showFollowerNotification(
                userId: followerId,
                userName: userName ?? 'Someone',
                userAvatar: userAvatar ?? data['avatar']?.toString(),
              );
            }
            break;
          case 'reward':
            await _pushService.showRewardNotification(title: 'You got a reward!', amount: payload['amount'] ?? 0, reason: payload['reason'] ?? '');
            break;
          case 'artwork_discovery':
            await _pushService.showArtworkDiscoveryNotification(artworkId: payload['artworkId']?.toString() ?? '', title: payload['title'] ?? '', artist: payload['artist'] ?? '', rewards: payload['rewards'] ?? 0);
            break;
          case 'nft_minting':
            await _pushService.showNFTMintingNotification(artworkId: payload['artworkId']?.toString() ?? '', artworkTitle: payload['artworkTitle'] ?? '', status: payload['status'] ?? '', transactionId: payload['transactionId']?.toString());
            break;
          case 'trading':
            await _pushService.showTradingNotification(tradeId: payload['tradeId']?.toString() ?? '', type: payload['tradeType'] ?? 'sale', artworkTitle: payload['artworkTitle'] ?? '', amount: (payload['amount'] is num) ? (payload['amount'] as num).toDouble() : 0.0, buyerName: payload['buyerName'], sellerName: payload['sellerName']);
            break;
          case 'achievement':
            await _pushService.showAchievementNotification(achievementId: payload['achievementId']?.toString() ?? '', title: payload['title'] ?? 'Achievement', description: payload['description'] ?? '', rewardTokens: payload['rewardTokens'] ?? 0);
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

  @override
  void dispose() {
    if (_socketListenersRegistered) {
      _socket.removeNotificationListener(_handleSocketNotification);
      _socketListenersRegistered = false;
    }
    if (_connectListenerRegistered) {
      _socket.removeConnectListener(_handleSocketReconnect);
      _connectListenerRegistered = false;
    }
    _subscriptionMonitorTimer?.cancel();
    _subscriptionMonitorTimer = null;
    _scheduledServerSync?.cancel();
    _scheduledServerSync = null;
    _stopAutoRefreshLoop();
    super.dispose();
  }
}
