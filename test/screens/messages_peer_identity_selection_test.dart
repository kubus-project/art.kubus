import 'package:art_kubus/screens/community/messages_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('walletless UUID profile selection becomes memberUserIds', () {
    final peer = conversationPeerSelectionFromProfile(<String, dynamic>{
      'user_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'username': 'quietmaker',
      'display_name': 'Quiet Maker',
    });
    final selection = partitionConversationParticipantsForTesting(
      <String>[peer.identity],
    );

    expect(peer.identity, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    expect(peer.displayLabel, 'Quiet Maker');
    expect(selection.memberUserIds,
        <String>['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb']);
    expect(selection.members, isEmpty);
  });

  test('walleted account selection keeps account ID and legacy wallet alias',
      () {
    const accountId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    const wallet = 'So1anaBase58WalletCase';
    final peer = conversationPeerSelectionFromProfile(<String, dynamic>{
      'userId': accountId,
      'wallet_address': wallet,
      'username': 'maker',
    });
    final selection = partitionConversationParticipantsForTesting(
      <String>[peer.identity],
      walletAliases: <String, String>{accountId: wallet},
    );

    expect(selection.memberUserIds, <String>[accountId]);
    expect(selection.members, <String>[wallet]);
  });

  test('groups keep existing wallet member submission semantics', () {
    const wallet = 'So1anaBase58WalletCase';
    final selection = partitionConversationParticipantsForTesting(
      <String>[
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        wallet,
      ],
      isGroup: true,
    );

    expect(selection.memberUserIds, isEmpty);
    expect(selection.members,
        <String>['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', wallet]);
  });
}
