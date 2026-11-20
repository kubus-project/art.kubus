import 'package:art_kubus/models/message.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _alice = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const String _bob = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

ChatMessage _message({String? senderUserId, String? senderWallet}) {
  return ChatMessage.fromJson(<String, dynamic>{
    'id': 'message-${senderUserId ?? 'legacy'}-${senderWallet ?? 'none'}',
    'conversation_id': 'conversation-1',
    'sender_user_id': senderUserId,
    'sender_wallet': senderWallet,
    'message': 'hello',
    'created_at': '2026-10-12T10:00:00Z',
  });
}

MessageReaction _reaction(List<String> reactors) {
  return MessageReaction.fromJson(<String, dynamic>{
    'emoji': '+1',
    'count': reactors.length,
    'reactors': reactors,
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.setAccountKey(_alice);
  });

  tearDown(AccountIdentity.resetForTesting);

  group('own-message identity uses the session account id', () {
    test('the account id decides when both wallets are empty or null', () {
      final mine = _message(senderUserId: _alice);

      expect(mine.isSentBy(accountId: AccountIdentity.accountKey), isTrue);
      expect(
        mine.isSentBy(accountId: AccountIdentity.accountKey, wallet: ''),
        isTrue,
      );
    });

    test('two walletless members never see each other as the sender', () {
      final fromAlice = _message(senderUserId: _alice);
      final fromBob = _message(senderUserId: _bob);

      expect(fromAlice.isSentBy(accountId: _alice), isTrue);
      expect(fromAlice.isSentBy(accountId: _bob), isFalse);
      expect(fromBob.isSentBy(accountId: _alice), isFalse);
      expect(fromBob.isSentBy(accountId: _bob), isTrue);

      AccountIdentity.setAccountKey(_bob);
      expect(
          fromAlice.isSentBy(accountId: AccountIdentity.accountKey), isFalse);
      expect(fromBob.isSentBy(accountId: AccountIdentity.accountKey), isTrue);
    });

    test('a payload user id is not overridden by a matching wallet', () {
      final message = _message(senderUserId: _bob, senderWallet: 'shared');

      expect(
        message.isSentBy(accountId: _alice, wallet: 'shared'),
        isFalse,
      );
    });

    test('a legacy payload with no user id falls back to the wallet', () {
      final message = _message(senderWallet: 'wallet-abc');

      expect(message.isSentBy(accountId: _alice, wallet: 'wallet-abc'), isTrue);
      expect(
          message.isSentBy(accountId: _alice, wallet: 'wallet-xyz'), isFalse);
    });

    test('empty and null wallets never compare equal', () {
      final emptyWallet = _message(senderWallet: '');
      final nullWallet = _message();

      expect(emptyWallet.isSentBy(wallet: ''), isFalse);
      expect(emptyWallet.isSentBy(wallet: null), isFalse);
      expect(nullWallet.isSentBy(wallet: ''), isFalse);
      expect(nullWallet.isSentBy(wallet: null), isFalse);
      expect(nullWallet.isSentBy(accountId: '', wallet: ''), isFalse);
    });

    test('a guest session owns no message that carries a user id', () {
      AccountIdentity.setAccountKey('');
      final message = _message(senderUserId: _alice);

      expect(
        message.isSentBy(accountId: AccountIdentity.accountKey, wallet: ''),
        isFalse,
      );
    });

    test('account ids compare case-insensitively', () {
      final message = _message(senderUserId: _alice.toUpperCase());

      expect(message.isSentBy(accountId: _alice), isTrue);
    });
  });

  group('reaction ownership uses the session account id', () {
    test('a walletless reactor is matched by account id', () {
      final reaction = _reaction(<String>[_alice]);

      expect(
          reaction.isReactedBy(accountId: AccountIdentity.accountKey), isTrue);
      expect(reaction.isReactedBy(accountId: _bob), isFalse);
    });

    test('a wallet-linked reactor is matched by wallet', () {
      final reaction = _reaction(<String>['wallet-abc']);

      expect(
        reaction.isReactedBy(accountId: _alice, wallet: 'wallet-abc'),
        isTrue,
      );
      expect(
        reaction.isReactedBy(accountId: _alice, wallet: 'wallet-xyz'),
        isFalse,
      );
    });

    test('an empty or null wallet never matches a reaction', () {
      final reaction = _reaction(<String>[_bob]);

      expect(reaction.isReactedBy(accountId: _alice, wallet: ''), isFalse);
      expect(reaction.isReactedBy(wallet: null), isFalse);
      expect(reaction.isReactedBy(accountId: '', wallet: ''), isFalse);
    });
  });
}
