import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/backend_api_service.dart';
import '../services/socket_service.dart';
import '../models/conversation.dart';
import '../services/user_service.dart';
import '../services/push_notification_service.dart';
import '../models/message.dart';
import '../models/user.dart';

class ChatProvider extends ChangeNotifier {
  // Socket event handlers
  void _onMembersUpdated(Map<String, dynamic> data) {
    try { refreshConversations(); } catch (e) { debugPrint('ChatProvider._onMembersUpdated error: $e'); }
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
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('ChatProvider._onConversationUpdated error: $e');
    }
  }
  final BackendApiService _api = BackendApiService();
  final SocketService _socket = SocketService();

  List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, int> _unreadCounts = {}; // conversationId -> unread count
  final Map<String, Future<List<Map<String, dynamic>>>> _membersRequests = {}; // convId -> in-flight Future
  final Map<String, Map<String, dynamic>> _membersCache = {}; // convId -> {'result': List<dynamic>, 'ts': int}
  final Map<String, User> _userCache = {}; // wallet -> User
  String? _currentWallet;
  String? _openConversationId;
  Timer? _pollTimer;
  // Removed cache listener: we fetch profiles directly from the API to avoid cache notification loops
  // VoidCallback? _userServiceListener;

  bool _initialized = false;
  int _lastChatVersion = 0;
  int _lastGlobalVersion = 0;
  // Throttle for notifyListeners to avoid update storms
  final int _notifyMaxPerSecond = 15;
  int _notificationsThisSecond = 0;
  DateTime _lastNotifyReset = DateTime.now();
  String _lastStateSignature = '';
  int _lastTotalUnread = 0;

  String _computeStateSignature() {
    try {
      final convCount = _conversations.length;
      int totalMessages = 0;
      int lastMsgHash = 0;
      for (final entry in _messages.entries) {
        totalMessages += entry.value.length;
        if (entry.value.isNotEmpty) lastMsgHash ^= entry.value[0].id.hashCode;
      }
      // Include user cache count and a lightweight hash of a few users so that profile updates
      // (displayName/profileImageUrl changes) can trigger UI updates in listeners.
      int userCount = _userCache.length;
      int usersHash = 0;
      var i = 0;
      for (final u in _userCache.values) {
        if (i >= 10) break; // only use a small sample to keep signature fast
        usersHash ^= u.id.hashCode ^ (u.name.hashCode) ^ ((u.profileImageUrl ?? '').hashCode);
        i++;
      }
      final totalUnreadCount = totalUnread;
      return '$convCount:$totalMessages:$lastMsgHash:$userCount:$usersHash:$totalUnreadCount';
    } catch (e) {
      return '';
    }
  }

  void _safeNotifyListeners({bool force = false}) {
    try {
      final now = DateTime.now();
      if (now.difference(_lastNotifyReset).inSeconds >= 1) {
        _notificationsThisSecond = 0;
        _lastNotifyReset = now;
      }
      var effectiveForce = force;
      // Always force notify when the total unread count changed since the
      // last notify. This ensures UI badges update immediately even if the
      // lightweight state signature fails to detect small map-only changes.
      try {
        final currTotal = totalUnread;
        if (currTotal != _lastTotalUnread) {
          effectiveForce = true;
        }
      } catch (_) {}

      if (!effectiveForce) {
        _notificationsThisSecond++;
        if (_notificationsThisSecond > _notifyMaxPerSecond) {
          debugPrint('ChatProvider._safeNotifyListeners: throttled, notified this second: $_notificationsThisSecond');
          return;
        }
      }
      // Dedup update: compute a lightweight signature of current chat state
      try {
        final sig = _computeStateSignature();
        if (!effectiveForce && sig == _lastStateSignature) {
          // Nothing changed in a meaningful way; skip notifying
          debugPrint('ChatProvider._safeNotifyListeners: signature unchanged, skipping notify: $sig');
          return;
        }
        _lastStateSignature = sig;
        // Update lastTotalUnread snapshot so subsequent changes are detected
        try { _lastTotalUnread = totalUnread; } catch (_) {}
      } catch (e) {
        // ignore signature errors
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ChatProvider._safeNotifyListeners: error notifying listeners: $e');
    }
  }

  List<Conversation> get conversations => _conversations;
  Map<String, List<ChatMessage>> get messages => _messages;
  Map<String, int> get unreadCounts => _unreadCounts;
  User? getCachedUser(String wallet) => _userCache[wallet];
  bool get isAuthenticated => (_api.getAuthToken() ?? '').isNotEmpty;

  Future<void> initialize({String? initialWallet}) async {
    if (_initialized) return;
    _initialized = true;
    // Warm persistent user cache into memory to avoid cold-start profile fetches
    try { await UserService.initialize(); } catch (e) { debugPrint('ChatProvider: UserService.initialize failed: $e'); }
    // Ensure auth token loaded once (and attempt single issuance if wallet provided)
    try { await _api.ensureAuthLoaded(walletAddress: initialWallet); } catch (_) {}
    // Determine wallet early so we can try to issue a token for the wallet before socket connect
    try {
      if (initialWallet != null && initialWallet.isNotEmpty) {
        _currentWallet = initialWallet;
        debugPrint('ChatProvider.initialize: initialWallet provided: $_currentWallet');
      }
      final meResp = await _api.getMyProfile();
      debugPrint('ChatProvider.initialize: getMyProfile response: $meResp');
      if (meResp['success'] == true && meResp['data'] != null) {
        final me = meResp['data'] as Map<String, dynamic>;
        _currentWallet = (me['wallet_address'] ?? me['walletAddress'] ?? me['wallet'])?.toString();
        debugPrint('ChatProvider.initialize: wallet from getMyProfile: $_currentWallet');
      }
    } catch (e) {
      debugPrint('ChatProvider: getMyProfile failed: $e');
      // Fallback: try to read persisted wallet from shared preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final w = prefs.getString('wallet_address') ?? prefs.getString('user_id') ?? prefs.getString('wallet') ?? '';
        debugPrint('ChatProvider.initialize: SharedPreferences wallet read: $w');
        if (w.isNotEmpty) _currentWallet = w.toString();
      } catch (e2) { debugPrint('ChatProvider: Failed to read wallet from shared prefs: $e2'); }
    }
    // Token issuance handled centrally via ensureAuthLoaded; no further action here.
    // Register socket listeners then connect & subscribe (with token if present)
    _socket.connect(_api.baseUrl);
    _socket.addMessageListener(_onMessageReceived);
    _socket.addMessageReadListener(_onMessageRead);
    _socket.addConversationListener(_onNewConversation);
    _socket.addConversationListener(_onMembersUpdated);
    _socket.addConversationListener(_onConversationUpdated);
    await refreshConversations();
    // After loading conversations, proactively fetch member profiles for faster UI updates
    try {
      final allWallets = <String>{};
      for (final conv in _conversations) {
        try {
          final members = await fetchMembers(conv.id);
          for (final m in members) {
            final wallet = ((m['wallet_address'] ?? m['wallet'] ?? m['walletAddress'] ?? m['id'])?.toString() ?? '');
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
          var ok = await _socket.connectAndSubscribe(_api.baseUrl, _currentWallet!);
          debugPrint('ChatProvider: socket connectAndSubscribe result: $ok');
          if (!ok) {
            debugPrint('ChatProvider: connectAndSubscribe failed, attempting token issuance and retry');
            try {
              final issued = await _api.issueTokenForWallet(_currentWallet!);
              if (issued) {
                await _api.loadAuthToken();
                ok = await _socket.connectAndSubscribe(_api.baseUrl, _currentWallet!);
                debugPrint('ChatProvider: socket connectAndSubscribe retry result: $ok');
              }
            } catch (e2) { debugPrint('ChatProvider: token issuance retry failed: $e2'); }
          }
          if (!ok) {
            // attempt subscribe as best effort
            _socket.subscribeUser(_currentWallet!);
          }
        } catch (e) {
          debugPrint('ChatProvider: connectAndSubscribe failed, falling back: $e');
          _socket.subscribeUser(_currentWallet!);
        }
      } else {
        // try to determine wallet if not set
        try {
          final meResp2 = await _api.getMyProfile();
          if (meResp2['success'] == true && meResp2['data'] != null) {
            final me2 = meResp2['data'] as Map<String, dynamic>;
            _currentWallet = (me2['wallet_address'] ?? me2['walletAddress'] ?? me2['wallet'])?.toString();
            if (_currentWallet != null && _currentWallet!.isNotEmpty) {
              try {
                final ok2 = await _socket.connectAndSubscribe(_api.baseUrl, _currentWallet!);
                debugPrint('ChatProvider: socket connectAndSubscribe result (after profile try): $ok2');
                if (!ok2) _socket.subscribeUser(_currentWallet!);
              } catch (e2) {
                debugPrint('ChatProvider: connectAndSubscribe fallback failed after profile try: $e2');
                _socket.subscribeUser(_currentWallet!);
              }
            }
          }
        } catch (e) {
          debugPrint('ChatProvider: Failed to determine current wallet during subscribe: $e');
        }
      }
    } catch (e) { debugPrint('ChatProvider: socket subscribe failed: $e'); }
    // Previously we relied on an internal cacheVersion notifier to trigger UI updates,
    // but that pattern caused repeated refreshes and UI update storms. We now avoid
    // relying on implicit cache notifications and prefer explicit API calls
    // via UserService.getUsersByWallets/getUserById when needed.
    // (previously we attempted to issue token here, moved earlier)
  }

  /// Bind to AppRefreshProvider for global or targeted chat refresh triggers
  void bindToRefresh(dynamic appRefresh) {
    try {
      if (appRefresh == null) return;
      _lastChatVersion = appRefresh.chatVersion ?? 0;
      _lastGlobalVersion = appRefresh.globalVersion ?? 0;
      appRefresh.addListener(() {
        try {
          if ((appRefresh.chatVersion ?? 0) != _lastChatVersion) {
            _lastChatVersion = appRefresh.chatVersion ?? 0;
            refreshConversations();
          } else if ((appRefresh.globalVersion ?? 0) != _lastGlobalVersion) {
            _lastGlobalVersion = appRefresh.globalVersion ?? 0;
            refreshConversations();
          }
        } catch (e) { debugPrint('ChatProvider.bindToRefresh handler error: $e'); }
      });
    } catch (e) { debugPrint('ChatProvider.bindToRefresh failed: $e'); }
  }
        // Force a notify when UI-driven fetches merge into the provider cache.
        // This bypasses the signature dedupe check so profile/avatar updates
        // take effect immediately in UI widgets that rely on provider state.

  Future<void> refreshConversations() async {
    try {
      debugPrint('ChatProvider.refreshConversations: isAuthenticated=${(_api.getAuthToken() ?? '').isNotEmpty}');
      // Ensure we attempt to issue or load auth token before making protected call
      try { await _api.ensureAuthLoaded(walletAddress: _currentWallet); } catch (_) {}
      final resp = await _api.fetchConversations();
      // If unauthorized, try the centralized ensureAuthLoaded once (single issuance attempt), then retry one time
      if (resp['status'] == 401) {
        debugPrint('ChatProvider.refreshConversations: received 401, calling ensureAuthLoaded and retrying once');
        try {
          await _api.ensureAuthLoaded(walletAddress: _currentWallet);
          final respRetry = await _api.fetchConversations();
          if (respRetry['success'] == true) {
            final items = (respRetry['data'] as List<dynamic>?) ?? [];
            _conversations = items.map((i) => Conversation.fromJson(i as Map<String, dynamic>)).toList();
            _unreadCounts.clear();
            for (final it in items) {
              final m = it as Map<String, dynamic>;
              final convId = (m['id'] as String);
              final unread = (m['unreadCount'] as int?) ?? (m['unread_count'] as int?) ?? 0;
              _unreadCounts[convId] = unread;
            }
            debugPrint('ChatProvider.refreshConversations: loaded ${_conversations.length} conversations after retry');
            _safeNotifyListeners(force: true);
            return;
          }
        } catch (e) {
          debugPrint('ChatProvider.refreshConversations: retry after 401 failed: $e');
        }
        return;
      }
      if (resp['success'] == true) {
        final items = (resp['data'] as List<dynamic>?) ?? [];
        _conversations = items.map((i) => Conversation.fromJson(i as Map<String, dynamic>)).toList();
        // populate unread counts
        _unreadCounts.clear();
        for (final it in items) {
          final m = it as Map<String, dynamic>;
          final convId = (m['id'] as String);
          final unread = (m['unreadCount'] as int?) ?? (m['unread_count'] as int?) ?? 0;
          _unreadCounts[convId] = unread;
        }
        debugPrint('ChatProvider.refreshConversations: loaded ${_conversations.length} conversations');
        _safeNotifyListeners(force: true);
        // Background: collect member wallets and prefetch their user profiles
        try {
          final all = <String>{};
          for (final c in _conversations) {
            try {
              final members = await fetchMembers(c.id);
              for (final m in members) {
                final wallet = ((m['wallet_address'] ?? m['wallet'] ?? m['walletAddress'] ?? m['id'])?.toString() ?? '');
                if (wallet.isNotEmpty) all.add(wallet);
              }
            } catch (_) {}
          }
          if (all.isNotEmpty) {
            _prefetchUsersForWallets(all.toList());
          }
        } catch (e) {
          debugPrint('ChatProvider.refreshConversations: background prefetch failed: $e');
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: Error refreshing conversations: $e');
    }
  }

  void _onMessageReceived(Map<String, dynamic> data) {
    try {
      final convIdRaw = (data['conversationId'] ?? data['conversation_id']) as String;
      final convId = convIdRaw;
      final msgJson = Map<String, dynamic>.from(data);
      final msg = ChatMessage.fromJson(msgJson);
      // Normalize keys to lowercase so lookups are stable across sockets and stores
      // If messages already fetched for this conversation, insert. Otherwise, fetch messages first so UI has proper history
      if (_messages.containsKey(convId)) {
        // If this conversation is currently open in the UI, mark message as read
        // and avoid incrementing the unread counter. Also ensure we inform server.
        if (_openConversationId != null && _openConversationId == convId) {
          // Insert the message into the in-memory list
          _messages[convId]!.insert(0, msg);
          // Optimistically mark this message as read locally
          markMessageReadLocal(convId, msg.id);
          // Ensure conversation unread count is zero while open
          _unreadCounts[convId] = 0;
          // Inform server about per-message read (fire-and-forget, no extra local adjustments)
          _sendMarkMessageReadToServer(convId, msg.id);
          _safeNotifyListeners();
        } else {
          _messages[convId]!.insert(0, msg);
        }
      } else {
        // Fetch messages in background, don't block socket handling
        debugPrint('ChatProvider: Messages for conv $convId unknown locally, fetching');
        // Mark as fetching with empty list to avoid duplicate fetches
        _messages[convId] = [];
        _api.fetchMessages(convId).then((resp) {
          if (resp['success'] == true) {
            final items = (resp['data'] as List<dynamic>?) ?? [];
            final list = items.map((i) => ChatMessage.fromJson(i as Map<String, dynamic>)).toList();
            _messages[convId] = list;
            // Insert incoming message at top if absent
            if (!_messages[convId]!.any((m) => m.id == msg.id)) {
              _messages[convId]!.insert(0, msg);
              // If this conversation is currently open, mark it read and mark this message read
              if (_openConversationId != null && _openConversationId == convId) {
                markMessageReadLocal(convId, msg.id);
                _unreadCounts[convId] = 0;
                _sendMarkMessageReadToServer(convId, msg.id);
              }
            }
            _safeNotifyListeners();
            debugPrint('ChatProvider: Fetched ${_messages[convId]?.length ?? 0} messages for conv $convId after socket event');
          }
        }).catchError((e) {
          debugPrint('ChatProvider: Background fetchMessages failed for conv $convId: $e');
        });
      }
      // Only increment unread count when the conversation is not currently open
      if (!(_openConversationId != null && _openConversationId == convId)) {
        _unreadCounts[convId] = (_unreadCounts[convId] ?? 0) + 1;
      }
      // Trigger an OS/local notification for incoming messages when the conversation
      // is not open. PushNotificationService will no-op if permission not granted.
      try {
        if (!(_openConversationId != null && _openConversationId == convId)) {
          final senderWallet = msg.senderWallet;
          final authorName = (_userCache[senderWallet]?.name) ?? (senderWallet.length > 10 ? '${senderWallet.substring(0, 10)}...' : senderWallet);
          final content = msg.message.toString();
          // Fire-and-forget: service early-returns when permission is not granted
          PushNotificationService().showCommunityNotification(
            postId: msg.id,
            authorName: authorName,
            content: content,
          );
        }
      } catch (e) {
        debugPrint('ChatProvider: Failed to show local notification for incoming message: $e');
      }
      debugPrint('ChatProvider: _onMessageReceived: convId=$convId, msgId=${msg.id}, messagesInConv=${_messages[convId]?.length ?? 0}, unread=${_unreadCounts[convId]}');
      // Report whether this conversation is known locally
      final convIdx = _conversations.indexWhere((c) => c.id == convId);
      debugPrint('ChatProvider: conv known locally: ${convIdx >= 0}, convCount=${_conversations.length}, index=$convIdx');
      // Force notify so unread badge updates are immediate in UI
      _safeNotifyListeners(force: true);
    } catch (e) {
      debugPrint('ChatProvider: Error handling incoming message: $e');
    }
  }

  void _onMessageRead(Map<String, dynamic> data) {
    try {
      final convIdRaw = (data['conversationId'] ?? data['conversation_id']) as String;
      final convId = convIdRaw;
      final messageId = (data['messageId'] ?? data['message_id']) as String;
      final reader = (data['reader'] ?? data['readerWallet'] ?? data['reader_wallet'] ?? data['wallet'] ?? data['sender_wallet']) as String?;
      // Update readers count for that message and clear unread state for reader
      final list = _messages[convId];
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          final m = list[i];
          if (m.id == messageId) {
            // Avoid double increment if we already marked read locally
            final newCount = m.readersCount + 1;
            final newData = m.data == null ? <String, dynamic>{} : Map<String, dynamic>.from(m.data!);
            newData['readersCount'] = newCount;
            // Build updated readers list to include this reader event if not present
            final existingReaders = m.readers.map((e) => Map<String, dynamic>.from(e)).toList();
            final readerWallet = reader?.toString() ?? '';
            final alreadyRegistered = existingReaders.any((r) => (r['wallet_address'] ?? r['wallet']) == readerWallet);
            if (!alreadyRegistered && readerWallet.isNotEmpty) {
              existingReaders.add({'wallet_address': readerWallet, 'read_at': DateTime.now().toIso8601String()});
              // Try to prefetch reader profile for avatar & displayName enhancements
              try { _prefetchUsersForWallets([readerWallet]); } catch (_) {}
            }
            final updatedMsg = ChatMessage(
              id: m.id,
              conversationId: m.conversationId,
              senderWallet: m.senderWallet,
              message: m.message,
              data: newData,
              readersCount: newCount,
              // If the reader is our wallet, set readByCurrent true
              readByCurrent: (readerWallet.isNotEmpty && _currentWallet != null && readerWallet == _currentWallet) ? true : m.readByCurrent,
              readers: existingReaders,
              createdAt: m.createdAt,
            );
            _messages[convId]![i] = updatedMsg;
            // If the reader is our wallet, decrease unread count
            if (reader != null && _currentWallet != null && reader.toString() == _currentWallet) {
              final curr = _unreadCounts[convId] ?? 0;
              if (curr > 0) _unreadCounts[convId] = curr - 1;
            }
            // Force notify so read-receipt UI updates immediately
            _safeNotifyListeners(force: true);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: Error handling message-read: $e');
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
      // Automatically subscribe to this conversation's socket room for real-time updates
      try { _socket.subscribeConversation(conv.id); } catch (e) { debugPrint('ChatProvider._onNewConversation: subscribeConversation failed: $e'); }
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('ChatProvider: Error handling new conversation: $e');
    }
  }

  Future<void> sendMessage(String conversationId, String message, {Map<String, dynamic>? data}) async {
    final result = await _api.sendMessage(conversationId, message, data: data);
    // Also append locally
    final msg = ChatMessage.fromJson(result['data']);
    final nid = conversationId;
    _messages.putIfAbsent(nid, () => []);
    _messages[nid]!.insert(0, msg);
    _safeNotifyListeners(force: true);
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final resp = await _api.fetchConversations();
    if (resp['success'] == true) {
      final items = (resp['data'] as List<dynamic>?) ?? [];
      _conversations = items.map((i) => Conversation.fromJson(i as Map<String, dynamic>)).toList();
      _safeNotifyListeners(force: true);
      return items.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    // Ensure the backend auth token is loaded before calling API to prevent 401s
    try { await _api.ensureAuthLoaded(walletAddress: _currentWallet); } catch (_) {}
    Map<String, dynamic> resp;
    try {
      resp = await _api.fetchMessages(conversationId);
    } catch (e) {
      debugPrint('ChatProvider: fetchMessages failed, attempting token refresh and retry: $e');
      // If we have a wallet, try to issue token and retry once
      try {
        if (_currentWallet != null && _currentWallet!.isNotEmpty) {
          final issued = await _api.issueTokenForWallet(_currentWallet!);
          if (issued) {
            await _api.loadAuthToken();
            resp = await _api.fetchMessages(conversationId);
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      } catch (e2) {
        debugPrint('ChatProvider: Second attempt to fetchMessages failed: $e2');
        rethrow;
      }
    }
    if (resp['success'] == true) {
      final items = (resp['data'] as List<dynamic>?) ?? [];
      final list = items.map((i) => ChatMessage.fromJson(i as Map<String, dynamic>)).toList();
      _messages[conversationId] = list;
      debugPrint('ChatProvider.loadMessages: conversationId=$conversationId loaded ${list.length} messages');
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
        debugPrint('ChatProvider.loadMessages: prefetch sender profiles failed: $e');
      }
      // If this conversation is currently open, mark it read after loading messages
      if (_openConversationId != null && _openConversationId == conversationId) {
        try { await markRead(conversationId); } catch (_) {}
      }
      return list;
    }
    return [];
  }


  // Fire-and-forget: inform server that a single message has been read, without
  // performing local state adjustments (used when we already updated local state optimistically).
  Future<void> _sendMarkMessageReadToServer(String conversationId, String messageId) async {
    try {
      await _api.markMessageRead(conversationId, messageId);
    } catch (e) {
      debugPrint('ChatProvider: _sendMarkMessageReadToServer failed: $e');
    }
  }
  Future<List<Map<String, dynamic>>> fetchMembers(String conversationId) async {
    // Return cached result if recent (TTL 30 seconds)
    final now = DateTime.now().millisecondsSinceEpoch;
    final cache = _membersCache[conversationId];
    if (cache != null) {
      final ts = cache['ts'] as int? ?? 0;
      if (now - ts < 30000) {
        try {
          return (cache['result'] as List<dynamic>).cast<Map<String, dynamic>>();
        } catch (_) {
          // fallthrough to fetch
        }
      }
    }

    // Deduplicate concurrent requests
    if (_membersRequests.containsKey(conversationId)) {
      try {
        final existing = await _membersRequests[conversationId];
        if (existing != null) return existing;
      } catch (e) {
        // If previous failed, continue to fetch anew
      } finally {
        _membersRequests.remove(conversationId);
      }
    }

    final completer = _api.fetchConversationMembers(conversationId).then((resp) {
      if (resp['success'] == true) {
        final list = (resp['data'] as List<dynamic>?) ?? [];
        // cache it
        _membersCache[conversationId] = {'result': list, 'ts': DateTime.now().millisecondsSinceEpoch};
        debugPrint('ChatProvider: cached ${list.length} members for conversation $conversationId');
        // Notify listeners so UI can react to newly-cached member lists
        try { _safeNotifyListeners(); } catch (_) {}
        // Prefetch user profiles for these members to populate local cache
        try {
          final wallets = <String>[];
          for (final m in list) {
            final wallet = ((m['wallet_address'] ?? m['wallet'] ?? m['walletAddress'] ?? m['id'])?.toString() ?? '');
            if (wallet.isNotEmpty) wallets.add(wallet);
          }
          if (wallets.isNotEmpty) _prefetchUsersForWallets(wallets);
        } catch (e) {
          debugPrint('ChatProvider: prefetch profiles after fetchMembers failed: $e');
        }
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
      // For 429 or other non-200, cache an empty list with a short cooldown to avoid spamming the server
      _membersCache[conversationId] = {'result': <dynamic>[], 'ts': DateTime.now().millisecondsSinceEpoch};
      debugPrint('ChatProvider: cached 0 members (empty) for conversation $conversationId');
      try { _safeNotifyListeners(); } catch (_) {}
      return <Map<String, dynamic>>[];
    }).whenComplete(() => _membersRequests.remove(conversationId));

    _membersRequests[conversationId] = completer;
    final result = await completer;
    return result;
  }

  Future<void> _prefetchUsersForWallets(List<String> wallets) async {
    try {
      debugPrint('ChatProvider._prefetchUsersForWallets: wallets=${wallets.length}');
      final uniq = wallets.where((w) => w.isNotEmpty).toSet().toList();
      if (uniq.isEmpty) return;
      final users = await UserService.getUsersByWallets(uniq);
      final updated = <String>[];
      for (final u in users) {
        if (u.id.isNotEmpty) { _userCache[u.id] = u; updated.add(u.id); }
      }
      if (updated.isNotEmpty) debugPrint('ChatProvider._prefetchUsersForWallets: updated users=${updated.length}, sample=${updated.take(6).toList()}');
      // Also populate UserService internal cache so other callers benefit
      try { UserService.setUsersInCache(users); } catch (_) {}
      // Notify listeners forcefully so UI updates (avatars/names/badges) are applied immediately
      try { _safeNotifyListeners(force: true); } catch (_) {}
    } catch (e) {
      debugPrint('ChatProvider._prefetchUsersForWallets failed: $e');
    }
  }

  /// Merge provided users into the ChatProvider user cache and notify listeners.
  /// This is intended for UI code that performs local fetches via UserService
  /// so that the provider cache remains in sync and UI updates are propagated.
  void mergeUserCache(List<User> users) {
    final updated = <String>[];
    for (final u in users) {
      if (u.id.isNotEmpty) {
        _userCache[u.id] = u;
        updated.add(u.id);
      }
    }
    if (updated.isNotEmpty) {
      debugPrint('ChatProvider.mergeUserCache: updated ${updated.length} users, sample=${updated.take(5).toList()}');
      try { _safeNotifyListeners(); } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> uploadAttachment(String conversationId, List<int> bytes, String filename, String contentType) async {
    final resp = await _api.uploadMessageAttachment(conversationId, bytes, filename, contentType);
    if (resp['success'] == true) {
      // The server will broadcast via sockets; ensure local state is refreshed
      await loadMessages(conversationId);
    }
    return resp;
  }

  Future<Conversation?> createConversation(String title, bool isGroup, List<String> members) async {
    try { await _api.loadAuthToken(); } catch (_) {}
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
              final w = prefs.getString('wallet_address') ?? prefs.getString('user_id') ?? '';
              if (w.isNotEmpty) _currentWallet = w.toString();
            } catch (e2) {
              debugPrint('createConversation: SharedPreferences fallback for wallet failed: $e2');
            }
            // If we still don't have a wallet and there IS a token, try resolving via getMyProfile
            if ((_api.getAuthToken() ?? '').isNotEmpty && (_currentWallet == null || _currentWallet!.isEmpty)) {
              try {
                final meResp = await _api.getMyProfile();
                if (meResp['success'] == true && meResp['data'] != null) {
                  final me = meResp['data'] as Map<String, dynamic>;
                  _currentWallet = (me['wallet_address'] ?? me['walletAddress'] ?? me['wallet'])?.toString();
                }
              } catch (e) {
                debugPrint('createConversation: getMyProfile failed while resolving wallet for conv list retry: $e');
              }
            }
          }

          if (_currentWallet != null && _currentWallet!.isNotEmpty) {
            final issued = await _api.issueTokenForWallet(_currentWallet!);
            if (issued) {
              try { await _api.loadAuthToken(); } catch (_) {}
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
            final cid = (item is Map<String, dynamic> ? (item['id'] ?? item['conversationId']) : null)?.toString();
            final isGroupFlag = (item is Map<String, dynamic>) ? ((item['isGroup'] ?? item['is_group'] ?? false) as bool) : false;
            if (cid == null || cid.isEmpty) continue;
            if (isGroupFlag == true) continue;

            final mresp = await _api.fetchConversationMembers(cid);
            if ((mresp['success'] == true) || (mresp['data'] != null)) {
              final list = (mresp['data'] ?? mresp['members'] ?? mresp['membersList']) as List<dynamic>?;
              if (list != null) {
                for (final m in list) {
                  try {
                    final wallet = ((m as Map<String, dynamic>)['wallet_address'] ?? m['wallet'] ?? m['walletAddress'] ?? m['id'])?.toString() ?? '';
                    if (wallet.isNotEmpty && wallet == target) {
                      // Found existing direct conversation — build Conversation from backend item
                      Conversation conv;
                      try {
                        conv = Conversation.fromJson(item as Map<String, dynamic>);
                      } catch (_) {
                        conv = Conversation(id: cid, title: (item['title'] ?? '')?.toString(), isGroup: false);
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
            debugPrint('createConversation: backend member check failed for conv item: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('createConversation: backend pre-check failed: $e');
    }

    var resp = await _api.createConversation(title: title, isGroup: isGroup, members: members);
    if (resp['success'] == true) {
      final conv = Conversation.fromJson(resp['data']);
      _conversations.insert(0, conv);
      _safeNotifyListeners(force: true);
      // Subscribe to the conversation room so we get real-time messages
      try { _socket.subscribeConversation(conv.id); } catch (e) { debugPrint('ChatProvider.createConversation: subscribeConversation failed: $e'); }
      // Optionally open conversation automatically
      try { await openConversation(conv.id); } catch (_) {}
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
            final w = prefs.getString('wallet_address') ?? prefs.getString('user_id') ?? '';
            if (w.isNotEmpty) { _currentWallet = w.toString(); }
          } catch (e) { debugPrint('createConversation: SharedPreferences wallet lookup failed: $e'); }
          // If we have a token and no wallet, try to call getMyProfile
          if ((_api.getAuthToken() ?? '').isNotEmpty && (_currentWallet == null || _currentWallet!.isEmpty)) {
            try {
              final meResp = await _api.getMyProfile();
              if (meResp['success'] == true && meResp['data'] != null) {
                final me = meResp['data'] as Map<String, dynamic>;
                _currentWallet = (me['wallet_address'] ?? me['walletAddress'] ?? me['wallet'])?.toString();
              }
            } catch (e) { debugPrint('createConversation: getMyProfile failed while resolving wallet for 401 retry: $e'); }
          }
        }

        if (_currentWallet != null && _currentWallet!.isNotEmpty) {
          final issued = await _api.issueTokenForWallet(_currentWallet!);
          if (issued) {
            try { await _api.loadAuthToken(); } catch (_) {}
            // Retry once
            resp = await _api.createConversation(title: title, isGroup: isGroup, members: members);
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

  Future<Map<String, dynamic>> uploadConversationAvatar(String conversationId, List<int> bytes, String filename, String contentType) async {
    final resp = await _api.uploadConversationAvatar(conversationId, bytes, filename, contentType);
    // If succeeded, refresh conversations
    if (resp['success'] == true) {
      await refreshConversations();
    }
    return resp;
  }

  /// Accepts either a wallet or a username. Tries to resolve username to wallet client-side for better UX.
  Future<void> addMember(String conversationId, String memberIdentifier) async {
    String memberWallet = memberIdentifier;
    try {
      if (!(memberIdentifier.startsWith('0x') && memberIdentifier.length >= 40)) {
        // Might be a username — resolve via UserService
        try {
          final user = await UserService.getUserByUsername(memberIdentifier);
          if (user != null && user.id.isNotEmpty) {
            memberWallet = user.id;
          }
        } catch (e) { debugPrint('ChatProvider.addMember: username resolution failed: $e'); }
      }
    } catch (_) {}
    await _api.addConversationMember(conversationId, memberWallet);
    await refreshConversations();
  }

  Future<void> removeMember(String conversationId, String memberIdentifier) async {
    // Try to resolve as username or wallet client-side. Backend supports accepting memberUsername/memberWallet
    var normalized = memberIdentifier;
    try {
      if (!(memberIdentifier.startsWith('0x') && memberIdentifier.length >= 40) && memberIdentifier.startsWith('@')) {
        normalized = memberIdentifier.replaceFirst('@', '');
      }
    } catch (_) {}
    await _api.removeConversationMember(conversationId, normalized);
    await refreshConversations();
  }

  Future<Map<String, dynamic>> transferOwnership(String conversationId, String newOwnerWallet) async {
    try {
      final resp = await _api.transferConversationOwner(conversationId, newOwnerWallet);
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
    try {
      if (wallet.isEmpty) return;
      if (_currentWallet == wallet) return;
      _currentWallet = wallet;
      debugPrint('ChatProvider.setCurrentWallet: wallet=$_currentWallet');
      // Ensure auth token is loaded/issued for this wallet
      try { await _api.ensureAuthLoaded(walletAddress: _currentWallet); } catch (e) { debugPrint('setCurrentWallet: ensureAuthLoaded failed: $e'); }
      // Subscribe socket to this user
      try {
        var ok = await _socket.connectAndSubscribe(_api.baseUrl, _currentWallet!);
        if (!ok) {
          try {
            final issued = await _api.issueTokenForWallet(_currentWallet!);
            if (issued) {
              await _api.loadAuthToken();
              ok = await _socket.connectAndSubscribe(_api.baseUrl, _currentWallet!);
            }
          } catch (_) {}
        }
        if (!ok) _socket.subscribeUser(_currentWallet!);
      } catch (e) {
        debugPrint('ChatProvider.setCurrentWallet: socket subscribe failed: $e');
        try { _socket.subscribeUser(_currentWallet!); } catch (_) {}
      }
      // Refresh conversations and messages for this wallet
      try {
        await refreshConversations();
      } catch (e) { debugPrint('ChatProvider.setCurrentWallet: refreshConversations failed: $e'); }
      // Notify UI immediately so badges reflect current state
      _safeNotifyListeners(force: true);
    } catch (e) {
      debugPrint('ChatProvider.setCurrentWallet error: $e');
    }
  }

  /// Open a conversation: subscribe to conversation room, load messages and mark read
  Future<void> openConversation(String conversationId) async {
    final nid = conversationId;
    _openConversationId = nid;
    try {
      _socket.subscribeConversation(nid);
    } catch (e) {
      debugPrint('ChatProvider.openConversation: subscribeConversation failed: $e');
    }
    try {
      await loadMessages(nid);
    } catch (e) {
      debugPrint('ChatProvider.openConversation: loadMessages failed: $e');
    }
    try {
      await markRead(nid);
    } catch (e) { debugPrint('ChatProvider.openConversation: markRead failed: $e'); }

    // Start periodic polling to keep the open conversation in sync in case socket events are missed
    try {
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          final resp = await _api.fetchMessages(nid);
          if (resp['success'] == true) {
            final items = (resp['data'] as List<dynamic>?) ?? [];
            final list = items.map((i) => ChatMessage.fromJson(i as Map<String, dynamic>)).toList();
            _messages[nid] = list;
            _safeNotifyListeners();
          }
        } catch (e) {
          debugPrint('ChatProvider: periodic fetchMessages failed for $nid: $e');
        }
      });
    } catch (e) {
      debugPrint('ChatProvider: Failed to start poll timer for conversation $nid: $e');
    }
  }

  /// Close an open conversation: unsubscribe from room and clear open state
  Future<void> closeConversation([String? conversationId]) async {
    final nid = (conversationId ?? _openConversationId);
    if (nid == null) { return; }
    try {
      _socket.leaveConversation(nid);
    } catch (e) { debugPrint('ChatProvider.closeConversation: leaveConversation failed: $e'); }
    if (_openConversationId != null && (_openConversationId! == nid)) _openConversationId = null;
    try { _pollTimer?.cancel(); _pollTimer = null; } catch (_) {}
  }

  /// Mark an individual message as read by the current user
  Future<void> markMessageRead(String conversationId, String messageId) async {
    try {
      await _api.markMessageRead(conversationId, messageId);
      final list = _messages[conversationId];
      if (list != null) {
        for (var i = 0; i < list.length; i++) {
          final m = list[i];
          if (m.id == messageId) {
            final updatedMsg = ChatMessage(
              id: m.id,
              conversationId: m.conversationId,
              senderWallet: m.senderWallet,
              message: m.message,
              data: m.data == null ? <String, dynamic>{} : Map<String, dynamic>.from(m.data!),
              readersCount: m.readersCount, // server will emit msg-read to increment
              readByCurrent: true,
              createdAt: m.createdAt,
            );
            _messages[conversationId]![i] = updatedMsg;
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
        final existingReaders = m.readers.map((e) => Map<String, dynamic>.from(e)).toList();
        final readerWallet = _currentWallet ?? '';
        if (readerWallet.isNotEmpty && !existingReaders.any((r) => (r['wallet_address'] ?? r['wallet']) == readerWallet)) {
          existingReaders.add({'wallet_address': readerWallet, 'read_at': DateTime.now().toIso8601String()});
        }
        final updatedMsg = ChatMessage(
          id: m.id,
          conversationId: m.conversationId,
          senderWallet: m.senderWallet,
          message: m.message,
          data: m.data == null ? <String, dynamic>{} : Map<String, dynamic>.from(m.data!),
          readersCount: m.readersCount + 1,
          readByCurrent: true,
          readers: existingReaders,
          createdAt: m.createdAt,
        );
        _messages[nid]![i] = updatedMsg;
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
    // No cache listener to remove (we avoid using the UserService cache notification system to prevent loops)
    try { _socket.removeMessageListener(_onMessageReceived); } catch (_) {}
    try { _socket.removeMessageReadListener(_onMessageRead); } catch (_) {}
    try { _socket.removeConversationListener(_onNewConversation); } catch (_) {}
    try { _socket.removeConversationListener(_onMembersUpdated); } catch (_) {}
    try { closeConversation(); } catch (_) {}
    super.dispose();
  }
}
