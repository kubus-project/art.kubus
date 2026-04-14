import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collab_invite.dart';
import '../models/collab_member.dart';
import '../config/config.dart';
import '../providers/app_refresh_provider.dart';
import '../providers/profile_provider.dart';
import '../services/backend_api_service.dart' show BackendApiRequestException;
import '../services/collab_api.dart';
import '../services/push_notification_service.dart';
import '../services/socket_service.dart';
import '../utils/wallet_utils.dart';

class CollabProvider extends ChangeNotifier {
  final CollabApi _api;
  final PushNotificationService _notifications;
  final SocketService _socket;

  CollabProvider({CollabApi? api, PushNotificationService? notifications})
      : _api = api ?? BackendCollabApi(),
        _notifications = notifications ?? PushNotificationService(),
        _socket = SocketService();

  AppRefreshProvider? _refreshProvider;
  VoidCallback? _refreshListener;
  ProfileProvider? _profileProvider;
  VoidCallback? _profileListener;

  int _lastGlobalVersion = 0;
  int _lastProfileVersion = 0;

  bool _socketBound = false;
  bool _connectListenerBound = false;
  String _lastAuthWallet = '';

  final Map<String, List<CollabMember>> _membersByEntityKey =
      <String, List<CollabMember>>{};
  final List<CollabInvite> _invitesInbox = <CollabInvite>[];
  final Set<String> _knownInviteIds = <String>{};
  static const int _maxKnownInviteIds = 200;

  Timer? _invitePollingTimer;
  Duration? _invitePollingIntervalCurrent;
  bool _pollingInFlight = false;
  bool _knownInvitesHydrated = false;
  bool _readyToNotifyNewInvites = false;
  DateTime? _lastInviteSyncAt;
  DateTime? _lastInviteSocketEventAt;
  final int _invitePollJitterSeconds = Random().nextInt(12);

  static const Duration _inviteSocketStaleAfter = Duration(minutes: 12);
  static const Duration _inviteSyncStaleAfter = Duration(minutes: 18);
  static const Duration _inviteForegroundActiveInterval =
      Duration(seconds: 150);
  static const Duration _inviteForegroundPassiveInterval =
      Duration(seconds: 360);
  static const Duration _inviteHealthyResumeRefreshInterval =
      Duration(minutes: 3);

  DateTime? _inviteBackoffUntil;
  Duration _inviteBackoff = Duration.zero;

  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;
  List<CollabInvite> get invitesInbox => List.unmodifiable(_invitesInbox);

  int get pendingInviteCount => _invitesInbox.where((i) => i.isPending).length;

  static const Map<String, String> _entityTypeAliases = {
    'artwork': 'artwork',
    'artworks': 'artwork',
    'collection': 'collection',
    'collections': 'collection',
    'event': 'events',
    'events': 'events',
    'exhibition': 'exhibitions',
    'exhibitions': 'exhibitions',
  };

  static String _normalizeEntityType(String raw) {
    final normalized = raw.trim().toLowerCase();
    return _entityTypeAliases[normalized] ?? normalized;
  }

  static String _key(String entityType, String entityId) =>
      '${_normalizeEntityType(entityType)}:${entityId.trim()}';

  List<CollabMember> collaboratorsFor(String entityType, String entityId) {
    return List.unmodifiable(_membersByEntityKey[_key(entityType, entityId)] ??
        const <CollabMember>[]);
  }

  void bindToRefresh(AppRefreshProvider refreshProvider) {
    if (identical(_refreshProvider, refreshProvider) &&
        _refreshListener != null) {
      return;
    }

    if (_refreshProvider != null && _refreshListener != null) {
      try {
        _refreshProvider!.removeListener(_refreshListener!);
      } catch (_) {}
    }

    _refreshProvider = refreshProvider;
    _lastGlobalVersion = refreshProvider.globalVersion;
    _lastProfileVersion = refreshProvider.profileVersion;

    _refreshListener = () {
      try {
        final nextGlobal = refreshProvider.globalVersion;
        final nextProfile = refreshProvider.profileVersion;
        final changed = nextGlobal != _lastGlobalVersion ||
            nextProfile != _lastProfileVersion;
        _lastGlobalVersion = nextGlobal;
        _lastProfileVersion = nextProfile;

        if (changed) {
          if (_isCollabSurfaceActive || !_socketHealthyForInviteFeed()) {
            unawaited(
              refreshInvites(showLoadingIndicator: false, notifyOnNew: false),
            );
          } else {
            _evaluateInvitePollingState();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CollabProvider: refresh listener error: $e');
        }
      }
    };
    refreshProvider.addListener(_refreshListener!);
  }

  void bindProfileProvider(ProfileProvider profileProvider) {
    if (identical(_profileProvider, profileProvider)) return;

    if (_profileProvider != null && _profileListener != null) {
      try {
        _profileProvider!.removeListener(_profileListener!);
      } catch (_) {}
    }

    _profileProvider = profileProvider;
    _profileListener = () {
      _syncAuthState();
    };
    profileProvider.addListener(_profileListener!);
    _syncAuthState();
  }

  void _bindSocketOnce() {
    if (_socketBound) return;
    _socketBound = true;
    _socket.addCollabListener(_onSocketCollabEvent);
    if (!_connectListenerBound) {
      _socket.addConnectListener(_handleSocketReconnect);
      _connectListenerBound = true;
    }
  }

  void _handleSocketReconnect() {
    if (!AppConfig.isFeatureEnabled('collabInvites')) return;
    if ((_api.getAuthToken() ?? '').trim().isEmpty) return;
    unawaited(refreshInvites(showLoadingIndicator: false, notifyOnNew: false));
    _evaluateInvitePollingState();
  }

  void _resetSessionState({
    bool clearKnownInvites = false,
  }) {
    stopInvitePolling();
    _pollingInFlight = false;
    _inviteBackoffUntil = null;
    _inviteBackoff = Duration.zero;
    _readyToNotifyNewInvites = false;
    _lastInviteSyncAt = null;
    _lastInviteSocketEventAt = null;
    _invitePollingIntervalCurrent = null;
    _initialized = false;
    _isLoading = false;
    _lastAuthWallet = '';
    _invitesInbox.clear();
    _membersByEntityKey.clear();
    _error = null;

    if (clearKnownInvites) {
      _knownInviteIds.clear();
      _knownInvitesHydrated = false;
    }
  }

  void _onSocketCollabEvent(Map<String, dynamic> payload) {
    if (!AppConfig.isFeatureEnabled('collabInvites')) return;
    final token = (_api.getAuthToken() ?? '').trim();
    if (token.isEmpty) return;

    final event = (payload['event'] ?? '').toString();
    if (event == 'collab:invites-updated') {
      _lastInviteSocketEventAt = DateTime.now();
      if (_pollingInFlight) return;
      _pollingInFlight = true;
      unawaited(
        _refreshInvitesInternal(showLoadingIndicator: false, notifyOnNew: true)
            .whenComplete(() {
          _pollingInFlight = false;
          _evaluateInvitePollingState();
        }),
      );
      return;
    }

    if (event == 'collab:members-updated') {
      final rawType =
          (payload['entityType'] ?? payload['entity_type'] ?? '').toString();
      final rawId =
          (payload['entityId'] ?? payload['entity_id'] ?? '').toString();
      final entityType = rawType.trim();
      final entityId = rawId.trim();
      if (entityType.isEmpty || entityId.isEmpty) return;
      final key = _key(entityType, entityId);
      if (!_membersByEntityKey.containsKey(key)) return;
      unawaited(loadCollaborators(entityType, entityId,
          refresh: true, showLoadingIndicator: false));
    }
  }

  void _syncAuthState() {
    if (!AppConfig.isFeatureEnabled('collabInvites')) return;

    final profile = _profileProvider;
    final signedIn = profile?.isSignedIn == true;
    final wallet = (profile?.currentUser?.walletAddress ?? '').trim();
    final token = (_api.getAuthToken() ?? '').trim();

    if (!signedIn || wallet.isEmpty || token.isEmpty) {
      if (_lastAuthWallet.isNotEmpty ||
          _invitesInbox.isNotEmpty ||
          _membersByEntityKey.isNotEmpty ||
          _error != null) {
        // Schedule notifyListeners in microtask to avoid synchronous notification
        // during ProxyProvider update callback, which could cause infinite recursion.
        _resetSessionState();
        Future.microtask(notifyListeners);
      } else {
        _resetSessionState();
      }
      return;
    }

    _bindSocketOnce();

    if (_lastAuthWallet != wallet) {
      _resetSessionState();
      _evaluateInvitePollingState();
      _lastAuthWallet = wallet;
      // Schedule notifyListeners in microtask to avoid synchronous notification.
      Future.microtask(notifyListeners);
      unawaited(initialize(refresh: true));
      _evaluateInvitePollingState();
      return;
    }

    if (!_initialized) {
      unawaited(initialize(refresh: true));
      _evaluateInvitePollingState();
    }
  }

  Future<void> initialize({bool refresh = false}) async {
    if (_initialized && !refresh) return;
    _initialized = true;
    _bindSocketOnce();

    final token = (_api.getAuthToken() ?? '').trim();
    if (token.isEmpty) {
      // Anonymous user; keep state empty and avoid noisy errors.
      _resetSessionState();
      notifyListeners();
      return;
    }

    await _hydrateKnownInvitesOnce();
    await refreshInvites(notifyOnNew: false);
    _readyToNotifyNewInvites = true;
    _evaluateInvitePollingState();
  }

  Future<void> refreshInvites(
      {bool showLoadingIndicator = true, bool notifyOnNew = false}) async {
    await _refreshInvitesInternal(
      showLoadingIndicator: showLoadingIndicator,
      notifyOnNew: notifyOnNew,
    );
  }

  bool get _isForeground => _refreshProvider?.isAppForeground ?? true;

  bool get _isCollabSurfaceActive {
    final refresh = _refreshProvider;
    if (refresh == null) return false;
    return refresh.isViewActive(
          AppRefreshProvider.viewCommunity,
          defaultIfUnknown: false,
        ) ||
        refresh.isViewActive(
          AppRefreshProvider.viewNotifications,
          defaultIfUnknown: false,
        ) ||
        refresh.isViewActive(
          AppRefreshProvider.viewProfile,
          defaultIfUnknown: false,
        );
  }

  bool _socketHealthyForInviteFeed() {
    if (!_socket.isConnected) return false;
    final expectedWallet = WalletUtils.canonical(_lastAuthWallet);
    if (expectedWallet.isEmpty) return false;
    final subscribedWallet =
        WalletUtils.canonical(_socket.currentSubscribedWallet);
    if (subscribedWallet.isEmpty || subscribedWallet != expectedWallet) {
      return false;
    }

    final now = DateTime.now();
    final socketEventRecent = _lastInviteSocketEventAt != null &&
        now.difference(_lastInviteSocketEventAt!) <= _inviteSocketStaleAfter;
    final syncRecent = _lastInviteSyncAt != null &&
        now.difference(_lastInviteSyncAt!) <= _inviteSyncStaleAfter;
    return socketEventRecent || syncRecent;
  }

  bool _shouldRefreshOnResumeOrForeground() {
    final socketHealthy = _socketHealthyForInviteFeed();
    if (!socketHealthy) {
      return true;
    }

    if (!_isCollabSurfaceActive) {
      return false;
    }

    final now = DateTime.now();
    final last = _lastInviteSocketEventAt ?? _lastInviteSyncAt;
    if (last == null) {
      return true;
    }
    return now.difference(last) >= _inviteHealthyResumeRefreshInterval;
  }

  Duration? _computeInvitePollingInterval() {
    if (!AppConfig.isFeatureEnabled('collabInvites')) return null;
    if ((_api.getAuthToken() ?? '').trim().isEmpty) return null;
    if (!_isForeground) return null;
    if (_socketHealthyForInviteFeed()) return null;

    final base = _isCollabSurfaceActive
        ? _inviteForegroundActiveInterval
        : _inviteForegroundPassiveInterval;
    final jitter = Duration(seconds: _invitePollJitterSeconds);
    return base + jitter;
  }

  void _evaluateInvitePollingState() {
    final nextInterval = _computeInvitePollingInterval();
    if (nextInterval == null) {
      stopInvitePolling();
      return;
    }
    if (_invitePollingTimer != null &&
        _invitePollingIntervalCurrent == nextInterval) {
      return;
    }
    startInvitePolling(interval: nextInterval);
  }

  void startInvitePolling({Duration interval = const Duration(seconds: 75)}) {
    if (!AppConfig.isFeatureEnabled('collabInvites')) return;
    final token = (_api.getAuthToken() ?? '').trim();
    if (token.isEmpty) return;
    _invitePollingTimer?.cancel();
    _invitePollingIntervalCurrent = interval;
    _invitePollingTimer = Timer.periodic(interval, (_) {
      if (_pollingInFlight) return;

      if (_socketHealthyForInviteFeed()) {
        stopInvitePolling();
        return;
      }

      final until = _inviteBackoffUntil;
      if (until != null && DateTime.now().isBefore(until)) {
        return;
      }

      _pollingInFlight = true;
      unawaited(
        _refreshInvitesInternal(showLoadingIndicator: false, notifyOnNew: true)
            .whenComplete(() {
          _pollingInFlight = false;
          _evaluateInvitePollingState();
        }),
      );
    });
  }

  void stopInvitePolling() {
    _invitePollingTimer?.cancel();
    _invitePollingTimer = null;
    _invitePollingIntervalCurrent = null;
  }

  Future<void> onAppResumed() async {
    if (_shouldRefreshOnResumeOrForeground()) {
      await refreshInvites(showLoadingIndicator: false, notifyOnNew: false);
    }
    _evaluateInvitePollingState();
  }

  void handleAppForegroundChanged(bool isForeground) {
    if (isForeground) {
      _evaluateInvitePollingState();
      if (_shouldRefreshOnResumeOrForeground()) {
        unawaited(
            refreshInvites(showLoadingIndicator: false, notifyOnNew: false));
      }
      return;
    }
    stopInvitePolling();
  }

  void handleViewVisibilityChanged() {
    _evaluateInvitePollingState();
  }

  Future<void> _refreshInvitesInternal(
      {required bool showLoadingIndicator, required bool notifyOnNew}) async {
    if (showLoadingIndicator) {
      _setLoading(true);
    }
    _error = null;

    try {
      final token = (_api.getAuthToken() ?? '').trim();
      if (token.isEmpty) {
        _resetSessionState();
        notifyListeners();
        return;
      }
      final invites = await _api.listMyCollabInvites();
      _lastInviteSyncAt = DateTime.now();

      // Successful response: clear any transient backoff.
      _inviteBackoffUntil = null;
      _inviteBackoff = Duration.zero;

      final newPendingInvites = invites
          .where((i) =>
              i.isPending &&
              i.id.trim().isNotEmpty &&
              !_knownInviteIds.contains(i.id))
          .toList(growable: false);

      _invitesInbox
        ..clear()
        ..addAll(invites);
      notifyListeners();

      for (final invite in invites) {
        final id = invite.id.trim();
        if (id.isEmpty) continue;
        _knownInviteIds.add(id);
      }
      _pruneKnownInviteIds();
      unawaited(_persistKnownInvites());

      if (notifyOnNew &&
          _readyToNotifyNewInvites &&
          _knownInvitesHydrated &&
          AppConfig.isFeatureEnabled('collabInviteNotifications') &&
          newPendingInvites.isNotEmpty) {
        await _emitInviteNotifications(newPendingInvites);
      }
    } catch (e) {
      if (e is BackendApiRequestException && e.statusCode == 503) {
        // Server temporarily unavailable: keep existing inbox and back off.
        final next = _inviteBackoff == Duration.zero
            ? const Duration(seconds: 60)
            : Duration(seconds: (_inviteBackoff.inSeconds * 2).clamp(60, 900));
        _inviteBackoff = next;
        _inviteBackoffUntil = DateTime.now().add(next);

        _error = 'Invites temporarily unavailable';
        notifyListeners();
        _evaluateInvitePollingState();
        return;
      }

      _error = e.toString();
      notifyListeners();
      _evaluateInvitePollingState();
    } finally {
      if (showLoadingIndicator) {
        _setLoading(false);
      }
    }
  }

  Future<void> _hydrateKnownInvitesOnce() async {
    if (_knownInvitesHydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored =
          prefs.getStringList('collab_known_invite_ids_v1') ?? const <String>[];
      for (final id in stored) {
        final trimmed = id.trim();
        if (trimmed.isEmpty) continue;
        _knownInviteIds.add(trimmed);
      }
      _pruneKnownInviteIds();
    } catch (_) {
      // Best-effort; if hydration fails we'll still function, but may notify more than desired.
    } finally {
      _knownInvitesHydrated = true;
    }
  }

  Future<void> _persistKnownInvites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pruneKnownInviteIds();
      final capped = _knownInviteIds.toList(growable: false);
      await prefs.setStringList('collab_known_invite_ids_v1', capped);
    } catch (_) {
      // Ignore persistence errors.
    }
  }

  void _pruneKnownInviteIds() {
    while (_knownInviteIds.length > _maxKnownInviteIds) {
      _knownInviteIds.remove(_knownInviteIds.first);
    }
  }

  Future<void> _emitInviteNotifications(
      List<CollabInvite> newPendingInvites) async {
    // Ensure notification service is ready (no-op if already initialized).
    unawaited(_notifications.initialize());

    final limited = newPendingInvites.take(3);
    for (final invite in limited) {
      final invitedBy = invite.invitedBy;
      final inviterName = (invitedBy?.displayName ?? '').trim().isNotEmpty
          ? invitedBy!.displayName!.trim()
          : ((invitedBy?.username ?? '').trim().isNotEmpty
              ? '@${invitedBy!.username}'
              : null);

      await _notifications.showCollabInviteNotification(
        inviteId: invite.id,
        entityType: invite.entityType,
        entityId: invite.entityId,
        role: invite.role,
        inviterName: inviterName,
      );
    }
  }

  Future<List<CollabMember>> loadCollaborators(
    String entityType,
    String entityId, {
    bool refresh = true,
    bool showLoadingIndicator = true,
  }) async {
    final normalizedType = _normalizeEntityType(entityType);
    final entityKey = _key(normalizedType, entityId);
    if (!refresh) {
      final cached = _membersByEntityKey[entityKey];
      if (cached != null) return List.unmodifiable(cached);
    }
    if (showLoadingIndicator) {
      _setLoading(true);
    }
    _error = null;
    try {
      final members = await _api.listCollaborators(normalizedType, entityId);
      _membersByEntityKey[entityKey] = members;
      notifyListeners();
      return members;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      if (showLoadingIndicator) {
        _setLoading(false);
      }
    }
  }

  Future<CollabInvite?> inviteCollaborator({
    required String entityType,
    required String entityId,
    required String invitedIdentifier,
    required String role,
  }) async {
    final normalizedType = _normalizeEntityType(entityType);
    _setLoading(true);
    _error = null;
    try {
      final invite = await _api.inviteCollaborator(
          normalizedType, entityId, invitedIdentifier, role);
      // Best effort: refresh invites for invited user is not possible client-side; refresh ours anyway.
      await refreshInvites();
      return invite;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> acceptInvite(String inviteId) async {
    final trimmedId = inviteId.trim();
    CollabInvite? removed;
    int removedIndex = -1;
    if (trimmedId.isNotEmpty) {
      removedIndex = _invitesInbox.indexWhere((i) => i.id.trim() == trimmedId);
      if (removedIndex != -1) {
        removed = _invitesInbox.removeAt(removedIndex);
        notifyListeners();
      }
    }

    _setLoading(true);
    _error = null;
    try {
      await _api.acceptInvite(inviteId);
      await refreshInvites(showLoadingIndicator: false, notifyOnNew: false);
    } catch (e) {
      if (removed != null) {
        final idx = (removedIndex >= 0 && removedIndex <= _invitesInbox.length)
            ? removedIndex
            : _invitesInbox.length;
        _invitesInbox.insert(idx, removed);
      }
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> declineInvite(String inviteId) async {
    final trimmedId = inviteId.trim();
    CollabInvite? removed;
    int removedIndex = -1;
    if (trimmedId.isNotEmpty) {
      removedIndex = _invitesInbox.indexWhere((i) => i.id.trim() == trimmedId);
      if (removedIndex != -1) {
        removed = _invitesInbox.removeAt(removedIndex);
        notifyListeners();
      }
    }

    _setLoading(true);
    _error = null;
    try {
      await _api.declineInvite(inviteId);
      await refreshInvites(showLoadingIndicator: false, notifyOnNew: false);
    } catch (e) {
      if (removed != null) {
        final idx = (removedIndex >= 0 && removedIndex <= _invitesInbox.length)
            ? removedIndex
            : _invitesInbox.length;
        _invitesInbox.insert(idx, removed);
      }
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCollaboratorRole({
    required String entityType,
    required String entityId,
    required String memberUserId,
    required String role,
  }) async {
    final normalizedType = _normalizeEntityType(entityType);
    _setLoading(true);
    _error = null;
    try {
      await _api.updateCollaboratorRole(
          normalizedType, entityId, memberUserId, role);
      await loadCollaborators(normalizedType, entityId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeCollaborator({
    required String entityType,
    required String entityId,
    required String memberUserId,
  }) async {
    final normalizedType = _normalizeEntityType(entityType);
    _setLoading(true);
    _error = null;
    try {
      await _api.removeCollaborator(normalizedType, entityId, memberUserId);
      await loadCollaborators(normalizedType, entityId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool next) {
    if (_isLoading == next) return;
    _isLoading = next;
    notifyListeners();
  }

  @override
  void dispose() {
    stopInvitePolling();
    if (_socketBound) {
      _socket.removeCollabListener(_onSocketCollabEvent);
    }
    if (_connectListenerBound) {
      _socket.removeConnectListener(_handleSocketReconnect);
      _connectListenerBound = false;
    }
    if (_refreshProvider != null && _refreshListener != null) {
      try {
        _refreshProvider!.removeListener(_refreshListener!);
      } catch (_) {}
    }
    _refreshProvider = null;
    _refreshListener = null;
    if (_profileProvider != null && _profileListener != null) {
      try {
        _profileProvider!.removeListener(_profileListener!);
      } catch (_) {}
    }
    _profileProvider = null;
    _profileListener = null;
    super.dispose();
  }

  Map<String, Object> get debugSnapshot => <String, Object>{
        'initialized': _initialized,
        'loading': _isLoading,
        'lastAuthWallet': _lastAuthWallet,
        'refreshBound': _refreshListener != null,
        'profileBound': _profileListener != null,
        'socketBound': _socketBound,
        'invitePollingActive': _invitePollingTimer?.isActive ?? false,
        'invitesInbox': _invitesInbox.length,
        'membersCacheEntries': _membersByEntityKey.length,
        'knownInviteIds': _knownInviteIds.length,
        'readyToNotifyNewInvites': _readyToNotifyNewInvites,
      };
}
