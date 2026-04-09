part of 'chat_provider.dart';

void _chatProviderStartSubscriptionMonitor(ChatProvider provider) {
  try {
    provider._subscriptionMonitorTimer?.cancel();
    provider._subscriptionMonitorTimer =
        Timer.periodic(const Duration(seconds: 45), (_) async {
      try {
        final expectedWallet = WalletUtils.canonical(provider._currentWallet);
        if (expectedWallet.isEmpty) return;
        final subscribed =
            WalletUtils.canonical(provider._socket.currentSubscribedWallet);
        if (subscribed.isEmpty || subscribed != expectedWallet) {
          debugPrint(
              'ChatProvider: subscription monitor detected mismatch (subscribed=$subscribed expected=${provider._currentWallet}), attempting resubscribe');
          var ok = await provider._socket
              .connectAndSubscribe(provider._api.baseUrl, provider._currentWallet!);
          debugPrint(
              'ChatProvider subscription monitor: connectAndSubscribe -> $ok');
          if (!ok) provider._socket.subscribeUser(provider._currentWallet!);
        }
      } catch (e) {
        debugPrint('ChatProvider._startSubscriptionMonitor check failed: $e');
      }
    });
  } catch (e) {
    debugPrint('ChatProvider._startSubscriptionMonitor failed to start: $e');
  }
}

void _chatProviderBindToRefresh(
  ChatProvider provider,
  AppRefreshProvider appRefresh,
) {
  try {
    if (identical(provider._boundRefreshProvider, appRefresh)) return;
    provider._unbindRefreshProvider();
    provider._boundRefreshProvider = appRefresh;
    provider._lastChatVersion = appRefresh.chatVersion;
    provider._lastGlobalVersion = appRefresh.globalVersion;
    provider._refreshListener = () {
      try {
        if (!provider._hasAuthContext) {
          return;
        }
        if (appRefresh.chatVersion != provider._lastChatVersion) {
          provider._lastChatVersion = appRefresh.chatVersion;
          if (appRefresh.isViewActive(AppRefreshProvider.viewChat) ||
              appRefresh.isAppForeground) {
            provider.refreshConversations();
          }
        } else if (appRefresh.globalVersion != provider._lastGlobalVersion) {
          provider._lastGlobalVersion = appRefresh.globalVersion;
          if (appRefresh.isViewActive(AppRefreshProvider.viewChat) ||
              appRefresh.isAppForeground) {
            provider.refreshConversations();
          }
        }
      } catch (e) {
        debugPrint('ChatProvider.bindToRefresh handler error: $e');
      }
    };
    appRefresh.addListener(provider._refreshListener!);
  } catch (e) {
    debugPrint('ChatProvider.bindToRefresh failed: $e');
  }
}

void _chatProviderBindAuthContext(
  ChatProvider provider, {
  ProfileProvider? profileProvider,
  String? walletAddress,
  bool? isSignedIn,
}) {
  try {
    final profileWallet =
        WalletUtils.normalize(profileProvider?.currentUser?.walletAddress);
    final wallet = WalletUtils.normalize(walletAddress);
    final resolvedWallet = profileWallet.isNotEmpty ? profileWallet : wallet;
    final signedIn = isSignedIn ?? (profileProvider?.isSignedIn ?? false);
    final token = (provider._api.getAuthToken() ?? '').trim();
    final signature =
        '${token.isNotEmpty}:${resolvedWallet.toLowerCase()}:${signedIn.toString()}';

    if (signature == provider._lastAuthSignature) return;
    provider._lastAuthSignature = signature;

    final hasSession = token.isNotEmpty || resolvedWallet.isNotEmpty || signedIn;
    if (!hasSession) {
      provider._resetSessionState(reason: 'authCleared');
      return;
    }

    if (resolvedWallet.isNotEmpty &&
        !WalletUtils.equals(resolvedWallet, provider._currentWallet)) {
      unawaited(provider.setCurrentWallet(resolvedWallet));
      return;
    }

    if (!provider._initialized) {
      unawaited(provider.initialize(
          initialWallet: resolvedWallet.isNotEmpty ? resolvedWallet : null));
      return;
    }

    if (provider._conversations.isEmpty || !provider._hasAuthToken) {
      unawaited(provider.refreshConversations());
    }
  } catch (e) {
    debugPrint('ChatProvider.bindAuthContext failed: $e');
  }
}

Future<void> _chatProviderSetCurrentWallet(
  ChatProvider provider,
  String wallet,
) async {
  try {
    if (wallet.isEmpty) return;
    if (WalletUtils.equals(provider._currentWallet, wallet)) return;
    if ((provider._currentWallet ?? '').isNotEmpty) {
      provider._resetSessionState(reason: 'walletChanged', notify: false);
    }
    provider._currentWallet = wallet;
    try {
      final meResp = await provider._api.getMyProfile();
      if (meResp['success'] == true && meResp['data'] != null) {
        final me = meResp['data'] as Map<String, dynamic>;
        final canonical =
            (me['wallet_address'] ?? me['wallet'] ?? me['id'])?.toString();
        if (canonical != null && canonical.isNotEmpty) {
          provider._currentWallet = canonical;
          debugPrint(
              'ChatProvider.setCurrentWallet: resolved canonical wallet=${provider._currentWallet} from server');
        }
      }
    } catch (e) {
      debugPrint(
          'ChatProvider.setCurrentWallet: failed to resolve canonical wallet from server: $e');
    }
    debugPrint('ChatProvider.setCurrentWallet: wallet=${provider._currentWallet}');
    try {
      await provider._api.ensureAuthLoaded(walletAddress: provider._currentWallet);
    } catch (e) {
      debugPrint('setCurrentWallet: ensureAuthLoaded failed: $e');
    }
    try {
      var ok = await provider._socket
          .connectAndSubscribe(provider._api.baseUrl, provider._currentWallet!);
      if (!ok) {
        try {
          final issued =
              await provider._api.issueTokenForWallet(provider._currentWallet!);
          if (issued) {
            await provider._api.loadAuthToken();
            ok = await provider._socket.connectAndSubscribe(
                provider._api.baseUrl, provider._currentWallet!);
          }
        } catch (_) {}
      }
      if (!ok) provider._socket.subscribeUser(provider._currentWallet!);
    } catch (e) {
      debugPrint('ChatProvider.setCurrentWallet: socket subscribe failed: $e');
      try {
        provider._socket.subscribeUser(provider._currentWallet!);
      } catch (_) {}
    }
    try {
      await provider.refreshConversations();
    } catch (e) {
      debugPrint(
          'ChatProvider.setCurrentWallet: refreshConversations failed: $e');
    }
    provider._startSubscriptionMonitor();
    provider._safeNotifyListeners(force: true);
  } catch (e) {
    debugPrint('ChatProvider.setCurrentWallet error: $e');
  }
}

Future<void> _chatProviderOpenConversation(
  ChatProvider provider,
  String conversationId,
) async {
  final nid = conversationId;
  provider._openConversationId = nid;
  try {
    try {
      final ok = await provider._socket.subscribeConversation(nid);
      debugPrint(
          'ChatProvider.openConversation: subscribeConversation result for $nid -> $ok');
    } catch (e) {
      debugPrint('ChatProvider.openConversation: subscribeConversation failed: $e');
    }
  } catch (e) {
    debugPrint('ChatProvider.openConversation: subscribeConversation failed: $e');
  }
  try {
    await provider.loadMessages(nid);
  } catch (e) {
    debugPrint('ChatProvider.openConversation: loadMessages failed: $e');
  }
  try {
    await provider.markRead(nid);
  } catch (e) {
    debugPrint('ChatProvider.openConversation: markRead failed: $e');
  }

  try {
    provider._pollTimer?.cancel();
    provider._pollTimer = null;
    final shouldPoll =
        !provider._socket.isConnected || !provider._socket.isSubscribedToConversation(nid);
    if (shouldPoll) {
      provider._pollTimer =
          Timer.periodic(const Duration(seconds: 12), (timer) async {
        try {
          final resp = await provider._api.fetchMessages(nid);
          if (resp['success'] == true) {
            final items = (resp['data'] as List<dynamic>?) ?? [];
            final list = items
                .map((i) => ChatMessage.fromJson(i as Map<String, dynamic>))
                .toList();
            provider._cacheMessages(nid, list);
            provider._safeNotifyListeners();
          }
        } catch (e) {
          debugPrint('ChatProvider: periodic fetchMessages failed for $nid: $e');
        }
      });
    }
  } catch (e) {
    debugPrint('ChatProvider: Failed to start poll timer for conversation $nid: $e');
  }
}

Future<void> _chatProviderCloseConversation(
  ChatProvider provider, [
  String? conversationId,
]) async {
  final nid = conversationId ?? provider._openConversationId;
  if (nid == null) {
    return;
  }
  try {
    provider._socket.leaveConversation(nid);
  } catch (e) {
    debugPrint('ChatProvider.closeConversation: leaveConversation failed: $e');
  }
  if (provider._openConversationId != null && provider._openConversationId == nid) {
    provider._openConversationId = null;
  }
  try {
    provider._pollTimer?.cancel();
    provider._pollTimer = null;
  } catch (_) {}
}
