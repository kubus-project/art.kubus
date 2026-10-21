import 'package:art_kubus/widgets/messaging/message_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isReadReceiptBoundary', () {
    test('a peer-read own message with no newer message is the boundary', () {
      expect(
        isReadReceiptBoundary(
          isMine: true,
          readByPeer: true,
          hasNewerMessage: false,
          newerReadByPeer: false,
        ),
        isTrue,
      );
    });

    test(
        'an own read message followed by an unread own message is the boundary',
        () {
      expect(
        isReadReceiptBoundary(
          isMine: true,
          readByPeer: true,
          hasNewerMessage: true,
          newerReadByPeer: false,
        ),
        isTrue,
      );
    });

    test(
        'a read message whose newer neighbour is also read is not the boundary',
        () {
      expect(
        isReadReceiptBoundary(
          isMine: true,
          readByPeer: true,
          hasNewerMessage: true,
          newerReadByPeer: true,
        ),
        isFalse,
      );
    });

    test('an unread own message is never the boundary', () {
      expect(
        isReadReceiptBoundary(
          isMine: true,
          readByPeer: false,
          hasNewerMessage: false,
          newerReadByPeer: false,
        ),
        isFalse,
      );
    });

    test('messages from the peer never carry the own receipt boundary', () {
      expect(
        isReadReceiptBoundary(
          isMine: false,
          readByPeer: true,
          hasNewerMessage: false,
          newerReadByPeer: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldAnimateMessageEntrance', () {
    test('a new message animates when motion is allowed', () {
      expect(
        shouldAnimateMessageEntrance(isNew: true, reduceMotion: false),
        isTrue,
      );
    });

    test('reduced motion places a new message without an entrance', () {
      expect(
        shouldAnimateMessageEntrance(isNew: true, reduceMotion: true),
        isFalse,
      );
    });

    test('already-animated messages never re-enter', () {
      expect(
        shouldAnimateMessageEntrance(isNew: false, reduceMotion: false),
        isFalse,
      );
    });
  });
}
