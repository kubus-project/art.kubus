import 'package:art_kubus/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

const String _ana = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const String _ben = 'a0b1c2d3-e4f5-4a6b-8c7d-9e0f1a2b3c4d';
const String _benWallet = 'So11111111111111111111111111111111111111112';

/// A read receipt as the chat provider and the members endpoint shape it.
Map<String, dynamic> _receipt({String? userId, String? wallet}) {
  return <String, dynamic>{
    if (userId != null) 'user_id': userId,
    if (userId != null) 'userId': userId,
    'wallet_address': wallet ?? '',
    'wallet': wallet ?? '',
    'read_at': '2026-11-15T10:00:00Z',
  };
}

void main() {
  group('an account-only reader counts as a receipt', () {
    test('a walletless reader by account id is a receipt from a peer', () {
      final readers = <Map<String, dynamic>>[_receipt(userId: _ben)];

      expect(
        hasReceiptFromOtherThanSender(
          readers,
          senderUserId: _ana,
          senderWallet: '',
        ),
        isTrue,
      );
    });

    test('the walletless sender reading their own message is not a receipt',
        () {
      final readers = <Map<String, dynamic>>[_receipt(userId: _ana)];

      expect(
        hasReceiptFromOtherThanSender(
          readers,
          senderUserId: _ana,
          senderWallet: '',
        ),
        isFalse,
      );
    });

    test('a wallet-linked reader still counts for a walletless sender', () {
      final readers = <Map<String, dynamic>>[
        _receipt(userId: _ben, wallet: _benWallet),
      ];

      expect(
        hasReceiptFromOtherThanSender(
          readers,
          senderUserId: _ana,
          senderWallet: '',
        ),
        isTrue,
      );
    });

    test('a legacy wallet receipt is matched by wallet for a wallet sender',
        () {
      final readers = <Map<String, dynamic>>[_receipt(wallet: _benWallet)];

      expect(
        hasReceiptFromOtherThanSender(
          readers,
          senderUserId: null,
          senderWallet: _benWallet,
        ),
        isFalse,
        reason: 'the sender read their own message',
      );
      expect(
        hasReceiptFromOtherThanSender(
          readers,
          senderUserId: _ana,
          senderWallet: _ana,
        ),
        isTrue,
      );
    });
  });

  group('no identity never counts', () {
    test('an entry with neither a user id nor a wallet is ignored', () {
      final readers = <Map<String, dynamic>>[
        <String, dynamic>{'wallet_address': '', 'user_id': ''},
      ];

      expect(
        hasReceiptFromOtherThanSender(
          readers,
          senderUserId: _ana,
          senderWallet: '',
        ),
        isFalse,
      );
    });

    test('two walletless accounts never read as the same reader', () {
      final entryFromBen = _receipt(userId: _ben);

      expect(
        isReaderEntryOf(entryFromBen, accountId: _ana, wallet: ''),
        isFalse,
      );
      expect(
        isReaderEntryOf(entryFromBen, accountId: _ben, wallet: ''),
        isTrue,
      );
    });
  });
}
