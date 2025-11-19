import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'dart:async';
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

  IO.Socket? _socket;
  final List<NotificationCallback> _notificationListeners = [];
  final List<NotificationCallback> _messageListeners = [];
  final List<NotificationCallback> _messageReadListeners = [];
  final List<NotificationCallback> _conversationListeners = [];
  final List<VoidCallback> _connectListeners = [];
  // Stream controllers for consumers that prefer Streams
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageReadController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _conversationMemberReadController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  String? _currentSubscribedWallet;
  final Set<String> _subscribedConversations = {};
  bool _notificationHandlerRegistered = false;
  final List<NotificationCallback> _messageReactionListeners = [];

  void _log(String msg) {
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
    try {
      final api = BackendApiService();
      final resolvedBase = (baseUrl ?? api.baseUrl).replaceAll(RegExp(r'/+$'), '');
      if (_socket != null && _socket!.connected) return true;

      final token = api.getAuthToken();

      final options = <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'auth': token != null ? {'token': token} : {},
        'extraHeaders': token != null ? {'Authorization': 'Bearer $token'} : {},
      };

      _socket = IO.io(resolvedBase, options);

      final completer = Completer<bool>();

      _socket!.onConnect((_) {
        debugPrint('SocketService: Connected');
        // Re-subscribe if we had a previous wallet
        if (_currentSubscribedWallet != null) {
          _resubscribe(_currentSubscribedWallet!);
        }
        // Notify connect listeners so UI can refresh data
        for (final cb in _connectListeners) {
          try { cb(); } catch (e) { debugPrint('SocketService: connect listener error: $e'); }
        }
        if (!completer.isCompleted) completer.complete(true);
      });
    _socket!.on('chat:conversation-updated', (data) {
      try {
        debugPrint('SocketService: Received chat:conversation-updated: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          for (final l in _conversationListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: chat:conversation-updated listener error: $e'); }
          }
        }
      } catch (e) { debugPrint('SocketService: chat:conversation-updated handler error: $e'); }
    });

    _socket!.onDisconnect((_) {
      debugPrint('SocketService: Disconnected');
      _notificationHandlerRegistered = false;
    });

      // start connection
    try {
      _socket!.connect();
    } catch (e) {
      debugPrint('SocketService: connect() error: $e');
    }

    // wait up to 6 seconds for connect
    return await completer.future.timeout(const Duration(seconds: 6), onTimeout: () => false);
    } catch (e) {
      debugPrint('SocketService.connect failed: $e');
      return false;
    }
  }

  // Stream getters for consumers
  Stream<Map<String, dynamic>> get onMessageReceived => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadController.stream;
  Stream<Map<String, dynamic>> get onConversationMemberRead => _conversationMemberReadController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;

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
            if (room == expectedRoom || room.toLowerCase() == expectedRoom.toLowerCase()) {
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
      debugPrint('SocketService.connectAndSubscribe error: $e');
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
  /// Only subscribes if not already subscribed to this wallet.
  void subscribeUser(String walletAddress) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('SocketService: Cannot subscribe - socket not connected');
      return;
    }

    final roomWallet = walletAddress.toString();
    // Prevent duplicate subscriptions (compare canonical strings)
    if (_currentSubscribedWallet == roomWallet) {
      debugPrint('SocketService: Already subscribed to $walletAddress');
      return;
    }

    // Unsubscribe from previous wallet if any (use stored canonical value)
    if (_currentSubscribedWallet != null) {
      _socket!.emit('unsubscribe:user', _currentSubscribedWallet);
    }

    _currentSubscribedWallet = roomWallet;
    // Emit the wallet room using canonical casing
    _socket!.emit('subscribe:user', _currentSubscribedWallet);

    // Register handlers only once
    void onSubscribeOk(dynamic payload) {
      debugPrint('SocketService: subscribe:ok for $walletAddress (room: user:$_currentSubscribedWallet)');
      _registerNotificationHandler();
    }

    void onSubscribeError(dynamic payload) {
      debugPrint('SocketService: subscribe:error for $walletAddress: $payload');
      _currentSubscribedWallet = null;
    }

    _socket!.once('subscribe:ok', onSubscribeOk);
    _socket!.once('subscribe:error', onSubscribeError);
  }

  void _registerNotificationHandler() {
    if (_notificationHandlerRegistered) return;
    
    _socket!.on('notification:new', (data) {
      try {
        debugPrint('SocketService: Received notification:new: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('notification:new -> listeners=${_notificationListeners.length}');
          for (final l in _notificationListeners) {
            try {
              l(mapped);
            } catch (e) {
              debugPrint('SocketService: Listener error: $e');
            }
          }
          try { _notificationController.add(mapped); _log('notification:new -> controller.added'); } catch (e) { debugPrint('SocketService: notification controller add error: $e'); }
        }
      } catch (e) {
        debugPrint('SocketService: notification:new handler error: $e');
      }
    });
    // Also handle read-all events
    _socket!.on('notification:read-all', (data) {
      try {
        final mapped = (data is Map<String, dynamic>) ? Map<String, dynamic>.from(data) : {'type': 'read-all', 'data': data};
        _log('notification:read-all -> listeners=${_notificationListeners.length}');
        for (final l in _notificationListeners) {
          try { l(mapped); } catch (e) { debugPrint('SocketService: ReadAll listener error: $e'); }
        }
      } catch (e) {
        debugPrint('SocketService: notification:read-all handler error: $e');
      }
    });
    
    _notificationHandlerRegistered = true;
    // Message & conversation handlers
    _socket!.on('chat:new-message', (data) {
      try {
        debugPrint('SocketService: Received chat:new-message: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('chat:new-message -> listeners=${_messageListeners.length}');
          for (final l in _messageListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: chat:new-message listener error: $e'); }
          }
          try { _messageController.add(mapped); _log('chat:new-message -> controller.added'); } catch (e) { debugPrint('SocketService: message controller add error: $e'); }
        }
      } catch (e) { debugPrint('SocketService: chat:new-message handler error: $e'); }
    });

    _socket!.on('chat:message-read', (data) {
      try {
        debugPrint('SocketService: Received chat:message-read: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('chat:message-read -> listeners=${_messageReadListeners.length}');
          for (final l in _messageReadListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: chat:message-read listener error: $e'); }
          }
          try { _messageReadController.add(mapped); _log('chat:message-read -> controller.added'); } catch (e) { debugPrint('SocketService: messageRead controller add error: $e'); }
        }
      } catch (e) { debugPrint('SocketService: chat:message-read handler error: $e'); }
    });

    _socket!.on('chat:new-conversation', (data) {
      try {
        debugPrint('SocketService: Received chat:new-conversation: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('chat:new-conversation -> listeners=${_conversationListeners.length}');
          for (final l in _conversationListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: chat:new-conversation listener error: $e'); }
          }
        }
      } catch (e) { debugPrint('SocketService: chat:new-conversation handler error: $e'); }
    });

    _socket!.on('chat:members-updated', (data) {
      try {
        debugPrint('SocketService: Received chat:members-updated: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('chat:members-updated -> listeners=${_conversationListeners.length}');
          for (final l in _conversationListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: chat:members-updated listener error: $e'); }
          }
          try { _conversationMemberReadController.add(mapped); _log('chat:members-updated -> controller.added'); } catch (e) { debugPrint('SocketService: conversationMember controller add error: $e'); }
        }
      } catch (e) { debugPrint('SocketService: chat:members-updated handler error: $e'); }
    });

    // Also accept server event names used elsewhere to maximize compatibility
    _socket!.on('message:received', (data) {
      try {
        debugPrint('SocketService: Received message:received: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('message:received -> listeners=${_messageListeners.length}');
          for (final l in _messageListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: message:received listener error: $e'); }
          }
          try { _messageController.add(mapped); _log('message:received -> controller.added'); } catch (e) { debugPrint('SocketService: message controller add error: $e'); }
        }
      } catch (e) { debugPrint('SocketService: message:received handler error: $e'); }
    });

    _socket!.on('message:read', (data) {
      try {
        debugPrint('SocketService: Received message:read: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _logEventDetails('message:read', mapped);
          _log('message:read -> listeners=${_messageReadListeners.length}');
          for (final l in _messageReadListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: message:read listener error: $e'); }
          }
          try { _messageReadController.add(mapped); _log('message:read -> controller.added'); } catch (e) { debugPrint('SocketService: messageRead controller add error: $e'); }
        }
      } catch (e) { debugPrint('SocketService: message:read handler error: $e'); }
    });

    _socket!.on('conversation:member:read', (data) {
      try {
        debugPrint('SocketService: Received conversation:member:read: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _logEventDetails('conversation:member:read', mapped);
          _log('conversation:member:read -> listeners=${_conversationListeners.length}');
          for (final l in _conversationListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: conversation:member:read listener error: $e'); }
          }
          try { _conversationMemberReadController.add(mapped); _log('conversation:member:read -> controller.added'); } catch (e) { debugPrint('SocketService: conversationMember controller add error: $e'); }
        }
      } catch (e) { debugPrint('SocketService: conversation:member:read handler error: $e'); }
    });

    _socket!.on('message:reaction', (data) {
      try {
        debugPrint('SocketService: Received message:reaction: $data');
        if (data is Map<String, dynamic>) {
          final mapped = Map<String, dynamic>.from(data);
          _log('message:reaction -> listeners=${_messageReactionListeners.length}');
          for (final l in _messageReactionListeners) {
            try { l(mapped); } catch (e) { debugPrint('SocketService: message:reaction listener error: $e'); }
          }
        }
      } catch (e) { debugPrint('SocketService: message:reaction handler error: $e'); }
    });
  }

  // Handled inline in _registerNotificationHandler

  void _resubscribe(String walletAddress) {
    debugPrint('SocketService: Re-subscribing to $walletAddress after reconnect');
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
      debugPrint('SocketService: Cannot subscribe to conversation - socket not connected');
      return false;
    }

    final nid = conversationId;
    if (_subscribedConversations.contains(nid)) {
      debugPrint('SocketService: Already subscribed to conversation $nid');
      return false;
    }
    _socket!.emit('subscribe:conversation', nid);
    final completer = Completer<bool>();

    _socket!.once('subscribe:ok', (payload) {
      try {
        if (payload is Map<String, dynamic> && payload['room'] != null) {
          final room = payload['room'].toString();
          if (room == 'conversation:$nid' || room.toLowerCase() == ('conversation:$nid').toLowerCase()) {
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
    debugPrint('SocketService: left conversation $nid');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _currentSubscribedWallet = null;
    _notificationHandlerRegistered = false;
  }

  bool get isConnected => _socket?.connected ?? false;
}
