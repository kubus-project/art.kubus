import 'package:art_kubus/models/conversation.dart';
import 'package:art_kubus/models/message.dart';
import 'package:art_kubus/models/resolved_conversation_participant.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/screens/community/conversation_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage message({
    String id = 'm1',
    String wallet = '0x1234567890abcdef1234567890abcdef12345678',
    String? displayName,
    String? avatar,
    String text = 'hello',
  }) {
    return ChatMessage(
      id: id,
      conversationId: 'c1',
      senderWallet: wallet,
      senderDisplayName: displayName,
      senderAvatar: avatar,
      message: text,
      createdAt: DateTime(2026, 1, 1, 12),
    );
  }

  final conversation = Conversation(
    id: 'c1',
    memberProfiles: [
      ConversationMemberProfile(
        wallet: '0x1234567890abcdef1234567890abcdef12345678',
        displayName: 'Snapshot Sender',
        avatarUrl: 'https://example.test/a.png',
      ),
    ],
  );

  test(
      'Conversation participant snapshot seeds sender display name before profile hydration',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);

    provider.seedConversationParticipants(conversation);
    final resolved = provider.resolveParticipantForMessage(
      message: message(),
      conversation: conversation,
    );

    expect(resolved.stableDisplayLabel, 'Snapshot Sender');
    expect(resolved.avatarUrl, 'https://example.test/a.png');
  });

  test('Message row key remains stable when participant displayName hydrates',
      () {
    final before = message(displayName: 'Fallback');
    final after = message(displayName: 'Hydrated Sender');

    expect(conversationMessageRowKey(before), conversationMessageRowKey(after));
  });

  test('Message row key remains stable when avatar hydrates', () {
    final before = message(avatar: null);
    final after = message(avatar: 'https://example.test/avatar.png');

    expect(conversationMessageRowKey(before), conversationMessageRowKey(after));
  });

  test(
      'Hydrating participant metadata does not remove/recreate message row identity',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final chatMessage = message(displayName: 'Snapshot Sender');

    provider.seedMessageParticipants([chatMessage]);
    final keyBefore = conversationMessageRowKey(chatMessage);
    provider.upsertParticipantIdentity(
      const ResolvedConversationParticipant(
        identityKey: '0x1234567890abcdef1234567890abcdef12345678',
        walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
        displayName: 'Hydrated Sender',
        source: ParticipantIdentitySource.profileHydration,
      ),
    );
    final keyAfter = conversationMessageRowKey(chatMessage);

    expect(keyAfter, keyBefore);
  });

  test('Message presentation uses ChatProvider label over message snapshot',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final chatMessage = message(displayName: 'Legacy Snapshot');

    provider.upsertParticipantIdentity(
      const ResolvedConversationParticipant(
        identityKey: '0x1234567890abcdef1234567890abcdef12345678',
        walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
        displayName: 'Provider Sender',
        avatarUrl: 'https://example.test/provider.png',
        source: ParticipantIdentitySource.profileHydration,
      ),
    );

    final presentation = resolveMessagePresentationForTesting(
      message: chatMessage,
      conversation: conversation,
      chatProvider: provider,
    );

    expect(presentation.senderLabel, 'Provider Sender');
    expect(presentation.senderAvatarUrl, 'https://example.test/provider.png');
    expect(presentation.rowKey, conversationMessageRowKey(chatMessage));
  });

  test(
      'Participant hydration updates presentation label without changing row key',
      () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final chatMessage = message(displayName: null, avatar: null);

    final before = resolveMessagePresentationForTesting(
      message: chatMessage,
      conversation: Conversation(id: 'c1'),
      chatProvider: provider,
    );

    provider.upsertParticipantIdentity(
      const ResolvedConversationParticipant(
        identityKey: '0x1234567890abcdef1234567890abcdef12345678',
        walletAddress: '0x1234567890abcdef1234567890abcdef12345678',
        displayName: 'Hydrated Sender',
        avatarUrl: 'https://example.test/hydrated.png',
        source: ParticipantIdentitySource.profileHydration,
      ),
    );

    final after = resolveMessagePresentationForTesting(
      message: chatMessage,
      conversation: Conversation(id: 'c1'),
      chatProvider: provider,
    );

    expect(before.senderLabel, '0x1234...5678');
    expect(after.senderLabel, 'Hydrated Sender');
    expect(after.senderAvatarUrl, 'https://example.test/hydrated.png');
    expect(after.rowKey, before.rowKey);
  });

  test('Fallback wallet label remains stable before profile hydration', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final resolved = provider.resolveParticipantForMessage(
      message: message(),
      conversation: Conversation(id: 'c1'),
    );

    expect(resolved.stableDisplayLabel, '0x1234...5678');
  });

  test('Opening conversation seeds sender once, not once per bubble', () {
    final provider = ChatProvider();
    addTearDown(provider.dispose);
    final messages = [
      message(id: 'm1'),
      message(id: 'm2', text: 'second'),
      message(id: 'm3', text: 'third'),
    ];

    provider.seedMessageParticipants(messages);

    expect(provider.participantIdentitySnapshot.length, 1);
  });

  test('Non-renderable messages still do not render', () {
    final empty = message(text: '');

    expect(empty.isRenderable, isFalse);
  });
}
