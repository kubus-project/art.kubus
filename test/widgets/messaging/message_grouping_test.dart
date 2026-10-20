import 'package:art_kubus/models/message.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/messaging/message_grouping.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const String _alice = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _bob = '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

ChatMessage _message({
  String id = 'm',
  String wallet = _alice,
  DateTime? at,
}) {
  return ChatMessage(
    id: id,
    conversationId: 'c1',
    senderWallet: wallet,
    message: 'hi',
    createdAt: at ?? DateTime(2026, 10, 20, 12),
  );
}

void main() {
  group('messagesShareGroup', () {
    test('same sender within the window shares a group', () {
      final a = _message(at: DateTime(2026, 10, 20, 12));
      final b = _message(at: DateTime(2026, 10, 20, 12, 4, 59));
      expect(messagesShareGroup(a, b), isTrue);
    });

    test('exactly the window boundary still shares a group', () {
      final a = _message(at: DateTime(2026, 10, 20, 12));
      final b = _message(
        at: DateTime(2026, 10, 20, 12).add(kMessageGroupWindow),
      );
      expect(messagesShareGroup(a, b), isTrue);
    });

    test('a gap beyond the window breaks the group', () {
      final a = _message(at: DateTime(2026, 10, 20, 12));
      final b = _message(at: DateTime(2026, 10, 20, 12, 5, 1));
      expect(messagesShareGroup(a, b), isFalse);
    });

    test('is symmetric in argument order', () {
      final a = _message(at: DateTime(2026, 10, 20, 12));
      final b = _message(at: DateTime(2026, 10, 20, 12, 2));
      expect(messagesShareGroup(a, b), messagesShareGroup(b, a));
    });

    test('different senders never share a group', () {
      final a = _message(wallet: _alice);
      final b = _message(wallet: _bob);
      expect(messagesShareGroup(a, b), isFalse);
    });

    test('wallet comparison ignores letter case', () {
      final a = _message(wallet: _alice);
      final b = _message(wallet: _alice.toUpperCase().replaceFirst('0X', '0x'));
      expect(messagesShareGroup(a, b), isTrue);
    });

    test('messages without any sender identity never group', () {
      final a = _message(wallet: '');
      final b = _message(wallet: '');
      expect(messagesShareGroup(a, b), isFalse);
    });
  });

  group('messageBubbleRadius', () {
    const outer = Radius.circular(KubusRadius.sheet);
    const inner = Radius.circular(KubusRadius.sm);

    test('a lone own message is fully rounded', () {
      final radius = messageBubbleRadius(
        isMine: true,
        groupStart: true,
        groupEnd: true,
      );
      expect(radius.topRight, outer);
      expect(radius.bottomRight, outer);
      expect(radius.topLeft, outer);
      expect(radius.bottomLeft, outer);
    });

    test('a middle message tightens the sender-side corners only', () {
      final mine = messageBubbleRadius(
        isMine: true,
        groupStart: false,
        groupEnd: false,
      );
      expect(mine.topRight, inner);
      expect(mine.bottomRight, inner);
      expect(mine.topLeft, outer);
      expect(mine.bottomLeft, outer);

      final theirs = messageBubbleRadius(
        isMine: false,
        groupStart: false,
        groupEnd: false,
      );
      expect(theirs.topLeft, inner);
      expect(theirs.bottomLeft, inner);
      expect(theirs.topRight, outer);
      expect(theirs.bottomRight, outer);
    });

    test('group start keeps the top corner full and group end the bottom', () {
      final start = messageBubbleRadius(
        isMine: false,
        groupStart: true,
        groupEnd: false,
      );
      expect(start.topLeft, outer);
      expect(start.bottomLeft, inner);

      final end = messageBubbleRadius(
        isMine: false,
        groupStart: false,
        groupEnd: true,
      );
      expect(end.topLeft, inner);
      expect(end.bottomLeft, outer);
    });
  });
}
