import 'package:art_kubus/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses wallet-free sender, reply, and reader account IDs', () {
    final message = ChatMessage.fromJson({
      'id': 'message-walletfree',
      'conversation_id': 'conversation-1',
      'sender_wallet': null,
      'sender_user_id': 'account-sender',
      'message': 'Hello',
      'created_at': '2026-10-12T10:00:00Z',
      'reply_preview': {
        'messageId': 'reply-1',
        'senderWallet': null,
        'senderUserId': 'account-reply',
        'senderDisplayName': 'Reply author',
        'message': 'Earlier message',
      },
      'readers': [
        {
          'user_id': 'account-reader',
          'userId': 'account-reader',
          'wallet_address': null,
          'displayName': 'Reader',
        },
      ],
    });

    expect(message.senderUserId, 'account-sender');
    expect(message.senderWallet, isEmpty);
    expect(message.replyTo?.senderUserId, 'account-reply');
    expect(message.readers.single['userId'], 'account-reader');
    expect(message.copyWith(message: 'Edited').senderUserId, 'account-sender');
  });

  test('parses hybrid sender and reply camel-case account fields', () {
    final message = ChatMessage.fromJson({
      'id': 'message-hybrid',
      'conversationId': 'conversation-1',
      'senderWallet': 'hybrid-wallet',
      'senderUserId': 'account-hybrid',
      'message': 'Hybrid identity',
      'createdAt': '2026-10-12T10:00:00Z',
      'replyPreview': {
        'messageId': 'reply-2',
        'senderWallet': 'reply-wallet',
        'senderUserId': 'account-reply-hybrid',
      },
    });

    expect(message.senderUserId, 'account-hybrid');
    expect(message.senderWallet, 'hybrid-wallet');
    expect(message.replyTo?.senderUserId, 'account-reply-hybrid');
    expect(message.replyTo?.senderWallet, 'reply-wallet');
    expect(message.copyWith().senderUserId, 'account-hybrid');
  });

  test('keeps legacy wallet sender when account identity is absent', () {
    final message = ChatMessage.fromJson({
      'id': 'message-legacy',
      'conversation_id': 'conversation-1',
      'sender_wallet': 'legacy-wallet',
      'message': 'Legacy',
      'created_at': '2026-10-12T10:00:00Z',
    });

    expect(message.senderWallet, 'legacy-wallet');
    expect(message.senderUserId, isNull);
    expect(message.copyWith(message: 'Updated').senderUserId, isNull);
  });
}
