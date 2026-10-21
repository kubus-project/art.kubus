import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';

/// Serves chat endpoints from the test. Conversation and message responses are
/// held by completers so a test can resolve account A's request after the
/// session has moved on.
class _ChatHttp {
  final Map<String, Completer<http.Response>> _pending = {};
  final Map<String, Completer<void>> _arrived = {};

  http.Response? _immediate(String path) {
    if (path == '/api/profiles/me') {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'wallet_address': 'walletA'},
        }),
        200,
      );
    }
    if (path.endsWith('/members')) {
      return http.Response(jsonEncode({'success': true, 'data': []}), 200);
    }
    return null;
  }

  /// Future that completes when the request for [key] reaches the mock.
  Future<void> arrived(String key) {
    return _arrived.putIfAbsent(key, () => Completer<void>()).future;
  }

  void complete(String key, Map<String, dynamic> body) {
    _pending[key]!.complete(http.Response(jsonEncode(body), 200));
  }

  MockClient client() {
    return MockClient((request) async {
      final path = request.url.path;
      final immediate = _immediate(path);
      if (immediate != null) return immediate;
      final isMessages =
          path.startsWith('/api/messages/') && path.endsWith('/messages');
      if (!isMessages && path != '/api/messages') {
        return http.Response(jsonEncode({'success': false}), 404);
      }
      final key = isMessages ? 'messages' : 'conversations';
      final completer = Completer<http.Response>();
      _pending[key] = completer;
      final arrived = _arrived.putIfAbsent(key, () => Completer<void>());
      if (!arrived.isCompleted) arrived.complete();
      return completer.future;
    });
  }
}

Map<String, dynamic> _conversation(String id) => {
      'id': id,
      'title': 'Conversation $id',
      'unreadCount': 3,
      'memberWallets': ['walletB'],
    };

Map<String, dynamic> _message(String id, String conversationId) => {
      'id': id,
      'conversationId': conversationId,
      'senderWallet': 'walletB',
      'message': 'hello from B',
      'createdAt': DateTime.utc(2026, 10, 21).toIso8601String(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('late conversations for account A are dropped after sign-out', () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    final pending = provider.refreshConversations();
    await http.arrived('conversations');

    // Sign-out: no token, no wallet, no profile.
    BackendApiService().setAuthTokenForTesting(null);
    provider.bindAuthContext(walletAddress: null, isSignedIn: false);
    expect(provider.conversations, isEmpty);

    http.complete('conversations', {
      'success': true,
      'data': [_conversation('convA')],
    });
    await pending;

    expect(provider.conversations, isEmpty);
    expect(provider.unreadCounts, isEmpty);
  });

  test('late messages for account A are not returned or cached after sign-out',
      () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    final pending = provider.loadMessages('convA');
    await http.arrived('messages');

    BackendApiService().setAuthTokenForTesting(null);
    provider.bindAuthContext(walletAddress: null, isSignedIn: false);

    http.complete('messages', {
      'success': true,
      'data': [_message('m1', 'convA')],
    });
    final result = await pending;

    expect(result, isEmpty);
    expect(provider.messages, isEmpty);
  });

  test('wallet change clears per-account caches and conversations', () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    // Populate A's state from a completed load.
    final loadA = provider.loadMessages('convA');
    await http.arrived('messages');
    http.complete('messages', {
      'success': true,
      'data': [_message('m1', 'convA')],
    });
    await loadA;
    expect(provider.messages.containsKey('convA'), isTrue);

    final refreshA = provider.refreshConversations();
    await http.arrived('conversations');
    http.complete('conversations', {
      'success': true,
      'data': [_conversation('convA')],
    });
    await refreshA;
    expect(provider.conversations, isNotEmpty);
    expect(provider.unreadCounts['convA'], 3);

    // Wallet change to B: A's caches, conversations and unread counts go.
    unawaited(provider.setCurrentWallet('walletB'));
    await Future<void>.delayed(Duration.zero);

    expect(provider.messages, isEmpty);
    expect(provider.conversations, isEmpty);
    expect(provider.unreadCounts, isEmpty);
    expect(provider.totalUnread, 0);
  });
}
