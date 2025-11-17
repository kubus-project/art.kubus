import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/socket_service.dart';

// Note: NotificationProvider will automatically attach to SocketService when created.
// It listens for incoming messages and increments the unread badge when appropriate.

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  bool _hasNew = false;
  int _lastNotifVersion = 0;
  int _lastGlobalVersion = 0;

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
}
