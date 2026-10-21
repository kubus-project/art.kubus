import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('token');
  });

  test('sendMessage updates conversation metadata and order', () async {
    final sentAt = DateTime.utc(2025, 1, 1, 12, 0, 0);

    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/messages' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'conv_a',
                  'title': 'Alpha',
                  'is_group': false,
                  'member_wallets': ['wallet_me', 'wallet_a'],
                  'last_message': 'old a',
                  'last_message_at': '2024-01-01T00:00:00Z',
                },
                {
                  'id': 'conv_b',
                  'title': 'Beta',
                  'is_group': false,
                  'member_wallets': ['wallet_me', 'wallet_b'],
                  'last_message': 'old b',
                  'last_message_at': '2024-01-02T00:00:00Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/messages/conv_b/messages' &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'msg_1',
                'conversation_id': 'conv_b',
                'sender_wallet': 'wallet_me',
                'message': 'new message',
                'created_at': sentAt.toIso8601String(),
              }
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/profiles/batch' &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({'success': true, 'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      }),
    );

    final provider = ChatProvider();
    await provider.listConversations();

    expect(provider.conversations.first.id, 'conv_a');

    await provider.sendMessage('conv_b', 'new message');

    expect(provider.conversations.first.id, 'conv_b');
    expect(provider.conversations.first.lastMessage, 'new message');
    expect(
      provider.conversations.first.lastMessageAt?.isAtSameMomentAs(sentAt),
      isTrue,
    );
  });

  test('incoming socket message inserts and increments unread when closed', () {
    final provider = ChatProvider()
      ..setCurrentWalletForTesting('wallet_me')
      ..handleIncomingMessageForTesting({
        'event': 'message:received',
        'data': {
          'message': {
            'id': 'socket_msg_1',
            'conversation_id': 'conv_socket',
            'sender_wallet': 'wallet_other',
            'message': 'hello from socket',
            'created_at': '2025-01-02T12:00:00Z',
          },
        },
      });

    expect(provider.messages['conv_socket'], hasLength(1));
    expect(provider.messages['conv_socket']!.single.id, 'socket_msg_1');
    expect(provider.unreadCounts['conv_socket'], 1);
    expect(
      provider.debugResourceSnapshot['lastIncomingConversationId'],
      'conv_socket',
    );
  });

  test('duplicate socket and polling payloads appear once', () {
    final provider = ChatProvider()..setCurrentWalletForTesting('wallet_me');
    final payload = {
      'conversationId': 'conv_dupe',
      'message': {
        'id': 'dupe_msg_1',
        'conversationId': 'conv_dupe',
        'senderWallet': 'wallet_other',
        'message': 'same message',
        'createdAt': '2025-01-02T12:00:00Z',
      },
    };

    provider.handleIncomingMessageForTesting(payload);
    provider.handleIncomingMessageForTesting(payload);

    expect(provider.messages['conv_dupe'], hasLength(1));
    expect(provider.unreadCounts['conv_dupe'], 1);
  });

  test('DM socket aliases with the same event ID increment unread once', () {
    final provider = ChatProvider()..setCurrentWalletForTesting('wallet_me');
    final message = <String, dynamic>{
      'id': 'message_event_42',
      'conversationId': 'conv_event_alias',
      'senderWallet': 'wallet_other',
      'message': 'one persisted message',
      'createdAt': '2025-01-02T12:00:00Z',
    };

    provider.handleIncomingMessageForTesting(<String, dynamic>{
      'event': 'message:received',
      'eventId': 'message_event_42',
      'data': <String, dynamic>{'message': message},
    });
    provider.handleIncomingMessageForTesting(<String, dynamic>{
      'event': 'chat:new-message',
      'eventId': 'message_event_42',
      'data': <String, dynamic>{'message': message},
    });

    expect(provider.messages['conv_event_alias'], hasLength(1));
    expect(
        provider.messages['conv_event_alias']!.single.id, 'message_event_42');
    expect(provider.unreadCounts['conv_event_alias'], 1);
  });

  test('open conversation receives incoming message without unread increment',
      () {
    final provider = ChatProvider()
      ..setCurrentWalletForTesting('wallet_me')
      ..setOpenConversationForTesting('conv_open')
      ..handleIncomingMessageForTesting({
        'message': {
          'id': 'open_msg_1',
          'conversation_id': 'conv_open',
          'sender_wallet': 'wallet_other',
          'message': 'visible immediately',
          'created_at': '2025-01-02T12:00:00Z',
        },
      });

    expect(provider.messages['conv_open'], hasLength(1));
    expect(provider.unreadCounts['conv_open'], 0);
  });

  test('late message response from the prior account cannot fill new cache',
      () async {
    final requestStarted = Completer<void>();
    final staleResponse = Completer<http.Response>();
    BackendApiService().setHttpClient(MockClient((request) async {
      expect(request.url.path, '/api/messages/private-a/messages');
      requestStarted.complete();
      return staleResponse.future;
    }));
    final provider = ChatProvider()
      ..switchAccountForTesting('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    addTearDown(provider.dispose);

    final pending = provider.loadMessages('private-a');
    await requestStarted.future;
    provider.switchAccountForTesting('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    staleResponse.complete(http.Response(
      jsonEncode(<String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a-message',
            'conversation_id': 'private-a',
            'sender_user_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            'sender_wallet': null,
            'message': 'private to account A',
            'created_at': '2026-10-20T10:00:00Z',
          },
        ],
      }),
      200,
    ));

    expect(await pending, isEmpty);
    expect(provider.messages, isEmpty);
    expect(provider.debugResourceSnapshot['currentAccountId'],
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  });

  test('account room event for unknown prior-session conversation is ignored',
      () async {
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == '/api/messages') {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'data': <dynamic>[]}),
          200,
        );
      }
      return http.Response('Not Found', 404);
    }));
    final provider = ChatProvider()
      ..switchAccountForTesting('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    addTearDown(provider.dispose);

    provider.handleIncomingMessageForTesting(<String, dynamic>{
      'conversationId': 'private-a',
      'message': <String, dynamic>{
        'id': 'a-message',
        'senderUserId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'message': 'private to account A',
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(provider.messages, isEmpty);
    expect(provider.unreadCounts, isEmpty);
  });

  test(
      'account switch clears the prior account conversation and message caches',
      () async {
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path == '/api/messages') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'private-a',
                'memberUserIds': <String>[
                  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                ],
                'isGroup': false,
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/messages/private-a/messages') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'a-message',
                'conversation_id': 'private-a',
                'sender_user_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                'message': 'private to account A',
                'created_at': '2026-10-20T10:00:00Z',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('Not Found', 404);
    }));
    final provider = ChatProvider()
      ..switchAccountForTesting('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    addTearDown(provider.dispose);

    await provider.refreshConversations();
    await provider.loadMessages('private-a');
    expect(provider.conversations.map((c) => c.id), contains('private-a'));
    expect(provider.messages['private-a'], hasLength(1));

    provider.switchAccountForTesting('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

    expect(provider.conversations, isEmpty);
    expect(provider.messages, isEmpty);
    expect(provider.unreadCounts, isEmpty);
    expect(provider.debugResourceSnapshot['currentAccountId'],
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  });

  test('legacy wallet session still accepts wallet-addressed incoming messages',
      () async {
    final provider = ChatProvider()
      ..setCurrentWalletForTesting('0xLegacyWallet');
    addTearDown(provider.dispose);

    provider.handleIncomingMessageForTesting(<String, dynamic>{
      'conversationId': 'wallet-conv',
      'message': <String, dynamic>{
        'id': 'legacy-message',
        'sender_wallet': '0xPeerWallet',
        'message': 'legacy wallet message',
      },
    });

    expect(provider.messages['wallet-conv'], hasLength(1));
    expect(
        provider.messages['wallet-conv']!.single.senderWallet, '0xPeerWallet');
    expect(provider.debugResourceSnapshot['currentAccountId'], isNull);
  });
}
