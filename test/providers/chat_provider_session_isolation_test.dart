import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';

/// Serves chat endpoints from the test. Held requests are queued per endpoint
/// and resolved oldest-first, so a test can answer account A's request after
/// the session has moved on to account B.
class _ChatHttp {
  final Map<String, List<Completer<http.Response>>> _held = {};
  final Map<String, Completer<void>> _arrived = {};

  /// Every request as "METHOD path", in arrival order.
  final List<String> requests = [];

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

  /// Endpoint key for a request, or null when the mock does not serve it.
  String? _keyFor(String method, String path) {
    if (path == '/api/messages') {
      return method == 'POST' ? 'create' : 'conversations';
    }
    if (path.startsWith('/api/messages/')) {
      if (path.endsWith('/messages') && method == 'POST') return 'send';
      if (path.endsWith('/messages')) return 'messages';
      if (path.contains('/messages/') && path.endsWith('/read')) {
        return 'messageRead';
      }
      if (path.endsWith('/read')) return 'conversationRead';
    }
    return null;
  }

  /// Future that completes when the first request for [key] reaches the mock.
  Future<void> arrived(String key) {
    return _arrived.putIfAbsent(key, () => Completer<void>()).future;
  }

  /// Answers the oldest held request for [key].
  void complete(String key, Map<String, dynamic> body, {int status = 200}) {
    final queue = _held[key]!;
    queue.removeAt(0).complete(http.Response(jsonEncode(body), status));
  }

  MockClient client() {
    return MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      final immediate = _immediate(path);
      if (immediate != null) return immediate;
      final key = _keyFor(request.method, path);
      if (key == null) {
        return http.Response(jsonEncode({'success': false}), 404);
      }
      if (key == 'conversationRead') {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      }
      final completer = Completer<http.Response>();
      _held.putIfAbsent(key, () => []).add(completer);
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

  test(
      'late listConversations response for account A is dropped after '
      'wallet change', () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    final pending = provider.listConversations();
    await http.arrived('conversations');

    // Switch to B while A's list request is still in flight.
    unawaited(provider.setCurrentWallet('walletB'));
    await Future<void>.delayed(Duration.zero);

    http.complete('conversations', {
      'success': true,
      'data': [_conversation('convA')],
    });
    final returned = await pending;

    expect(returned, isEmpty);
    expect(provider.conversations, isEmpty);
    expect(provider.unreadCounts, isEmpty);
  });

  test(
      'sendMessage completing for account A does not write to the new '
      'session after wallet change', () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    final pending = provider.sendMessage('convA', 'hi');
    await http.arrived('send');

    unawaited(provider.setCurrentWallet('walletB'));
    await Future<void>.delayed(Duration.zero);

    http.complete('send', {
      'success': true,
      'data': _message('m2', 'convA'),
    });
    await pending;

    expect(provider.messages.containsKey('convA'), isFalse);
    expect(provider.messages, isEmpty);
  });

  test(
      'no conversation read fallback is sent for account A after wallet '
      'change', () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    final pending = provider.markMessageRead('convA', 'm1');
    await http.arrived('messageRead');

    unawaited(provider.setCurrentWallet('walletB'));
    await Future<void>.delayed(Duration.zero);

    // Server says the message is not found, which would normally fall back to
    // marking the whole conversation read.
    http.complete('messageRead', {'success': false}, status: 404);
    await pending;

    expect(
      http.requests.where((r) => r == 'POST /api/messages/convA/read'),
      isEmpty,
    );
    expect(
      http.requests.where((r) => r.endsWith('/api/messages/convA/read')),
      isEmpty,
    );
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

  test(
      'socket message for a conversation of the previous session is ignored '
      'after switch', () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    final refreshA = provider.refreshConversations();
    await http.arrived('conversations');
    http.complete('conversations', {
      'success': true,
      'data': [_conversation('convA')],
    });
    await refreshA;
    expect(provider.conversations, isNotEmpty);

    unawaited(provider.setCurrentWallet('walletB'));
    await Future<void>.delayed(Duration.zero);
    expect(provider.conversations, isEmpty);

    // A late frame for A's conversation arrives after the switch.
    provider.handleIncomingMessageForTesting(_message('m3', 'convA'));

    expect(provider.messages.containsKey('convA'), isFalse);
    expect(provider.unreadCounts, isEmpty);
  });

  test('socket message is ignored while no wallet is bound', () {
    final provider = ChatProvider();
    provider.setCurrentWalletForTesting(null);

    provider.handleIncomingMessageForTesting(_message('m4', 'convX'));

    expect(provider.messages, isEmpty);
    expect(provider.unreadCounts, isEmpty);
  });

  test(
      'createConversation completing for account A writes nothing after '
      'wallet change', () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    final pending = provider.createConversation('Chat', false, ['walletB']);
    await http.arrived('conversations');
    http.complete('conversations', {'success': true, 'data': []});
    await http.arrived('create');

    unawaited(provider.setCurrentWallet('walletB'));
    await Future<void>.delayed(Duration.zero);

    http.complete('create', {
      'success': true,
      'data': _conversation('convNew'),
    });
    final created = await pending;

    expect(created, isNull);
    expect(provider.conversations, isEmpty);
    expect(provider.unreadCounts, isEmpty);
  });

  test(
      'createConversation does not create anything after a wallet change '
      'during the conversation pre-check', () async {
    final http = _ChatHttp();
    BackendApiService().setHttpClient(http.client());
    BackendApiService().setAuthTokenForTesting('tokenA');

    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('walletA');

    final pending = provider.createConversation('Chat', false, ['walletB']);
    await http.arrived('conversations');

    unawaited(provider.setCurrentWallet('walletB'));
    await Future<void>.delayed(Duration.zero);

    http.complete('conversations', {
      'success': true,
      'data': [_conversation('convA')],
    });
    final created = await pending;

    expect(created, isNull);
    expect(provider.conversations, isEmpty);
    expect(
      http.requests.where((r) => r.startsWith('POST ')),
      isEmpty,
    );
  });
}
