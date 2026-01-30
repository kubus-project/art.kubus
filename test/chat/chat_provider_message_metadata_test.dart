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
}
