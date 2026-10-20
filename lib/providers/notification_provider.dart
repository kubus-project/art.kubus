import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../l10n/app_localizations_sl.dart';
import '../services/backend_api_service.dart';
import '../services/socket_service.dart';
import '../utils/account_identity.dart';
import '../services/push_notification_service.dart';
import '../utils/wallet_utils.dart';
import 'app_refresh_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final BackendApiService _backend = BackendApiService();
  final SocketService _socket = SocketService();
  final PushNotificationService _pushService = PushNotificationService();

  // Community notifications (likes, comments, follows)
  int _communityUnreadCount = 0;
  int _messageUnreadCount = 0;

  bool _hasNew = false;
  int _lastNotifVersion = 0;
  int _lastGlobalVersion = 0;
  AppRefreshProvider? _boundRefreshProvider;
  VoidCallback? _refreshListener;
  bool _initialized = false;
  bool _initializing = false;
  bool _refreshInFlight = false;
  bool _socketListenersRegistered = false;
  bool _summarySocketListenerRegistered = false;
  bool _connectListenerRegistered = false;
  String? _currentWallet;
  String? _currentAccountId;
  int _summaryRevision = 0;
  int _summaryRequestVersion = 0;
  final Set<String> _shownEventIds = <String>{};
  Timer? _scheduledServerSync;
  DateTime? _scheduledServerSyncDueAt;
  Timer? _cadenceTimer;
  Duration? _cadenceInterval;
  DateTime? _lastSubscriptionCheckAt;
  DateTime? _lastServerSync;
  final Duration _minServerSyncInterval = const Duration(seconds: 8);
  final Duration _degradedForegroundCadence = const Duration(seconds: 55);
  final Duration _degradedBackgroundCadence = const Duration(seconds: 150);
  final Duration _healthySocketCadence = const Duration(minutes: 5);
  final Duration _subscriptionCheckInterval = const Duration(minutes: 3);

  int _debugCadenceTicks = 0;
  int _debugSyncs = 0;
  int _debugSkippedSyncs = 0;
  bool get _hasAuthToken => (_backend.getAuthToken() ?? '').isNotEmpty;
  bool get _hasAuthContext =>
      _hasAuthToken ||
      ((_currentWallet ?? '').isNotEmpty) ||
      _currentAccountId != null;

  AppLocalizations get _l10n {
    final languageCode =
        ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return languageCode == 'sl' ? AppLocalizationsSl() : AppLocalizationsEn();
  }

  // Counts are always taken from the backend summary. ChatProvider owns
  // conversation row state; this provider supplies app-wide unread totals.
  int get unreadCount => _communityUnreadCount;
  int get messageUnreadCount => _messageUnreadCount;
  int get totalUnreadCount => _communityUnreadCount + _messageUnreadCount;
  bool get hasNew => _hasNew;

  NotificationProvider() {
    // Defer heavy work until the widget tree is ready; initialization is invoked
    // explicitly from ArtKubus after providers mount. This constructor must not
    // start async work so unit tests/builds without Material bindings stay safe.
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

      final hasSession = await _backend.restoreExistingSession();
      if (!hasSession) {
        if (kDebugMode) {
          debugPrint(
            'NotificationProvider.initialize: skipping protected init - no restored auth session',
          );
        }
        if (_currentAccountId != null) {
          _socket.unsubscribeAccount(_currentAccountId!);
        } else if ((_currentWallet ?? '').isNotEmpty) {
          _socket.unsubscribeUser(_currentWallet!);
        }
        _resetSessionState(clearUnreadCount: true);
        return;
      }

      final claims = _backend.getCurrentAuthTokenClaims();
      final accountId = accountUserIdFromClaims(claims);
      final resolvedWallet = await _resolveWallet(
        walletOverride,
        accountId: accountId,
      );
      final normalizedWallet = WalletUtils.normalize(resolvedWallet);
      final walletChanged =
          _initialized && !WalletUtils.equals(normalizedWallet, _currentWallet);
      final accountChanged = _initialized && accountId != _currentAccountId;

      debugPrint(
        'NotificationProvider.initialize: wallet=$normalizedWallet, changed=$walletChanged',
      );

      // Always register listeners (idempotent)
      _registerSocketListeners();

      if (_initialized && !force && !walletChanged && !accountChanged) {
        debugPrint(
          'NotificationProvider.initialize: already initialized, skipping',
        );
        return;
      }

      if ((_initialized && walletChanged) || accountChanged) {
        if (accountChanged && _currentAccountId != null) {
          _socket.unsubscribeAccount(_currentAccountId!);
        }
        _resetSessionState(clearUnreadCount: true);
      } else {
        _stopAutoRefreshLoop();
        _scheduledServerSync?.cancel();
        _scheduledServerSync = null;
        _scheduledServerSyncDueAt = null;
      }
      _currentWallet = normalizedWallet.isEmpty ? null : normalizedWallet;
      _currentAccountId = accountId;
      _initialized = true;

      // Ensure socket connection is alive. ChatProvider already connects, but
      // calling connect() again is safe and will no-op when already connected.
      try {
        await _socket.connect(_backend.baseUrl);
        // Ensure we are subscribed to user's room so incoming notifications are delivered
        try {
          final roomIdentity = _currentAccountId ?? _currentWallet;
          if (roomIdentity != null && roomIdentity.isNotEmpty) {
            final isAccountId = _currentAccountId != null;
            var ok = isAccountId
                ? await _socket.connectAndSubscribeAccount(
                    _backend.baseUrl,
                    roomIdentity,
                  )
                : await _socket.connectAndSubscribe(
                    _backend.baseUrl,
                    roomIdentity,
                  );
            debugPrint(
              'NotificationProvider.initialize: connectAndSubscribe result: $ok',
            );
            debugPrint(
              'NotificationProvider.initialize: socket currentSubscribedWallet=${_socket.currentSubscribedWallet}',
            );
            if (!ok) {
              debugPrint(
                'NotificationProvider.initialize: connectAndSubscribe failed, falling back to subscribeUser',
              );
              if (isAccountId) {
                _socket.subscribeAccount(roomIdentity);
              } else {
                _socket.subscribeUser(roomIdentity);
              }
            }
          }
        } catch (e) {
          debugPrint(
            'NotificationProvider.initialize: subscribe to user room failed: $e',
          );
        }
        debugPrint('NotificationProvider.initialize: socket connected');
      } catch (e) {
        debugPrint(
          'NotificationProvider.initialize: socket connect failed: $e',
        );
      }

      // Refresh unread count immediately so UI reflects backend state.
      await refresh(force: true);
      _ensureCadenceTimer(forceRestart: true);
      debugPrint(
        'NotificationProvider.initialize: COMPLETE, unread=$_communityUnreadCount',
      );
    } finally {
      _initializing = false;
    }
  }

  Future<String?> _resolveWallet(
    String? override, {
    String? accountId,
  }) async {
    try {
      if (_hasAuthToken) {
        final me = await _backend.getMyProfile();
        if (me['success'] == true && me['data'] != null) {
          final data = me['data'] as Map<String, dynamic>;
          final wallet = (data['wallet_address'] ??
                  data['walletAddress'] ??
                  data['wallet'])
              ?.toString();
          if (wallet != null && wallet.isNotEmpty) return wallet;
        }
      }
    } catch (e) {
      debugPrint(
        'NotificationProvider._resolveWallet: getMyProfile failed: $e',
      );
    }

    // A cached wallet can belong to the account that used this device before
    // the current walletless account. Never use it as a room identity when the
    // authenticated token names an account but has no wallet claim.
    // An authenticated account without a profile wallet must stay walletless;
    // an override or persisted wallet may belong to the previous account.
    if (accountId != null) return null;

    if (override != null && override.isNotEmpty) return override;

    final tokenWallet = _backend.getCurrentAuthWalletAddress();
    if (tokenWallet != null && tokenWallet.isNotEmpty) return tokenWallet;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored =
          prefs.getString('wallet_address') ?? prefs.getString('wallet');
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
    if (!_summarySocketListenerRegistered) {
      _socket.addUnreadSummaryListener(_handleUnreadSummary);
      _summarySocketListenerRegistered = true;
    }
    if (!_connectListenerRegistered) {
      _socket.addConnectListener(_handleSocketReconnect);
      _connectListenerRegistered = true;
    }
  }

  void _resetSessionState({required bool clearUnreadCount}) {
    _scheduledServerSync?.cancel();
    _scheduledServerSync = null;
    _scheduledServerSyncDueAt = null;
    _stopAutoRefreshLoop();
    _lastSubscriptionCheckAt = null;
    _refreshInFlight = false;
    _lastServerSync = null;
    _currentWallet = null;
    _currentAccountId = null;
    _initialized = false;
    _summaryRevision++;
    _summaryRequestVersion++;
    _shownEventIds.clear();

    if (clearUnreadCount) {
      final changed =
          _communityUnreadCount != 0 || _messageUnreadCount != 0 || _hasNew;
      _communityUnreadCount = 0;
      _messageUnreadCount = 0;
      _hasNew = false;
      if (changed) {
        notifyListeners();
      }
    } else {
      _hasNew = _communityUnreadCount > 0;
    }
  }

  void _handleSocketReconnect() {
    unawaited(_refreshAfterSocketReconnect());
  }

  Future<void> _refreshAfterSocketReconnect() async {
    final wallet = _currentWallet;
    if (!_hasAuthContext) return;
    final accountId = _currentAccountId;
    final identity = accountId ?? wallet;
    if (identity != null && identity.isNotEmpty) {
      try {
        final ok = accountId != null
            ? await _socket.connectAndSubscribeAccount(
                _backend.baseUrl,
                accountId,
              )
            : await _socket.connectAndSubscribe(_backend.baseUrl, identity);
        if (!ok) {
          if (accountId != null) {
            _socket.subscribeAccount(accountId);
          } else {
            _socket.subscribeUser(identity);
          }
        }
      } catch (e) {
        debugPrint('NotificationProvider: reconnect resubscribe failed: $e');
      }
    }
    // Account rooms are joined from the authenticated socket token, so a
    // walletless account still receives summaries after reconnect.
    await refresh(force: true);
  }

  void _ensureCadenceTimer({bool forceRestart = false}) {
    final interval = _computeCadenceInterval();
    if (interval == null) {
      _cadenceTimer?.cancel();
      _cadenceTimer = null;
      _cadenceInterval = null;
      return;
    }

    if (!forceRestart &&
        _cadenceTimer != null &&
        _cadenceInterval == interval) {
      return;
    }

    _cadenceTimer?.cancel();
    _cadenceInterval = interval;
    if (kDebugMode) {
      debugPrint(
        'NotificationProvider: cadence interval set to ${interval.inSeconds}s',
      );
    }
    _cadenceTimer = Timer.periodic(interval, (_) {
      if (!_initialized) return;
      if (!_isForeground) return;
      _debugCadenceTicks++;
      _maybeCheckSubscription();
      if (_isSocketHealthyForNotifications()) {
        return;
      }
      _scheduleServerSync();
    });
  }

  Duration? _computeCadenceInterval() {
    if (!_initialized) return null;
    if (!_isForeground) return null;
    if (_isSocketHealthyForNotifications()) {
      return _isNotificationsSurfaceActive ? _healthySocketCadence : null;
    }
    final active = _isNotificationsSurfaceActive;
    return active ? _degradedForegroundCadence : _degradedBackgroundCadence;
  }

  bool get _isForeground => _boundRefreshProvider?.isAppForeground ?? true;

  bool get _isNotificationsSurfaceActive {
    return _boundRefreshProvider?.isViewActive(
          AppRefreshProvider.viewNotifications,
          grace: const Duration(minutes: 2),
          defaultIfUnknown: false,
        ) ??
        false;
  }

  bool _isSocketHealthyForNotifications() {
    if (!_socket.isConnected) return false;
    final accountId = _currentAccountId;
    if (accountId != null) {
      return _socket.currentSubscribedIdentityIsAccount &&
          _socket.currentSubscribedAccountId == accountId;
    }
    final expectedWallet = WalletUtils.canonical(_currentWallet);
    if (expectedWallet.isEmpty) return false;
    final subscribed = WalletUtils.canonical(_socket.currentSubscribedWallet);
    return subscribed.isNotEmpty && subscribed == expectedWallet;
  }

  void handleAppForegroundChanged(bool isForeground) {
    _ensureCadenceTimer(forceRestart: true);
    if (isForeground) {
      if (_isSocketHealthyForNotifications()) {
        if (_isNotificationsSurfaceActive) {
          _scheduleServerSync(force: true);
        } else {
          _maybeCheckSubscription();
        }
      } else {
        _scheduleServerSync(force: true);
      }
    }
  }

  void handleViewVisibilityChanged() {
    _ensureCadenceTimer(forceRestart: true);
    if (_isNotificationsSurfaceActive && !_isSocketHealthyForNotifications()) {
      _scheduleServerSync();
    }
  }

  void _stopAutoRefreshLoop() {
    _cadenceTimer?.cancel();
    _cadenceTimer = null;
    _cadenceInterval = null;
  }

  void _scheduleServerSync({Duration? delay, bool force = false}) {
    if (!_hasAuthContext) {
      return;
    }
    if (!force &&
        delay == null &&
        _isSocketHealthyForNotifications() &&
        !_isNotificationsSurfaceActive) {
      return;
    }
    if (_refreshInFlight && !force) {
      _debugSkippedSyncs++;
      return;
    }
    final computedDelay =
        force ? (delay ?? Duration.zero) : _computeSyncDelay(delay);
    final dueAt = DateTime.now().add(computedDelay);
    if (!force &&
        _scheduledServerSync != null &&
        (_scheduledServerSync?.isActive ?? false) &&
        _scheduledServerSyncDueAt != null &&
        _scheduledServerSyncDueAt!.isBefore(dueAt)) {
      _debugSkippedSyncs++;
      return;
    }
    _scheduledServerSync?.cancel();
    _scheduledServerSyncDueAt = dueAt;
    _scheduledServerSync = Timer(computedDelay, () {
      _scheduledServerSync = null;
      _scheduledServerSyncDueAt = null;
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

  Future<void> refresh({bool force = false}) async {
    if (!_hasAuthContext) {
      return;
    }

    if (force) {
      _scheduledServerSync?.cancel();
      await _syncUnreadCount(force: true);
      return;
    }

    _scheduleServerSync();
  }

  Future<void> _syncUnreadCount({bool force = false}) async {
    if (!_hasAuthContext) {
      return;
    }

    if (_refreshInFlight && !force) {
      debugPrint('NotificationProvider.refresh: already in flight, skipping');
      _debugSkippedSyncs++;
      return;
    }

    _refreshInFlight = true;
    try {
      try {
        await _backend.loadAuthToken();
      } catch (_) {}
      final hasSession = await _backend.restoreExistingSession();
      final token = _backend.getAuthToken();
      if (!hasSession || token == null || token.isEmpty) {
        debugPrint(
          'NotificationProvider.refresh: skipping unread fetch - no auth token available',
        );
        _resetSessionState(clearUnreadCount: true);
        return;
      }

      final requestVersion = ++_summaryRequestVersion;
      final observedRevision = _summaryRevision;
      final summary = await _backend.getUnreadNotificationSummary();
      if (summary == null ||
          requestVersion != _summaryRequestVersion ||
          observedRevision != _summaryRevision) {
        return;
      }
      _applyUnreadSummary(<String, dynamic>{
        'notifications': <String, dynamic>{
          'unreadCount': summary.notificationsUnreadCount,
        },
        'messages': <String, dynamic>{
          'unreadCount': summary.messagesUnreadCount,
        },
        'totalUnreadCount': summary.totalUnreadCount,
        if (summary.generatedAt != null)
          'generatedAt': summary.generatedAt!.toIso8601String(),
      });
      _lastServerSync = DateTime.now();
      _debugSyncs++;
    } catch (e) {
      debugPrint('NotificationProvider.refresh error: $e');
    } finally {
      _refreshInFlight = false;
    }
  }

  void _handleSocketNotification(Map<String, dynamic> data) {
    if (!_hasAuthContext) return;
    try {
      final typeRaw = (data['type'] ?? data['event'] ?? data['action'])
              ?.toString()
              .toLowerCase() ??
          '';
      final isReadEvent = typeRaw.contains('read') && !typeRaw.contains('new');
      if (isReadEvent) {
        _summaryRevision++;
        _scheduleServerSync(
          delay: const Duration(milliseconds: 300),
          force: true,
        );
        return;
      }
      _summaryRevision++;
      _scheduleServerSync(
        delay: const Duration(milliseconds: 300),
        force: true,
      );

      // Message notifications are represented by the chat transport and its
      // message-specific local notification. The summary event updates their
      // badge count; displaying this row as well would duplicate the DM alert.
      if (typeRaw == 'message' || typeRaw == 'dm') return;
      unawaited(handleIncomingNotification(data));
    } catch (e) {
      debugPrint('NotificationProvider._handleSocketNotification error: $e');
    }
  }

  void _handleUnreadSummary(Map<String, dynamic> payload) {
    if (!_hasAuthContext) return;
    _summaryRevision++;
    _summaryRequestVersion++;
    _scheduledServerSync?.cancel();
    _scheduledServerSync = null;
    _scheduledServerSyncDueAt = null;
    _applyUnreadSummary(payload);
    _lastServerSync = DateTime.now();
  }

  void _applyUnreadSummary(Map<String, dynamic> payload) {
    final summary = NotificationUnreadSummary.fromJson(payload);
    final notifications = summary.notificationsUnreadCount < 0
        ? 0
        : summary.notificationsUnreadCount;
    final messages =
        summary.messagesUnreadCount < 0 ? 0 : summary.messagesUnreadCount;
    if (notifications == _communityUnreadCount &&
        messages == _messageUnreadCount) {
      return;
    }
    _communityUnreadCount = notifications;
    _messageUnreadCount = messages;
    _hasNew = notifications > 0;
    notifyListeners();
  }

  /// Bind to the AppRefreshProvider to receive global or specific refresh triggers.
  void bindToRefresh(AppRefreshProvider appRefresh) {
    try {
      if (identical(_boundRefreshProvider, appRefresh) &&
          _refreshListener != null) {
        return;
      }

      if (_boundRefreshProvider != null && _refreshListener != null) {
        try {
          _boundRefreshProvider!.removeListener(_refreshListener!);
        } catch (_) {}
      }

      _boundRefreshProvider = appRefresh;
      _lastNotifVersion = appRefresh.notificationsVersion;
      _lastGlobalVersion = appRefresh.globalVersion;
      _refreshListener = () {
        try {
          handleViewVisibilityChanged();
          if (!_hasAuthContext) {
            return;
          }
          final notificationsChanged =
              appRefresh.notificationsVersion != _lastNotifVersion;
          final globalChanged = appRefresh.globalVersion != _lastGlobalVersion;

          if (!notificationsChanged && !globalChanged) {
            return;
          }

          if (notificationsChanged) {
            _lastNotifVersion = appRefresh.notificationsVersion;
          }
          if (globalChanged) {
            _lastGlobalVersion = appRefresh.globalVersion;
          }

          final notificationsSurfaceActive = _isNotificationsSurfaceActive;
          final socketHealthy = _isSocketHealthyForNotifications();

          if (notificationsChanged) {
            if (notificationsSurfaceActive) {
              refresh(force: true);
            } else if (!socketHealthy) {
              _scheduleServerSync();
            } else {
              _maybeCheckSubscription();
            }
            return;
          }

          if (globalChanged && notificationsSurfaceActive) {
            refresh(force: true);
            return;
          }

          if (globalChanged && !socketHealthy) {
            _scheduleServerSync();
          }
        } catch (e) {
          /* ignore */
        }
      };
      appRefresh.addListener(_refreshListener!);
      _ensureCadenceTimer(forceRestart: true);
    } catch (e) {
      // ignore
    }
  }

  Map<String, int> get debugCounters => <String, int>{
        'cadenceTicks': _debugCadenceTicks,
        'syncs': _debugSyncs,
        'skippedSyncs': _debugSkippedSyncs,
      };

  void increment([int by = 1]) {
    if (by > 0) unawaited(refresh(force: true));
  }

  void reset() {
    if (_hasAuthContext) {
      unawaited(refresh(force: true));
      return;
    }
    _resetSessionState(clearUnreadCount: true);
  }

  Future<void> markViewed({bool syncServer = true}) async {
    if (syncServer) {
      try {
        await _backend.markAllNotificationsAsRead();
        await refresh(force: true);
      } catch (e) {
        debugPrint('NotificationProvider.markViewed: backend sync failed: $e');
      }
    }
  }

  /// Centralized handler for incoming socket `notification:new` events.
  /// - Deduplicates stable event IDs and shows localized local copy. Unread
  ///   counts are updated only from the authoritative summary endpoint/event.
  Future<void> handleIncomingNotification(Map<String, dynamic> payload) async {
    try {
      // Parse notification type and relevant payload fields
      // Work on a mutable copy for potential raw wrappers
      var parsedPayload = Map<String, dynamic>.from(payload);
      String resolvedType = (parsedPayload['type'] ??
              parsedPayload['interactionType'] ??
              parsedPayload['data']?['type'] ??
              '')
          .toString();
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
        resolvedType = (parsedPayload['type'] ??
                parsedPayload['interactionType'] ??
                parsedPayload['data']?['type'] ??
                '')
            .toString();
      }

      final normalizedType = resolvedType.toLowerCase();
      final data = (parsedPayload['data'] is Map)
          ? Map<String, dynamic>.from(parsedPayload['data'] as Map)
          : <String, dynamic>{};
      final eventId = (parsedPayload['eventId'] ??
              parsedPayload['event_id'] ??
              data['eventId'] ??
              parsedPayload['id'])
          ?.toString()
          .trim();
      if (eventId != null && eventId.isNotEmpty) {
        if (_shownEventIds.contains(eventId)) return;
        _shownEventIds.add(eventId);
        if (_shownEventIds.length > 512) {
          _shownEventIds.remove(_shownEventIds.first);
        }
      }

      // ChatProvider owns the message transport and presents one localized DM
      // alert per stable message ID. Avoid a second alert from this row event.
      if (normalizedType == 'message' || normalizedType == 'dm') return;
      final postId =
          (data['postId'] ?? data['targetId'] ?? parsedPayload['postId'])
              ?.toString();
      final comment =
          (data['commentPreview'] ?? parsedPayload['comment'])?.toString();

      String? userName;
      String? userAvatar;
      final sender = parsedPayload['sender'];
      if (sender is Map) {
        userName =
            (sender['displayName'] ?? sender['username'] ?? sender['name'])
                ?.toString();
        userAvatar =
            sender['avatar']?.toString() ?? sender['avatarUrl']?.toString();
      }
      userName ??= (parsedPayload['userName'] ?? parsedPayload['authorName'])
          ?.toString();
      userAvatar ??= parsedPayload['avatar']?.toString();

      final followerWallet = (data['followerWallet'] ??
              data['walletAddress'] ??
              data['wallet'] ??
              parsedPayload['followerWallet'] ??
              parsedPayload['userId'])
          ?.toString();

      // Show local notification for community interactions and other types
      try {
        final l10n = _l10n;
        await _pushService.initialize();
        await _pushService.waitForPermissionSettlement();
        final canDisplayLocally = await _pushService.refreshPermissionStatus();
        if (!canDisplayLocally) {
          if (kDebugMode) {
            debugPrint(
              'NotificationProvider: skipping local notification display '
              '(permission not granted yet)',
            );
          }
          return;
        }
        switch (normalizedType) {
          case 'comment':
            await _pushService.showCommunityInteractionNotification(
              postId: postId ?? '',
              type: 'comment',
              userName: userName ?? l10n.notificationSomeoneFallback,
              comment: comment,
            );
            break;
          case 'like':
            await _pushService.showCommunityInteractionNotification(
              postId: postId ?? '',
              type: 'like',
              userName: userName ?? l10n.notificationSomeoneFallback,
            );
            break;
          case 'share':
            await _pushService.showCommunityInteractionNotification(
              postId: postId ?? '',
              type: 'share',
              userName: userName ?? l10n.notificationSomeoneFallback,
            );
            break;
          case 'mention':
            await _pushService.showCommunityInteractionNotification(
              postId: postId ?? '',
              type: 'mention',
              userName: userName ?? l10n.notificationSomeoneFallback,
            );
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
                userName: userName ?? l10n.notificationSomeoneFallback,
                userAvatar: userAvatar ?? data['avatar']?.toString(),
              );
            }
            break;
          case 'reward':
            await _pushService.showRewardNotification(
              title: l10n.notificationRecognitionRecordedTitle,
              amount: payload['amount'] is num
                  ? (payload['amount'] as num).toInt()
                  : int.tryParse(payload['amount']?.toString() ?? '') ?? 0,
              reason: payload['reason']?.toString() ?? '',
              currency: (payload['currency'] ?? payload['rewardCurrency'])
                  ?.toString(),
            );
            break;
          case 'artwork_discovery':
            await _pushService.showArtworkDiscoveryNotification(
              artworkId: payload['artworkId']?.toString() ?? '',
              title: payload['title'] ?? '',
              artist: payload['artist'] ?? '',
            );
            break;
          case 'nft_minting':
            await _pushService.showNFTMintingNotification(
              artworkId: payload['artworkId']?.toString() ?? '',
              artworkTitle: payload['artworkTitle'] ?? '',
              status: payload['status'] ?? '',
              transactionId: payload['transactionId']?.toString(),
            );
            break;
          case 'trading':
            await _pushService.showTradingNotification(
              tradeId: payload['tradeId']?.toString() ?? '',
              type: payload['tradeType'] ?? 'sale',
              artworkTitle: payload['artworkTitle'] ?? '',
              amount: (payload['amount'] is num)
                  ? (payload['amount'] as num).toDouble()
                  : 0.0,
              buyerName: payload['buyerName'],
              sellerName: payload['sellerName'],
            );
            break;
          case 'achievement':
            await _pushService.showAchievementNotification(
              achievementId: payload['achievementId']?.toString() ?? '',
              title: payload['title'] ?? l10n.notificationAchievementFallback,
              description: payload['description'] ?? '',
              rewardTokens: payload['rewardTokens'] ?? 0,
            );
            break;
          default:
            // For other types, do not show a local notification but we already updated UI counters
            break;
        }
      } catch (e) {
        debugPrint(
          'NotificationProvider: failed to show local notification: $e',
        );
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
    if (_summarySocketListenerRegistered) {
      _socket.removeUnreadSummaryListener(_handleUnreadSummary);
      _summarySocketListenerRegistered = false;
    }
    if (_connectListenerRegistered) {
      _socket.removeConnectListener(_handleSocketReconnect);
      _connectListenerRegistered = false;
    }
    if (_boundRefreshProvider != null && _refreshListener != null) {
      try {
        _boundRefreshProvider!.removeListener(_refreshListener!);
      } catch (_) {}
    }
    _boundRefreshProvider = null;
    _refreshListener = null;
    _scheduledServerSync?.cancel();
    _scheduledServerSync = null;
    _scheduledServerSyncDueAt = null;
    _stopAutoRefreshLoop();
    super.dispose();
  }

  Map<String, Object> get debugSnapshot => <String, Object>{
        'initialized': _initialized,
        'hasAuthContext': _hasAuthContext,
        'currentWallet': _currentWallet ?? '',
        'currentAccountId': _currentAccountId ?? '',
        'unreadCount': _communityUnreadCount,
        'messageUnreadCount': _messageUnreadCount,
        'totalUnreadCount': totalUnreadCount,
        'hasNew': _hasNew,
        'refreshBound': _refreshListener != null,
        'socketListenersRegistered': _socketListenersRegistered,
        'connectListenerRegistered': _connectListenerRegistered,
        'cadenceTimerActive': _cadenceTimer?.isActive ?? false,
        'scheduledSyncActive': _scheduledServerSync?.isActive ?? false,
        'currentSubscribedWallet': _socket.currentSubscribedWallet ?? '',
        'currentSubscribedAccountId': _socket.currentSubscribedAccountId ?? '',
      };

  @visibleForTesting
  void setAuthenticatedSessionForTesting({String? wallet, String? accountId}) {
    _currentWallet = wallet;
    _currentAccountId = canonicalAccountUserId(accountId);
    _initialized = true;
  }

  @visibleForTesting
  void handleUnreadSummaryForTesting(Map<String, dynamic> payload) {
    _handleUnreadSummary(payload);
  }

  @visibleForTesting
  void handleNotificationForTesting(Map<String, dynamic> payload) {
    _handleSocketNotification(payload);
  }

  @visibleForTesting
  Future<void> handleSocketReconnectForTesting() =>
      _refreshAfterSocketReconnect();

  void _maybeCheckSubscription() {
    final now = DateTime.now();
    final last = _lastSubscriptionCheckAt;
    if (last != null && now.difference(last) < _subscriptionCheckInterval) {
      return;
    }
    _lastSubscriptionCheckAt = now;
    try {
      final accountId = _currentAccountId;
      final expectedIdentity =
          accountId ?? WalletUtils.canonical(_currentWallet);
      if (expectedIdentity.isEmpty) return;
      final subscribed = _socket.currentSubscribedIdentity ?? '';
      final correctlyTyped =
          _socket.currentSubscribedIdentityIsAccount == (accountId != null);
      if (subscribed.isEmpty ||
          subscribed != expectedIdentity ||
          !correctlyTyped) {
        debugPrint(
          'NotificationProvider: subscription check mismatch, attempting resubscribe',
        );
        final future = accountId != null
            ? _socket.connectAndSubscribeAccount(_backend.baseUrl, accountId)
            : _socket.connectAndSubscribe(_backend.baseUrl, expectedIdentity);
        future.then((ok) {
          debugPrint('NotificationProvider: connectAndSubscribe -> $ok');
          if (!ok) {
            if (accountId != null) {
              _socket.subscribeAccount(accountId);
            } else {
              _socket.subscribeUser(expectedIdentity);
            }
          }
        }).catchError((e) {
          debugPrint('NotificationProvider: connectAndSubscribe error: $e');
        });
      }
    } catch (e) {
      debugPrint('NotificationProvider._maybeCheckSubscription failed: $e');
    }
  }
}
