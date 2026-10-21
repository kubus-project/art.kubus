import 'package:art_kubus/models/conversation.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _conversationId = 'a0840000-0000-4000-8000-0000000000c1';
const String _selfWallet = '0x00000000000000000000000000000000000a0841';
const String _otherWallet = '0x00000000000000000000000000000000000b0841';
const String _messageId = '21ea8ea5-7186-47f3-bc14-336344c48f3c';

/// Exact `chat:new-message` frame captured from the staging backend.
Map<String, dynamic> _capturedFrame() => <String, dynamic>{
      'id': _messageId,
      'eventId': _messageId,
      'conversation_id': _conversationId,
      'sender_wallet': _otherWallet,
      'content': 'WS1 probe 1',
      'message': 'WS1 probe 1',
      'text': 'WS1 probe 1',
      'body': 'WS1 probe 1',
      'created_at': '2026-10-21T02:03:57.243Z',
      'createdAt': '2026-10-21T02:03:57.243Z',
      'data': <String, dynamic>{},
      'reply_to_message_id': null,
      'replyToMessageId': null,
      'reply_preview': null,
      'replyPreview': null,
      'reactions': <dynamic>[],
      'senderUsername': 'qa_b_084',
      'sender_username': 'qa_b_084',
      'senderDisplayName': 'QA Account B',
      'sender_display_name': 'QA Account B',
      'senderAvatar': null,
      'sender_avatar': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('captured chat:new-message frame', () {
    test('is inserted once into the open-list conversation messages', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);

      provider.handleIncomingMessageForTesting(_capturedFrame());

      final messages = provider.messages[_conversationId];
      expect(messages, isNotNull);
      expect(messages, hasLength(1));
      final message = messages!.single;
      expect(message.id, equals(_messageId));
      expect(message.conversationId, equals(_conversationId));
      expect(message.senderWallet, equals(_otherWallet));
      expect(message.message, equals('WS1 probe 1'));
    });

    test('replaying the same frame does not duplicate the message', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);

      provider.handleIncomingMessageForTesting(_capturedFrame());
      provider.handleIncomingMessageForTesting(_capturedFrame());

      expect(provider.messages[_conversationId], hasLength(1));
    });

    test('updates the conversation list preview when the conversation exists',
        () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);
      provider.conversations.add(Conversation(id: _conversationId));

      provider.handleIncomingMessageForTesting(_capturedFrame());

      final conversation = provider.conversations
          .firstWhere((conversation) => conversation.id == _conversationId);
      expect(conversation.lastMessage, equals('WS1 probe 1'));
      expect(
        conversation.lastMessageAt,
        equals(DateTime.parse('2026-10-21T02:03:57.243Z')),
      );
    });

    test('increments unread when the conversation is not open', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);

      provider.handleIncomingMessageForTesting(_capturedFrame());

      expect(provider.unreadCounts[_conversationId], equals(1));
      expect(provider.totalUnread, equals(1));
    });

    test('does not increment unread when the conversation is open', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);
      provider.setOpenConversationForTesting(_conversationId);

      provider.handleIncomingMessageForTesting(_capturedFrame());

      expect(provider.messages[_conversationId], hasLength(1));
      expect(provider.unreadCounts[_conversationId] ?? 0, equals(0));
    });

    test('empty nested data does not replace the top-level message', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);
      final frame = _capturedFrame()..['data'] = <String, dynamic>{};

      provider.handleIncomingMessageForTesting(frame);

      expect(provider.messages[_conversationId]?.single.message,
          equals('WS1 probe 1'));
    });

    test('non-message nested data does not replace the top-level message', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);
      final frame = _capturedFrame()
        ..['data'] = <String, dynamic>{'status': 'delivered'}
        ..['payload'] = <String, dynamic>{};

      provider.handleIncomingMessageForTesting(frame);

      expect(provider.messages[_conversationId]?.single.id, equals(_messageId));
    });
  });

  group('non-message events stay rejected', () {
    test('notification-shaped payload with a message body is ignored', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);

      provider.handleIncomingMessageForTesting(<String, dynamic>{
        'type': 'notification',
        'id': 'notif-1',
        'conversation_id': _conversationId,
        'sender_wallet': _otherWallet,
        'message': 'You have a new message',
        'data': <String, dynamic>{'id': 'notif-1'},
      });

      expect(provider.messages[_conversationId], isNull);
      expect(provider.totalUnread, equals(0));
    });

    test('event-named notification payload is ignored', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);

      provider.handleIncomingMessageForTesting(<String, dynamic>{
        'event': 'notification.created',
        'conversation_id': _conversationId,
        'data': <String, dynamic>{
          'id': 'notif-2',
          'message': 'You have a new message',
        },
      });

      expect(provider.messages[_conversationId], isNull);
      expect(provider.totalUnread, equals(0));
    });

    test('read receipt with empty data is ignored', () {
      final provider = ChatProvider();
      provider.setCurrentWalletForTesting(_selfWallet);

      provider.handleIncomingMessageForTesting(<String, dynamic>{
        'event': 'read',
        'conversation_id': _conversationId,
        'message_id': _messageId,
        'reader': _otherWallet,
        'data': <String, dynamic>{},
      });

      expect(provider.messages[_conversationId], isNull);
    });
  });
}
