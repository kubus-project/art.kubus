import 'package:art_kubus/models/conversation.dart';
import 'package:art_kubus/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversation preserves walletless canonical member identity', () {
    final conversation = Conversation.fromJson(<String, dynamic>{
      'id': 'conversation-1',
      'is_group': false,
      'member_user_ids': <String>[
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ],
      'member_profiles': <Map<String, dynamic>>[
        <String, dynamic>{
          'user_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          'wallet_address': null,
          'display_name': 'Walletless peer',
        },
      ],
      'member_count': 2,
    });

    expect(conversation.memberUserIds, <String>[
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    ]);
    expect(conversation.memberProfiles, hasLength(1));
    expect(conversation.memberProfiles.single.userId,
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    expect(conversation.memberProfiles.single.wallet, isEmpty);
    expect(conversation.memberProfiles.single.displayName, 'Walletless peer');
  });

  test('message preserves canonical sender account ID without wallet', () {
    final message = ChatMessage.fromJson(<String, dynamic>{
      'id': 'message-1',
      'conversation_id': 'conversation-1',
      'sender_user_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'sender_wallet': null,
      'message': 'hello',
      'created_at': '2026-10-20T10:00:00.000Z',
    });

    expect(message.senderUserId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    expect(message.senderWallet, isEmpty);
    expect(message.copyWith(message: 'updated').senderUserId,
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  });
}
