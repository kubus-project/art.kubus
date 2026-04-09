part of 'chat_provider.dart';

Future<List<Map<String, dynamic>>> _chatProviderFetchMembers(
  ChatProvider provider,
  String conversationId,
) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final cache = provider._membersCache[conversationId];
  if (cache != null) {
    final ts = cache['ts'] as int? ?? 0;
    if (now - ts < 30000) {
      try {
        return (cache['result'] as List<dynamic>).cast<Map<String, dynamic>>();
      } catch (_) {}
    }
  }

  if (provider._membersRequests.containsKey(conversationId)) {
    try {
      final existing = await provider._membersRequests[conversationId];
      if (existing != null) return existing;
    } catch (_) {
      // Fall through to a fresh fetch.
    } finally {
      provider._membersRequests.remove(conversationId);
    }
  }

  final completer = provider._api.fetchConversationMembers(conversationId).then(
    (resp) {
      if (resp['success'] == true) {
        final list = (resp['data'] as List<dynamic>?) ?? [];
        provider._cacheMembers(
          conversationId,
          list,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        );
        debugPrint(
            'ChatProvider: cached ${list.length} members for conversation $conversationId');
        try {
          provider._safeNotifyListeners();
        } catch (_) {}
        try {
          final wallets = <String>[];
          for (final m in list) {
            final wallet = ((m['wallet_address'] ??
                        m['wallet'] ??
                        m['walletAddress'] ??
                        m['id'])
                    ?.toString() ??
                '');
            if (wallet.isNotEmpty) wallets.add(wallet);
          }
          if (wallets.isNotEmpty) {
            provider._prefetchUsersForWallets(wallets);
          }
        } catch (e) {
          debugPrint(
              'ChatProvider: prefetch profiles after fetchMembers failed: $e');
        }
        return list.map((e) => e as Map<String, dynamic>).toList();
      }

      provider._cacheMembers(
        conversationId,
        const <dynamic>[],
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint(
          'ChatProvider: cached 0 members (empty) for conversation $conversationId');
      try {
        provider._safeNotifyListeners();
      } catch (_) {}
      return <Map<String, dynamic>>[];
    },
  ).whenComplete(() => provider._membersRequests.remove(conversationId));

  provider._membersRequests[conversationId] = completer;
  return await completer;
}

Future<void> _chatProviderPrefetchUsersForWallets(
  ChatProvider provider,
  List<String> wallets,
) async {
  try {
    debugPrint(
        'ChatProvider._prefetchUsersForWallets: wallets=${wallets.length}');
    final uniq = wallets.where((w) => w.isNotEmpty).toSet().toList();
    if (uniq.isEmpty) return;
    final users = await UserService.getUsersByWallets(uniq);
    final updated = <String>[];
    for (final u in users) {
      if (u.id.isNotEmpty) {
        provider._cacheUser(u);
        updated.add(u.id);
      }
    }
    if (updated.isNotEmpty) {
      debugPrint(
          'ChatProvider._prefetchUsersForWallets: updated users=${updated.length}, sample=${updated.take(6).toList()}');
    }
    try {
      UserService.setUsersInCache(users);
    } catch (_) {}
    try {
      provider._safeNotifyListeners(force: true);
    } catch (_) {}
  } catch (e) {
    debugPrint('ChatProvider._prefetchUsersForWallets failed: $e');
  }
}

void _chatProviderMergeUserCache(
  ChatProvider provider,
  List<User> users,
) {
  final updated = <String>[];
  for (final u in users) {
    if (u.id.isNotEmpty) {
      provider._cacheUser(u);
      updated.add(u.id);
    }
  }
  if (updated.isNotEmpty) {
    debugPrint(
        'ChatProvider.mergeUserCache: updated ${updated.length} users, sample=${updated.take(5).toList()}');
    try {
      provider._safeNotifyListeners();
    } catch (_) {}
    try {
      UserService.setUsersInCache(users);
    } catch (_) {}
  }
}
