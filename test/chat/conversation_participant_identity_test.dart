import 'package:art_kubus/models/resolved_conversation_participant.dart';
import 'package:art_kubus/models/conversation.dart';
import 'package:art_kubus/models/message.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'normalizeParticipantIdentityKey keeps account identity across wallet changes',
      () {
    expect(
      normalizeParticipantIdentityKey(
        walletAddress: '0xABC',
        userId: 'user_1',
        senderId: 'sender_1',
      ),
      'user_1',
    );
  });

  test('wallet-free messages resolve to their canonical conversation member',
      () {
    final provider = ChatProvider();
    final conversation = Conversation.fromJson({
      'id': 'conversation-1',
      'memberProfiles': [
        {'userId': 'account-a', 'wallet': null, 'displayName': 'Artist A'}
      ],
    });
    provider.seedConversationParticipants(conversation);
    final message = ChatMessage.fromJson({
      'id': 'message-1',
      'conversationId': 'conversation-1',
      'senderUserId': 'account-a',
      'senderWallet': null,
      'message': 'Hello',
    });
    final participant = provider.resolveParticipantForMessage(
        message: message, conversation: conversation);
    expect(participant.identityKey, 'account-a');
    expect(participant.userId, 'account-a');
    expect(participant.walletAddress, isNull);
    expect(participant.displayName, 'Artist A');
    final hybrid = ChatMessage.fromJson({
      'id': 'message-2',
      'conversationId': 'conversation-1',
      'senderUserId': 'account-a',
      'senderWallet': 'linked-wallet',
      'message': 'After linking',
    });
    expect(
        provider
            .resolveParticipantForMessage(
                message: hybrid, conversation: conversation)
            .identityKey,
        participant.identityKey);
    provider.dispose();
  });

  test('stableDisplayLabel uses displayName first', () {
    const participant = ResolvedConversationParticipant(
      identityKey: 'user',
      walletAddress: '0x1234567890abcdef',
      displayName: 'Ada Lovelace',
      username: 'ada',
    );
    expect(participant.stableDisplayLabel, 'Ada Lovelace');
  });

  test('stableDisplayLabel uses username second', () {
    const participant = ResolvedConversationParticipant(
      identityKey: 'user',
      username: 'ada',
    );
    expect(participant.stableDisplayLabel, '@ada');
  });

  test('stableDisplayLabel uses compact wallet fallback', () {
    const participant = ResolvedConversationParticipant(
      identityKey: '0x1234567890abcdef',
      walletAddress: '0x1234567890abcdef',
    );
    expect(participant.stableDisplayLabel, '0x1234...cdef');
  });

  test('mergeFrom does not downgrade profileHydration to fallback', () {
    const current = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: 'Hydrated',
      source: ParticipantIdentitySource.profileHydration,
    );
    const next = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: 'Fallback',
      source: ParticipantIdentitySource.fallback,
    );

    final merged = current.mergeFrom(next);
    expect(merged.source, ParticipantIdentitySource.profileHydration);
    expect(merged.displayName, 'Hydrated');
  });

  test('mergeFrom does not replace non-empty displayName with empty', () {
    const current = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: 'Ada',
      source: ParticipantIdentitySource.messageSnapshot,
    );
    const next = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: '',
      source: ParticipantIdentitySource.profileHydration,
    );

    expect(current.mergeFrom(next).displayName, 'Ada');
  });

  test('mergeFrom upgrades conversationSnapshot to profileHydration', () {
    const current = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: 'Snapshot',
      source: ParticipantIdentitySource.conversationSnapshot,
    );
    const next = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: 'Hydrated',
      source: ParticipantIdentitySource.profileHydration,
    );

    final merged = current.mergeFrom(next);
    expect(merged.source, ParticipantIdentitySource.profileHydration);
    expect(merged.displayName, 'Hydrated');
  });

  test('hasSameVisibleIdentity detects display/avatar changes', () {
    const first = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: 'Ada',
      avatarUrl: 'a.png',
    );
    const renamed = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: 'Grace',
      avatarUrl: 'a.png',
    );
    const reavatar = ResolvedConversationParticipant(
      identityKey: 'user',
      displayName: 'Ada',
      avatarUrl: 'b.png',
    );

    expect(first.hasSameVisibleIdentity(renamed), isFalse);
    expect(first.hasSameVisibleIdentity(reavatar), isFalse);
  });
}
