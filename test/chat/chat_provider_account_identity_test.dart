import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('token');
  });

  test('walletless same-text messages from two senders are not merged',
      () async {
    final hold = Completer<http.Response>();
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/messages/conv_x/messages') {
          return hold.future;
        }
        return http.Response('Not Found', 404);
      }),
    );

    final provider = ChatProvider()..setCurrentWalletForTesting(null);
    final pending = provider.sendMessage('conv_x', 'same text');
    expect(provider.messages['conv_x'], hasLength(1));
    final tempId = provider.messages['conv_x']!.single.id;
    expect(tempId, startsWith('temp-'));

    // A different walletless, accountless sender posts the same text now.
    provider.handleIncomingMessageForTesting({
      'event': 'message:received',
      'data': {
        'message': {
          'id': 'srv_b',
          'conversation_id': 'conv_x',
          'message': 'same text',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      },
    });

    final ids = provider.messages['conv_x']!.map((m) => m.id).toSet();
    expect(ids, containsAll(<String>[tempId, 'srv_b']));
    expect(provider.messages['conv_x'], hasLength(2));

    hold.complete(_json({
      'success': true,
      'data': {
        'id': 'srv_own',
        'conversation_id': 'conv_x',
        'sender_wallet': 'wallet_own',
        'message': 'same text',
        'created_at': DateTime.now().toUtc().toIso8601String()
      }
    }, 201));
    await pending;
  });

  test('same wallet echo replaces the optimistic message', () async {
    final hold = Completer<http.Response>();
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/messages/conv_y/messages') {
          return hold.future;
        }
        return http.Response('Not Found', 404);
      }),
    );

    final provider = ChatProvider()..setCurrentWalletForTesting('wallet_me');
    final pending = provider.sendMessage('conv_y', 'echo me');
    expect(provider.messages['conv_y'], hasLength(1));

    provider.handleIncomingMessageForTesting({
      'event': 'message:received',
      'data': {
        'message': {
          'id': 'srv_a',
          'conversation_id': 'conv_y',
          'sender_wallet': 'wallet_me',
          'message': 'echo me',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      },
    });

    expect(provider.messages['conv_y'], hasLength(1));
    expect(provider.messages['conv_y']!.single.id, 'srv_a');

    hold.complete(_json({
      'success': true,
      'data': {
        'id': 'srv_own',
        'conversation_id': 'conv_x',
        'sender_wallet': 'wallet_own',
        'message': 'same text',
        'created_at': DateTime.now().toUtc().toIso8601String()
      }
    }, 201));
    await pending;
  });

  test('late markRead response after account switch writes no state', () async {
    final hold = Completer<http.Response>();
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/messages/conv_r/read') {
          return hold.future;
        }
        return http.Response('Not Found', 404);
      }),
    );

    final provider = ChatProvider()
      ..setCurrentWalletForTesting('wallet_me')
      ..setCurrentAccountIdForTesting(null);
    // Closed conversation: an incoming message raises the unread count.
    provider.handleIncomingMessageForTesting({
      'event': 'message:received',
      'data': {
        'message': {
          'id': 'in_1',
          'conversation_id': 'conv_r',
          'sender_wallet': 'wallet_other',
          'message': 'unread',
          'created_at': '2025-01-02T12:00:00Z',
        },
      },
    });
    expect(provider.unreadCounts['conv_r'], 1);

    final pending = provider.markRead('conv_r');
    provider.switchAccountForTesting('a1b2c3d4-0000-4000-8000-00000000000b');
    hold.complete(_json({'success': true}));
    await pending;

    expect(provider.unreadCounts.containsKey('conv_r'), isFalse);
  });

  test('toggleReaction keys a walletless account by account id', () async {
    var reactionCalls = 0;
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/messages/conv_t/messages/m1/reactions') {
          reactionCalls++;
          return _json({'success': true});
        }
        return http.Response('Not Found', 404);
      }),
    );

    final provider = ChatProvider()..setCurrentWalletForTesting(null);
    provider.handleIncomingMessageForTesting({
      'event': 'message:received',
      'data': {
        'message': {
          'id': 'm1',
          'conversation_id': 'conv_t',
          'sender_wallet': 'wallet_other',
          'message': 'react to me',
          'created_at': '2025-01-02T12:00:00Z',
        },
      },
    });
    provider
        .setCurrentAccountIdForTesting('6c421a31-405e-4d9e-8b74-9dc357fd13b2');

    await provider.toggleReaction('conv_t', 'm1', '👍');
    final reaction = provider.messages['conv_t']!.single.reactions.single;
    expect(reaction.reactors, ['6c421a31-405e-4d9e-8b74-9dc357fd13b2']);
    expect(provider.isReactionByCurrentUser(reaction), isTrue);
    expect(reactionCalls, 1);

    // Second toggle removes the account's reaction.
    await provider.toggleReaction('conv_t', 'm1', '👍');
    expect(provider.messages['conv_t']!.single.reactions, isEmpty);
    expect(reactionCalls, 2);
  });

  test('toggleReaction without any reactor identity does nothing', () async {
    var reactionCalls = 0;
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/reactions')) reactionCalls++;
        return _json({'success': true});
      }),
    );

    final provider = ChatProvider()..setCurrentWalletForTesting(null);
    provider.handleIncomingMessageForTesting({
      'event': 'message:received',
      'data': {
        'message': {
          'id': 'm2',
          'conversation_id': 'conv_n',
          'sender_wallet': 'wallet_other',
          'message': 'no identity',
          'created_at': '2025-01-02T12:00:00Z',
        },
      },
    });

    await provider.toggleReaction('conv_n', 'm2', '👍');
    expect(provider.messages['conv_n']!.single.reactions, isEmpty);
    expect(reactionCalls, 0);
  });

  test('late toggleReaction response after account switch writes no state',
      () async {
    final hold = Completer<http.Response>();
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/messages/conv_s/messages/m3/reactions') {
          return hold.future;
        }
        return http.Response('Not Found', 404);
      }),
    );

    final provider = ChatProvider()..setCurrentWalletForTesting('wallet_me');
    provider.handleIncomingMessageForTesting({
      'event': 'message:received',
      'data': {
        'message': {
          'id': 'm3',
          'conversation_id': 'conv_s',
          'sender_wallet': 'wallet_other',
          'message': 'switch me',
          'created_at': '2025-01-02T12:00:00Z',
        },
      },
    });

    final pending = provider.toggleReaction('conv_s', 'm3', '👍');
    provider.switchAccountForTesting('a1b2c3d4-0000-4000-8000-00000000000b');
    hold.complete(_json({'success': true}));
    await pending;

    expect(provider.messages.containsKey('conv_s'), isFalse);
  });
}
