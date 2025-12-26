import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'backend_api_service.dart';
// wallet_utils is intentionally not used here because the server now expects
// canonical wallet casing when subscribing to user rooms. Keep the import
// commented for reference.
// import '../utils/wallet_utils.dart';

typedef NotificationCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _socketBaseUrl;
  String? _socketAuthToken;
  Completer<bool>? _connectCompleter;
  final List<NotificationCallback> _notificationListeners = [];
  final List<NotificationCallback> _messageListeners = [];
  final List<NotificationCallback> _messageReadListeners = [];
  final List<NotificationCallback> _conversationListeners = [];
  final List<VoidCallback> _connectListeners = [];
  final List<NotificationCallback> _markerListeners = [];
  // Stream controllers for consumers that prefer Streams
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageReadController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _conversationMemberReadController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _postController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _markerController = StreamController<Map<String, dynamic>>.broadcast();
  final List<NotificationCallback> _postListeners = [];
  String? _currentSubscribedWallet;
  final Set<String> _subscribedConversations = {};
  bool _notificationHandlerRegistered = false;
  final List<NotificationCallback> _messageReactionListeners = [];

  void _log(String msg) {
    if (!kDebugMode) return;
    try {
      debugPrint('SocketService: ${DateTime.now().toIso8601String()} - $msg');
    } catch (_) {}
  }

  void _logEventDetails(String eventName, Map<String, dynamic> payload) {
    // Simplified logging for production
    final messageId = payload['message_id'] ?? payload['messageId'] ?? '';
    final wallet = payload['wallet'] ?? payload['reader'] ?? '';
    final conversationId = payload['conversation_id'] ?? payload['conversationId'] ?? '';
    _log('$eventName -> msg=$messageId, wallet=$wallet, conv=$conversationId');
  }

  /// Add a listener for incoming notifications. Multiple listeners are supported.
  void addNotificationListener(NotificationCallback cb) {
    if (!_notificationListeners.contains(cb)) _notificationListeners.add(cb);
    _log('addNotificationListener: total=${_notificationListeners.length}');
  }

  /// Remove a previously added listener.
  void removeNotificationListener(NotificationCallback cb) {
    _notificationListeners.remove(cb);
    _log('removeNotificationListener: total=${_notificationListeners.length}');
  }

  void addMessageListener(NotificationCallback cb) {
    if (!_messageListeners.contains(cb)) _messageListeners.add(cb);
    _log('addMessageListener: total=${_messageListeners.length}');
  }

  void addMessageReadListener(NotificationCallback cb) {
    if (!_messageReadListeners.contains(cb)) _messageReadListeners.add(cb);
    _log('addMessageReadListener: total=${_messageReadListeners.length}');
  }

  void removeMessageListener(NotificationCallback cb) {
    _messageListeners.remove(cb);
    _log('removeMessageListener: total=${_messageListeners.length}');
  }

  void removeMessageReadListener(NotificationCallback cb) {
    _messageReadListeners.remove(cb);
    _log('removeMessageReadListener: total=${_messageReadListeners.length}');
  }

  void addConversationListener(NotificationCallback cb) {
    if (!_conversationListeners.contains(cb)) _conversationListeners.add(cb);
    _log('addConversationListener: total=${_conversationListeners.length}');
  }

  void removeConversationListener(NotificationCallback cb) {
    _conversationListeners.remove(cb);
    _log('removeConversationListener: total=${_conversationListeners.length}');
  }

  void addMessageReactionListener(NotificationCallback cb) {
    if (!_messageReactionListeners.contains(cb)) _messageReactionListeners.add(cb);
    _log('addMessageReactionListener: total=${_messageReactionListeners.length}');
  }

  void removeMessageReactionListener(NotificationCallback cb) {
    _messageReactionListeners.remove(cb);
    _log('removeMessageReactionListener: total=${_messageReactionListeners.length}');
  }

  /// Connects socket to backend. If `baseUrl` is null uses `BackendApiService().baseUrl`.
  /// Returns true when connected, false on error/timeout.
  Future<bool> connect([String? baseUrl]) async {
    final api = BackendApiService();

    // Ensure auth token is loaded so we can supply it to the socket handshake.
    try {
      await api.ensureAuthLoaded();
    } catch (e) {
      _log('ensureAuthLoaded failed: $e');
    }

    final resolvedBase = (baseUrl ?? api.baseUrl).replaceAll(RegExp(r'/+$'), '');

    final nextToken = (api.getAuthToken() ?? '').trim();
    final currentToken = (_socketAuthToken ?? '').trim();

    // If auth token changes (login/logout) we must recreate the socket so the
    // handshake includes the new token. This prevents "anonymous socket" state
    // where presence/chat subscriptions silently fail until app restart.
    if (_socket != null && nextToken != currentToken) {
      disconnect();
    }

    // If the target base URL changes, reset the socket instance.
    if (_socket != null && _socketBaseUrl != null && _socketBaseUrl != resolvedBase) {
      disconnect();
    }

    if (_socket != null && _socket!.connected) return true;

    // Reuse an in-flight connect attempt.
    if (_connectCompleter != null) {
      return _connectCompleter!.future
          .timeout(const Duration(seconds: 6), onTimeout: () => false);
    }

    if (_socket == null) {
      final token = (api.getAuthToken() ?? '').trim();
      _socketAuthToken = token.isNotEmpty ? token : null;
      final options = <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'auth': token.isNotEmpty ? {'token': token} : {},
        'extraHeaders': token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {},
      };

      _socketBaseUrl = resolvedBase;
      _socket = io.io(resolvedBase, options);

      // Register all event handlers once per socket instance.
      _notificationHandlerRegistered = false;
      _registerAllHandlers();

      _socket!.onConnect((_) {
        _log('Connected');
        // Re-subscribe if we had a previous wallet.
        if (_currentSubscribedWallet != null) {
          _resubscribe(_currentSubscribedWallet!);
        }
        // Notify connect listeners so UI can refresh data.
        for (final cb in _connectListeners) {
          try {
            cb();
          } catch (e) {
            _log('connect listener error: $e');
          }
        }
        final c = _connectCompleter;
        if (c != null && !c.isCompleted) c.complete(true);
        _connectCompleter = null;
      });

      _socket!.onDisconnect((_) {
        _log('Disconnected');
        final c = _connectCompleter;
        if (c != null && !c.isCompleted) c.complete(false);
        _connectCompleter = null;
      });

      // Fail fast on connection errors.
      _socket!.on('connect_error', (err) {
        _log('connect_error: $err');
        final c = _connectCompleter;
        if (c != null && !c.isCompleted) c.complete(false);
        _connectCompleter = null;
      });
    }

    _connectCompleter = Completer<bool>();

    // Start connection.
    try {
      _socket!.connect();
    } catch (e) {
      _log('connect() error: $e');
      final c = _connectCompleter;
      if (c != null && !c.isCompleted) c.complete(false);
      _connectCompleter = null;
      return false;
    }

    // Wait up to 6 seconds for connect.
    return _connectCompleter!.future
        .timeout(const Duration(seconds: 6), onTimeout: () => false);
  }

  // Stream getters for consumers
  Stream<Map<String, dynamic>> get onMessageReceived => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadController.stream;
  Stream<Map<String, dynamic>> get onConversationMemberRead => _conversationMemberReadController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onPostCreated => _postController.stream;
  Stream<Map<String, dynamic>> get onMarkerCreated => _markerController.stream;

  void addPostListener(NotificationCallback cb) {
    if (!_postListeners.contains(cb)) _postListeners.add(cb);
    _log('addPostListener: total=${_postListeners.length}');
  }

  void removePostListener(NotificationCallback cb) {
    _postListeners.remove(cb);
    _log('removePostListener: total=${_postListeners.length}');
  }

  void addMarkerListener(NotificationCallback cb) {
    if (!_markerListeners.contains(cb)) _markerListeners.add(cb);
    _log('addMarkerListener: total=${_markerListeners.length}');
  }

  void removeMarkerListener(NotificationCallback cb) {
    _markerListeners.remove(cb);
    _log('removeMarkerListener: total=${_markerListeners.length}');
  }

  /// Connects and attempts to subscribe, resolving when subscription is confirmed or rejects on timeout/error
  Future<bool> connectAndSubscribe(String baseUrl, String walletAddress, {Duration timeout = const Duration(seconds: 6)}) async {
    try {
      // Ensure socket is connected before attempting subscription
      final connected = await connect(baseUrl);
      if (!connected) return false;

      final expectedRoom = 'user:${walletAddress.toString()}';
      final completer = Completer<bool>();

      void handleOk(dynamic payload) {
        try {
          if (payload is Map<String, dynamic> && payload['room'] != null) {
            final room = payload['room'].toString();
            if (room == expectedRoom) {
              if (!completer.isCompleted) completer.complete(true);
            } else {
              // Not the ack we're waiting for - ignore
              _log('connectAndSubscribe: ignoring subscribe:ok for room=$room expected=$expectedRoom');
            }
          } else {
            // Fallback: if payload is a string or has no room, accept as generic ack
            if (!completer.isCompleted) completer.complete(true);
          }
        } catch (e) {
          if (!completer.isCompleted) completer.complete(false);
        }
      }

      void handleErr(dynamic payload) {
        try {
          _log('connectAndSubscribe: subscribe:error payload=$payload');
        } catch (_) {}
        if (!completer.isCompleted) completer.complete(false);
      }

      _socket!.once('subscribe:ok', handleOk);
      _socket!.once('subscribe:error', handleErr);
      // Request subscription; subscribeUser registers its own handlers too
      subscribeUser(walletAddress);

      return await completer.future.timeout(timeout, onTimeout: () => false);
    } catch (e) {
      _log('connectAndSubscribe error: $e');
      return false;
    }
  }

  void addConnectListener(VoidCallback cb) {
    if (!_connectListeners.contains(cb)) _connectListeners.add(cb);
    _log('addConnectListener: total=${_connectListeners.length}');
  }

  void removeConnectListener(VoidCallback cb) {
    _connectListeners.remove(cb);
    _log('removeConnectListener: total=${_connectListeners.length}');
  }

  /// Subscribe to personal user room. Requires server validation with JWT.
  /// Will auto-connect if needed and avoid duplicate subscriptions.
  void subscribeUser(String walletAddress) {
    final roomWallet = walletAddress.toString();
    if (roomWallet.isEmpty) return;

    final previouslySubscribed = _currentSubscribedWallet;
    final socketReady = _socket != null && _socket!.connected;

    if (!socketReady) {
      _currentSubscribedWallet = roomWallet;
      _log('subscribeUser queued until socket connects');
      unawaited(connect());
      return;
    }

    // Prevent duplicate subscriptions (compare canonical strings)
    if (previouslySubscribed == roomWallet) {
      _log('Already subscribed to $walletAddress');
      return;
    }

    // Unsubscribe from previous wallet if any (use stored canonical value)
    if (previouslySubscribed != null && previouslySubscribed.isNotEmpty) {
      _socket!.emit('unsubscribe:user', previouslySubscribed);
    }

    _currentSubscribedWallet = roomWallet;
    // Emit the wallet room using canonical casing
    _socket!.emit('subscribe:user', _currentSubscribedWallet);
    _log('emitted subscribe:user for $_currentSubscribedWallet');
    bool awaitingAck = true; // ignore: unused_local_variable

    // Register handlers only once
    void onSubscribeOk(dynamic payload) {
      _log('subscribe:ok for $walletAddress (room: user:$_currentSubscribedWallet)');
      awaitingAck = false;
    }

    void onSubscribeError(dynamic payload) {
      _log('subscribe:error for $walletAddress: $payload');
      _currentSubscribedWallet = null;
      awaitingAck = false;
    }

    _socket!.once('subscribe:ok', onSubscribeOk);
    _socket!.once('subscribe:error', onSubscribeError);
  }

  void _registerAllHandlers() {
    if (_socket == null) return;
    if (_notificationHandlerRegistered) return;
    _notificationHandlerRegistered = true;
    
    // Helper to normalize incoming payloads which may be a Map, JSON string, or a List
    Map<String, dynamic>? mapFromPayload(dynamic data) {
      try {
        if (data == null) return null;
        if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
        if (data is String) {
          try {
            final parsed = json.decode(data);
            if (parsed is Map<String, dynamic>) return Map<String, dynamic>.from(parsed);
            if (parsed is List && parsed.isNotEmpty && parsed.first is Map) return Map<String, dynamic>.from(parsed.first as Map);
          } catch (_) {
            // not JSON, ignore
          }
        }
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) return Map<String, dynamic>.from(first);
          if (first is String) {
            try {
              final parsed = json.decode(first);
              if (parsed is Map<String, dynamic>) return Map<String, dynamic>.from(parsed);
            } catch (_) {}
          }
        }
      } catch (_) {}
      return null;
    }

    _socket!.on('notification:new', (data) {
      try {
        _log('Received notification:new');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _log('notification:new -> listeners=${_notificationListeners.length}');
          for (final l in _notificationListeners) {
            try {
              l(mapped);
            } catch (e) {
              _log('notification:new listener error: $e');
            }
          }
          try { _notificationController.add(mapped); _log('notification:new -> controller.added'); } catch (e) { _log('notification controller add error: $e'); }
        } else {
          _log('chat:new-message -> could not map payload, sending raw wrapper to listeners');
          final rawMap = {'raw': data};
          for (final l in _messageListeners) {
            try { l(rawMap); } catch (e) { _log('chat:new-message fallback listener error: $e'); }
          }
          try { _messageController.add(rawMap); _log('chat:new-message -> controller.added (raw)'); } catch (e) { _log('message controller add error: $e'); }
        }
      } catch (e) {
        _log('notification:new handler error: $e');
      }
    });

    _socket!.on('chat:conversation-updated', (data) {
      try {
        _log('Received chat:conversation-updated');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          for (final l in _conversationListeners) {
            try {
              l(mapped);
            } catch (e) {
              _log('chat:conversation-updated listener error: $e');
            }
          }
        }
      } catch (e) {
        _log('chat:conversation-updated handler error: $e');
      }
    });

    _socket!.on('art-marker:created', (data) {
      try {
        _log('Received art-marker:created');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _log('art-marker:created -> listeners=${_markerListeners.length}');
          for (final l in _markerListeners) {
            try { l(mapped); } catch (e) { _log('marker listener error: $e'); }
          }
          try { _markerController.add(mapped); _log('art-marker:created -> controller.added'); } catch (e) { _log('marker controller add error: $e'); }
        }
      } catch (e) { _log('art-marker:created handler error: $e'); }
    });
    // Feed updates: new posts or reposts
    _socket!.on('community:new_post', (data) {
      try {
        _log('Received community:new_post');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          for (final l in _postListeners) {
            try { l(mapped); } catch (e) { _log('post listener error: $e'); }
          }
          try { _postController.add(mapped); _log('community:new_post -> controller.added'); } catch (e) { _log('post controller add error: $e'); }
        }
      } catch (e) {
        _log('community:new_post handler error: $e');
      }
    });
    // Also handle read-all events
    _socket!.on('notification:read-all', (data) {
      try {
        final mapped = (data is Map<String, dynamic>) ? Map<String, dynamic>.from(data) : {'type': 'read-all', 'data': data};
        _log('notification:read-all -> listeners=${_notificationListeners.length}');
        for (final l in _notificationListeners) {
          try { l(mapped); } catch (e) { _log('ReadAll listener error: $e'); }
        }
      } catch (e) {
        _log('notification:read-all handler error: $e');
      }
    });
    
    // Message & conversation handlers
    _socket!.on('chat:new-message', (data) {
      try {
        _log('Received chat:new-message');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _log('chat:new-message -> listeners=${_messageListeners.length}');
          for (final l in _messageListeners) {
            try { l(mapped); } catch (e) { _log('chat:new-message listener error: $e'); }
          }
          try { _messageController.add(mapped); _log('chat:new-message -> controller.added'); } catch (e) { _log('message controller add error: $e'); }
        } else {
          _log('chat:message-read -> could not map payload, sending raw wrapper to listeners');
          final rawMap = {'raw': data};
          for (final l in _messageReadListeners) {
            try { l(rawMap); } catch (e) { _log('chat:message-read fallback listener error: $e'); }
          }
          try { _messageReadController.add(rawMap); _log('chat:message-read -> controller.added (raw)'); } catch (e) { _log('messageRead controller add error: $e'); }
        }
      } catch (e) { _log('chat:new-message handler error: $e'); }
    });

    _socket!.on('chat:message-read', (data) {
      try {
        _log('Received chat:message-read');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _log('chat:message-read -> listeners=${_messageReadListeners.length}');
          for (final l in _messageReadListeners) {
            try { l(mapped); } catch (e) { _log('chat:message-read listener error: $e'); }
          }
          try { _messageReadController.add(mapped); _log('chat:message-read -> controller.added'); } catch (e) { _log('messageRead controller add error: $e'); }
        } else {
          _log('chat:new-conversation -> could not map payload, sending raw wrapper to listeners');
          final rawMap = {'raw': data};
          for (final l in _conversationListeners) {
            try { l(rawMap); } catch (e) { _log('chat:new-conversation fallback listener error: $e'); }
          }
        }
      } catch (e) { _log('chat:message-read handler error: $e'); }
    });

    _socket!.on('chat:new-conversation', (data) {
      try {
        _log('Received chat:new-conversation');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _log('chat:new-conversation -> listeners=${_conversationListeners.length}');
          for (final l in _conversationListeners) {
            try { l(mapped); } catch (e) { _log('chat:new-conversation listener error: $e'); }
          }
        } else {
          _log('chat:members-updated -> could not map payload, sending raw wrapper to listeners');
          final rawMap = {'raw': data};
          for (final l in _conversationListeners) {
            try { l(rawMap); } catch (e) { _log('chat:members-updated fallback listener error: $e'); }
          }
          try { _conversationMemberReadController.add(rawMap); _log('chat:members-updated -> controller.added (raw)'); } catch (e) { _log('conversationMember controller add error: $e'); }
        }
      } catch (e) { _log('chat:new-conversation handler error: $e'); }
    });

    _socket!.on('chat:members-updated', (data) {
      try {
        _log('Received chat:members-updated');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _log('chat:members-updated -> listeners=${_conversationListeners.length}');
          for (final l in _conversationListeners) {
            try { l(mapped); } catch (e) { _log('chat:members-updated listener error: $e'); }
          }
          try { _conversationMemberReadController.add(mapped); _log('chat:members-updated -> controller.added'); } catch (e) { _log('conversationMember controller add error: $e'); }
        } else {
          _log('message:received -> could not map payload, sending raw wrapper to listeners');
          final rawMap = {'raw': data};
          for (final l in _messageListeners) {
            try { l(rawMap); } catch (e) { _log('message:received fallback listener error: $e'); }
          }
          try { _messageController.add(rawMap); _log('message:received -> controller.added (raw)'); } catch (e) { _log('message controller add error: $e'); }
        }
      } catch (e) { _log('chat:members-updated handler error: $e'); }
    });

    // Also accept server event names used elsewhere to maximize compatibility
    _socket!.on('message:received', (data) {
      try {
        _log('Received message:received');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _log('message:received -> listeners=${_messageListeners.length}');
          for (final l in _messageListeners) {
            try { l(mapped); } catch (e) { _log('message:received listener error: $e'); }
          }
          try { _messageController.add(mapped); _log('message:received -> controller.added'); } catch (e) { _log('message controller add error: $e'); }
        } else {
          _log('message:read -> could not map payload, sending raw wrapper to listeners');
          final rawMap = {'raw': data};
          _logEventDetails('message:read', rawMap);
          for (final l in _messageReadListeners) {
            try { l(rawMap); } catch (e) { _log('message:read fallback listener error: $e'); }
          }
          try { _messageReadController.add(rawMap); _log('message:read -> controller.added (raw)'); } catch (e) { _log('messageRead controller add error: $e'); }
        }
      } catch (e) { _log('message:received handler error: $e'); }
    });

    _socket!.on('message:read', (data) {
      try {
        _log('Received message:read');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _logEventDetails('message:read', mapped);
          _log('message:read -> listeners=${_messageReadListeners.length}');
          for (final l in _messageReadListeners) {
            try { l(mapped); } catch (e) { _log('message:read listener error: $e'); }
          }
          try { _messageReadController.add(mapped); _log('message:read -> controller.added'); } catch (e) { _log('messageRead controller add error: $e'); }
        } else {
          _log('conversation:member:read -> could not map payload, sending raw wrapper to listeners');
          final rawMap = {'raw': data};
          _logEventDetails('conversation:member:read', rawMap);
          for (final l in _conversationListeners) {
            try { l(rawMap); } catch (e) { _log('conversation:member:read fallback listener error: $e'); }
          }
          try { _conversationMemberReadController.add(rawMap); _log('conversation:member:read -> controller.added (raw)'); } catch (e) { _log('conversationMember controller add error: $e'); }
        }
      } catch (e) { _log('message:read handler error: $e'); }
    });

    _socket!.on('conversation:member:read', (data) {
      try {
        _log('Received conversation:member:read');
        final mapped = mapFromPayload(data);
        if (mapped != null) {
          _logEventDetails('conversation:member:read', mapped);
          _log('conversation:member:read -> listeners=${_conversationListeners.length}');
          for (final l in _conversationListeners) {
            try { l(mapped); } catch (e) { _log('conversation:member:read listener error: $e'); }
          }
          try { _conversationMemberReadController.add(mapped); _log('conversation:member:read -> controller.added'); } catch (e) { _log('conversationMember controller add error: $e'); }
        }
      } catch (e) { _log('conversation:member:read handler error: $e'); }
    });

    _socket!.on('message:reaction', (data) {
      try {
        _log('Received message:reaction');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('message:reaction -> listeners=${_messageReactionListeners.length}');
          for (final l in _messageReactionListeners) {
            try { l(mapped); } catch (e) { _log('message:reaction listener error: $e'); }
          }
        }
      } catch (e) { _log('message:reaction handler error: $e'); }
    });

    _socket!.on('chat:conversation-renamed', (data) {
      try {
        _log('Received chat:conversation-renamed');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('chat:conversation-renamed -> listeners=${_conversationListeners.length}');
          for (final l in _conversationListeners) {
            try { l(mapped); } catch (e) { _log('conversation-renamed listener error: $e'); }
          }
        }
      } catch (e) { _log('chat:conversation-renamed handler error: $e'); }
    });
  }

  // Handled inline in _registerNotificationHandler

  void _resubscribe(String walletAddress) {
    _log('Re-subscribing to $walletAddress after reconnect');
    _currentSubscribedWallet = null; // Reset to allow resubscription
    subscribeUser(walletAddress);
  }

  void unsubscribeUser(String walletAddress) {
    if (_socket == null) return;
    final roomWallet = walletAddress.toString();
    _socket!.emit('unsubscribe:user', roomWallet);
    if (_currentSubscribedWallet == roomWallet) {
      _currentSubscribedWallet = null;
    }
  }

  /// Subscribe to a conversation room so the client receives message/read/member events
  Future<bool> subscribeConversation(String conversationId, {Duration timeout = const Duration(seconds: 6)}) async {
    // Async subscription with acknowledgement
    if (_socket == null || !_socket!.connected) {
      _log('Cannot subscribe to conversation - socket not connected');
      return false;
    }

    final nid = conversationId;
    if (_subscribedConversations.contains(nid)) {
      _log('Already subscribed to conversation $nid');
      return false;
    }
    _socket!.emit('subscribe:conversation', nid);
    final completer = Completer<bool>();

    _socket!.once('subscribe:ok', (payload) {
      try {
        if (payload is Map<String, dynamic> && payload['room'] != null) {
          final room = payload['room'].toString();
          if (room == 'conversation:$nid') {
            if (!completer.isCompleted) completer.complete(true);
          } else {
            _log('subscribeConversation: ignoring subscribe:ok for room=$room expected=conversation:$nid');
          }
        } else {
          if (!completer.isCompleted) completer.complete(true);
        }
      } catch (e) {
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    _socket!.once('subscribe:error', (payload) {
      try { _log('subscribeConversation: subscribe:error payload=$payload'); } catch (_) {}
      if (!completer.isCompleted) completer.complete(false);
    });

    // Wait for acknowledgement or timeout
    final ok = await completer.future.timeout(timeout, onTimeout: () => false);
    if (ok == true) {
      _subscribedConversations.add(nid);
      return true;
    }
    return false;
  }

  /// Leave a previously subscribed conversation room
  void leaveConversation(String conversationId) {
    if (_socket == null) return;
    final nid = conversationId;
    if (!_subscribedConversations.contains(nid)) return;
    _socket!.emit('leave:conversation', nid);
    _subscribedConversations.remove(nid);
    _log('left conversation $nid');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _socketBaseUrl = null;
    _socketAuthToken = null;
    _currentSubscribedWallet = null;
    _notificationHandlerRegistered = false;
    _connectCompleter = null;
  }

  bool get isConnected => _socket?.connected ?? false;

  /// Returns the wallet address the socket is currently subscribed to (user room), or null.
  String? get currentSubscribedWallet => _currentSubscribedWallet;
}
