import 'package:art_kubus/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty message is not renderable', () {
    final message = ChatMessage(
      id: 'msg-1',
      conversationId: 'conv-1',
      senderWallet: 'wallet-1',
      message: '',
      reactions: const [],
      readersCount: 0,
      readByCurrent: false,
      readers: const [],
      createdAt: DateTime(2025, 1, 1),
    );

    expect(message.isRenderable, isFalse);
  });

  test('message with text content is renderable', () {
    final message = ChatMessage(
      id: 'msg-2',
      conversationId: 'conv-1',
      senderWallet: 'wallet-1',
      message: 'Hello, world!',
      reactions: const [],
      readersCount: 0,
      readByCurrent: false,
      readers: const [],
      createdAt: DateTime(2025, 1, 1),
    );

    expect(message.isRenderable, isTrue);
  });

  test('message with whitespace is not renderable', () {
    final message = ChatMessage(
      id: 'msg-3',
      conversationId: 'conv-1',
      senderWallet: 'wallet-1',
      message: '   \n\t  ',
      reactions: const [],
      readersCount: 0,
      readByCurrent: false,
      readers: const [],
      createdAt: DateTime(2025, 1, 1),
    );

    expect(message.isRenderable, isFalse);
  });

  test('message with reactions is renderable even if empty', () {
    final message = ChatMessage(
      id: 'msg-4',
      conversationId: 'conv-1',
      senderWallet: 'wallet-1',
      message: '',
      reactions: const [
        MessageReaction(
          emoji: '👍',
          count: 2,
          reactors: ['wallet-2', 'wallet-3'],
        ),
      ],
      readersCount: 0,
      readByCurrent: false,
      readers: const [],
      createdAt: DateTime(2025, 1, 1),
    );

    expect(message.isRenderable, isTrue);
  });

  test('message with reply is renderable even if empty', () {
    final message = ChatMessage(
      id: 'msg-5',
      conversationId: 'conv-1',
      senderWallet: 'wallet-1',
      message: '',
      replyTo: const MessageReply(
        messageId: 'msg-0',
        senderWallet: 'wallet-2',
        message: 'Original message',
      ),
      reactions: const [],
      readersCount: 0,
      readByCurrent: false,
      readers: const [],
      createdAt: DateTime(2025, 1, 1),
    );

    expect(message.isRenderable, isTrue);
  });

  test('message with data content is renderable', () {
    final message = ChatMessage(
      id: 'msg-6',
      conversationId: 'conv-1',
      senderWallet: 'wallet-1',
      message: '',
      data: const {'image': 'https://example.com/image.jpg'},
      reactions: const [],
      readersCount: 0,
      readByCurrent: false,
      readers: const [],
      createdAt: DateTime(2025, 1, 1),
    );

    expect(message.isRenderable, isTrue);
  });
}
