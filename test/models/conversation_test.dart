import 'package:art_kubus/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses backend account, wallet-only, and hybrid member profiles', () {
    final conversation = Conversation.fromJson({
      'id': 'conversation-1',
      'memberProfiles': [
        {
          'userId': 'account-walletfree',
          'wallet': null,
          'displayName': 'Wallet Free',
          'avatarUrl': 'https://example.test/free.png',
        },
        {
          'userId': null,
          'wallet': 'wallet-only-address',
          'displayName': 'Wallet Only',
          'avatarUrl': null,
        },
        {
          'userId': 'account-hybrid',
          'wallet': 'hybrid-wallet-address',
          'displayName': 'Hybrid',
          'avatarUrl': null,
        },
      ],
      'memberUserIds': ['account-walletfree', 'account-hybrid'],
      'memberWallets': ['wallet-only-address', 'hybrid-wallet-address'],
      'memberCount': 3,
    });

    expect(conversation.memberProfiles, hasLength(3));
    expect(
      conversation.memberProfiles.map((member) => member.userId),
      ['account-walletfree', null, 'account-hybrid'],
    );
    expect(
      conversation.memberProfiles.map((member) => member.wallet),
      ['', 'wallet-only-address', 'hybrid-wallet-address'],
    );
    expect(
        conversation.memberUserIds, ['account-walletfree', 'account-hybrid']);
    expect(conversation.memberWallets,
        ['wallet-only-address', 'hybrid-wallet-address']);
    expect(conversation.memberCount, 3);
  });

  test('preserves wallet-era aliases and derives account IDs once', () {
    final conversation = Conversation.fromJson({
      'id': 'legacy-conversation',
      'member_profiles': [
        {
          'user_id': 'account-1',
          'wallet_address': 'legacy-wallet',
          'display_name': 'Legacy Member',
        },
        {'wallet_address': 'wallet-only'},
      ],
      'member_wallets': ['legacy-wallet', 'wallet-only'],
      'member_count': '2',
    });

    expect(conversation.memberProfiles, hasLength(2));
    expect(conversation.memberUserIds, ['account-1']);
    expect(conversation.memberWallets, ['legacy-wallet', 'wallet-only']);
    expect(conversation.memberProfiles.first.displayName, 'Legacy Member');
    expect(conversation.memberCount, 2);
  });

  test('keeps a walletless member profile in snake_case payloads', () {
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
}
