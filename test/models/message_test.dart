import 'package:art_kubus/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage sender identity', () {
    test('parses a snake_case sender user id with a null sender wallet', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-walletfree',
        'conversation_id': 'conversation-1',
        'sender_user_id': 'account-sender',
        'sender_wallet': null,
        'message': 'Hello',
        'created_at': '2026-10-12T10:00:00Z',
      });

      expect(message.senderUserId, 'account-sender');
      expect(message.senderWallet, isEmpty);
    });

    test('parses a camelCase sender user id alongside a wallet', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-hybrid',
        'conversationId': 'conversation-1',
        'senderUserId': 'account-hybrid',
        'senderWallet': 'hybrid-wallet',
        'message': 'Hybrid identity',
        'createdAt': '2026-10-12T10:00:00Z',
      });

      expect(message.senderUserId, 'account-hybrid');
      expect(message.senderWallet, 'hybrid-wallet');
    });

    test('a legacy payload with no user id keeps a null senderUserId', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
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

    test('a blank sender user id is treated as absent', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-blank',
        'conversation_id': 'conversation-1',
        'sender_user_id': '   ',
        'sender_wallet': 'some-wallet',
        'message': 'Blank',
        'created_at': '2026-10-12T10:00:00Z',
      });

      expect(message.senderUserId, isNull);
    });

    test('a walletless sender keeps the member profile fields', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-profile',
        'conversation_id': 'conversation-1',
        'sender_user_id': 'account-profile',
        'sender_wallet': null,
        'display_name': 'Walletless member',
        'avatar_url': 'https://example.test/member.png',
        'message': 'Profile',
        'created_at': '2026-10-12T10:00:00Z',
      });

      expect(message.senderUserId, 'account-profile');
      expect(message.senderDisplayName, 'Walletless member');
      expect(message.senderAvatar, 'https://example.test/member.png');
    });

    test('copyWith keeps the sender user id', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-copy',
        'conversation_id': 'conversation-1',
        'sender_user_id': 'account-copy',
        'sender_wallet': null,
        'message': 'Original',
        'created_at': '2026-10-12T10:00:00Z',
      });

      expect(message.copyWith(message: 'Edited').senderUserId, 'account-copy');
    });
  });

  group('MessageReply sender identity', () {
    test('reply preview carries a camelCase user id with a null wallet', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-reply',
        'conversation_id': 'conversation-1',
        'sender_user_id': 'account-sender',
        'sender_wallet': null,
        'message': 'Answer',
        'created_at': '2026-10-12T10:00:00Z',
        'reply_preview': <String, dynamic>{
          'messageId': 'reply-1',
          'senderWallet': null,
          'senderUserId': 'account-reply',
          'senderDisplayName': 'Reply author',
          'message': 'Earlier message',
        },
      });

      expect(message.replyTo?.senderUserId, 'account-reply');
      expect(message.replyTo?.senderWallet, isEmpty);
      expect(message.replyTo?.senderDisplayName, 'Reply author');
    });

    test('reply preview accepts a snake_case user id', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-reply-snake',
        'conversation_id': 'conversation-1',
        'sender_user_id': 'account-sender',
        'message': 'Answer',
        'created_at': '2026-10-12T10:00:00Z',
        'replyPreview': <String, dynamic>{
          'message_id': 'reply-2',
          'sender_wallet': null,
          'sender_user_id': 'account-reply-snake',
        },
      });

      expect(message.replyTo?.senderUserId, 'account-reply-snake');
      expect(message.replyTo?.messageId, 'reply-2');
    });

    test('reply preview without a user id keeps a null senderUserId', () {
      final message = ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-reply-legacy',
        'conversation_id': 'conversation-1',
        'sender_wallet': 'legacy-wallet',
        'message': 'Answer',
        'created_at': '2026-10-12T10:00:00Z',
        'reply_preview': <String, dynamic>{
          'messageId': 'reply-3',
          'senderWallet': 'legacy-reply-wallet',
        },
      });

      expect(message.replyTo?.senderWallet, 'legacy-reply-wallet');
      expect(message.replyTo?.senderUserId, isNull);
    });
  });
}
