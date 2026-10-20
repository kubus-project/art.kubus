import 'package:art_kubus/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

const _acc = '6c421a31-405e-4d9e-8b74-9dc357fd13b2';
const _acc2 = 'a1b2c3d4-0000-4000-8000-00000000000b';

void main() {
  test('parses camelCase reactorUserIds aligned with reactors', () {
    final reaction = MessageReaction.fromJson({
      'emoji': '👍',
      'count': 2,
      'reactors': ['wallet_a', _acc],
      'reactorUserIds': [_acc2, _acc],
    });

    expect(reaction.count, 2);
    expect(reaction.reactors, ['wallet_a', _acc]);
    expect(reaction.reactorUserIds, [_acc2, _acc]);
    expect(reaction.userIdAt(0), _acc2);
    expect(reaction.userIdAt(1), _acc);
  });

  test('parses snake_case reactor_user_ids', () {
    final reaction = MessageReaction.fromJson({
      'emoji': '🔥',
      'count': 1,
      'reactors': [_acc],
      'reactor_user_ids': [_acc.toUpperCase()],
    });

    expect(reaction.reactorUserIds, [_acc]);
  });

  test('legacy null entries stay null and keep alignment', () {
    final reaction = MessageReaction.fromJson({
      'emoji': '❤️',
      'count': 3,
      'reactors': ['wallet_legacy', _acc, 'wallet_other'],
      'reactorUserIds': [null, _acc, null],
    });

    expect(reaction.reactors, ['wallet_legacy', _acc, 'wallet_other']);
    expect(reaction.reactorUserIds, [null, _acc, null]);
    expect(reaction.alignedReactorUserIds, [null, _acc, null]);
  });

  test('missing reactorUserIds reads as all-null (older backend)', () {
    final reaction = MessageReaction.fromJson({
      'emoji': '👍',
      'count': 1,
      'reactors': ['wallet_only'],
    });

    expect(reaction.reactorUserIds, [null]);
    expect(reaction.userIdAt(0), isNull);
    expect(reaction.alignedReactorUserIds, [null]);
  });

  test('empty reactor entries are dropped together with their user id', () {
    final reaction = MessageReaction.fromJson({
      'emoji': '👍',
      'count': 2,
      'reactors': ['', _acc],
      'reactorUserIds': [_acc2, _acc],
    });

    expect(reaction.reactors, [_acc]);
    expect(reaction.reactorUserIds, [_acc]);
  });

  test('invalid user id values parse to null', () {
    final reaction = MessageReaction.fromJson({
      'emoji': '👍',
      'count': 1,
      'reactors': ['wallet_x'],
      'reactorUserIds': ['not-a-uuid'],
    });

    expect(reaction.reactorUserIds, [null]);
  });
}
