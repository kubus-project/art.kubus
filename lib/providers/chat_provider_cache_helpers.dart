part of 'chat_provider.dart';

void _chatProviderCacheMessages(
  ChatProvider provider,
  String conversationId,
  List<ChatMessage> messages,
) {
  final trimmed = messages.length <= ChatProvider._maxMessagesPerConversation
      ? List<ChatMessage>.from(messages)
      : List<ChatMessage>.from(
          messages.take(ChatProvider._maxMessagesPerConversation),
        );
  provider._messages[conversationId] = trimmed;
  provider._messageCacheTouchMs[conversationId] =
      DateTime.now().millisecondsSinceEpoch;
  provider._pruneCacheMap<List<ChatMessage>>(
    provider._messages,
    provider._messageCacheTouchMs,
    ChatProvider._maxCachedMessageConversations,
    preserveKey: provider._openConversationId,
  );
}

void _chatProviderTouchMessageCache(
  ChatProvider provider,
  String conversationId,
) {
  if (provider._messages.containsKey(conversationId)) {
    provider._messageCacheTouchMs[conversationId] =
        DateTime.now().millisecondsSinceEpoch;
  }
}

void _chatProviderCacheMembers(
  ChatProvider provider,
  String conversationId,
  List<dynamic> list, {
  required int timestampMs,
}) {
  provider._membersCache[conversationId] = {
    'result': list,
    'ts': timestampMs,
  };
  provider._membersCacheTouchMs[conversationId] = timestampMs;
  provider._pruneCacheMap<Map<String, dynamic>>(
    provider._membersCache,
    provider._membersCacheTouchMs,
    ChatProvider._maxCachedMemberLists,
  );
}

void _chatProviderCacheUser(ChatProvider provider, User user) {
  if (user.id.isEmpty) return;
  provider._userCache[user.id] = user;
  provider._userCacheTouchMs[user.id] = DateTime.now().millisecondsSinceEpoch;
  provider._pruneCacheMap<User>(
    provider._userCache,
    provider._userCacheTouchMs,
    ChatProvider._maxCachedUsers,
  );
}

void _chatProviderPruneCacheMap<T>(
  Map<String, T> cache,
  Map<String, int> touchMs,
  int maxEntries, {
  String? preserveKey,
}) {
  if (cache.length <= maxEntries) return;
  final entries = touchMs.entries.toList(growable: false)
    ..sort((a, b) => a.value.compareTo(b.value));
  for (final entry in entries) {
    if (cache.length <= maxEntries) break;
    if (preserveKey != null && entry.key == preserveKey) continue;
    cache.remove(entry.key);
    touchMs.remove(entry.key);
  }
}

void _chatProviderResetSessionState(
  ChatProvider provider, {
  required String reason,
  required bool notify,
}) {
  try {
    provider._pollTimer?.cancel();
    provider._pollTimer = null;
    provider._pollIntervalCurrent = null;
  } catch (_) {}
  try {
    provider._subscriptionMonitorTimer?.cancel();
    provider._subscriptionMonitorTimer = null;
    provider._subscriptionMonitorIntervalCurrent = null;
  } catch (_) {}

  provider._openConversationId = null;
  try {
    provider._socket.leaveAllConversations();
  } catch (_) {}

  provider._currentWallet = null;
  provider._conversations = [];
  provider._messages.clear();
  provider._messageCacheTouchMs.clear();
  provider._unreadCounts.clear();
  provider._membersRequests.clear();
  provider._membersCache.clear();
  provider._membersCacheTouchMs.clear();
  provider._userCache.clear();
  provider._userCacheTouchMs.clear();
  provider._lastUnauthorizedAt = null;
  provider._lastStateSignature = '';
  provider._lastTotalUnread = 0;

  if (kDebugMode) {
    debugPrint('ChatProvider: reset session state ($reason)');
  }
  if (notify) {
    provider._safeNotifyListeners(force: true);
  }
}
