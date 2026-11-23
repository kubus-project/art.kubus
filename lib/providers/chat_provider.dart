import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../config/config.dart';
import '../services/account_identity.dart';
import '../services/backend_api_service.dart';
import '../services/socket_service.dart';
import '../models/conversation.dart';
import '../models/resolved_conversation_participant.dart';
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

/// The result of starting a conversation. [recipientUnavailable] is the neutral
/// "cannot message this account" state. The backend answers every restricted,
/// closed or unknown recipient the same way, so no reason is carried.
class ConversationCreateOutcome {
  const ConversationCreateOutcome({
    this.conversation,
    this.recipientUnavailable = false,
  });

  final Conversation? conversation;
  final bool recipientUnavailable;
}

class ChatProvider extends ChangeNotifier {
  static const int _maxCachedMessageConversations = 24;
  static const int _maxMessagesPerConversation = 200;
  static const int _maxCachedMemberLists = 80;
  static const int _maxCachedUsers = 320;

  ChatProvider() {
    AccountIdentity.addListener(_handleAccountIdentityChanged);
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
        'ChatProvider constructor: failed to register socket listeners: $e',
      );
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
          'ChatProvider._onMembersUpdated: refreshConversations completed',
        );
      }).catchError((e) {
        debugPrint(
          'ChatProvider._onMembersUpdated: refreshConversations error: $e',
        );
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
    String conversationId,
  ) {
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
              final w = WalletUtils.normalize(
                (map['wallet_address'] ??
                        map['wallet'] ??
                        map['walletAddress'] ??
                        map['id'])
                    ?.toString(),
              );
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
        'ChatProvider.getPreloadedProfileMapsForConversation failed: $e',
      );
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

  Future<void> _hydrateConversationsFromPayload(
    List<dynamic> items, {
    bool forceNotify = true,
    int? sessionGeneration,
  }) async {
    final generation = sessionGeneration ?? _sessionGeneration;
    if (generation != _sessionGeneration) return;
    try {
      _conversations = items
          .map((i) => Conversation.fromJson(i as Map<String, dynamic>))
          .toList();
      // A conversation listed for this session is live again (for example the
      // same account signing back in), so its socket events are accepted.
      _retiredSessionConversationIds.removeAll(_conversations.map((c) => c.id));
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
      'ChatProvider._hydrateConversationsFromPayload: hydrated ${_conversations.length} conversations',
    );
    try {
      await _prefetchMembersAndProfilesFromConversations(
        _conversations,
        sessionGeneration: generation,
      );
    } catch (e) {
      debugPrint(
        'ChatProvider._hydrateConversationsFromPayload prefetch failed: $e',
      );
    }
  }

  Future<void> _prefetchMembersAndProfilesFromConversations(
    List<Conversation> convs, {
    int? sessionGeneration,
  }) async {
    final generation = sessionGeneration ?? _sessionGeneration;
    try {
      final wallets = <String>{};
      final accountIds = <String>{};
      final myWalletCanonical = WalletUtils.canonical(_currentWallet);
      final mySessionAccountId = _sessionAccountUuid();

      void collectWallet(String? wallet) {
        if (wallet == null) return;
        final normalized = WalletUtils.normalize(wallet);
        if (normalized.isEmpty) return;
        // An account UUID is an identity, never a wallet.
        if (WalletUtils.isAccountUuid(normalized)) return;
        final canonical = WalletUtils.canonical(normalized);
        if (myWalletCanonical.isNotEmpty && canonical == myWalletCanonical) {
          return;
        }
        wallets.add(normalized);
      }

      // A member without a wallet is identified by its account UUID alone.
      void collectAccountId(String? userId, {required bool hasWallet}) {
        if (hasWallet) return;
        final id = (userId ?? '').trim();
        if (!WalletUtils.isAccountUuid(id)) return;
        if (WalletUtils.sameIdentity(id, mySessionAccountId)) return;
        accountIds.add(id);
      }

      final convsNeedingMembers = <Conversation>[];
      for (final conv in convs) {
        var hasMetadata = false;
        if (conv.memberProfiles.isNotEmpty) {
          hasMetadata = true;
          for (final profile in conv.memberProfiles) {
            collectWallet(profile.wallet);
            collectAccountId(profile.userId,
                hasWallet: WalletUtils.normalize(profile.wallet).isNotEmpty);
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
          final counterpart = conv.counterpartProfile!;
          collectWallet(counterpart.wallet);
          collectAccountId(counterpart.userId,
              hasWallet: WalletUtils.normalize(counterpart.wallet).isNotEmpty);
        }
        if (!hasMetadata) {
          convsNeedingMembers.add(conv);
        }
      }

      for (final conv in convsNeedingMembers) {
        try {
          final members = await fetchMembers(conv.id);
          if (generation != _sessionGeneration) return;
          for (final member in members) {
            final rawId = member['id']?.toString();
            final wallet = WalletUtils.normalize(
              (member['wallet_address'] ??
                      member['wallet'] ??
                      member['walletAddress'] ??
                      rawId)
                  ?.toString(),
            );
            collectWallet(wallet);
            final userId = member['user_id'] ??
                member['userId'] ??
                (WalletUtils.isAccountUuid(rawId) ? rawId : null);
            collectAccountId(userId?.toString(), hasWallet: wallet.isNotEmpty);
          }
        } catch (e) {
          debugPrint(
            'ChatProvider._prefetchMembersAndProfilesFromConversations: fetchMembers failed for ${conv.id}: $e',
          );
        }
      }

      if (wallets.isNotEmpty && generation == _sessionGeneration) {
        await _prefetchUsersForWallets(wallets.toList());
      }
      if (accountIds.isNotEmpty && generation == _sessionGeneration) {
        await _prefetchUsersForAccountIds(accountIds.toList());
      }
    } catch (e) {
      debugPrint(
        'ChatProvider._prefetchMembersAndProfilesFromConversations error: $e',
      );
    }
  }

  /// Test seam: the participant prefetch for [convs], as a load runs it.
  @visibleForTesting
  Future<void> prefetchParticipantsForTesting(List<Conversation> convs) =>
      _prefetchMembersAndProfilesFromConversations(convs);

  /// The signed-in account's UUID, or empty. A wallet is never returned here.
  String _sessionAccountUuid() {
    final key = AccountIdentity.accountKey.trim();
    return WalletUtils.isAccountUuid(key) ? key : '';
  }

  final BackendApiService _api = BackendApiService();
  final SocketService _socket = SocketService();

  // Bumped on every account/wallet boundary (wallet change, sign-out, auth
  // cleared). Async loaders capture it before awaiting and drop their results
  // when it changed, so a late response for account A never lands in B's state.
  int _sessionGeneration = 0;

  // Conversation ids that belonged to a session that has been left. Socket
  // events for these are dropped unless the current session lists them too.
  final Set<String> _retiredSessionConversationIds = <String>{};

  List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, int> _unreadCounts = {}; // conversationId -> unread count
  final Map<String, Future<List<Map<String, dynamic>>>> _membersRequests =
      {}; // convId -> in-flight Future
  final Map<String, Map<String, dynamic>> _membersCache =
      {}; // convId -> {'result': List<dynamic>, 'ts': int}
  final Map<String, User> _userCache = {}; // wallet -> User
  final Map<String, ResolvedConversationParticipant> _participantIdentityByKey =
      {};
  final Set<String> _participantHydrationInFlight = <String>{};
  int _participantIdentityRevision = 0;
  StreamSubscription<Map<String, dynamic>>? _eventBusSub;
  StreamSubscription<Map<String, dynamic>>? _eventBusProfilesSub;
  String? _currentWallet;

  /// Wallet the chat session is currently bound to (test observation only).
  @visibleForTesting
  String? get currentWalletForTesting => _currentWallet;

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
  // The owner of "who is signed in", handed in by the binder. Every "is this
  // me" decision about a message or socket payload goes through it.
  ProfileProvider? _identityOwner;
  String _lastAuthAccountId = '';
  // The account whose personal socket rooms this session holds. Read by the
  // session reset, which runs after _lastAuthAccountId has already moved on to
  // the new account on a switch.
  String _socketAccountId = '';
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
          'ChatProvider._safeNotifyListeners: throttled, notified $_notificationsThisSecond times this second',
        );
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
  Map<String, ResolvedConversationParticipant>
      get participantIdentitySnapshot =>
          Map.unmodifiable(_participantIdentityByKey);
  int get participantIdentityRevision => _participantIdentityRevision;

  User? getCachedUser(String wallet) {
    final cached = _userCache[wallet];
    if (cached != null) {
      _userCacheTouchMs[wallet] = DateTime.now().millisecondsSinceEpoch;
    }
    return cached;
  }

  void seedConversationParticipants(Conversation conversation) {
    var seeded = 0;

    void add(
      String? wallet, {
      String? displayName,
      String? username,
      String? avatarUrl,
      ParticipantIdentitySource source =
          ParticipantIdentitySource.conversationSnapshot,
    }) {
      final normalizedWallet = WalletUtils.normalize(wallet);
      final key = normalizeParticipantIdentityKey(
        walletAddress: normalizedWallet,
        userId: normalizedWallet,
      );
      if (key == 'unknown') return;
      final changed = _upsertParticipantIdentity(
        ResolvedConversationParticipant(
          identityKey: key,
          walletAddress: normalizedWallet.isEmpty ? null : normalizedWallet,
          userId: normalizedWallet.isEmpty ? null : normalizedWallet,
          displayName: _meaningfulDisplayName(displayName, normalizedWallet),
          username: _meaningfulUsername(username),
          avatarUrl: _normalizeParticipantAvatar(avatarUrl),
          source: source,
          updatedAt: DateTime.now(),
        ),
        notify: false,
      );
      if (changed) seeded++;
    }

    for (final profile in conversation.memberProfiles) {
      add(
        profile.wallet,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
      );
    }
    final counterpart = conversation.counterpartProfile;
    if (counterpart != null) {
      add(
        counterpart.wallet,
        displayName: counterpart.displayName,
        avatarUrl: counterpart.avatarUrl,
      );
    }
    for (final wallet in conversation.memberWallets) {
      add(wallet);
    }

    if (kDebugMode && seeded > 0) {
      debugPrint('ChatProvider: seeded $seeded conversation participants');
    }
    if (seeded > 0) {
      _safeNotifyListeners(force: true);
    }
  }

  void seedMessageParticipants(Iterable<ChatMessage> messages) {
    var seeded = 0;
    for (final message in messages) {
      final key = normalizeParticipantIdentityKey(
        walletAddress: message.senderWallet,
        userId: message.senderWallet,
        senderId: message.id,
      );
      if (key == 'unknown') continue;
      final changed = _upsertParticipantIdentity(
        ResolvedConversationParticipant(
          identityKey: key,
          walletAddress: WalletUtils.normalize(message.senderWallet),
          userId: WalletUtils.normalize(message.senderWallet),
          displayName: _meaningfulDisplayName(
            message.senderDisplayName,
            message.senderWallet,
          ),
          username: _meaningfulUsername(message.senderUsername),
          avatarUrl: _normalizeParticipantAvatar(message.senderAvatar),
          source: ParticipantIdentitySource.messageSnapshot,
          updatedAt: message.createdAt,
        ),
        notify: false,
      );
      if (changed) seeded++;
    }
    if (kDebugMode && seeded > 0) {
      debugPrint('ChatProvider: seeded $seeded message participants');
    }
    if (seeded > 0) {
      _safeNotifyListeners(force: true);
    }
  }

  void upsertParticipantIdentity(ResolvedConversationParticipant participant) {
    _upsertParticipantIdentity(participant, notify: true);
  }

  ResolvedConversationParticipant resolveParticipantForMessage({
    required ChatMessage message,
    required Conversation conversation,
    String? currentUserWallet,
    String? currentUserId,
    String? currentUserDisplayName,
    String? currentUserAvatarUrl,
  }) {
    final senderWallet = WalletUtils.normalize(message.senderWallet);
    final senderKey = normalizeParticipantIdentityKey(
      walletAddress: senderWallet,
      userId: senderWallet,
      senderId: message.id,
    );
    final currentKey = normalizeParticipantIdentityKey(
      walletAddress: currentUserWallet,
      userId: currentUserId,
    );

    if (currentKey != 'unknown' && senderKey == currentKey) {
      final local = ResolvedConversationParticipant(
        identityKey: currentKey,
        walletAddress: WalletUtils.normalize(currentUserWallet).isNotEmpty
            ? WalletUtils.normalize(currentUserWallet)
            : senderWallet,
        userId: WalletUtils.normalize(currentUserId).isNotEmpty
            ? WalletUtils.normalize(currentUserId)
            : senderWallet,
        displayName: _meaningfulDisplayName(
          currentUserDisplayName,
          senderWallet,
        ),
        avatarUrl: _normalizeParticipantAvatar(currentUserAvatarUrl),
        source: ParticipantIdentitySource.localUser,
        updatedAt: DateTime.now(),
      );
      _upsertParticipantIdentity(local, notify: false);
      return _participantIdentityByKey[currentKey] ?? local;
    }

    final cached = _participantIdentityByKey[senderKey];
    if (cached != null) return cached;

    _upsertParticipantIdentity(
      ResolvedConversationParticipant(
        identityKey: senderKey,
        walletAddress: senderWallet.isEmpty ? null : senderWallet,
        userId: senderWallet.isEmpty ? null : senderWallet,
        displayName: _meaningfulDisplayName(
          message.senderDisplayName,
          senderWallet,
        ),
        username: _meaningfulUsername(message.senderUsername),
        avatarUrl: _normalizeParticipantAvatar(message.senderAvatar),
        source: ParticipantIdentitySource.messageSnapshot,
        updatedAt: message.createdAt,
      ),
      notify: false,
    );
    return _participantIdentityByKey[senderKey] ??
        ResolvedConversationParticipant(
          identityKey: senderKey,
          walletAddress: senderWallet.isEmpty ? null : senderWallet,
          userId: senderWallet.isEmpty ? null : senderWallet,
          source: ParticipantIdentitySource.fallback,
          updatedAt: message.createdAt,
        );
  }

  Future<void> hydrateConversationParticipants({
    required Conversation conversation,
    required Iterable<ChatMessage> messages,
  }) async {
    seedConversationParticipants(conversation);
    seedMessageParticipants(messages);

    final walletsByKey = <String, String>{};
    for (final participant in _participantIdentityByKey.values) {
      final wallet = WalletUtils.normalize(participant.walletAddress);
      if (wallet.isEmpty) continue;
      if (_participantHasProfileMetadata(participant)) continue;
      walletsByKey[participant.identityKey] = wallet;
    }

    final pendingKeys = walletsByKey.keys
        .where((key) => !_participantHydrationInFlight.contains(key))
        .toList(growable: false);
    if (pendingKeys.isEmpty) return;
    _participantHydrationInFlight.addAll(pendingKeys);

    final wallets = pendingKeys.map((key) => walletsByKey[key]!).toList();
    var hydrated = 0;
    try {
      final cachedUsers = UserService.getCachedUsers(wallets);
      for (final entry in cachedUsers.entries) {
        hydrated += _upsertUserParticipant(entry.value, notify: false) ? 1 : 0;
      }

      final stillMissing = wallets.where((wallet) {
        final key = normalizeParticipantIdentityKey(
          walletAddress: wallet,
          userId: wallet,
        );
        final participant = _participantIdentityByKey[key];
        return participant == null ||
            !_participantHasProfileMetadata(participant);
      }).toList(growable: false);

      if (stillMissing.isNotEmpty) {
        final users = await UserService.getUsersByWallets(stillMissing);
        try {
          UserService.setUsersInCache(users);
        } catch (_) {}
        for (final user in users) {
          hydrated += _upsertUserParticipant(user, notify: false) ? 1 : 0;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ChatProvider: hydrate participants failed: $e');
      }
    } finally {
      _participantHydrationInFlight.removeAll(pendingKeys);
    }

    if (kDebugMode && hydrated > 0) {
      debugPrint('ChatProvider: hydrated participant count=$hydrated');
    }
    if (hydrated > 0) {
      _safeNotifyListeners(force: true);
    }
  }

  bool _upsertUserParticipant(User user, {required bool notify}) {
    if (user.id.isEmpty) return false;
    return _upsertParticipantIdentity(
      ResolvedConversationParticipant(
        identityKey: normalizeParticipantIdentityKey(
          walletAddress: user.id,
          userId: user.id,
        ),
        walletAddress: user.id,
        userId: user.id,
        displayName: _meaningfulDisplayName(user.name, user.id),
        username: _meaningfulUsername(user.username),
        avatarUrl: _normalizeParticipantAvatar(user.profileImageUrl),
        source: ParticipantIdentitySource.profileHydration,
        updatedAt: DateTime.now(),
      ),
      notify: notify,
    );
  }

  bool _upsertParticipantIdentity(
    ResolvedConversationParticipant participant, {
    required bool notify,
  }) {
    final key = participant.identityKey.trim().toLowerCase();
    if (key.isEmpty || key == 'unknown') return false;
    final normalized = ResolvedConversationParticipant(
      identityKey: key,
      walletAddress: WalletUtils.normalize(participant.walletAddress).isEmpty
          ? null
          : WalletUtils.normalize(participant.walletAddress),
      userId: WalletUtils.normalize(participant.userId).isEmpty
          ? null
          : WalletUtils.normalize(participant.userId),
      displayName: _meaningfulDisplayName(
        participant.displayName,
        participant.walletAddress,
      ),
      username: _meaningfulUsername(participant.username),
      avatarUrl: _normalizeParticipantAvatar(participant.avatarUrl),
      source: participant.source,
      updatedAt: participant.updatedAt,
    );

    final existing = _participantIdentityByKey[key];
    final merged =
        existing == null ? normalized : existing.mergeFrom(normalized);
    if (existing != null && existing == merged) return false;
    final visibleChanged =
        existing == null || !existing.hasSameVisibleIdentity(merged);
    _participantIdentityByKey[key] = merged;
    if (visibleChanged) {
      _participantIdentityRevision++;
      if (kDebugMode) {
        debugPrint(
          'ChatProvider: participant visible cache changes revision=$_participantIdentityRevision',
        );
      }
      if (notify) {
        _safeNotifyListeners(force: true);
      }
    }
    return visibleChanged;
  }

  bool _participantHasProfileMetadata(
    ResolvedConversationParticipant participant,
  ) {
    final hasDisplay = (participant.displayName ?? '').trim().isNotEmpty ||
        (participant.username ?? '').trim().isNotEmpty;
    final hasAvatar = (participant.avatarUrl ?? '').trim().isNotEmpty;
    return participant.source.index >=
            ParticipantIdentitySource.profileHydration.index &&
        (hasDisplay || hasAvatar);
  }

  String? _meaningfulDisplayName(String? value, String? wallet) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final normalizedWallet = WalletUtils.normalize(wallet);
    if (normalizedWallet.isNotEmpty &&
        trimmed.toLowerCase() == normalizedWallet.toLowerCase()) {
      return null;
    }
    if (WalletUtils.looksLikeWallet(trimmed)) return null;
    return trimmed;
  }

  String? _meaningfulUsername(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (WalletUtils.looksLikeWallet(trimmed.replaceFirst('@', ''))) {
      return null;
    }
    return trimmed;
  }

  String? _normalizeParticipantAvatar(String? avatar) {
    final normalized = MediaUrlResolver.resolve(avatar);
    if (normalized == null || normalized.trim().isEmpty) return null;
    return normalized.trim();
  }

  // A wallet alone may request a chat session, so it counts here. This gates
  // network work only; nothing in the UI reads it as "signed in".
  bool get _hasAuthContext =>
      _api.hasAuthSession || ((_currentWallet ?? '').isNotEmpty);
  Map<String, Object?> get debugResourceSnapshot => <String, Object?>{
        'initialized': _initialized,
        'hasAuthToken': _api.hasAuthSession,
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
  bool matchesOptimisticMessageForTesting(
    ChatMessage current,
    ChatMessage incoming,
  ) =>
      _matchesOptimisticMessage(current, incoming);

  @visibleForTesting
  void handleMessageReactionForTesting(Map<String, dynamic> data) {
    _onMessageReaction(data);
  }

  @visibleForTesting
  void handleMessageReadForTesting(Map<String, dynamic> data) {
    _onMessageRead(data);
  }

  /// Test seam: the owner that answers "is this me", as the binder hands it in.
  @visibleForTesting
  void setIdentityOwnerForTesting(ProfileProvider? owner) {
    _identityOwner = owner;
  }

  @visibleForTesting
  void setCurrentWalletForTesting(String? wallet) {
    _currentWallet = wallet;
  }

  /// Test seam: the account whose personal socket room this session joined.
  @visibleForTesting
  void bindSocketAccountForTesting(String accountId) {
    _socketAccountId = accountId;
  }

  /// Test seam: runs a session reset with [reason], as the auth bind does.
  @visibleForTesting
  void resetSessionForTesting(String reason) {
    _resetSessionState(reason: reason, notify: false);
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

  void _resetSessionState({required String reason, bool notify = true}) {
    _chatProviderResetSessionState(this, reason: reason, notify: notify);
  }

  /// A walletless switch leaves the wallet empty on both sides, and the profile
  /// that carries the account id clears first. The identity change is the
  /// signal that reaches this provider before the next token's first request.
  /// A same-account change (wallet link, re-issued token) keeps the state.
  void _handleAccountIdentityChanged() {
    final key = AccountIdentity.accountKey;
    if (key.isNotEmpty && key == _lastAuthAccountId) return;
    _resetSessionState(reason: 'accountChanged');
    // Recorded after the reset so the bind path sees this account as current
    // and does not reset again for the same switch.
    _lastAuthAccountId = key;
  }

  /// The session's canonical account id for socket routing, or empty when
  /// unknown. A legacy token with no id claim reports its wallet as the account
  /// key. That is a wallet, not an account id, so it is not returned here.
  String _socketSessionAccountId() {
    final key = AccountIdentity.accountKey.trim();
    if (key.isEmpty || WalletUtils.equals(key, _currentWallet)) return '';
    return key;
  }

  /// Whether an identity named by a socket payload or a message is the
  /// signed-in account. The owner answers; without one bound nobody is.
  bool _isCurrentAccountActor({String? userId, String? wallet}) =>
      _identityOwner?.isCurrentAccountActor(
          accountId: userId, wallet: wallet) ??
      false;

  /// A trimmed identifier from the first of [keys] that carries one, or null.
  String? _identityText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final text = (data[key] ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// The account id a socket payload names as its recipient, or null.
  String? _socketRecipientUserId(Map<String, dynamic>? data) {
    if (data == null) return null;
    final nested = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : const <String, dynamic>{};
    for (final source in <Map<String, dynamic>>[data, nested]) {
      for (final key in const ['recipientUserId', 'recipient_user_id']) {
        final value = source[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  /// Whether a socket event for [conversationId] belongs to the current session.
  ///
  /// The session is known by its account id or, for a wallet session, its
  /// wallet. A payload that names a recipient account must name this session's
  /// account, so an event addressed to a previous account is dropped. Otherwise
  /// the event belongs to a conversation the session has joined (or is joining).
  bool _isSocketEventForCurrentSession(
    String conversationId, [
    Map<String, dynamic>? data,
  ]) {
    final wallet = (_currentWallet ?? '').trim();
    final accountId = _socketSessionAccountId();
    if (wallet.isEmpty && accountId.isEmpty) return false;
    final addressedTo = _socketRecipientUserId(data);
    // Addressed to this session by account id, or by wallet for a legacy
    // payload. An unknown identity never matches, and ids compare
    // case-insensitively.
    if (addressedTo != null &&
        !WalletUtils.sameIdentity(addressedTo, accountId) &&
        !WalletUtils.sameIdentity(addressedTo, wallet)) {
      return false;
    }
    if (_conversations.any((c) => c.id == conversationId)) return true;
    return !_retiredSessionConversationIds.contains(conversationId);
  }

  Future<void> initialize({String? initialWallet}) async {
    final normalizedInitialWallet = (initialWallet ?? '').trim();
    if (_initialized) {
      if (normalizedInitialWallet.isNotEmpty) {
        await setCurrentWallet(normalizedInitialWallet);
      } else if (_conversations.isEmpty && _api.hasAuthSession) {
        unawaited(refreshConversations());
      }
      return;
    }
    _initialized = true;
    // We do not automatically initialize persisted user cache here to avoid
    // eagerly loading data for anonymous users; initialization occurs on wallet
    // registration or profile load.
    // Ensure auth token loaded once (and attempt single issuance if wallet provided)
    final initGeneration = _sessionGeneration;
    var hasSession = false;
    try {
      if (normalizedInitialWallet.isNotEmpty) {
        await _api.ensureAuthLoaded(walletAddress: initialWallet);
      }
      hasSession = await _api.restoreExistingSession();
    } catch (_) {}
    if (!hasSession) {
      _initialized = false;
      if (initGeneration == _sessionGeneration) {
        _currentWallet =
            normalizedInitialWallet.isNotEmpty ? normalizedInitialWallet : null;
      }
      if (kDebugMode) {
        debugPrint(
          'ChatProvider.initialize: skipping protected init - no restored auth session',
        );
      }
      return;
    }
    // Determine wallet early so we can try to issue a token for the wallet before socket connect
    try {
      if (initialWallet != null &&
          initialWallet.isNotEmpty &&
          initGeneration == _sessionGeneration) {
        _currentWallet = initialWallet;
        debugPrint(
          'ChatProvider.initialize: initialWallet provided: $_currentWallet',
        );
      }
      final meResp = await _api.getMyProfile();
      debugPrint('ChatProvider.initialize: getMyProfile response: $meResp');
      if (meResp['success'] == true && meResp['data'] != null) {
        final me = meResp['data'] as Map<String, dynamic>;
        final resolvedWallet =
            (me['wallet_address'] ?? me['walletAddress'] ?? me['wallet'])
                ?.toString();
        if (initGeneration == _sessionGeneration) {
          _currentWallet = resolvedWallet;
        }
        debugPrint(
          'ChatProvider.initialize: wallet from getMyProfile: $_currentWallet',
        );
      }
    } catch (e) {
      debugPrint('ChatProvider: getMyProfile failed: $e');
      // Fallback: try to read persisted wallet from shared preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final w = storedWalletFromPrefs(prefs);
        debugPrint(
          'ChatProvider.initialize: SharedPreferences wallet read: $w',
        );
        if (w.isNotEmpty && initGeneration == _sessionGeneration) {
          _currentWallet = w.toString();
        }
      } catch (e2) {
        debugPrint(
          'ChatProvider: Failed to read wallet from shared prefs: $e2',
        );
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
    // Listeners stay registered for every later session. Past this point a
    // sign-out or account switch owns subscription and loading through
    // setCurrentWallet, so a superseded initialize stops after each await.
    bool superseded() => initGeneration != _sessionGeneration;
    await refreshConversations();
    if (superseded()) return;
    // After loading conversations, proactively fetch member profiles for faster UI updates
    try {
      final allWallets = <String>{};
      for (final conv in List<Conversation>.of(_conversations)) {
        if (superseded()) return;
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
      if (allWallets.isNotEmpty && !superseded()) {
        await _prefetchUsersForWallets(allWallets.toList());
      }
    } catch (e) {
      debugPrint('ChatProvider.initialize: prefetch users failed: $e');
    }
    if (superseded()) return;
    // Subscribe to user room if we have a wallet
    try {
      if (_currentWallet != null && _currentWallet!.isNotEmpty) {
        // Attempt to connect and confirm subscription before loading messages; fallback to subscribeUser if not supported
        try {
          var ok = await _socket.connectAndSubscribe(
            _api.baseUrl,
            _currentWallet!,
          );
          debugPrint('ChatProvider: socket connectAndSubscribe result: $ok');
          if (superseded()) return;
          if (!ok) {
            debugPrint(
              'ChatProvider: connectAndSubscribe failed, attempting token issuance and retry',
            );
            try {
              if (AppConfig.enableDebugIssueToken) {
                final issued = await _api.issueDebugTokenForWallet(
                  _currentWallet!,
                );
                if (issued) {
                  await _api.loadAuthToken();
                  if (superseded()) return;
                  ok = await _socket.connectAndSubscribe(
                    _api.baseUrl,
                    _currentWallet!,
                  );
                  debugPrint(
                    'ChatProvider: socket connectAndSubscribe retry result: $ok',
                  );
                }
              }
            } catch (e2) {
              debugPrint('ChatProvider: token issuance retry failed: $e2');
            }
          }
          if (superseded()) return;
          if (!ok) {
            // attempt subscribe as best effort
            _socket.subscribeUser(_currentWallet!);
          }
        } catch (e) {
          debugPrint(
            'ChatProvider: connectAndSubscribe failed, falling back: $e',
          );
          if (superseded()) return;
          _socket.subscribeUser(_currentWallet!);
        }
        // Log subscription state for debugging
        try {
          final currentSub = _socket.currentSubscribedWallet;
          debugPrint(
            'ChatProvider.initialize: socket currentSubscribedWallet=$currentSub expected=$_currentWallet',
          );
        } catch (_) {}
      } else {
        // try to determine wallet if not set
        try {
          final meResp2 = await _api.getMyProfile();
          if (meResp2['success'] == true && meResp2['data'] != null) {
            final me2 = meResp2['data'] as Map<String, dynamic>;
            final resolvedWallet2 =
                (me2['wallet_address'] ?? me2['walletAddress'] ?? me2['wallet'])
                    ?.toString();
            if (superseded()) return;
            _currentWallet = resolvedWallet2;
            if (_currentWallet != null && _currentWallet!.isNotEmpty) {
              try {
                final ok2 = await _socket.connectAndSubscribe(
                  _api.baseUrl,
                  _currentWallet!,
                );
                debugPrint(
                  'ChatProvider: socket connectAndSubscribe result (after profile try): $ok2',
                );
                if (!ok2) _socket.subscribeUser(_currentWallet!);
              } catch (e2) {
                debugPrint(
                  'ChatProvider: connectAndSubscribe fallback failed after profile try: $e2',
                );
                _socket.subscribeUser(_currentWallet!);
              }
            }
          }
        } catch (e) {
          debugPrint(
            'ChatProvider: Failed to determine current wallet during subscribe: $e',
          );
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
            'ChatProvider: EventBus profile_updated handler error: $e',
          );
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
                    achievementProgress: [],
                  );
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
        'ChatProvider: EventBus profiles_updated subscription failed: $e',
      );
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

  void bindAuthContext({
    ProfileProvider? profileProvider,
    String? accountId,
    String? walletAddress,
    bool? isSignedIn,
  }) {
    _chatProviderBindAuthContext(
      this,
      profileProvider: profileProvider,
      accountId: accountId,
      walletAddress: walletAddress,
      isSignedIn: isSignedIn,
    );
  }

  Future<void> refreshConversations() async {
    // Responses for a previous session/account are dropped (see _sessionGeneration).
    final generation = _sessionGeneration;
    try {
      debugPrint(
        'ChatProvider.refreshConversations: isAuthenticated=${_api.hasAuthSession}',
      );
      if (!_hasAuthContext) {
        return;
      }
      if (_lastUnauthorizedAt != null &&
          DateTime.now().difference(_lastUnauthorizedAt!) < _unauthCooldown) {
        return;
      }
      // Ensure we attempt to issue or load auth token before making protected call
      final hasSession = await _api.restoreExistingSession();
      if (generation != _sessionGeneration) return;
      if (!hasSession) {
        _lastUnauthorizedAt = DateTime.now();
        return;
      }
      if (!_api.hasAuthSession && (_currentWallet ?? '').isNotEmpty) {
        try {
          await _api.ensureAuthLoaded(walletAddress: _currentWallet);
        } catch (_) {}
        if (generation != _sessionGeneration) return;
      }
      final resp = await _api.fetchConversations();
      if (generation != _sessionGeneration) return;
      if (resp['status'] == 401) {
        _lastUnauthorizedAt = DateTime.now();
        return;
      }
      if (resp['success'] == true) {
        final items = (resp['data'] as List<dynamic>?) ?? [];
        await _hydrateConversationsFromPayload(
          items,
          sessionGeneration: generation,
        );
        if (generation != _sessionGeneration) return;
        _lastUnauthorizedAt = null;
        debugPrint(
          'ChatProvider.refreshConversations: loaded ${_conversations.length} conversations',
        );
      }
    } catch (e) {
      debugPrint('ChatProvider: Error refreshing conversations: $e');
    }
  }

  void _upsertConversationMetadataForMessage(
    String conversationId,
    ChatMessage message, {
    bool force = false,
  }) {
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
      memberUserIds: existing.memberUserIds,
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

  /// Wallet named by a /profiles/me payload. The profile row `id` is not a
  /// wallet: subscribing with it makes the server reject subscribe:user.
  static String walletFromProfilePayload(Map<String, dynamic> me) =>
      (me['wallet_address'] ?? me['walletAddress'] ?? me['wallet'] ?? '')
          .toString()
          .trim();

  /// Wallet persisted by the auth/profile flow. `user_id` is an account key
  /// and may not be a wallet, so it must never be used as a socket room id.
  static String storedWalletFromPrefs(SharedPreferences prefs) =>
      (prefs.getString('wallet_address') ?? prefs.getString('wallet') ?? '')
          .trim();

  Map<String, dynamic>? _normalizeIncomingMessagePayload(
    Map<String, dynamic> data,
  ) {
    // Envelope fields (`data`, `payload`) only win when they actually carry a
    // message. An empty or metadata-only envelope must not shadow the top-level
    // message fields the backend sends alongside it.
    Map<String, dynamic>? unwrapCandidate(
      Object? candidate, {
      bool requireMessage = false,
    }) {
      if (candidate is! Map) return null;
      final map = Map<String, dynamic>.from(candidate);
      final nestedMessage = map['message'];
      final unwrapped =
          nestedMessage is Map ? Map<String, dynamic>.from(nestedMessage) : map;
      if (requireMessage && !_looksLikeIncomingMessage(unwrapped)) {
        return null;
      }
      return unwrapped;
    }

    final rawMessage = unwrapCandidate(data['message']);
    if (rawMessage != null) return rawMessage;

    final rawData = unwrapCandidate(data['data'], requireMessage: true);
    if (rawData != null) return rawData;

    final rawPayload = unwrapCandidate(data['payload'], requireMessage: true);
    if (rawPayload != null) return rawPayload;

    final rawRaw = unwrapCandidate(data['raw']);
    if (rawRaw != null) {
      return _looksLikeIncomingMessage(rawRaw) ? rawRaw : null;
    }

    return _looksLikeIncomingMessage(data)
        ? Map<String, dynamic>.from(data)
        : null;
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
    final nonMessageSignals = <String>[event, eventType, type].join('|');
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

    final hasBody =
        (payload['message']?.toString().trim().isNotEmpty == true) ||
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

    return hasBody || hasRenderableAttachment || hasReply;
  }

  bool _isNonMessageEventPayload(Map<String, dynamic> data) {
    final topLevelEvent = data['event']?.toString().toLowerCase() ?? '';
    final topLevelEventType = data['eventType']?.toString().toLowerCase() ?? '';
    final topLevelType = data['type']?.toString().toLowerCase() ?? '';
    final topLevelSignals = <String>[
      topLevelEvent,
      topLevelEventType,
      topLevelType,
    ].join('|');
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

    final keys =
        payload.keys.map((key) => key.toString().toLowerCase()).toSet();
    final onlyMetaKeys = keys.every(
      (key) => <String>{
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
      }.contains(key),
    );
    if (onlyMetaKeys) return true;

    return !_looksLikeIncomingMessage(payload);
  }

  bool _matchesOptimisticMessage(ChatMessage current, ChatMessage incoming) {
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
    // A walletless optimistic message is this account's own send. Only the
    // account's echo may replace it; another walletless sender never can.
    final sameSender = WalletUtils.canonical(current.senderWallet).isEmpty
        ? _isCurrentAccountActor(
            userId: incoming.senderUserId,
            wallet: incoming.senderWallet,
          )
        : WalletUtils.equals(current.senderWallet, incoming.senderWallet);
    if (!sameSender) return false;
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
          debugPrint(
            'ChatProvider._onMessageReceived: rejecting non-message event payload',
          );
        }
        return;
      }

      final payload = _normalizeIncomingMessagePayload(data);
      if (payload == null) {
        if (kDebugMode) {
          debugPrint(
            'ChatProvider._onMessageReceived: payload normalization failed',
          );
        }
        return;
      }

      final convId = _extractIncomingConversationId(data, payload);
      if (convId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'ChatProvider._onMessageReceived: missing conversation id; rawData=$data',
          );
        }
        return;
      }
      if (!_isSocketEventForCurrentSession(convId, data)) {
        if (kDebugMode) {
          debugPrint(
            'ChatProvider._onMessageReceived: dropping event outside current session',
          );
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
            'ChatProvider._onMessageReceived: ignoring non-renderable payload=${payload.keys.toList()}',
          );
        }
        return;
      }
      final normalizedMsg = msg;
      final isSelfSender = _isCurrentAccountActor(
        userId: normalizedMsg.senderUserId,
        wallet: normalizedMsg.senderWallet,
      );
      final existing = _messages[convId] ?? const <ChatMessage>[];
      final next = <ChatMessage>[];
      var inserted = false;
      final alreadyHadServerMessage = existing.any(
        (message) => message.id == normalizedMsg.id,
      );
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
      } else if (!alreadyHadServerMessage && !isSelfSender) {
        _unreadCounts[convId] = (_unreadCounts[convId] ?? 0) + 1;
      }
      _upsertConversationMetadataForMessage(convId, normalizedMsg);
      // Trigger an OS/local notification for incoming messages when the conversation
      // is not open. PushNotificationService will no-op if permission not granted.
      try {
        if (!isOpen && !alreadyHadServerMessage && !isSelfSender) {
          final senderWallet = normalizedMsg.senderWallet;
          final authorName = normalizedMsg.senderDisplayName ??
              normalizedMsg.senderUsername ??
              _userCache[senderWallet]?.name ??
              (senderWallet.length > 10
                  ? '${senderWallet.substring(0, 10)}...'
                  : senderWallet);
          final content = normalizedMsg.message.toString();
          // Fire-and-forget: service early-returns when permission is not granted
          PushNotificationService()
              .showDirectMessageNotification(
            eventId: normalizedMsg.id,
            conversationId: convId,
            senderName: authorName,
            content: content,
          )
              .catchError((e) {
            debugPrint(
              'ChatProvider: showDirectMessageNotification failed: $e',
            );
          });
        }
      } catch (e) {
        debugPrint(
          'ChatProvider: Failed to show local notification for incoming message: $e',
        );
      }
      if (kDebugMode) {
        debugPrint(
          'ChatProvider: _onMessageReceived: convId=$convId, msgId=${normalizedMsg.id}, messagesInConv=${_messages[convId]?.length ?? 0}, unread=${_unreadCounts[convId]}',
        );
        // Report whether this conversation is known locally.
        final convIdx = _conversations.indexWhere((c) => c.id == convId);
        debugPrint(
          'ChatProvider: conv known locally: ${convIdx >= 0}, convCount=${_conversations.length}, index=$convIdx',
        );
      }
      // Force notify so unread badge updates are immediate in UI
      _safeNotifyListeners(force: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ChatProvider: Error handling incoming message: $e');
      }
    }
  }

  bool _isRenderableIncomingMessage(ChatMessage message) =>
      message.isRenderable;

  void _onMessageRead(Map<String, dynamic> data) {
    try {
      final convId =
          (data['conversation_id'] ?? data['conversationId'] ?? '').toString();
      final messageId =
          (data['message_id'] ?? data['messageId'] ?? '').toString();
      final reader = (data['reader'] ?? data['wallet'] ?? '').toString();
      // The reader is named by account id, wallet, or both. A payload with no
      // user id is a legacy one, whose `reader` is the wallet.
      final readerUserId = _identityText(data, const ['userId', 'user_id']);
      final readerWallet = _identityText(
              data, const ['wallet', 'walletAddress']) ??
          (readerUserId == null ? _identityText(data, const ['reader']) : null);

      if (convId.isEmpty || messageId.isEmpty) return;
      if (!_isSocketEventForCurrentSession(convId, data)) return;

      debugPrint(
        'ChatProvider._onMessageRead: convId=$convId, messageId=$messageId, reader=$reader',
      );

      final list = _messages[convId];
      if (list == null) {
        debugPrint(
          'ChatProvider._onMessageRead: No messages found for conv $convId',
        );
        return;
      }

      var messageFound = false;
      for (var i = 0; i < list.length; i++) {
        final m = list[i];
        if (m.id != messageId) continue;

        messageFound = true;

        // Check if this reader is already in the list
        final alreadyRegistered = m.readers.any((r) => isReaderEntryOf(
              r,
              accountId: readerUserId,
              wallet: readerWallet,
            ));

        if (alreadyRegistered) {
          debugPrint(
            'ChatProvider._onMessageRead: Reader $reader already registered for message $messageId',
          );
          break;
        }

        // Add reader to list
        final newReaders = List<Map<String, dynamic>>.from(m.readers);
        final readAt = (data['read_at'] ?? data['readAt'] ?? data['readAtUtc'])
            ?.toString();
        newReaders.add(
          _buildReaderMetadata(
            readerWallet ?? '',
            userId: readerUserId,
            readAtOverride: readAt,
            payload: data,
          ),
        );

        final updatedMsg = m.copyWith(
          readers: newReaders,
          readersCount: newReaders.length,
          readByCurrent: _isCurrentAccountActor(
            userId: readerUserId,
            wallet: readerWallet,
          )
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
        if (_isCurrentAccountActor(
            userId: readerUserId, wallet: readerWallet)) {
          final curr = _unreadCounts[convId] ?? 0;
          if (curr > 0) _unreadCounts[convId] = curr - 1;
        }

        debugPrint(
          'ChatProvider._onMessageRead: Updated message $messageId with new reader $reader, total readers: ${updatedMsg.readersCount}',
        );

        // Force immediate notification for read receipt updates
        _safeNotifyListeners(force: true);
        break;
      }

      if (!messageFound) {
        debugPrint(
          'ChatProvider._onMessageRead: Message $messageId not found in conversation $convId',
        );
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
          'ChatProvider._onNewConversation: subscribeConversation failed: $e',
        );
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
        'ChatProvider._onConversationMemberRead: convId=$convId, wallet=$wallet, lastRead=$lastRead',
      );
      if (convId.isEmpty) return;
      final memberUserId = _identityText(data, const ['userId', 'user_id']);
      // Detection only: the member is this session when the account id or the
      // wallet names it.
      if (_isCurrentAccountActor(
        userId: memberUserId,
        wallet: wallet.isEmpty ? null : wallet,
      )) {
        _unreadCounts[convId] = 0;
        _safeNotifyListeners(force: true);
      }
    } catch (e) {
      debugPrint('ChatProvider._onConversationMemberRead: error: $e');
    }
  }

  Future<void> sendMessage(
    String conversationId,
    String message, {
    Map<String, dynamic>? data,
    String? replyToId,
  }) async {
    final nid = conversationId;
    final trimmedMessage = message.trim();
    final hasRenderableData = (data ?? const <String, dynamic>{}).entries.any((
      entry,
    ) {
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
    // Responses for a previous session/account must not touch this session's
    // caches (see _sessionGeneration).
    final generation = _sessionGeneration;
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
      // Parse first so a failed response still throws; only the writes are fenced.
      final msg = ChatMessage.fromJson(result['data']);
      if (generation != _sessionGeneration) return;
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
      if (generation != _sessionGeneration) rethrow;
      final current = _messages[nid] ?? const <ChatMessage>[];
      _cacheMessages(
        nid,
        current
            .map(
              (item) => item.id == tempId
                  ? item.copyWith(
                      data: {
                        ...?item.data,
                        'sendStatus': 'failed',
                        'error': e.toString(),
                      },
                    )
                  : item,
            )
            .toList(growable: false),
      );
      _safeNotifyListeners(force: true);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    // Capture before the fetch: a late response must not be stamped with the
    // generation of the session that replaced this one.
    final generation = _sessionGeneration;
    final resp = await _api.fetchConversations();
    if (generation != _sessionGeneration) return const [];
    if (resp['success'] == true) {
      final items = (resp['data'] as List<dynamic>?) ?? [];
      await _hydrateConversationsFromPayload(
        items,
        sessionGeneration: generation,
      );
      return items.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    // Messages fetched under a previous session/account are never cached.
    final generation = _sessionGeneration;
    // Ensure the backend auth token is loaded before calling API to prevent 401s
    try {
      await _api.ensureAuthLoaded(walletAddress: _currentWallet);
    } catch (_) {}
    if (generation != _sessionGeneration) return const <ChatMessage>[];
    Map<String, dynamic> resp;
    try {
      resp = await _api.fetchMessages(conversationId);
    } catch (e) {
      debugPrint(
        'ChatProvider: fetchMessages failed, attempting session restore and retry: $e',
      );
      try {
        final restored = await _api.restoreExistingSession();
        if (generation != _sessionGeneration) {
          return const <ChatMessage>[];
        }
        if (!restored) {
          rethrow;
        }
        resp = await _api.fetchMessages(conversationId);
      } catch (e2) {
        debugPrint('ChatProvider: Second attempt to fetchMessages failed: $e2');
        rethrow;
      }
    }
    if (generation != _sessionGeneration) return const <ChatMessage>[];
    if (resp['success'] == true) {
      final items = (resp['data'] as List<dynamic>?) ?? [];
      final list = items
          .map((i) => ChatMessage.fromJson(i as Map<String, dynamic>))
          .toList();
      _cacheMessages(conversationId, list);
      seedMessageParticipants(list);
      debugPrint(
        'ChatProvider.loadMessages: conversationId=$conversationId loaded ${list.length} messages',
      );
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
          'ChatProvider.loadMessages: prefetch sender profiles failed: $e',
        );
      }
      // If this conversation is currently open, mark it read after loading messages
      if (generation != _sessionGeneration) return const <ChatMessage>[];
      if (_openConversationId != null &&
          _openConversationId == conversationId) {
        try {
          await markRead(conversationId, sessionGeneration: generation);
        } catch (_) {}
      }
      return list;
    }
    return [];
  }

  // Fire-and-forget: inform server that a single message has been read, without
  // performing local state adjustments (used when we already updated local state optimistically).
  Future<void> _sendMarkMessageReadToServer(
    String conversationId,
    String messageId,
  ) async {
    try {
      final resp = await _api.markMessageRead(conversationId, messageId);
      debugPrint(
        'ChatProvider._sendMarkMessageReadToServer: resp=$resp for conv=$conversationId msg=$messageId',
      );
    } catch (e) {
      debugPrint('ChatProvider: _sendMarkMessageReadToServer failed: $e');
    }
  }

  Map<String, dynamic> _buildReaderMetadata(
    String wallet, {
    String? userId,
    String? readAtOverride,
    Map<String, dynamic>? payload,
  }) {
    final normalizedWallet = wallet.trim();
    final normalizedUserId = (userId ?? '').trim();
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
      displayName =
          normalizedWallet.isNotEmpty ? normalizedWallet : normalizedUserId;
    }

    return {
      'wallet_address': normalizedWallet,
      'wallet': normalizedWallet,
      'user_id': normalizedUserId,
      'userId': normalizedUserId,
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

  Future<void> _prefetchUsersForAccountIds(List<String> accountIds) async {
    await _chatProviderPrefetchUsersForAccountIds(this, accountIds);
  }

  /// Merge provided users into the ChatProvider user cache and notify listeners.
  /// This is intended for UI code that performs local fetches via UserService
  /// so that the provider cache remains in sync and UI updates are propagated.
  void mergeUserCache(List<User> users) {
    _chatProviderMergeUserCache(this, users);
  }

  Future<Map<String, dynamic>> uploadAttachment(
    String conversationId,
    List<int> bytes,
    String filename,
    String contentType,
  ) async {
    final generation = _sessionGeneration;
    final resp = await _api.uploadMessageAttachment(
      conversationId,
      bytes,
      filename,
      contentType,
    );
    // A response for a previous session must not reload that conversation into the current one.
    if (generation != _sessionGeneration) return resp;
    if (resp['success'] == true) {
      // The server will broadcast via sockets; ensure local state is refreshed
      await loadMessages(conversationId);
    }
    return resp;
  }

  /// The backend answers a restricted, closed or unknown recipient with
  /// 404 RECIPIENT_UNAVAILABLE. Nothing else about the refusal is surfaced.
  bool _isRecipientUnavailable(Map<String, dynamic> resp) {
    if (resp['status'] != 404) return false;
    final code = (resp['errorCode'] ?? '').toString().trim().toUpperCase();
    return code == 'RECIPIENT_UNAVAILABLE';
  }

  static const ConversationCreateOutcome _noConversation =
      ConversationCreateOutcome();

  static ConversationCreateOutcome _created(Conversation conversation) =>
      ConversationCreateOutcome(conversation: conversation);

  /// Starts (or finds) a conversation with [members]. Members are wallets or
  /// account UUIDs; the server resolves either. The result says when the
  /// recipient cannot be messaged.
  Future<Conversation?> createConversation(
    String title,
    bool isGroup,
    List<String> members,
  ) async =>
      (await createConversationOutcome(title, isGroup, members)).conversation;

  Future<ConversationCreateOutcome> createConversationOutcome(
    String title,
    bool isGroup,
    List<String> members,
  ) async {
    // Every state write and socket call below is fenced: when the session
    // changes while a request is in flight, the result is not adopted.
    final generation = _sessionGeneration;
    try {
      await _api.loadAuthToken();
    } catch (_) {}
    if (generation != _sessionGeneration) return _noConversation;
    // First-pass: fetch conversations from backend and try to find an existing 1:1 conversation
    try {
      var convResp = await _api.fetchConversations();
      if (generation != _sessionGeneration) return _noConversation;
      // If unauthorized, try to issue a token for current wallet and retry once
      try {
        final status = convResp['status'] as int?;
        if (status == 401) {
          // Resolve wallet if unknown - prefer SharedPreferences (non-sensitive) before any auth calls
          if (_currentWallet == null || _currentWallet!.isEmpty) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final w = storedWalletFromPrefs(prefs);
              if (generation != _sessionGeneration) return _noConversation;
              if (w.isNotEmpty) _currentWallet = w.toString();
            } catch (e2) {
              debugPrint(
                'createConversation: SharedPreferences fallback for wallet failed: $e2',
              );
            }
            // If we still don't have a wallet and there IS a token, try resolving via getMyProfile
            if (_api.hasAuthSession &&
                (_currentWallet == null || _currentWallet!.isEmpty)) {
              try {
                final meResp = await _api.getMyProfile();
                if (generation != _sessionGeneration) return _noConversation;
                if (meResp['success'] == true && meResp['data'] != null) {
                  final me = meResp['data'] as Map<String, dynamic>;
                  _currentWallet = (me['wallet_address'] ??
                          me['walletAddress'] ??
                          me['wallet'])
                      ?.toString();
                }
              } catch (e) {
                debugPrint(
                  'createConversation: getMyProfile failed while resolving wallet for conv list retry: $e',
                );
              }
            }
          }

          if (AppConfig.enableDebugIssueToken &&
              _currentWallet != null &&
              _currentWallet!.isNotEmpty) {
            final issued = await _api.issueDebugTokenForWallet(_currentWallet!);
            if (generation != _sessionGeneration) return _noConversation;
            if (issued) {
              try {
                await _api.loadAuthToken();
              } catch (_) {}
              convResp = await _api.fetchConversations();
              if (generation != _sessionGeneration) return _noConversation;
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
            if (generation != _sessionGeneration) return _noConversation;
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
                    final memberUserId =
                        ((m)['user_id'] ?? m['userId'])?.toString() ?? '';
                    final isTarget = (wallet.isNotEmpty && wallet == target) ||
                        (memberUserId.isNotEmpty &&
                            WalletUtils.sameIdentity(memberUserId, target));
                    if (isTarget) {
                      // Found existing direct conversation — build Conversation from backend item
                      Conversation conv;
                      try {
                        conv = Conversation.fromJson(
                          item as Map<String, dynamic>,
                        );
                      } catch (_) {
                        conv = Conversation(
                          id: cid,
                          title: (item['title'] ?? '')?.toString(),
                          isGroup: false,
                        );
                      }
                      // Insert into local cache for quick access
                      _conversations.removeWhere((c) => c.id == cid);
                      _conversations.insert(0, conv);
                      _safeNotifyListeners(force: true);
                      return _created(conv);
                    }
                  } catch (_) {}
                }
              }
            }
          } catch (e) {
            debugPrint(
              'createConversation: backend member check failed for conv item: $e',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('createConversation: backend pre-check failed: $e');
    }

    var resp = await _api.createConversation(
      title: title,
      isGroup: isGroup,
      members: members,
    );
    if (generation != _sessionGeneration) return _noConversation;
    if (_isRecipientUnavailable(resp)) {
      return const ConversationCreateOutcome(recipientUnavailable: true);
    }
    if (resp['success'] == true) {
      final conv = Conversation.fromJson(resp['data']);
      _conversations.insert(0, conv);
      _safeNotifyListeners(force: true);
      // Subscribe to the conversation room so we get real-time messages
      try {
        final ok = await _socket.subscribeConversation(conv.id);
        debugPrint(
          'ChatProvider.createConversation: subscribeConversation result: $ok',
        );
      } catch (e) {
        debugPrint(
          'ChatProvider.createConversation: subscribeConversation failed: $e',
        );
      }
      if (generation != _sessionGeneration) return _noConversation;
      // Optionally open conversation automatically
      try {
        await openConversation(conv.id);
      } catch (_) {}
      return _created(conv);
    }

    // If unauthorized, attempt to obtain a token for the current wallet and retry once
    try {
      final status = resp['status'] as int?;
      if (status == 401) {
        // Prefer SharedPreferences to locate wallet before trying profile endpoint
        if (_currentWallet == null || _currentWallet!.isEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final w = storedWalletFromPrefs(prefs);
            if (generation != _sessionGeneration) return _noConversation;
            if (w.isNotEmpty) {
              _currentWallet = w.toString();
            }
          } catch (e) {
            debugPrint(
              'createConversation: SharedPreferences wallet lookup failed: $e',
            );
          }
          // If we have a token and no wallet, try to call getMyProfile
          if (_api.hasAuthSession &&
              (_currentWallet == null || _currentWallet!.isEmpty)) {
            try {
              final meResp = await _api.getMyProfile();
              if (generation != _sessionGeneration) return _noConversation;
              if (meResp['success'] == true && meResp['data'] != null) {
                final me = meResp['data'] as Map<String, dynamic>;
                _currentWallet = (me['wallet_address'] ??
                        me['walletAddress'] ??
                        me['wallet'])
                    ?.toString();
              }
            } catch (e) {
              debugPrint(
                'createConversation: getMyProfile failed while resolving wallet for 401 retry: $e',
              );
            }
          }
        }

        if (AppConfig.enableDebugIssueToken &&
            _currentWallet != null &&
            _currentWallet!.isNotEmpty) {
          final issued = await _api.issueDebugTokenForWallet(_currentWallet!);
          if (generation != _sessionGeneration) return _noConversation;
          if (issued) {
            try {
              await _api.loadAuthToken();
            } catch (_) {}
            if (generation != _sessionGeneration) return _noConversation;
            // Retry once
            resp = await _api.createConversation(
              title: title,
              isGroup: isGroup,
              members: members,
            );
            if (generation != _sessionGeneration) return _noConversation;
            if (_isRecipientUnavailable(resp)) {
              return const ConversationCreateOutcome(
                  recipientUnavailable: true);
            }
            if (resp['success'] == true) {
              final conv = Conversation.fromJson(resp['data']);
              _conversations.insert(0, conv);
              _safeNotifyListeners(force: true);
              return _created(conv);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ChatProvider.createConversation retry flow failed: $e');
    }

    return _noConversation;
  }

  Future<Map<String, dynamic>> uploadConversationAvatar(
    String conversationId,
    List<int> bytes,
    String filename,
    String contentType,
  ) async {
    final resp = await _api.uploadConversationAvatar(
      conversationId,
      bytes,
      filename,
      contentType,
    );
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

  Future<List<String>> _collectConversationMemberWallets(
    String conversationId, {
    Conversation? conversationHint,
  }) async {
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
              WalletUtils.resolveFromMap(entry.cast<String, dynamic>()),
            );
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
          'ChatProvider._collectConversationMemberWallets: fetchMembers failed for $conversationId: $e',
        );
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

  /// Accepts either a wallet or a username. A walletless member is named by
  /// [memberUserId], the account id from the picker; it is then added by that
  /// id alone. Returns the created conversation when a new group chat is spawned.
  Future<Conversation?> addMember(
    String conversationId,
    String memberIdentifier, {
    String? memberUserId,
  }) async {
    final generation = _sessionGeneration;
    final accountId = (memberUserId ?? '').trim();
    if (WalletUtils.isAccountUuid(accountId)) {
      return _addWalletlessMember(conversationId, accountId, generation);
    }
    final trimmed = memberIdentifier.trim();
    if (trimmed.isEmpty) return null;

    var memberWallet = trimmed;
    final usernameCandidate = trimmed.replaceFirst(RegExp(r'^@+'), '');
    debugPrint(
      'ChatProvider.addMember: called with identifier="$memberIdentifier"',
    );
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
        'ChatProvider.addMember: resolved wallet empty for "$memberIdentifier"',
      );
      return null;
    }

    final conversation = _findConversationById(conversationId);
    final existingMembers = await _collectConversationMemberWallets(
      conversationId,
      conversationHint: conversation,
    );
    if (generation != _sessionGeneration) return null;
    final alreadyMember = existingMembers.any(
      (wallet) => WalletUtils.equals(wallet, memberWallet),
    );
    if (alreadyMember) {
      debugPrint(
        'ChatProvider.addMember: $memberWallet is already a member of $conversationId',
      );
      return conversation;
    }

    final uniqueMembers = _mergeMemberSets(existingMembers, [memberWallet]);
    final isGroupConversation = conversation?.isGroup == true;
    final shouldCreateGroup = !isGroupConversation && uniqueMembers.length >= 3;

    if (shouldCreateGroup) {
      debugPrint(
        'ChatProvider.addMember: promoting $conversationId to group (members=${uniqueMembers.length})',
      );
      final sanitizedMembers = uniqueMembers
          .where((wallet) => !WalletUtils.equals(wallet, _currentWallet))
          .toList();
      final groupTitle = (conversation?.title?.trim().isNotEmpty ?? false)
          ? conversation!.title!.trim()
          : 'Group chat';
      final newConversation = await createConversation(
        groupTitle,
        true,
        sanitizedMembers,
      );
      if (generation != _sessionGeneration) return null;
      if (newConversation != null) {
        await _prefetchUsersForWallets(uniqueMembers);
        return newConversation;
      }
      debugPrint(
        'ChatProvider.addMember: failed to create group conversation; falling back to inline member add',
      );
    }

    try {
      final resp = await _api.addConversationMember(
        conversationId,
        memberWallet,
      );
      debugPrint(
        'ChatProvider.addMember: addConversationMember response: $resp',
      );
    } catch (e) {
      debugPrint(
        'ChatProvider.addMember: addConversationMember call failed: $e',
      );
    }

    if (generation != _sessionGeneration) return null;
    await fetchMembers(conversationId);
    await _prefetchUsersForWallets([memberWallet]);
    await refreshConversations();
    return conversation;
  }

  /// Adds a walletless member by account id. The wallet-keyed steps (the local
  /// duplicate check and the promotion to a new group) do not apply, so the
  /// backend decides a duplicate.
  Future<Conversation?> _addWalletlessMember(
    String conversationId,
    String accountId,
    int generation,
  ) async {
    final conversation = _findConversationById(conversationId);
    try {
      final resp = await _api.addConversationMember(
        conversationId,
        '',
        userId: accountId,
      );
      debugPrint(
        'ChatProvider.addMember: addConversationMember response: $resp',
      );
    } catch (e) {
      debugPrint(
        'ChatProvider.addMember: addConversationMember call failed: $e',
      );
    }
    if (generation != _sessionGeneration) return null;
    await fetchMembers(conversationId);
    await refreshConversations();
    return conversation;
  }

  Future<void> removeMember(
    String conversationId,
    String memberIdentifier,
  ) async {
    // Try to resolve as username or wallet client-side. Backend supports accepting memberUsername/memberWallet
    var normalized = memberIdentifier;
    try {
      if (!(memberIdentifier.startsWith('0x') &&
              memberIdentifier.length >= 40) &&
          memberIdentifier.startsWith('@')) {
        normalized = memberIdentifier.replaceFirst('@', '');
      }
    } catch (_) {}
    final generation = _sessionGeneration;
    await _api.removeConversationMember(conversationId, normalized);
    if (generation != _sessionGeneration) return;
    await refreshConversations();
  }

  Future<void> renameConversation(
    String conversationId,
    String newTitle,
  ) async {
    try {
      final generation = _sessionGeneration;
      final result = await _api.renameConversation(conversationId, newTitle);
      if (generation != _sessionGeneration) return;
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
            memberUserIds: old.memberUserIds,
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
      final generation = _sessionGeneration;
      final result = await _api.deleteConversation(conversationId);
      if (generation != _sessionGeneration) return;
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
    String conversationId,
    String newOwnerWallet,
  ) async {
    try {
      final generation = _sessionGeneration;
      final resp = await _api.transferConversationOwner(
        conversationId,
        newOwnerWallet,
      );
      if (generation != _sessionGeneration) return resp;
      await refreshConversations();
      return resp;
    } catch (e) {
      debugPrint('ChatProvider: transferOwnership failed: $e');
      rethrow;
    }
  }

  Future<void> markRead(String conversationId, {int? sessionGeneration}) async {
    final generation = sessionGeneration ?? _sessionGeneration;
    // Never send a read for a previous account's conversation under the
    // current token; drop the local write if the session changed mid-flight.
    if (generation != _sessionGeneration) return;
    await _api.markConversationRead(conversationId);
    if (generation != _sessionGeneration) return;
    _unreadCounts[conversationId] = 0;
    _safeNotifyListeners(force: true);
  }

  /// Called when the app detects the current user wallet has changed/connected.
  /// Ensures provider state (auth, socket subscription, conversations) is refreshed
  /// so UI (unread badges, conversations) updates immediately after wallet connect.
  Future<void> setCurrentWallet(
    String wallet, {
    bool Function()? shouldContinue,
  }) async {
    await _chatProviderSetCurrentWallet(
      this,
      wallet,
      shouldContinue: shouldContinue,
    );
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
    final generation = _sessionGeneration;
    try {
      final resp = await _api.markMessageRead(conversationId, messageId);
      debugPrint(
        'ChatProvider.markMessageRead: api response for conv=$conversationId msg=$messageId -> $resp',
      );
      // The session changed while the request was in flight: no fallback read
      // and no local writes into the new session.
      if (generation != _sessionGeneration) return;
      // If server indicates not found or failure, try to mark the conversation read as a fallback
      if (resp['success'] != true &&
          (resp['status'] == 404 || resp['status'] == 400)) {
        try {
          await markRead(conversationId, sessionGeneration: generation);
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
              'ChatProvider.markMessageRead: updated local message readByCurrent for conv=$conversationId msg=$messageId at index=$i',
            );
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
        final readerAccountId = _socketSessionAccountId();
        if ((readerWallet.isNotEmpty || readerAccountId.isNotEmpty) &&
            !existingReaders.any((r) => isReaderEntryOf(
                  r,
                  accountId: readerAccountId,
                  wallet: readerWallet,
                ))) {
          existingReaders.add(_buildReaderMetadata(
            readerWallet,
            userId: readerAccountId,
          ));
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
    AccountIdentity.removeListener(_handleAccountIdentityChanged);
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
      if (!_isSocketEventForCurrentSession(convId, data)) return;

      final list = _messages[convId];
      if (list == null) return;

      for (var i = 0; i < list.length; i++) {
        if (list[i].id == messageId) {
          // Parse reactions
          List<MessageReaction> parsedReactions = [];
          if (reactions is List) {
            parsedReactions = reactions
                .map(
                  (r) => MessageReaction.fromJson(Map<String, dynamic>.from(r)),
                )
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
          memberUserIds: old.memberUserIds,
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
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    // Optimistic update
    final list = _messages[conversationId];
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == messageId) {
          final msg = list[i];
          final accountId = _socketSessionAccountId();
          final wallet = (_currentWallet ?? '').trim();
          // A reactor is stored as the wallet when there is one, else as the
          // account id. A session with neither has no reaction to record.
          final reactor = wallet.isNotEmpty ? wallet : accountId;
          if (reactor.isEmpty) return;

          // Check if already reacted
          final existingReactionIndex = msg.reactions.indexWhere(
            (r) => r.emoji == emoji,
          );
          bool isRemoving = false;

          List<MessageReaction> newReactions = List.from(msg.reactions);

          if (existingReactionIndex >= 0) {
            final reaction = newReactions[existingReactionIndex];
            if (reaction.isReactedBy(accountId: accountId, wallet: wallet)) {
              // Remove reaction
              isRemoving = true;
              final newReactors = reaction.reactorsExcept(
                accountId: accountId,
                wallet: wallet,
              );
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
                ..add(reactor);
              newReactions[existingReactionIndex] = MessageReaction(
                emoji: emoji,
                count: newReactors.length,
                reactors: newReactors,
              );
            }
          } else {
            // Create new reaction
            newReactions.add(
              MessageReaction(
                emoji: emoji,
                count: 1,
                reactors: [reactor],
              ),
            );
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
                conversationId,
                messageId,
                emoji,
              );
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
