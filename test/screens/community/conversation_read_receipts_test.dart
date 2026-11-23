import 'package:art_kubus/models/message.dart';
import 'package:art_kubus/screens/community/conversation_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _other = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';
const _myWallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';
const _otherWallet = '9wHbF2e8q1Lm5VxT3rZ7cKpN4aYdGsUoJ6EhQvB1WmRj';

ChatMessage _message(
  String id, {
  String? senderUserId,
  String? senderWallet,
  bool readByCurrent = false,
}) {
  return ChatMessage.fromJson(<String, dynamic>{
    'id': id,
    'conversation_id': 'conversation-1',
    'sender_user_id': senderUserId,
    'sender_wallet': senderWallet,
    'message': 'hello',
    'created_at': '2026-11-15T10:00:00Z',
    'read_by_current': readByCurrent,
  });
}

void main() {
  group('read receipts for a walletless reader', () {
    test('marks other accounts messages, never its own or an already read one',
        () {
      final ids = readReceiptCandidateIds(
        <ChatMessage>[
          _message('own', senderUserId: _me),
          _message('theirs', senderUserId: _other),
          _message('read', senderUserId: _other, readByCurrent: true),
        ],
        accountId: _me,
        wallet: '',
      );

      expect(ids, <String>['theirs']);
    });

    test('a session with neither a wallet nor an account id marks nothing', () {
      final ids = readReceiptCandidateIds(
        <ChatMessage>[_message('theirs', senderUserId: _other)],
        accountId: '',
        wallet: '',
      );

      expect(ids, isEmpty);
    });
  });

  group('read receipts for a wallet reader', () {
    test('marks other wallets messages and never its own wallet message', () {
      final ids = readReceiptCandidateIds(
        <ChatMessage>[
          _message('own', senderWallet: _myWallet),
          _message('theirs', senderWallet: _otherWallet),
        ],
        accountId: '',
        wallet: _myWallet,
      );

      expect(ids, <String>['theirs']);
    });
  });
}
