import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../config/config.dart';
import '../services/backend_api_service.dart';
import '../services/socket_service.dart';
import '../models/conversation.dart';
import '../services/user_service.dart';
import '../services/push_notification_service.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/user_profile.dart';
import '../services/event_bus.dart';
import '../utils/media_url_resolver.dart';
import '../utils/wallet_utils.dart';
import 'app_refresh_provider.dart';
import 'profile_provider.dart';

part 'chat_provider_cache_helpers.dart';
part 'chat_provider_conversation_helpers.dart';
part 'chat_provider_lifecycle_helpers.dart';

class ChatProvider extends ChangeNotifier {
  static const int _maxCachedMessageConversations = 24;
  static const int _maxMessagesPerConversation = 200;
  static const int _maxCachedMemberLists = 80;
  static const int _maxCachedUsers = 320;

  ChatProvider() {
    // Register socket listeners early so the provider receives events even
    // if initialize() runs earlier or in a different order. SocketService
    // deduplicates listeners, so calling these here is safe.
    try {
      _socket.addMessageListener(_onMessageReceived);
      _socket.addMessageReadListener(_onMessageRead);
      _socket.addConversationListener(_onNewConversation);
      _socket.addConversationListener(_onMembersUpdated);
      _socket.addConversationListener(_onConversationUpdated);
      _socket.addConversationListener(_onConversationMemberRead);
      _socket.addMessageReactionListener(_onMessageReaction);
    } catch (e) {
      debugPrint(
          'ChatProvider constructor: failed to register socket listeners: $e');
    }
  }
  // Socket event handlers
  void _onMembersUpdated(Map<String, dynamic> data) {
    try {
      debugPrint('ChatProvider._onMembersUpdated: payload=$data');
      // Refresh conversations so UI reflects membership changes
      if (!_hasAuthContext) {
        return;
      }
      refreshConversations().then((_) {
        debugPrint(
            'ChatProvider._onMembersUpdated: refreshConversations completed');
      }).catchError((e) {
        debugPrint(
            'ChatProvider._onMembersUpdated: refreshConversations error: $e');
      });
    } catch (e) {
      debugPrint('ChatProvider._onMembersUpdated error: $e');
    }
  }

  void _onConversationUpdated(Map<String, dynamic> data) {
    try {
      final conv = Conversation.fromJson(data);
      final idx = _conversations.indexWhere((c) => c.id == conv.id);
      if (idx >= 0) {
        _conversations[idx] = conv;
      } else {
        _conversations.insert(0, conv);
      }
      final seeded = _seedConversationMetadataCaches(conv);
      if (seeded.isNotEmpty) {
        try {
          UserService.setUsersInCache(seeded);
        } catch (_) {}
      }
      try {
        unawaited(_prefetchMembersAndProfilesFromConversations([conv]));
      } catch (_) {}
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('ChatProvider._onConversationUpdated error: $e');
    }
  }

  /// Returns a synchronous preloaded map of members, avatar URLs and display names for a conversation.
  /// This function avoids network calls and uses the provider's cached members and user cache when available.
  Map<String, dynamic> getPreloadedProfileMapsForConversation(
      String conversationId) {
    final result = <String, dynamic>{
      'members': <String>[],
      'avatars': <String, String?>{},
      'names': <String, String?>{},
    };
    try {
      final avatarsMap = result['avatars'] as Map<String, String?>;
      final namesMap = result['names'] as Map<String, String?>;
      final wallets = <String>[];
      final seenWallets = <String>{};
      final myWalletCanonical = WalletUtils.canonical(_currentWallet);

      void addWallet(String wallet) {
        final normalized = WalletUtils.normalize(wallet);
        if (normalized.isEmpty) return;
        final canonical = WalletUtils.canonical(normalized);
        if (myWalletCanonical.isNotEmpty && canonical == myWalletCanonical) {
          return;
        }
        if (seenWallets.add(canonical)) {
          wallets.add(normalized);
        }
      }

      void seedFromProfile(ConversationMemberProfile profile) {
        final wallet = WalletUtils.normalize(profile.wallet);
        if (wallet.isEmpty) return;
        addWallet(wallet);
        if ((profile.displayName ?? '').isNotEmpty) {
          namesMap[wallet] = profile.displayName;
        }
        if ((profile.avatarUrl ?? '').isNotEmpty) {
          avatarsMap[wallet] = profile.avatarUrl;
        }
      }

      // Prefer conversation-level metadata (member profiles, counterpart profile, member wallets)
      try {
        Conversation? conv;
        for (final c in _conversations) {
          if (c.id == conversationId) {
            conv = c;
            break;
          }
        }
        if (conv != null) {
          if (conv.memberProfiles.isNotEmpty) {
            for (final profile in conv.memberProfiles) {
              seedFromProfile(profile);
            }
          }
          if (conv.counterpartProfile != null) {
            seedFromProfile(conv.counterpartProfile!);
          }
          if (conv.memberWallets.isNotEmpty) {
            for (final wallet in conv.memberWallets) {
              addWallet(wallet);
            }
          }
        }
      } catch (_) {}

      // Get members list from members cache if available
      final cache = _membersCache[conversationId];
      final now = DateTime.now().millisecondsSinceEpoch;
      if (cache != null) {
        final ts = cache['ts'] as int? ?? 0;
        if (now - ts < 30000) {
          try {
            final members = (cache['result'] as List<dynamic>?) ?? [];
            for (final m in members) {
              final map = (m as Map).cast<String, dynamic>();
              final w = WalletUtils.normalize((map['wallet_address'] ??
                      map['wallet'] ??
                      map['walletAddress'] ??
                      map['id'])
                  ?.toString());
              if (w.isNotEmpty) {
                addWallet(w);
                final displayName =
                    (map['displayName'] ?? map['display_name'] ?? map['name'])
                        ?.toString();
                if (displayName != null &&
                    displayName.isNotEmpty &&
                    (namesMap[w] == null || namesMap[w]!.isEmpty)) {
                  namesMap[w] = displayName;
                }
                final avatar =
                    (map['avatar_url'] ?? map['avatarUrl'] ?? map['avatar'])
                        ?.toString();
                if (avatar != null &&
                    avatar.isNotEmpty &&
                    (avatarsMap[w] == null || avatarsMap[w]!.isEmpty)) {
                  avatarsMap[w] = avatar;
                }
              }
            }
          } catch (_) {}
        }
      }
      // If still empty, try inferring from recent messages
      if (wallets.isEmpty) {
        final msgs = _messages[conversationId];
        if (msgs != null) {
          final set = <String>{};
          for (final m in msgs) {
            final w = WalletUtils.normalize(m.senderWallet);
            if (w.isNotEmpty && w != _currentWallet) set.add(w);
          }
          for (final w in set) {
            addWallet(w);
          }
        }
      }
      // Populate returned maps from provider cache (usercache)
      result['members'] = wallets;
      for (final w in wallets) {
        final cu = _userCache[w];
        if (cu != null) {
          // Only expose real profileImageUrl from cache here; do not fabricate a safe avatar in provider-level maps.
          if ((avatarsMap[w] == null || avatarsMap[w]!.isEmpty) &&
              (cu.profileImageUrl ?? '').isNotEmpty) {
            avatarsMap[w] = cu.profileImageUrl;
          }
          if ((namesMap[w] == null || namesMap[w]!.isEmpty) &&
              cu.name.isNotEmpty) {
            namesMap[w] = cu.name;
          }
        } else {
          // Do not assign a fabricated avatar here; let the UI/widget decide how to render missing avatars.
          namesMap[w] ??= w;
        }
      }
    } catch (e) {
      debugPrint(
          'ChatProvider.getPreloadedProfileMapsForConversation failed: $e');
    }
    return result;
  }

  List<User> _seedConversationMetadataCaches(Conversation conv) {
    final seededUsers = <User>[];
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entries = <Map<String, dynamic>>[];
      final seenWallets = <String>{};

      void addProfile(ConversationMemberProfile profile) {
        final wallet = WalletUtils.normalize(profile.wallet);
        if (wallet.isEmpty) return;
        final canonical = WalletUtils.canonical(wallet);
        if (!seenWallets.add(canonical)) return;
        entries.add({
          'wallet_address': wallet,
          'wallet': wallet,
          'walletAddress': wallet,
          'displayName': profile.displayName,
          'display_name': profile.displayName,
          'name': profile.displayName,
          'avatar_url': profile.avatarUrl,
          'avatarUrl': profile.avatarUrl,
          'avatar': profile.avatarUrl,
        });
        final newUser = _buildUserFromProfile(profile);
        final existing = _userCache[wallet];
        var shouldReplace = false;
        if (existing == null) {
          shouldReplace = true;
        } else {
          final existingAvatar = existing.profileImageUrl ?? '';
          final incomingAvatar = newUser.profileImageUrl ?? '';
          final existingName = existing.name;
          if (existingAvatar.isEmpty && incomingAvatar.isNotEmpty) {
            shouldReplace = true;
          }
          if ((existingName.isEmpty || existingName == existing.id) &&
              newUser.name.isNotEmpty) {
            shouldReplace = true;
          }
        }
        if (shouldReplace) {
          _cacheUser(newUser);
          seededUsers.add(newUser);
        }
      }

      if (conv.memberProfiles.isNotEmpty) {
        for (final profile in conv.memberProfiles) {
          addProfile(profile);
        }
      }
      if (conv.counterpartProfile != null) {
        addProfile(conv.counterpartProfile!);
      }
      if (conv.memberWallets.isNotEmpty) {
        for (final wallet in conv.memberWallets) {
          final trimmed = WalletUtils.normalize(wallet);
          if (trimmed.isEmpty) continue;
          final canonical = WalletUtils.canonical(trimmed);
          if (seenWallets.contains(canonical)) continue;
          seenWallets.add(canonical);
          entries.add({
            'wallet_address': trimmed,
            'wallet': trimmed,
            'walletAddress': trimmed,
          });
        }
      }

      if (entries.isNotEmpty) {
        _cacheMembers(conv.id, entries, timestampMs: now);
      }
    } catch (e) {
      debugPrint('ChatProvider._seedConversationMetadataCaches error: $e');
    }
    return seededUsers;
  }

  User _buildUserFromProfile(ConversationMemberProfile profile) {
    final wallet = profile.wallet.trim();
    final displayName =
        (profile.displayName != null && profile.displayName!.trim().isNotEmpty)
            ? profile.displayName!.trim()
            : wallet;
    final sanitized =
        displayName.replaceAll(RegExp(r'[^a-zA-Z0-9_\s]'), '').trim();
    final usernameSeed = sanitized.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final fallbackUsername = usernameSeed.isNotEmpty
        ? usernameSeed
        : (wallet.length > 8 ? wallet.substring(0, 8) : wallet);
    return User(
      id: wallet,
      name: displayName,
      username: '@$fallbackUsername',
      bio: '',
      profileImageUrl: profile.avatarUrl,
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      isFollowing: false,
      isVerified: false,
      joinedDate: 'Joined recently',
      achievementProgress: const [],
    );
  }

  Future<void> _hydrateConversationsFromPayload(List<dynamic> items,
      {bool forceNotify = true}) async {
    try {
      _conversations = items
          .map((i) => Conversation.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _conversations = [];
    }
    _unreadCounts.clear();
    for (final it in items) {
      try {
        final m = it as Map<String, dynamic>;
        final convId =
            ((m['id'] ?? m['conversationId'] ?? m['conversation_id']) ?? '')
                .toString();
        if (convId.isEmpty) continue;
        final unread =
            (m['unreadCount'] as int?) ?? (m['unread_count'] as int?) ?? 0;
        _unreadCounts[convId] = unread;
      } catch (_) {}
    }
    final seededUsers = <User>[];
    for (final conv in _conversations) {
      seededUsers.addAll(_seedConversationMetadataCaches(conv));
    }
    if (seededUsers.isNotEmpty) {
      try {
        UserService.setUsersInCache(seededUsers);
      } catch (_) {}
    }
    if (forceNotify) {
      _safeNotifyListeners(force: true);
    } else {
      _safeNotifyListeners();
    }
    debugPrint(
        'ChatProvider._hydrateConversationsFromPayload: hydrated ${_conversations.length} conversations');
    try {
      await _prefetchMembersAndProfilesFromConversations(_conversations);
    } catch (e) {
      debugPrint(
          'ChatProvider._hydrateConversationsFromPayload prefetch failed: $e');
    }
  }

  Future<void> _prefetchMembersAndProfilesFromConversations(
      List<Conversation> convs) async {
    try {
      final wallets = <String>{};
      final myWalletCanonical = WalletUtils.canonical(_currentWallet);

      void collectWallet(String? wallet) {
        if (wallet == null) return;
        final normalized = WalletUtils.normalize(wallet);
        if (normalized.isEmpty) return;
        final canonical = WalletUtils.canonical(normalized);
        if (myWalletCanonical.isNotEmpty && canonical == myWalletCanonical) {
          return;
        }
        wallets.add(normalized);
      }

      final convsNeedingMembers = <Conversation>[];
      for (final conv in convs) {
        var hasMetadata = false;
        if (conv.memberProfiles.isNotEmpty) {
          hasMetadata = true;
          for (final profile in conv.memberProfiles) {
            collectWallet(profile.wallet);
          }
        }
        if (conv.memberWallets.isNotEmpty) {
          hasMetadata = true;
          for (final wallet in conv.memberWallets) {
            collectWallet(wallet);
          }
        }
        if (conv.counterpartProfile != null) {
          hasMetadata = true;
          collectWallet(conv.counterpartProfile!.wallet);
        }
        if (!hasMetadata) {
          convsNeedingMembers.add(conv);
        }
      }

      for (final conv in convsNeedingMembers) {
        try {
          final members = await fetchMembers(conv.id);
          for (final member in members) {
            final wallet = WalletUtils.normalize((member['wallet_address'] ??
                    member['wallet'] ??
                    member['walletAddress'] ??
                    member['id'])
                ?.toString());
            collectWallet(wallet);
          }
        } catch (e) {
          debugPrint(
              'ChatProvider._prefetchMembersAndProfilesFromConversations: fetchMembers failed for ${conv.id}: $e');
        }
      }

      if (wallets.isNotEmpty) {
        await _prefetchUsersForWallets(wallets.toList());
      }
    } catch (e) {
      debugPrint(
          'ChatProvider._prefetchMembersAndProfilesFromConversations error: $e');
    }
  }

  final BackendApiService _api = BackendApiService();
  final SocketService _socket = SocketService();

  List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, int> _unreadCounts = {}; // conversationId -> unread count
  final Map<String, Future<List<Map<String, dynamic>>>> _membersRequests =
      {}; // convId -> in-flight Future
  final Map<String, Map<String, dynamic>> _membersCache =
      {}; // convId -> {'result': List<dynamic>, 'ts': int}
  final Map<String, User> _userCache = {}; // wallet -> User
  StreamSubscription<Map<String, dynamic>>? _eventBusSub;
  StreamSubscription<Map<String, dynamic>>? _eventBusProfilesSub;
  String? _currentWallet;
  String? _openConversationId;
  DateTime? _openConversationStartedAt;
  Timer? _pollTimer;
  Duration? _pollIntervalCurrent;
  Timer? _subscriptionMonitorTimer;
  Duration? _subscriptionMonitorIntervalCurrent;

  bool _initialized = false;
  AppRefreshProvider? _boundRefreshProvider;
  VoidCallback? _refreshListener;
  int _lastChatVersion = 0;
  int _lastGlobalVersion = 0;
  // Throttle for notifyListeners to avoid update storms
  final int _notifyMaxPerSecond = 15;
  int _notificationsThisSecond = 0;
  DateTime _lastNotifyReset = DateTime.now();
  String _lastStateSignature = '';
  int _lastTotalUnread = 0;
  DateTime? _lastUnauthorizedAt;
  final Duration _unauthCooldown = const Duration(seconds: 30);
  String _lastAuthSignature = '';
  DateTime? _lastIncomingMessageAt;
  String? _lastIncomingConversationId;
  final Map<String, int> _messageCacheTouchMs = {};
  final Map<String, int> _membersCacheTouchMs = {};
  final Map<String, int> _userCacheTouchMs = {};

  String _computeStateSignature() {
    try {
      final convCount = _conversations.length;
      int totalMessages = 0;
      // Use a more reliable hash that combines conversation IDs with their message counts
      // and the actual latest message ID (not XOR which can collide)
      final convHashes = <String>[];
      for (final entry in _messages.entries) {
        final count = entry.value.length;
        totalMessages += count;
        if (entry.value.isNotEmpty) {
          // Include conv ID, message count, and first message ID for reliable change detection
          convHashes.add('${entry.key}:$count:${entry.value[0].id}');
        }
      }
      // Sort to ensure consistent ordering
      convHashes.sort();
      final messagesHash = convHashes.join('|');

      final totalUnreadCount = totalUnread;
      // Simpler signature focusing on what matters: conversations, messages, and unread count
      return '$convCount:$totalMessages:${messagesHash.hashCode}:$totalUnreadCount';
    } catch (e) {
      return '';
    }
  }

  void _safeNotifyListeners({bool force = false}) {
    try {
      // Reset throttle counter every second
      final now = DateTime.now();
      if (now.difference(_lastNotifyReset).inSeconds >= 1) {
        _notificationsThisSecond = 0;
        _lastNotifyReset = now;
      }

      var effectiveForce = force;

      // Always force notify when the total unread count changed
      try {
        final currTotal = totalUnread;
        if (currTotal != _lastTotalUnread) {
          effectiveForce = true;
          _lastTotalUnread = currTotal;
        }
      } catch (_) {}

      // If forced, skip all checks and notify immediately
      if (effectiveForce) {
        notifyListeners();
        return;
      }

      // Apply throttle for non-forced updates
      _notificationsThisSecond++;
      if (_notificationsThisSecond > _notifyMaxPerSecond) {
        debugPrint(
            'ChatProvider._safeNotifyListeners: throttled, notified $_notificationsThisSecond times this second');
        return;
      }

      // Check signature to avoid redundant notifications
      try {
        final sig = _computeStateSignature();
        if (sig == _lastStateSignature) {
          return; // No change detected
        }
        _lastStateSignature = sig;
      } catch (e) {
        // If signature computation fails, notify anyway to be safe
      }

      notifyListeners();
    } catch (e) {
      debugPrint('ChatProvider._safeNotifyListeners: error: $e');
    }
  }

  List<Conversation> get conversations => _conversations;
  Map<String, List<ChatMessage>> get messages => _messages;
  Map<String, int> get unreadCounts => _unreadCounts;
  User? getCachedUser(String wallet) {
    final cached = _userCache[wallet];
    if (cached != null) {
      _userCacheTouchMs[wallet] = DateTime.now().millisecondsSinceEpoch;
    }
    return cached;
  }

  bool get isAuthenticated => (_api.getAuthToken() ?? '').isNotEmpty;
  bool get _hasAuthToken => (_api.getAuthToken() ?? '').isNotEmpty;
  bool get _hasAuthContext =>
      _hasAuthToken || ((_currentWallet ?? '').isNotEmpty);
  Map<String, Object?> get debugResourceSnapshot => <String, Object?>{
        'initialized': _initialized,
        'hasAuthToken': _hasAuthToken,
        'currentWallet': _currentWallet,
        'openConversationId': _openConversationId,
        'lastIncomingMessageAt': _lastIncomingMessageAt?.toIso8601String(),
        'lastIncomingConversationId': _lastIncomingConversationId,
        'conversationCount': _conversations.length,
        'messageConversationCount': _messages.length,
        'cachedMemberLists': _membersCache.length,
        'cachedUsers': _userCache.length,
        'activeTimers': <String, bool>{
          'pollTimer': _pollTimer?.isActive ?? false,
          'subscriptionMonitor': _subscriptionMonitorTimer?.isActive ?? false,
        },
        'timerIntervalsSeconds': <String, int?>{
          'poll': _pollIntervalCurrent?.inSeconds,
          'subscriptionMonitor': _subscriptionMonitorIntervalCurrent?.inSeconds,
        },
        'socketConnected': _socket.isConnected,
        'subscribedConversationIdsCount':
            _socket.subscribedConversationIds.length,
        'bindings': <String, bool>{
          'refreshProvider': _boundRefreshProvider != null,
          'refreshListener': _refreshListener != null,
          'eventBusProfile': _eventBusSub != null,
          'eventBusProfiles': _eventBusProfilesSub != null,
        },
        'socket': _socket.debugResourceSnapshot,
      };

  @visibleForTesting
  void handleIncomingMessageForTesting(Map<String, dynamic> data) {
    _onMessageReceived(data);
  }

  @visibleForTesting
  void setCurrentWalletForTesting(String? wallet) {
    _currentWallet = wallet;
  }

  @visibleForTesting
  void setOpenConversationForTesting(String? conversationId) {
    final normalized = (conversationId ?? '').trim();
    _openConversationId = normalized.isEmpty ? null : normalized;
    _openConversationStartedAt = normalized.isEmpty ? null : DateTime.now();
  }

  void _unbindRefreshProvider() {
    final provider = _boundRefreshProvider;
    final listener = _refreshListener;
    if (provider != null && listener != null) {
      try {
        provider.removeListener(listener);
      } catch (_) {}
    }
    _refreshListener = null;
    _boundRefreshProvider = null;
  }

  void _cacheMessages(String conversationId, List<ChatMessage> messages) {
    _chatProviderCacheMessages(this, conversationId, messages);
  }

  void _touchMessageCache(String conversationId) {
    _chatProviderTouchMessageCache(this, conversationId);
  }

  void _cacheMembers(
    String conversationId,
    List<dynamic> list, {
    required int timestampMs,
  }) {
    _chatProviderCacheMembers(
      this,
      conversationId,
      list,
      timestampMs: timestampMs,
    );
  }

  void _cacheUser(User user) {
    _chatProviderCacheUser(this, user);
  }

  void _pruneCacheMap<T>(
    Map<String, T> cache,
    Map<String, int> touchMs,
    int maxEntries, {
    String? preserveKey,
  }) {
    _chatProviderPruneCacheMap(
      cache,
      touchMs,
      maxEntries,
      preserveKey: preserveKey,
    );
  }

  void _resetSessionState({
    required String reason,
    bool notify = true,
  }) {
    _chatProviderResetSessionState(this, reason: reason, notify: notify);
  }

  Future<void> initialize({String? initialWallet}) async {
    final normalizedInitialWallet = (initialWallet ?? '').trim();
    if (_initialized) {
      if (normalizedInitialWallet.isNotEmpty) {
        await setCurrentWallet(normalizedInitialWallet);
      } else if (_conversations.isEmpty && isAuthenticated) {
        unawaited(refreshConversations());
      }
      return;
    }
    _initialized = true;
    // We do not automatically initialize persisted user cache here to avoid
    // eagerly loading data for anonymous users; initialization occurs on wallet
    // registration or profile load.
    // Ensure auth token loaded once (and attempt single issuance if wallet provided)
    var hasSession = false;
    try {
      if (normalizedInitialWallet.isNotEmpty) {
        await _api.ensureAuthLoaded(walletAddress: initialWallet);
      }
      hasSession = await _api.restoreExistingSession();
    } catch (_) {}
    if (!hasSession) {
      _initialized = false;
      _currentWallet =
          normalizedInitialWallet.isNotEmpty ? normalizedInitialWallet : null;
      if (kDebugMode) {
        debugPrint(
          'ChatProvider.initialize: skipping protected init - no restored auth session',
        );
      }
      return;
    }
    // Determine wallet early so we can try to issue a token for the wallet before socket connect
    try {
      if (initialWallet != null && initialWallet.isNotEmpty) {
        _currentWallet = initialWallet;
        debugPrint(
            'ChatProvider.initialize: initialWallet provided: $_currentWallet');
      }
      final meResp = await _api.getMyProfile();
      debugPrint('ChatProvider.initialize: getMyProfile response: $meResp');
      if (meResp['success'] == true && meResp['data'] != null) {
        final me = meResp['data'] as Map<String, dynamic>;
        _currentWallet =
            (me['wallet_address'] ?? me['walletAddress'] ?? me['wallet'])
                ?.toString();
        debugPrint(
            'ChatProvider.initialize: wallet from getMyProfile: $_currentWallet');
      }
    } catch (e) {
      debugPrint('ChatProvider: getMyProfile failed: $e');
      // Fallback: try to read persisted wallet from shared preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final w = prefs.getString('wallet_address') ??
            prefs.getString('user_id') ??
            prefs.getString('wallet') ??
            '';
        debugPrint(
            'ChatProvider.initialize: SharedPreferences wallet read: $w');
        if (w.isNotEmpty) _currentWallet = w.toString();
      } catch (e2) {
        debugPrint(
            'ChatProvider: Failed to read wallet from shared prefs: $e2');
      }
    }
    // Token issuance handled centrally via ensureAuthLoaded; no further action here.
    // Register socket listeners then connect & subscribe (with token if present)
    _socket.connect(_api.baseUrl);
    _socket.addMessageListener(_onMessageReceived);
    _socket.addMessageReadListener(_onMessageRead);
    _socket.addConversationListener(_onNewConversation);
    _socket.addConversationListener(_onMembersUpdated);
    _socket.addConversationListener(_onConversationUpdated);
    _socket.addConversationListener(_onConversationMemberRead);
    _socket.addConversationListener(_onConversationRenamed);
    _socket.addMessageReactionListener(_onMessageReaction);
    await refreshConversations();
    // After loading conversations, proactively fetch member profiles for faster UI updates
    try {
      final allWallets = <String>{};
      for (final conv in _conversations) {
        try {
          final members = await fetchMembers(conv.id);
          for (final m in members) {
            final wallet = ((m['wallet_address'] ??
                        m['wallet'] ??
                        m['walletAddress'] ??
                        m['id'])
                    ?.toString() ??
                '');
            if (wallet.isNotEmpty) allWallets.add(wallet);
          }
        } catch (_) {}
      }
      if (allWallets.isNotEmpty) {
        await _prefetchUsersForWallets(allWallets.toList());
      }
    } catch (e) {
      debugPrint('ChatProvider.initialize: prefetch users failed: $e');
    }
    // Subscribe to user room if we have a wallet
    try {
      if (_currentWallet != null && _currentWallet!.isNotEmpty) {
        // Attempt to connect and confirm subscription before loading messages; fallback to subscribeUser if not supported
        try {
          var ok =
              await _socket.connectAndSubscribe(_api.baseUrl, _currentWallet!);
          debugPrint('ChatProvider: socket connectAndSubscribe result: $ok');
          if (!ok) {
            debugPrint(
                'ChatProvider: connectAndSubscribe failed, attempting token issuance and retry');
            try {
              if (AppConfig.enableDebugIssueToken) {
                final issued =
                    await _api.issueDebugTokenForWallet(_currentWallet!);
                if (issued) {
                  await _api.loadAuthToken();
                  ok = await _socket.connectAndSubscribe(
                      _api.baseUrl, _currentWallet!);
                  debugPrint(
                      'ChatProvider: socket connectAndSubscribe retry result: $ok');
                }
              }
            } catch (e2) {
              debugPrint('ChatProvider: token issuance retry failed: $e2');
            }
          }
          if (!ok) {
            // attempt subscribe as best effort
            _socket.subscribeUser(_currentWallet!);
          }
        } catch (e) {
          debugPrint(
              'ChatProvider: connectAndSubscribe failed, falling back: $e');
          _socket.subscribeUser(_currentWallet!);
        }
        // Log subscription state for debugging
        try {
          final currentSub = _socket.currentSubscribedWallet;
          debugPrint(
              'ChatProvider.initialize: socket currentSubscribedWallet=$currentSub expected=$_currentWallet');
        } catch (_) {}
      } else {
        // try to determine wallet if not set
        try {
          final meResp2 = await _api.getMyProfile();
          if (meResp2['success'] == true && meResp2['data'] != null) {
            final me2 = meResp2['data'] as Map<String, dynamic>;
            _currentWallet =
                (me2['wallet_address'] ?? me2['walletAddress'] ?? me2['wallet'])
                    ?.toString();
            if (_currentWallet != null && _currentWallet!.isNotEmpty) {
              try {
                final ok2 = await _socket.connectAndSubscribe(
                    _api.baseUrl, _currentWallet!);
                debugPrint(
                    'ChatProvider: socket connectAndSubscribe result (after profile try): $ok2');
                if (!ok2) _socket.subscribeUser(_currentWallet!);
              } catch (e2) {
                debugPrint(
                    'ChatProvider: connectAndSubscribe fallback failed after profile try: $e2');
                _socket.subscribeUser(_currentWallet!);
              }
            }
          }
        } catch (e) {
          debugPrint(
              'ChatProvider: Failed to determine current wallet during subscribe: $e');
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: socket subscribe failed: $e');
    }
    // Start a periodic subscription monitor to ensure we stay subscribed to the user's room
    _startSubscriptionMonitor();
    // Subscribe to EventBus profile updates so that ChatProvider merges updated profiles
    try {
      _eventBusSub = EventBus().on('profile_updated').listen((m) {
        try {
          final payload = m['payload'];
          if (payload == null) return;
          User? u;
          if (payload is UserProfile) {
            final p = payload;
            u = User(
              id: p.walletAddress,
              name: p.displayName,
              username: p.username,
              bio: p.bio,
              profileImageUrl: p.avatar,
              coverImageUrl: MediaUrlResolver.resolve(p.coverImage),
              followersCount: p.stats?.followersCount ?? 0,
              followingCount: p.stats?.followingCount ?? 0,
              postsCount: p.stats?.artworksCreated ?? 0,
              isFollowing: false,
              isVerified: false,
              joinedDate: p.createdAt.toIso8601String(),
              achievementProgress: [],
            );
          } else if (payload is Map<String, dynamic>) {
            final map = payload;
            // attempt to parse as UserProfile-like map
            try {
              final p = UserProfile.fromJson(map);
              u = User(
                id: p.walletAddress,
                name: p.displayName,
                username: p.username,
                bio: p.bio,
                profileImageUrl: p.avatar,
                coverImageUrl: MediaUrlResolver.resolve(p.coverImage),
                followersCount: p.stats?.followersCount ?? 0,
                followingCount: p.stats?.followingCount ?? 0,
                postsCount: p.stats?.artworksCreated ?? 0,
                isFollowing: false,
                isVerified: false,
                joinedDate: p.createdAt.toIso8601String(),
                achievementProgress: [],
              );
            } catch (_) {}
          } else if (payload is User) {
            u = payload;
          }
          if (u != null) {
            try {
              mergeUserCache([u]);
            } catch (_) {}
          }
        } catch (e) {
          debugPrint(
              'ChatProvider: EventBus profile_updated handler error: $e');
        }
      });
    } catch (e) {
      debugPrint('ChatProvider: EventBus subscription failed: $e');
    }
    try {
      _eventBusProfilesSub = EventBus().on('profiles_updated').listen((m) {
        try {
          final payload = m['payload'];
          if (payload is List) {
            final users = <User>[];
            for (final item in payload) {
              if (item == null) continue;
              if (item is User) {
                users.add(item);
              } else if (item is Map<String, dynamic>) {
                try {
                  // Attempt to parse minimal fields to User
                  final id = (item['id'] ??
                              item['wallet_address'] ??
                              item['wallet'] ??
                              item['username'])
                          ?.toString() ??
                      '';
                  final name =
                      (item['name'] ?? item['displayName'] ?? '')?.toString() ??
                          '';
                  final username = (item['username'] ?? '')?.toString() ?? '';
                  final avatar = (item['profileImageUrl'] ??
                          item['avatar'] ??
                          item['avatar_url'] ??
                          '')
                      ?.toString();
                  final followers = (item['followersCount'] ??
                          item['followers_count'] ??
                          0) as int? ??
                      0;
                  final following = (item['followingCount'] ??
                          item['following_count'] ??
                          0) as int? ??
                      0;
                  final posts = (item['postsCount'] ?? item['posts_count'] ?? 0)
                          as int? ??
                      0;
                  final u = User(
                      id: id,
                      name: name,
                      username: username,
                      bio: (item['bio'] ?? '')?.toString() ?? '',
                      profileImageUrl: avatar,
                      followersCount: followers,
                      followingCount: following,
                      postsCount: posts,
                      isFollowing: false,
                      isVerified: false,
                      joinedDate: '',
                      achievementProgress: []);
                  users.add(u);
                } catch (_) {}
              }
            }
            if (users.isNotEmpty) mergeUserCache(users);
          }
        } catch (e) {
          debugPrint('ChatProvider: profiles_updated handler error: $e');
        }
      });
    } catch (e) {
      debugPrint(
          'ChatProvider: EventBus profiles_updated subscription failed: $e');
    }
    // Previously we relied on an internal cacheVersion notifier to trigger UI updates,
    // but that pattern caused repeated refreshes and UI update storms. We now avoid
    // relying on implicit cache notifications and prefer explicit API calls
    // via UserService.getUsersByWallets/getUserById when needed.
    // (previously we attempted to issue token here, moved earlier)
  }

  void _startSubscriptionMonitor() {
    _chatProviderStartSubscriptionMonitor(this);
  }

  /// Bind to AppRefreshProvider for global or targeted chat refresh triggers
  void bindToRefresh(AppRefreshProvider appRefresh) {
    _chatProviderBindToRefresh(this, appRefresh);
  }

  void handleAppForegroundChanged(bool isForeground) {
    _chatProviderHandleAppForegroundChanged(this, isForeground);
  }

  void handleViewVisibilityChanged() {
    _chatProviderHandleViewVisibilityChanged(this);
  }
  // Force a notify when UI-driven fetches merge into the provider cache.
  // This bypasses the signature dedupe check so profile/avatar updates
  // take effect immediately in UI widgets that rely on provider state.

  void bindAuthContext(
      {ProfileProvider? profileProvider,
      String? walletAddress,
      bool? isSignedIn}) {
    _chatProviderBindAuthContext(
      this,
      profileProvider: profileProvider,
      walletAddress: walletAddress,
      isSignedIn: isSignedIn,
    );
  }

  Future<void> refreshConversations() async {
    try {
      debugPrint(
          'ChatProvider.refreshConversations: isAuthenticated=$_hasAuthToken');
      if (!_hasAuthContext) {
        return;
      }
      if (_lastUnauthorizedAt != null &&
          DateTime.now().difference(_lastUnauthorizedAt!) < _unauthCooldown) {
        return;
      }
      // Ensure we attempt to issue or load auth token before making protected call
      final hasSession = await _api.restoreExistingSession();
      if (!hasSession) {
        _lastUnauthorizedAt = DateTime.now();
        return;
      }
      if (!_hasAuthToken && (_currentWallet ?? '').isNotEmpty) {
        try {
          await _api.ensureAuthLoaded(walletAddress: _currentWallet);
        } catch (_) {}
      }
      final resp = await _api.fetchConversations();
      if (resp['status'] == 401) {
        _lastUnauthorizedAt = DateTime.now();
        return;
      }
      if (resp['success'] == true) {
        final items = (resp['data'] as List<dynamic>?) ?? [];
        await _hydrateConversationsFromPayload(items);
        _lastUnauthorizedAt = null;
        debugPrint(
            'ChatProvider.refreshConversations: loaded ${_conversations.length} conversations');
      }
    } catch (e) {
      debugPrint('ChatProvider: Error refreshing conversations: $e');
    }
  }

  void _upsertConversationMetadataForMessage(
      String conversationId, ChatMessage message,
      {bool force = false}) {
    final convId = conversationId.trim();
    if (convId.isEmpty) return;
    final index = _conversations.indexWhere((c) => c.id == convId);
    if (index == -1) return;

    final existing = _conversations[index];
    final lastAt = existing.lastMessageAt;
    final shouldUpdateTimestamp = force ||
        lastAt == null ||
        message.createdAt.isAfter(lastAt) ||
        message.createdAt.isAtSameMomentAs(lastAt);

    final updated = Conversation(
      id: existing.id,
      title: existing.title,
      rawTitle: existing.rawTitle,
      isGroup: existing.isGroup,
      createdBy: existing.createdBy,
      lastMessageAt:
          shouldUpdateTimestamp ? message.createdAt : existing.lastMessageAt,
      lastMessage:
          shouldUpdateTimestamp ? message.message : existing.lastMessage,
      displayAvatar: existing.displayAvatar,
      memberWallets: existing.memberWallets,
      memberProfiles: existing.memberProfiles,
      memberCount: existing.memberCount,
      counterpartProfile: existing.counterpartProfile,
    );

    if (!shouldUpdateTimestamp) {
      _conversations[index] = updated;
      return;
    }

    if (index == 0) {
      _conversations[0] = updated;
    } else {
      _conversations.removeAt(index);
      _conversations.insert(0, updated);
    }
  }

  Map<String, dynamic>? _normalizeIncomingMessagePayload(
      Map<String, dynamic> data) {
    Map<String, dynamic>? unwrapCandidate(Object? candidate) {
      if (candidate is! Map) return null;
      final map = Map<String, dynamic>.from(candidate);
      final nestedMessage = map['message'];
      if (nestedMessage is Map) {
        return Map<String, dynamic>.from(nestedMessage);
      }
      return map;
    }

    final rawMessage = unwrapCandidate(data['message']);
    if (rawMessage != null) return rawMessage;

    final rawData = unwrapCandidate(data['data']);
    if (rawData != null) return rawData;

    final rawPayload = unwrapCandidate(data['payload']);
    if (rawPayload != null) return rawPayload;

    final rawRaw = unwrapCandidate(data['raw']);
    if (rawRaw != null) {
      return _looksLikeIncomingMessage(rawRaw) ? rawRaw : null;
    }

    return _looksLikeIncomingMessage(data) ? Map<String, dynamic>.from(data) : null;
  }

  String _extractIncomingConversationId(
    Map<String, dynamic> data,
    Map<String, dynamic> payload,
  ) {
    final dataNode = data['data'];
    final dataMap =
        dataNode is Map ? Map<String, dynamic>.from(dataNode) : null;
    final payloadNode = data['payload'];
    final payloadMap =
        payloadNode is Map ? Map<String, dynamic>.from(payloadNode) : null;

    return (payload['conversationId'] ??
            payload['conversation_id'] ??
            data['conversationId'] ??
            data['conversation_id'] ??
            dataMap?['conversationId'] ??
            dataMap?['conversation_id'] ??
            payloadMap?['conversationId'] ??
            payloadMap?['conversation_id'] ??
            '')
        .toString()
        .trim();
  }

  bool _looksLikeIncomingMessage(Map<String, dynamic> payload) {
    final event = payload['event']?.toString().toLowerCase() ?? '';
    final eventType = payload['eventType']?.toString().toLowerCase() ?? '';
    final type = payload['type']?.toString().toLowerCase() ?? '';
    final nonMessageSignals = <String>[
      event,
      eventType,
      type,
    ].join('|');
    if (nonMessageSignals.contains('read') ||
        nonMessageSignals.contains('receipt') ||
        nonMessageSignals.contains('member') ||
        nonMessageSignals.contains('reaction') ||
        nonMessageSignals.contains('subscribe') ||
        nonMessageSignals.contains('update') ||
        nonMessageSignals.contains('conversation') ||
        nonMessageSignals.contains('notification')) {
      return false;
    }

    final hasBody = (payload['message']?.toString().trim().isNotEmpty == true) ||
        (payload['content']?.toString().trim().isNotEmpty == true) ||
        (payload['text']?.toString().trim().isNotEmpty == true) ||
        (payload['body']?.toString().trim().isNotEmpty == true);
    final hasRenderableAttachment = payload['attachment'] is Map ||
        payload['attachments'] is List ||
        payload['media'] is Map ||
        payload['image'] != null ||
        payload['file'] != null ||
        payload['url'] != null;
    final hasReply = payload['replyTo'] is Map || payload['reply_to'] is Map;
    final hasReactions = (payload['reactions'] as List?)?.isNotEmpty == true;

    return hasBody || hasRenderableAttachment || hasReply || hasReactions;
  }

  bool _isNonMessageEventPayload(Map<String, dynamic> data) {
    final topLevelEvent = data['event']?.toString().toLowerCase() ?? '';
    final topLevelEventType = data['eventType']?.toString().toLowerCase() ?? '';
    final topLevelType = data['type']?.toString().toLowerCase() ?? '';
    final topLevelSignals = <String>[topLevelEvent, topLevelEventType, topLevelType].join('|');
    if (topLevelSignals.contains('notification') ||
        topLevelSignals.contains('read') ||
        topLevelSignals.contains('receipt') ||
        topLevelSignals.contains('member') ||
        topLevelSignals.contains('reaction') ||
        topLevelSignals.contains('subscribe') ||
        topLevelSignals.contains('update')) {
      return true;
    }

    final payload = _normalizeIncomingMessagePayload(data);
    if (payload == null) return true;

    final keys = payload.keys.map((key) => key.toString().toLowerCase()).toSet();
    final onlyMetaKeys = keys.every((key) => <String>{
          'event',
          'eventtype',
          'type',
          'reader',
          'readers',
          'read_at',
          'readat',
          'room',
          'conversationid',
          'conversation_id',
          'messageid',
          'message_id',
          'member',
          'members',
          'payload',
          'data',
          'raw',
          'status',
          'state',
          'subscription',
        }.contains(key));
    if (onlyMetaKeys) return true;

    return !_looksLikeIncomingMessage(payload);
  }

  bool _matchesOptimisticMessage(
    ChatMessage current,
    ChatMessage incoming,
  ) {
    final clientTempId = current.data?['clientTempId']?.toString();
    final incomingClientTempId = incoming.data?['clientTempId']?.toString();
    if (clientTempId != null &&
        clientTempId.isNotEmpty &&
        clientTempId == incomingClientTempId) {
      return true;
    }

    final isOptimistic = current.id.startsWith('temp-') ||
        current.data?['sendStatus']?.toString() == 'sending';
    if (!isOptimistic) return false;
    if (!WalletUtils.equals(current.senderWallet, incoming.senderWallet)) {
      return false;
    }
    if (current.message.trim() != incoming.message.trim()) return false;

    final deltaSeconds =
        current.createdAt.difference(incoming.createdAt).inSeconds.abs();
    return deltaSeconds <= 120;
  }

  void _onMessageReceived(Map<String, dynamic> data) {
    try {
      // Multi-layer validation: reject non-message events before attempting to parse as ChatMessage.
      if (_isNonMessageEventPayload(data)) {
        if (kDebugMode) {
          debugPrint('ChatProvider._onMessageReceived: rejecting non-message event payload');
        }
        return;
      }
      
      final payload = _normalizeIncomingMessagePayload(data);
      if (payload == null) {
        if (kDebugMode) {
          debugPrint('ChatProvider._onMessageReceived: payload normalization failed');
        }
        return;
      }

      final convId = _extractIncomingConversationId(data, payload);
      if (convId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              'ChatProvider._onMessageReceived: missing conversation id; rawData=$data');
        }
        return;
      }

      final msg = ChatMessage.fromJson(<String, dynamic>{
        ...payload,
        'conversationId': convId,
      });
      if (!_isRenderableIncomingMessage(msg)) {
        if (kDebugMode) {
          debugPrint(
              'ChatProvider._onMessageReceived: ignoring non-renderable payload=${payload.keys.toList()}');
        }
        return;
      }
      final normalizedMsg = msg;
      final existing = _messages[convId] ?? const <ChatMessage>[];
      final next = <ChatMessage>[];
      var inserted = false;
      final alreadyHadServerMessage =
          existing.any((message) => message.id == normalizedMsg.id);
      for (final current in existing) {
        if (current.id == normalizedMsg.id ||
            _matchesOptimisticMessage(current, normalizedMsg)) {
          if (!inserted) {
            next.add(normalizedMsg);
            inserted = true;
          }
        } else {
          next.add(current);
        }
      }
      if (!inserted) next.add(normalizedMsg);
      next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cacheMessages(convId, next);
      _lastIncomingMessageAt = DateTime.now();
      _lastIncomingConversationId = convId;

      final isOpen = _openConversationId == convId;
      if (isOpen) {
        _unreadCounts[convId] = 0;
        markMessageReadLocal(convId, normalizedMsg.id);
        _sendMarkMessageReadToServer(convId, normalizedMsg.id);
      } else if (!alreadyHadServerMessage &&
          !WalletUtils.equals(normalizedMsg.senderWallet, _currentWallet)) {
        _unreadCounts[convId] = (_unreadCounts[convId] ?? 0) + 1;
      }
      _upsertConversationMetadataForMessage(convId, normalizedMsg);
      // Trigger an OS/local notification for incoming messages when the conversation
      // is not open. PushNotificationService will no-op if permission not granted.
      try {
        if (!isOpen) {
          final senderWallet = normalizedMsg.senderWallet;
          final authorName = (_userCache[senderWallet]?.name) ??
              (senderWallet.length > 10
                  ? '${senderWallet.substring(0, 10)}...'
                  : senderWallet);
          final content = normalizedMsg.message.toString();
          // Fire-and-forget: service early-returns when permission is not granted
          PushNotificationService()
              .showCommunityNotification(
            postId: normalizedMsg.id,
            authorName: authorName,
            content: content,
          )
              .catchError((e) {
            debugPrint('ChatProvider: showCommunityNotification failed: $e');
          });
        }
      } catch (e) {
        debugPrint(
            'ChatProvider: Failed to show local notification for incoming message: $e');
      }
      if (kDebugMode) {
        debugPrint(
            'ChatProvider: _onMessageReceived: convId=$convId, msgId=${normalizedMsg.id}, messagesInConv=${_messages[convId]?.length ?? 0}, unread=${_unreadCounts[convId]}');
        // Report whether this conversation is known locally.
        final convIdx = _conversations.indexWhere((c) => c.id == convId);
        debugPrint(
            'ChatProvider: conv known locally: ${convIdx >= 0}, convCount=${_conversations.length}, index=$convIdx');
      }
      // Force notify so unread badge updates are immediate in UI
      _safeNotifyListeners(force: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ChatProvider: Error handling incoming message: $e');
      }
    }
  }

  bool _isRenderableIncomingMessage(ChatMessage message) => message.isRenderable;

  void _onMessageRead(Map<String, dynamic> data) {
    try {
      final convId =
          (data['conversation_id'] ?? data['conversationId'] ?? '').toString();
      final messageId =
          (data['message_id'] ?? data['messageId'] ?? '').toString();
      final reader = (data['reader'] ?? data['wallet'] ?? '').toString();

      if (convId.isEmpty || messageId.isEmpty) return;

      debugPrint(
          'ChatProvider._onMessageRead: convId=$convId, messageId=$messageId, reader=$reader');

      final list = _messages[convId];
      if (list == null) {
        debugPrint(
            'ChatProvider._onMessageRead: No messages found for conv $convId');
        return;
      }

      var messageFound = false;
      for (var i = 0; i < list.length; i++) {
        final m = list[i];
        if (m.id != messageId) continue;

        messageFound = true;

        // Check if this reader is already in the list
        final readerCanonical = WalletUtils.canonical(reader);
        final alreadyRegistered = m.readers.any((r) {
          final existing = WalletUtils.normalize(
              (r['wallet_address'] ?? r['wallet'] ?? '').toString());
          return existing.isNotEmpty &&
              WalletUtils.equals(existing, readerCanonical);
        });

        if (alreadyRegistered) {
          debugPrint(
              'ChatProvider._onMessageRead: Reader $reader already registered for message $messageId');
          break;
        }

        // Add reader to list
        final newReaders = List<Map<String, dynamic>>.from(m.readers);
        final readAt = (data['read_at'] ?? data['readAt'] ?? data['readAtUtc'])
            ?.toString();
        newReaders.add(_buildReaderMetadata(reader,
            readAtOverride: readAt, payload: data));

        final updatedMsg = m.copyWith(
          readers: newReaders,
          readersCount: newReaders.length,
          readByCurrent: (_currentWallet != null &&
                  WalletUtils.equals(reader, _currentWallet))
              ? true
              : m.readByCurrent,
        );

        // Create completely new list instance to ensure change detection
        final newList = <ChatMessage>[];
        for (var j = 0; j < list.length; j++) {
          newList.add(j == i ? updatedMsg : list[j]);
        }
        _cacheMessages(convId, newList);

        // Update unread count if current user is the reader
        if (_currentWallet != null &&
            WalletUtils.equals(reader, _currentWallet)) {
          final curr = _unreadCounts[convId] ?? 0;
          if (curr > 0) _unreadCounts[convId] = curr - 1;
        }

        debugPrint(
            'ChatProvider._onMessageRead: Updated message $messageId with new reader $reader, total readers: ${updatedMsg.readersCount}');

        // Force immediate notification for read receipt updates
        _safeNotifyListeners(force: true);
        break;
      }

      if (!messageFound) {
        debugPrint(
            'ChatProvider._onMessageRead: Message $messageId not found in conversation $convId');
      }
    } catch (e) {
      debugPrint('ChatProvider._onMessageRead error: $e');
    }
  }

  void _onNewConversation(Map<String, dynamic> data) {
    try {
      final conv = Conversation.fromJson(data);
      // Prepend or update conversation in the list
      final idx = _conversations.indexWhere((c) => c.id == conv.id);
      if (idx >= 0) {
        _conversations[idx] = conv;
      } else {
        _conversations.insert(0, conv);
      }
      final seeded = _seedConversationMetadataCaches(conv);
      if (seeded.isNotEmpty) {
        try {
          UserService.setUsersInCache(seeded);
        } catch (_) {}
      }
      try {
        unawaited(_prefetchMembersAndProfilesFromConversations([conv]));
      } catch (_) {}
      // Automatically subscribe to this conversation's socket room for real-time updates
      try {
        _socket.subscribeConversation(conv.id);
      } catch (e) {
        debugPrint(
            'ChatProvider._onNewConversation: subscribeConversation failed: $e');
      }
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('ChatProvider: Error handling new conversation: $e');
    }
  }

  /// Handler for conversation-level member read events emitted by the server.
  /// This updates unread counters for the current user when the server reports
  /// that this user has marked the conversation as read.
  void _onConversationMemberRead(Map<String, dynamic> data) {
    try {
      final convId = ((data['conversationId'] ?? data['conversation_id']) ?? '')
          .toString();
      final wallet = ((data['wallet'] ??
                  data['walletAddress'] ??
                  data['member'] ??
                  data['reader']) ??
              '')
          .toString();
      final lastRead =
          ((data['last_read_at'] ?? data['lastReadAt'] ?? data['lastRead']) ??
                  '')
              .toString();
      debugPrint(
          'ChatProvider._onConversationMemberRead: convId=$convId, wallet=$wallet, lastRead=$lastRead');
      if (convId.isEmpty) return;
      // Compare wallet to current wallet case-insensitively for detection only
      if (wallet.isNotEmpty &&
          _currentWallet != null &&
          WalletUtils.equals(wallet, _currentWallet)) {
        _unreadCounts[convId] = 0;
        _safeNotifyListeners(force: true);
      }
    } catch (e) {
      debugPrint('ChatProvider._onConversationMemberRead: error: $e');
    }
  }

  Future<void> sendMessage(String conversationId, String message,
      {Map<String, dynamic>? data, String? replyToId}) async {
    final nid = conversationId;
    final trimmedMessage = message.trim();
    final hasRenderableData = (data ?? const <String, dynamic>{}).entries.any((entry) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value == null) return false;
      if (value is String && value.trim().isEmpty) return false;
      if (value is List && value.isEmpty) return false;
      if (value is Map && value.isEmpty) return false;
      return const [
        'message',
        'messageText',
        'text',
        'content',
        'body',
        'caption',
        'attachment',
        'attachments',
        'media',
        'image',
        'imageUrl',
        'file',
        'fileUrl',
        'url',
      ].contains(key);
    });
    if (trimmedMessage.isEmpty && !hasRenderableData) return;
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticData = <String, dynamic>{
      ...?data,
      'clientTempId': tempId,
      'sendStatus': 'sending',
    };
    final tempMessage = ChatMessage(
      id: tempId,
      conversationId: nid,
      senderWallet: _currentWallet ?? '',
      message: trimmedMessage,
      data: optimisticData,
      createdAt: DateTime.now(),
      readByCurrent: true,
    );
    final existing = _messages[nid] ?? const <ChatMessage>[];
    _cacheMessages(nid, <ChatMessage>[tempMessage, ...existing]);
    _upsertConversationMetadataForMessage(nid, tempMessage);
    _safeNotifyListeners(force: true);

    try {
      final result = await _api.sendMessage(
        conversationId,
        message,
        data: optimisticData,
        replyToId: replyToId,
      );
      final msg = ChatMessage.fromJson(result['data']);
      final current = _messages[nid] ?? const <ChatMessage>[];
      final replaced = <ChatMessage>[];
      var inserted = false;
      for (final item in current) {
        if (item.id == tempId || item.id == msg.id) {
          if (!inserted) {
            replaced.add(msg);
            inserted = true;
          }
        } else {
          replaced.add(item);
        }
      }
      if (!inserted) replaced.insert(0, msg);
      replaced.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cacheMessages(nid, replaced);
      _upsertConversationMetadataForMessage(nid, msg, force: true);
      _safeNotifyListeners(force: true);
    } catch (e) {
      final current = _messages[nid] ?? const <ChatMessage>[];
      _cacheMessages(
        nid,
        current
            .map((item) => item.id == tempId
                ? item.copyWith(data: {
                    ...?item.data,
                    'sendStatus': 'failed',
                    'error': e.toString(),
                  })
                : item)
            .toList(growable: false),
      );
      _safeNotifyListeners(force: true);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final resp = await _api.fetchConversations();
    if (resp['success'] == true) {
      final items = (resp['data'] as List<dynamic>?) ?? [];
      await _hydrateConversationsFromPayload(items);
      return items.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    // Ensure the backend auth token is loaded before calling API to prevent 401s
    try {
      await _api.ensureAuthLoaded(walletAddress: _currentWallet);
    } catch (_) {}
    Map<String, dynamic> resp;
    try {
      resp = await _api.fetchMessages(conversationId);
    } catch (e) {
      debugPrint(
          'ChatProvider: fetchMessages failed, attempting session restore and retry: $e');
      try {
        final restored = await _api.restoreExistingSession();
        if (!restored) {
          rethrow;
        }
        resp = await _api.fetchMessages(conversationId);
      } catch (e2) {
        debugPrint('ChatProvider: Second attempt to fetchMessages failed: $e2');
        rethrow;
      }
    }
    if (resp['success'] == true) {
      final items = (resp['data'] as List<dynamic>?) ?? [];
      final list = items
          .map((i) => ChatMessage.fromJson(i as Map<String, dynamic>))
          .toList();
      _cacheMessages(conversationId, list);
      debugPrint(
          'ChatProvider.loadMessages: conversationId=$conversationId loaded ${list.length} messages');
      _safeNotifyListeners(force: true);
      // Prefetch sender profiles so message list shows stable names/avatars
      try {
        final wallets = <String>{};
        for (final m in list) {
          final w = m.senderWallet;
          if (w.isNotEmpty) wallets.add(w);
        }
        if (wallets.isNotEmpty) _prefetchUsersForWallets(wallets.toList());
      } catch (e) {
        debugPrint(
            'ChatProvider.loadMessages: prefetch sender profiles failed: $e');
      }
      // If this conversation is currently open, mark it read after loading messages
      if (_openConversationId != null &&
          _openConversationId == conversationId) {
        try {
          await markRead(conversationId);
        } catch (_) {}
      }
      return list;
    }
    return [];
  }

  // Fire-and-forget: inform server that a single message has been read, without
  // performing local state adjustments (used when we already updated local state optimistically).
  Future<void> _sendMarkMessageReadToServer(
      String conversationId, String messageId) async {
    try {
      final resp = await _api.markMessageRead(conversationId, messageId);
      debugPrint(
          'ChatProvider._sendMarkMessageReadToServer: resp=$resp for conv=$conversationId msg=$messageId');
    } catch (e) {
      debugPrint('ChatProvider: _sendMarkMessageReadToServer failed: $e');
    }
  }

  Map<String, dynamic> _buildReaderMetadata(String wallet,
      {String? readAtOverride, Map<String, dynamic>? payload}) {
    final normalizedWallet = wallet.trim();
    final timestamp = (readAtOverride != null && readAtOverride.isNotEmpty)
        ? readAtOverride
        : DateTime.now().toIso8601String();

    String? displayName = (payload?['reader_display_name'] ??
            payload?['readerDisplayName'] ??
            payload?['displayName'])
        ?.toString();
    String? avatarUrl = (payload?['reader_avatar'] ??
            payload?['readerAvatar'] ??
            payload?['avatar_url'] ??
            payload?['avatarUrl'])
        ?.toString();

    final cachedUser = _userCache[normalizedWallet] ??
        UserService.getCachedUser(normalizedWallet);
    if (cachedUser != null) {
      if ((displayName == null || displayName.isEmpty) &&
          cachedUser.name.isNotEmpty) {
        displayName = cachedUser.name;
      }
      final cachedAvatar = cachedUser.profileImageUrl;
      if ((avatarUrl == null || avatarUrl.isEmpty) &&
          cachedAvatar != null &&
          cachedAvatar.isNotEmpty) {
        avatarUrl = cachedAvatar;
      }
    }

    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        UserService.isPlaceholderAvatarUrl(avatarUrl)) {
      avatarUrl = null;
    }
    if (displayName == null || displayName.trim().isEmpty) {
      displayName = normalizedWallet;
    }

    return {
      'wallet_address': normalizedWallet,
      'wallet': normalizedWallet,
      'read_at': timestamp,
      'displayName': displayName,
      'avatar_url': avatarUrl,
    };
  }

  Future<List<Map<String, dynamic>>> fetchMembers(String conversationId) async {
    return _chatProviderFetchMembers(this, conversationId);
  }

  Future<void> _prefetchUsersForWallets(List<String> wallets) async {
    await _chatProviderPrefetchUsersForWallets(this, wallets);
  }

  /// Merge provided users into the ChatProvider user cache and notify listeners.
  /// This is intended for UI code that performs local fetches via UserService
  /// so that the provider cache remains in sync and UI updates are propagated.
  void mergeUserCache(List<User> users) {
    _chatProviderMergeUserCache(this, users);
  }

  Future<Map<String, dynamic>> uploadAttachment(String conversationId,
      List<int> bytes, String filename, String contentType) async {
    final resp = await _api.uploadMessageAttachment(
        conversationId, bytes, filename, contentType);
    if (resp['success'] == true) {
      // The server will broadcast via sockets; ensure local state is refreshed
      await loadMessages(conversationId);
    }
    return resp;
  }

  Future<Conversation?> createConversation(
      String title, bool isGroup, List<String> members) async {
    try {
      await _api.loadAuthToken();
    } catch (_) {}
    // First-pass: fetch conversations from backend and try to find an existing 1:1 conversation
    try {
      var convResp = await _api.fetchConversations();
      // If unauthorized, try to issue a token for current wallet and retry once
      try {
        final status = convResp['status'] as int?;
        if (status == 401) {
          // Resolve wallet if unknown - prefer SharedPreferences (non-sensitive) before any auth calls
          if (_currentWallet == null || _currentWallet!.isEmpty) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final w = prefs.getString('wallet_address') ??
                  prefs.getString('user_id') ??
                  '';
              if (w.isNotEmpty) _currentWallet = w.toString();
            } catch (e2) {
              debugPrint(
                  'createConversation: SharedPreferences fallback for wallet failed: $e2');
            }
            // If we still don't have a wallet and there IS a token, try resolving via getMyProfile
            if ((_api.getAuthToken() ?? '').isNotEmpty &&
                (_currentWallet == null || _currentWallet!.isEmpty)) {
              try {
                final meResp = await _api.getMyProfile();
                if (meResp['success'] == true && meResp['data'] != null) {
                  final me = meResp['data'] as Map<String, dynamic>;
                  _currentWallet = (me['wallet_address'] ??
                          me['walletAddress'] ??
                          me['wallet'])
                      ?.toString();
                }
              } catch (e) {
                debugPrint(
                    'createConversation: getMyProfile failed while resolving wallet for conv list retry: $e');
              }
            }
          }

          if (AppConfig.enableDebugIssueToken &&
              _currentWallet != null &&
              _currentWallet!.isNotEmpty) {
            final issued = await _api.issueDebugTokenForWallet(_currentWallet!);
            if (issued) {
              try {
                await _api.loadAuthToken();
              } catch (_) {}
              convResp = await _api.fetchConversations();
            }
          }
        }
      } catch (e) {
        debugPrint('createConversation: conv fetch retry flow failed: $e');
      }
      // convResp expected to be Map<String,dynamic> with 'data' or 'conversations' list
      List<dynamic> convList = [];
      try {
        if (convResp['data'] is List) {
          convList = convResp['data'] as List<dynamic>;
        } else if (convResp['conversations'] is List) {
          convList = convResp['conversations'] as List<dynamic>;
        }
      } catch (_) {
        convList = [];
      }

      final target = (members.isNotEmpty ? members.first : '');
      if (target.isNotEmpty && !isGroup) {
        for (final item in convList) {
          try {
            final cid = (item is Map<String, dynamic>
                    ? (item['id'] ?? item['conversationId'])
                    : null)
                ?.toString();
            final isGroupFlag = (item is Map<String, dynamic>)
                ? ((item['isGroup'] ?? item['is_group'] ?? false) as bool)
                : false;
            if (cid == null || cid.isEmpty) continue;
            if (isGroupFlag == true) continue;

            final mresp = await _api.fetchConversationMembers(cid);
            if ((mresp['success'] == true) || (mresp['data'] != null)) {
              final list = (mresp['data'] ??
                  mresp['members'] ??
                  mresp['membersList']) as List<dynamic>?;
              if (list != null) {
                for (final m in list) {
                  try {
                    final wallet =
                        ((m as Map<String, dynamic>)['wallet_address'] ??
                                    m['wallet'] ??
                                    m['walletAddress'] ??
                                    m['id'])
                                ?.toString() ??
                            '';
                    if (wallet.isNotEmpty && wallet == target) {
                      // Found existing direct conversation — build Conversation from backend item
                      Conversation conv;
                      try {
                        conv =
                            Conversation.fromJson(item as Map<String, dynamic>);
                      } catch (_) {
                        conv = Conversation(
                            id: cid,
                            title: (item['title'] ?? '')?.toString(),
                            isGroup: false);
                      }
                      // Insert into local cache for quick access
                      _conversations.removeWhere((c) => c.id == cid);
                      _conversations.insert(0, conv);
                      _safeNotifyListeners(force: true);
                      return conv;
                    }
                  } catch (_) {}
                }
              }
            }
          } catch (e) {
            debugPrint(
                'createConversation: backend member check failed for conv item: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('createConversation: backend pre-check failed: $e');
    }

    var resp = await _api.createConversation(
        title: title, isGroup: isGroup, members: members);
    if (resp['success'] == true) {
      final conv = Conversation.fromJson(resp['data']);
      _conversations.insert(0, conv);
      _safeNotifyListeners(force: true);
      // Subscribe to the conversation room so we get real-time messages
      try {
        final ok = await _socket.subscribeConversation(conv.id);
        debugPrint(
            'ChatProvider.createConversation: subscribeConversation result: $ok');
      } catch (e) {
        debugPrint(
            'ChatProvider.createConversation: subscribeConversation failed: $e');
      }
      // Optionally open conversation automatically
      try {
        await openConversation(conv.id);
      } catch (_) {}
      return conv;
    }

    // If unauthorized, attempt to obtain a token for the current wallet and retry once
    try {
      final status = resp['status'] as int?;
      if (status == 401) {
        // Prefer SharedPreferences to locate wallet before trying profile endpoint
        if (_currentWallet == null || _currentWallet!.isEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final w = prefs.getString('wallet_address') ??
                prefs.getString('user_id') ??
                '';
            if (w.isNotEmpty) {
              _currentWallet = w.toString();
            }
          } catch (e) {
            debugPrint(
                'createConversation: SharedPreferences wallet lookup failed: $e');
          }
          // If we have a token and no wallet, try to call getMyProfile
          if ((_api.getAuthToken() ?? '').isNotEmpty &&
              (_currentWallet == null || _currentWallet!.isEmpty)) {
            try {
              final meResp = await _api.getMyProfile();
              if (meResp['success'] == true && meResp['data'] != null) {
                final me = meResp['data'] as Map<String, dynamic>;
                _currentWallet = (me['wallet_address'] ??
                        me['walletAddress'] ??
                        me['wallet'])
                    ?.toString();
              }
            } catch (e) {
              debugPrint(
                  'createConversation: getMyProfile failed while resolving wallet for 401 retry: $e');
            }
          }
        }

        if (AppConfig.enableDebugIssueToken &&
            _currentWallet != null &&
            _currentWallet!.isNotEmpty) {
          final issued = await _api.issueDebugTokenForWallet(_currentWallet!);
          if (issued) {
            try {
              await _api.loadAuthToken();
            } catch (_) {}
            // Retry once
            resp = await _api.createConversation(
                title: title, isGroup: isGroup, members: members);
            if (resp['success'] == true) {
              final conv = Conversation.fromJson(resp['data']);
              _conversations.insert(0, conv);
              _safeNotifyListeners(force: true);
              return conv;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ChatProvider.createConversation retry flow failed: $e');
    }

    return null;
  }

  Future<Map<String, dynamic>> uploadConversationAvatar(String conversationId,
      List<int> bytes, String filename, String contentType) async {
    final resp = await _api.uploadConversationAvatar(
        conversationId, bytes, filename, contentType);
    // If succeeded, refresh conversations
    if (resp['success'] == true) {
      await refreshConversations();
    }
    return resp;
  }

  Conversation? _findConversationById(String conversationId) {
    try {
      return _conversations.firstWhere((c) => c.id == conversationId);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _collectConversationMemberWallets(String conversationId,
      {Conversation? conversationHint}) async {
    final ordered = <String>[];
    final seen = <String>{};

    void addWallet(String? wallet) {
      final normalized = WalletUtils.normalize(wallet);
      if (normalized.isEmpty) return;
      final canonical = WalletUtils.canonical(normalized);
      if (seen.add(canonical)) {
        ordered.add(normalized);
      }
    }

    final convo = conversationHint ?? _findConversationById(conversationId);
    if (convo != null) {
      for (final wallet in convo.memberWallets) {
        addWallet(wallet);
      }
      for (final profile in convo.memberProfiles) {
        addWallet(profile.wallet);
      }
      if (convo.counterpartProfile != null) {
        addWallet(convo.counterpartProfile!.wallet);
      }
    }

    final cache = _membersCache[conversationId];
    if (cache != null) {
      final entries = cache['result'];
      if (entries is List) {
        for (final entry in entries) {
          if (entry is Map<String, dynamic>) {
            addWallet(WalletUtils.resolveFromMap(entry));
          } else if (entry is Map) {
            addWallet(
                WalletUtils.resolveFromMap(entry.cast<String, dynamic>()));
          }
        }
      }
    }

    if (ordered.isEmpty) {
      try {
        final members = await fetchMembers(conversationId);
        for (final member in members) {
          addWallet(WalletUtils.resolveFromMap(member));
        }
      } catch (e) {
        debugPrint(
            'ChatProvider._collectConversationMemberWallets: fetchMembers failed for $conversationId: $e');
      }
    }

    final me = WalletUtils.normalize(_currentWallet);
    if (me.isNotEmpty) addWallet(me);
    return ordered;
  }

  List<String> _mergeMemberSets(List<String> base, List<String> extras) {
    final map = <String, String>{};
    void add(String? wallet) {
      final normalized = WalletUtils.normalize(wallet);
      if (normalized.isEmpty) return;
      final canonical = WalletUtils.canonical(normalized);
      map.putIfAbsent(canonical, () => normalized);
    }

    for (final wallet in base) {
      add(wallet);
    }
    for (final wallet in extras) {
      add(wallet);
    }
    return map.values.toList();
  }

  /// Accepts either a wallet or a username. Returns the created conversation when a new group chat is spawned.
  Future<Conversation?> addMember(
      String conversationId, String memberIdentifier) async {
    final trimmed = memberIdentifier.trim();
    if (trimmed.isEmpty) return null;

    var memberWallet = trimmed;
    final usernameCandidate = trimmed.replaceFirst(RegExp(r'^@+'), '');
    debugPrint(
        'ChatProvider.addMember: called with identifier="$memberIdentifier"');
    try {
      final user = await UserService.getUserByUsername(usernameCandidate);
      if (user != null && user.id.isNotEmpty) {
        memberWallet = user.id;
      }
    } catch (e) {
      debugPrint('ChatProvider.addMember: username resolution failed: $e');
    }
    memberWallet = WalletUtils.normalize(memberWallet);
    if (memberWallet.isEmpty) {
      debugPrint(
          'ChatProvider.addMember: resolved wallet empty for "$memberIdentifier"');
      return null;
    }

    final conversation = _findConversationById(conversationId);
    final existingMembers = await _collectConversationMemberWallets(
        conversationId,
        conversationHint: conversation);
    final alreadyMember = existingMembers
        .any((wallet) => WalletUtils.equals(wallet, memberWallet));
    if (alreadyMember) {
      debugPrint(
          'ChatProvider.addMember: $memberWallet is already a member of $conversationId');
      return conversation;
    }

    final uniqueMembers = _mergeMemberSets(existingMembers, [memberWallet]);
    final isGroupConversation = conversation?.isGroup == true;
    final shouldCreateGroup = !isGroupConversation && uniqueMembers.length >= 3;

    if (shouldCreateGroup) {
      debugPrint(
          'ChatProvider.addMember: promoting $conversationId to group (members=${uniqueMembers.length})');
      final sanitizedMembers = uniqueMembers
          .where((wallet) => !WalletUtils.equals(wallet, _currentWallet))
          .toList();
      final groupTitle = (conversation?.title?.trim().isNotEmpty ?? false)
          ? conversation!.title!.trim()
          : 'Group chat';
      final newConversation =
          await createConversation(groupTitle, true, sanitizedMembers);
      if (newConversation != null) {
        await _prefetchUsersForWallets(uniqueMembers);
        return newConversation;
      }
      debugPrint(
          'ChatProvider.addMember: failed to create group conversation; falling back to inline member add');
    }

    try {
      final resp =
          await _api.addConversationMember(conversationId, memberWallet);
      debugPrint(
          'ChatProvider.addMember: addConversationMember response: $resp');
    } catch (e) {
      debugPrint(
          'ChatProvider.addMember: addConversationMember call failed: $e');
    }

    await fetchMembers(conversationId);
    await _prefetchUsersForWallets([memberWallet]);
    await refreshConversations();
    return conversation;
  }

  Future<void> removeMember(
      String conversationId, String memberIdentifier) async {
    // Try to resolve as username or wallet client-side. Backend supports accepting memberUsername/memberWallet
    var normalized = memberIdentifier;
    try {
      if (!(memberIdentifier.startsWith('0x') &&
              memberIdentifier.length >= 40) &&
          memberIdentifier.startsWith('@')) {
        normalized = memberIdentifier.replaceFirst('@', '');
      }
    } catch (_) {}
    await _api.removeConversationMember(conversationId, normalized);
    await refreshConversations();
  }

  Future<void> renameConversation(
      String conversationId, String newTitle) async {
    try {
      final result = await _api.renameConversation(conversationId, newTitle);
      if (result['success'] == true) {
        // Update local conversation
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          final old = _conversations[index];
          final updated = Conversation(
            id: old.id,
            title: newTitle,
            rawTitle: newTitle,
            isGroup: old.isGroup,
            createdBy: old.createdBy,
            lastMessageAt: old.lastMessageAt,
            lastMessage: old.lastMessage,
            displayAvatar: old.displayAvatar,
            memberWallets: old.memberWallets,
            memberProfiles: old.memberProfiles,
            memberCount: old.memberCount,
            counterpartProfile: old.counterpartProfile,
          );
          _conversations[index] = updated;
          _safeNotifyListeners(force: true);
        }
        await refreshConversations();
      }
    } catch (e) {
      debugPrint('ChatProvider.renameConversation error: $e');
      rethrow;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      final result = await _api.deleteConversation(conversationId);
      if (result['success'] == true) {
        _conversations.removeWhere((c) => c.id == conversationId);
        _messages.remove(conversationId);
        _unreadCounts.remove(conversationId);
        _membersCache.remove(conversationId);
        _membersRequests.remove(conversationId);
        _messageCacheTouchMs.remove(conversationId);
        _membersCacheTouchMs.remove(conversationId);
        if (_openConversationId == conversationId) {
          _openConversationId = null;
        }
        _safeNotifyListeners(force: true);
        await refreshConversations();
        return;
      }
      throw Exception(result['error'] ?? 'Delete conversation failed');
    } catch (e) {
      debugPrint('ChatProvider.deleteConversation error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> transferOwnership(
      String conversationId, String newOwnerWallet) async {
    try {
      final resp =
          await _api.transferConversationOwner(conversationId, newOwnerWallet);
      await refreshConversations();
      return resp;
    } catch (e) {
      debugPrint('ChatProvider: transferOwnership failed: $e');
      rethrow;
    }
  }

  Future<void> markRead(String conversationId) async {
    await _api.markConversationRead(conversationId);
    _unreadCounts[conversationId] = 0;
    _safeNotifyListeners(force: true);
  }

  /// Called when the app detects the current user wallet has changed/connected.
  /// Ensures provider state (auth, socket subscription, conversations) is refreshed
  /// so UI (unread badges, conversations) updates immediately after wallet connect.
  Future<void> setCurrentWallet(String wallet) async {
    await _chatProviderSetCurrentWallet(this, wallet);
  }

  /// Open a conversation: subscribe to conversation room, load messages and mark read
  Future<void> openConversation(String conversationId) async {
    await _chatProviderOpenConversation(this, conversationId);
  }

  /// Close an open conversation: unsubscribe from room and clear open state
  Future<void> closeConversation([String? conversationId]) async {
    await _chatProviderCloseConversation(this, conversationId);
  }

  /// Mark an individual message as read by the current user
  Future<void> markMessageRead(String conversationId, String messageId) async {
    try {
      final resp = await _api.markMessageRead(conversationId, messageId);
      debugPrint(
          'ChatProvider.markMessageRead: api response for conv=$conversationId msg=$messageId -> $resp');
      // If server indicates not found or failure, try to mark the conversation read as a fallback
      if (resp['success'] != true &&
          (resp['status'] == 404 || resp['status'] == 400)) {
        try {
          await markRead(conversationId);
        } catch (_) {}
        return;
      }
      final list = _messages[conversationId];
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          final m = list[i];
          if (m.id == messageId) {
            final updatedMsg = m.copyWith(readByCurrent: true);
            // Replace list instance to ensure UI consumers detect the change
            try {
              final oldList = _messages[conversationId] ?? <ChatMessage>[];
              final newList = List<ChatMessage>.from(oldList);
              newList[i] = updatedMsg;
              _cacheMessages(conversationId, newList);
            } catch (_) {
              _messages[conversationId]![i] = updatedMsg;
              _touchMessageCache(conversationId);
            }
            debugPrint(
                'ChatProvider.markMessageRead: updated local message readByCurrent for conv=$conversationId msg=$messageId at index=$i');
            // Decrease unread count for conversation if present
            final curr = _unreadCounts[conversationId] ?? 0;
            if (curr > 0) _unreadCounts[conversationId] = curr - 1;
            _safeNotifyListeners(force: true);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: markMessageRead failed: $e');
    }
  }

  /// Optimistically mark a message as read locally (UI only), will be persisted by markMessageRead
  void markMessageReadLocal(String conversationId, String messageId) {
    final nid = conversationId;
    final list = _messages[nid];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (m.id == messageId) {
        if (m.readByCurrent) break;
        final existingReaders =
            m.readers.map((e) => Map<String, dynamic>.from(e)).toList();
        final readerWallet = WalletUtils.normalize(_currentWallet);
        final readerCanonical = WalletUtils.canonical(readerWallet);
        if (readerWallet.isNotEmpty &&
            !existingReaders.any((r) {
              try {
                final existing = WalletUtils.normalize(
                    ((r['wallet_address'] ?? r['wallet']) ?? '').toString());
                return existing.isNotEmpty &&
                    WalletUtils.equals(existing, readerCanonical) &&
                    readerCanonical.isNotEmpty;
              } catch (_) {
                return false;
              }
            })) {
          existingReaders.add(_buildReaderMetadata(readerWallet));
        }
        final updatedMsg = m.copyWith(
          readersCount: existingReaders.length,
          readByCurrent: true,
          readers: existingReaders,
        );
        try {
          final oldList = _messages[nid] ?? <ChatMessage>[];
          final newList = List<ChatMessage>.from(oldList);
          newList[i] = updatedMsg;
          _cacheMessages(nid, newList);
        } catch (_) {
          _messages[nid]![i] = updatedMsg;
          _touchMessageCache(nid);
        }
        final curr = _unreadCounts[nid] ?? 0;
        if (curr > 0) _unreadCounts[nid] = curr - 1;
        // Force notify so the optimistic local read is reflected immediately
        _safeNotifyListeners(force: true);
        break;
      }
    }
  }

  // Utility: get unread count total
  int get totalUnread => _unreadCounts.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    _unbindRefreshProvider();
    try {
      _subscriptionMonitorTimer?.cancel();
      _subscriptionMonitorTimer = null;
    } catch (_) {}
    try {
      _pollTimer?.cancel();
      _pollTimer = null;
    } catch (_) {}
    try {
      _socket.removeMessageListener(_onMessageReceived);
    } catch (_) {}
    try {
      _socket.removeMessageReadListener(_onMessageRead);
    } catch (_) {}
    try {
      _socket.removeConversationListener(_onNewConversation);
    } catch (_) {}
    try {
      _socket.removeConversationListener(_onMembersUpdated);
    } catch (_) {}
    try {
      _socket.removeConversationListener(_onConversationUpdated);
    } catch (_) {}
    try {
      _socket.removeConversationListener(_onConversationMemberRead);
    } catch (_) {}
    try {
      _socket.removeConversationListener(_onConversationRenamed);
    } catch (_) {}
    try {
      _socket.removeMessageReactionListener(_onMessageReaction);
    } catch (_) {}
    try {
      _resetSessionState(reason: 'dispose', notify: false);
    } catch (_) {}
    try {
      _eventBusSub?.cancel();
      _eventBusSub = null;
    } catch (_) {}
    try {
      _eventBusProfilesSub?.cancel();
      _eventBusProfilesSub = null;
    } catch (_) {}
    super.dispose();
  }

  void _onMessageReaction(Map<String, dynamic> data) {
    try {
      final convId =
          (data['conversationId'] ?? data['conversation_id'])?.toString() ?? '';
      final messageId =
          (data['messageId'] ?? data['message_id'])?.toString() ?? '';
      final reactions = data['reactions']; // List of reaction objects

      if (convId.isEmpty || messageId.isEmpty) return;

      final list = _messages[convId];
      if (list == null) return;

      for (var i = 0; i < list.length; i++) {
        if (list[i].id == messageId) {
          // Parse reactions
          List<MessageReaction> parsedReactions = [];
          if (reactions is List) {
            parsedReactions = reactions
                .map((r) =>
                    MessageReaction.fromJson(Map<String, dynamic>.from(r)))
                .toList();
          }

          final updatedMsg = list[i].copyWith(reactions: parsedReactions);

          // Update list
          final newList = List<ChatMessage>.from(list);
          newList[i] = updatedMsg;
          _cacheMessages(convId, newList);

          _safeNotifyListeners(force: true);
          break;
        }
      }
    } catch (e) {
      debugPrint('ChatProvider._onMessageReaction error: $e');
    }
  }

  void _onConversationRenamed(Map<String, dynamic> data) {
    try {
      final convId =
          (data['conversationId'] ?? data['conversation_id'])?.toString() ?? '';
      final newTitle = (data['title'])?.toString() ?? '';

      if (convId.isEmpty) return;

      // Update local conversation title
      final index = _conversations.indexWhere((c) => c.id == convId);
      if (index != -1) {
        final old = _conversations[index];
        final updated = Conversation(
          id: old.id,
          title: newTitle,
          rawTitle: newTitle,
          isGroup: old.isGroup,
          createdBy: old.createdBy,
          lastMessageAt: old.lastMessageAt,
          lastMessage: old.lastMessage,
          displayAvatar: old.displayAvatar,
          memberWallets: old.memberWallets,
          memberProfiles: old.memberProfiles,
          memberCount: old.memberCount,
          counterpartProfile: old.counterpartProfile,
        );
        _conversations[index] = updated;
        _safeNotifyListeners(force: true);
      }
    } catch (e) {
      debugPrint('ChatProvider._onConversationRenamed error: $e');
    }
  }

  Future<void> toggleReaction(
      String conversationId, String messageId, String emoji) async {
    // Optimistic update
    final list = _messages[conversationId];
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == messageId) {
          final msg = list[i];
          final currentWallet = _currentWallet ?? '';

          // Check if already reacted
          final existingReactionIndex =
              msg.reactions.indexWhere((r) => r.emoji == emoji);
          bool isRemoving = false;

          List<MessageReaction> newReactions = List.from(msg.reactions);

          if (existingReactionIndex >= 0) {
            final reaction = newReactions[existingReactionIndex];
            if (reaction.reactors.contains(currentWallet)) {
              // Remove reaction
              isRemoving = true;
              final newReactors = List<String>.from(reaction.reactors)
                ..remove(currentWallet);
              if (newReactors.isEmpty) {
                newReactions.removeAt(existingReactionIndex);
              } else {
                newReactions[existingReactionIndex] = MessageReaction(
                  emoji: emoji,
                  count: newReactors.length,
                  reactors: newReactors,
                );
              }
            } else {
              // Add to existing reaction
              final newReactors = List<String>.from(reaction.reactors)
                ..add(currentWallet);
              newReactions[existingReactionIndex] = MessageReaction(
                emoji: emoji,
                count: newReactors.length,
                reactors: newReactors,
              );
            }
          } else {
            // Create new reaction
            newReactions.add(MessageReaction(
              emoji: emoji,
              count: 1,
              reactors: [currentWallet],
            ));
          }

          // Update local state
          final updatedMsg = msg.copyWith(reactions: newReactions);
          final newList = List<ChatMessage>.from(list);
          newList[i] = updatedMsg;
          _cacheMessages(conversationId, newList);
          _safeNotifyListeners(force: true);

          // Call API
          try {
            if (isRemoving) {
              await _api.removeMessageReaction(
                  conversationId, messageId, emoji);
            } else {
              await _api.addMessageReaction(conversationId, messageId, emoji);
            }
          } catch (e) {
            // Revert on failure (could be improved, but simple for now)
            debugPrint('ChatProvider.toggleReaction failed: $e');
            // Ideally we would revert the optimistic update here
          }
          break;
        }
      }
    }
  }
}
