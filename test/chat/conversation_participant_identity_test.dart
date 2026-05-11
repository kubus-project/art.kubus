import 'package:art_kubus/models/resolved_conversation_participant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeParticipantIdentityKey prefers wallet over userId', () {
    expect(
      normalizeParticipantIdentityKey(
        walletAddress: '0xABC',
        userId: 'user_1',
        senderId: 'sender_1',
      ),
      '0xabc',
    );
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
