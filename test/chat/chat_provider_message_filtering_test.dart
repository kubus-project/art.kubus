import 'package:art_kubus/models/message.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('empty incoming message payload is ignored', () {
    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('wallet-self');

    provider.handleIncomingMessageForTesting(<String, dynamic>{
      'id': 'msg-empty',
      'conversationId': 'conv-1',
      'senderWallet': 'wallet-other',
      'message': '',
      'data': <String, dynamic>{},
      'createdAt': '2025-01-01T00:00:00.000Z',
    });

    expect(provider.messages['conv-1'], isNull);
    expect(provider.totalUnread, equals(0));
  });

  test('socket echo replaces optimistic temp message', () {
    final provider = ChatProvider();
    provider.setCurrentWalletForTesting('wallet-self');
    provider.messages['conv-1'] = <ChatMessage>[
      ChatMessage(
        id: 'temp-1',
        conversationId: 'conv-1',
        senderWallet: 'wallet-other',
        message: 'Hello there',
        data: const <String, dynamic>{'sendStatus': 'sending'},
        readersCount: 0,
        readByCurrent: false,
        readers: const <Map<String, dynamic>>[],
        createdAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
      ),
    ];

    provider.handleIncomingMessageForTesting(<String, dynamic>{
      'message': <String, dynamic>{
        'id': 'msg-real-1',
        'conversationId': 'conv-1',
        'senderWallet': 'wallet-other',
        'message': 'Hello there',
        'createdAt': '2025-01-01T00:00:10.000Z',
      },
    });

    final messages = provider.messages['conv-1'];
    expect(messages, isNotNull);
    expect(messages, hasLength(1));
    expect(messages!.single.id, equals('msg-real-1'));
    expect(messages.single.isRenderable, isTrue);
  });
}
