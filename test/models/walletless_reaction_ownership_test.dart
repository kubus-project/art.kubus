import 'package:art_kubus/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

const String _ana = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const String _ben = 'a0b1c2d3-e4f5-4a6b-8c7d-9e0f1a2b3c4d';
const String _anaWallet = 'So11111111111111111111111111111111111111112';

MessageReaction _reaction(List<String> reactors) {
  return MessageReaction.fromJson(<String, dynamic>{
    'emoji': '+1',
    'count': reactors.length,
    'reactors': reactors,
  });
}

void main() {
  group('two walletless users own their own reactions', () {
    test('a walletless reactor is the one account that reacted', () {
      final reaction = _reaction(<String>[_ana]);

      expect(reaction.isReactedBy(accountId: _ana), isTrue);
      expect(reaction.isReactedBy(accountId: _ben), isFalse);
    });

    test('each walletless user sees only their own reaction on a shared chip',
        () {
      final reaction = _reaction(<String>[_ana, _ben]);

      expect(reaction.isReactedBy(accountId: _ana), isTrue);
      expect(reaction.isReactedBy(accountId: _ben), isTrue);
      expect(
        reaction.reactorsExcept(accountId: _ana),
        <String>[_ben],
        reason: 'removing ana leaves ben reacted',
      );
      expect(
        reaction.reactorsExcept(accountId: _ben),
        <String>[_ana],
      );
    });

    test('account ids compare case-insensitively', () {
      final reaction = _reaction(<String>[_ana]);

      expect(reaction.isReactedBy(accountId: _ana.toUpperCase()), isTrue);
    });

    test('an empty reactor and an empty session never match', () {
      final reaction = _reaction(<String>['', _ben]);

      expect(reaction.isReactedBy(accountId: '', wallet: ''), isFalse);
      expect(reaction.isReactedBy(), isFalse);
      expect(reaction.isReactedBy(accountId: _ana), isFalse);
      // A blank reactor is dropped when the summary is parsed.
      expect(reaction.reactors, <String>[_ben]);
      expect(reaction.reactorsExcept(accountId: ''), <String>[_ben]);
    });
  });

  group('wallet-linked reactions keep working', () {
    test('a reactor stored as a wallet matches the wallet session', () {
      final reaction = _reaction(<String>[_anaWallet]);

      expect(reaction.isReactedBy(accountId: _ana, wallet: _anaWallet), isTrue);
      expect(reaction.isReactedBy(accountId: _ben), isFalse);
    });

    test('a legacy token that reports its wallet as the account key matches',
        () {
      final reaction = _reaction(<String>[_anaWallet]);

      expect(
        reaction.isReactedBy(accountId: _anaWallet, wallet: _anaWallet),
        isTrue,
      );
      expect(
        reaction.reactorsExcept(accountId: _anaWallet, wallet: _anaWallet),
        isEmpty,
      );
    });

    test('removing one account keeps another account on the same chip', () {
      final reaction = _reaction(<String>[_anaWallet, _ben]);

      expect(
        reaction.reactorsExcept(accountId: _ana, wallet: _anaWallet),
        <String>[_ben],
      );
    });
  });
}
