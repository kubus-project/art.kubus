part of 'chat_provider.dart';

const Duration _chatSubscriptionMonitorActiveInterval =
  Duration(seconds: 60);
const Duration _chatSubscriptionMonitorPassiveInterval =
  Duration(seconds: 150);
const Duration _chatSubscriptionMonitorHealthyInterval =
    Duration(minutes: 3);
const Duration _chatSubscriptionMonitorBackgroundInterval =
    Duration(minutes: 4);

const Duration _chatConversationPollActiveInterval = Duration(seconds: 18);
const Duration _chatConversationPollPassiveInterval = Duration(seconds: 45);

bool _chatProviderIsForeground(ChatProvider provider) {
  return provider._boundRefreshProvider?.isAppForeground ?? true;
}

bool _chatProviderIsChatSurfaceActive(ChatProvider provider) {
  if ((provider._openConversationId ?? '').isNotEmpty) {
    return true;
  }
  final refresh = provider._boundRefreshProvider;
  if (refresh == null) return false;
  return refresh.isViewActive(
    AppRefreshProvider.viewChat,
    grace: const Duration(minutes: 2),
    defaultIfUnknown: false,
  );
}

bool _chatProviderSocketHealthyForWallet(ChatProvider provider) {
  final expectedWallet = WalletUtils.canonical(provider._currentWallet);
  if (expectedWallet.isEmpty) return false;
  if (!provider._socket.isConnected) return false;
  final subscribedWallet =
      WalletUtils.canonical(provider._socket.currentSubscribedWallet);
  return subscribedWallet.isNotEmpty && subscribedWallet == expectedWallet;
}

Duration? _chatProviderComputeSubscriptionMonitorInterval(ChatProvider provider) {
  if (!provider._hasAuthContext) return null;
  if (!_chatProviderIsForeground(provider)) {
    return _chatSubscriptionMonitorBackgroundInterval;
  }
  if (_chatProviderSocketHealthyForWallet(provider)) {
    return _chatSubscriptionMonitorHealthyInterval;
  }
  return _chatProviderIsChatSurfaceActive(provider)
      ? _chatSubscriptionMonitorActiveInterval
      : _chatSubscriptionMonitorPassiveInterval;
}

Duration? _chatProviderComputeConversationPollingInterval(
  ChatProvider provider,
  String conversationId,
) {
  if (!provider._hasAuthContext) return null;
  if (conversationId.trim().isEmpty) return null;
  if (!_chatProviderIsForeground(provider)) return null;

  final hasHealthySocket = provider._socket.isConnected &&
      provider._socket.isSubscribedToConversation(conversationId);
  if (hasHealthySocket) return null;

  return _chatProviderIsChatSurfaceActive(provider)
      ? _chatConversationPollActiveInterval
      : _chatConversationPollPassiveInterval;
}

void _chatProviderEvaluateSubscriptionMonitor(
  ChatProvider provider, {
  bool forceRestart = false,
}) {
  final interval = _chatProviderComputeSubscriptionMonitorInterval(provider);
  if (interval == null) {
    provider._subscriptionMonitorTimer?.cancel();
    provider._subscriptionMonitorTimer = null;
    provider._subscriptionMonitorIntervalCurrent = null;
    return;
  }

  if (!forceRestart &&
      provider._subscriptionMonitorTimer != null &&
      provider._subscriptionMonitorIntervalCurrent == interval) {
    return;
  }

  provider._subscriptionMonitorTimer?.cancel();
  provider._subscriptionMonitorIntervalCurrent = interval;
  provider._subscriptionMonitorTimer = Timer.periodic(interval, (_) async {
    try {
      if (!provider._hasAuthContext) {
        provider._subscriptionMonitorTimer?.cancel();
        provider._subscriptionMonitorTimer = null;
        provider._subscriptionMonitorIntervalCurrent = null;
        return;
      }

      final nextInterval =
          _chatProviderComputeSubscriptionMonitorInterval(provider);
      if (nextInterval == null) {
        provider._subscriptionMonitorTimer?.cancel();
        provider._subscriptionMonitorTimer = null;
        provider._subscriptionMonitorIntervalCurrent = null;
        return;
      }
      if (nextInterval != provider._subscriptionMonitorIntervalCurrent) {
        _chatProviderEvaluateSubscriptionMonitor(
          provider,
          forceRestart: true,
        );
      }

      final expectedWallet = WalletUtils.canonical(provider._currentWallet);
      if (expectedWallet.isEmpty) return;
      final subscribed =
          WalletUtils.canonical(provider._socket.currentSubscribedWallet);
      if (subscribed.isEmpty || subscribed != expectedWallet) {
        if (kDebugMode) {
          debugPrint(
              'ChatProvider: subscription monitor detected mismatch (subscribed=$subscribed expected=${provider._currentWallet}), attempting resubscribe');
        }
        var ok = await provider._socket
            .connectAndSubscribe(provider._api.baseUrl, provider._currentWallet!);
        if (kDebugMode) {
          debugPrint(
              'ChatProvider subscription monitor: connectAndSubscribe -> $ok');
        }
        if (!ok) provider._socket.subscribeUser(provider._currentWallet!);
      }

      _chatProviderEvaluateConversationPolling(provider);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ChatProvider._startSubscriptionMonitor check failed: $e');
      }
    }
  });
}

void _chatProviderEvaluateConversationPolling(
  ChatProvider provider, {
  bool forceRestart = false,
}) {
  final nid = provider._openConversationId;
  if (nid == null || nid.trim().isEmpty) {
    provider._pollTimer?.cancel();
    provider._pollTimer = null;
    provider._pollIntervalCurrent = null;
    return;
  }

  final interval = _chatProviderComputeConversationPollingInterval(provider, nid);
  if (interval == null) {
    provider._pollTimer?.cancel();
    provider._pollTimer = null;
    provider._pollIntervalCurrent = null;
    return;
  }

  if (!forceRestart &&
      provider._pollTimer != null &&
      provider._pollIntervalCurrent == interval) {
    return;
  }

  provider._pollTimer?.cancel();
  provider._pollIntervalCurrent = interval;
  provider._pollTimer = Timer.periodic(interval, (timer) async {
    try {
      if (provider._openConversationId != nid) {
        timer.cancel();
        if (identical(provider._pollTimer, timer)) {
          provider._pollTimer = null;
          provider._pollIntervalCurrent = null;
        }
        return;
      }

      final nextInterval =
          _chatProviderComputeConversationPollingInterval(provider, nid);
      if (nextInterval == null) {
        timer.cancel();
        if (identical(provider._pollTimer, timer)) {
          provider._pollTimer = null;
          provider._pollIntervalCurrent = null;
        }
        return;
      }
      if (nextInterval != provider._pollIntervalCurrent) {
        _chatProviderEvaluateConversationPolling(provider, forceRestart: true);
        return;
      }

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
      if (kDebugMode) {
        debugPrint('ChatProvider: periodic fetchMessages failed for $nid: $e');
      }
    }
  });
}

void _chatProviderEvaluatePollingCadence(
  ChatProvider provider, {
  bool forceRestart = false,
}) {
  _chatProviderEvaluateSubscriptionMonitor(
    provider,
    forceRestart: forceRestart,
  );
  _chatProviderEvaluateConversationPolling(
    provider,
    forceRestart: forceRestart,
  );
}

void _chatProviderHandleAppForegroundChanged(
  ChatProvider provider,
  bool isForeground,
) {
  _chatProviderEvaluatePollingCadence(provider, forceRestart: true);
  if (isForeground && provider._hasAuthContext) {
    unawaited(provider.refreshConversations());
  }
}

void _chatProviderHandleViewVisibilityChanged(ChatProvider provider) {
  _chatProviderEvaluatePollingCadence(provider, forceRestart: true);
}

void _chatProviderStartSubscriptionMonitor(ChatProvider provider) {
  try {
    _chatProviderEvaluateSubscriptionMonitor(provider, forceRestart: true);
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
          _chatProviderEvaluatePollingCadence(provider, forceRestart: true);
          return;
        }
        final shouldRefreshConversations =
            _chatProviderIsChatSurfaceActive(provider) ||
                !_chatProviderSocketHealthyForWallet(provider);
        if (appRefresh.chatVersion != provider._lastChatVersion) {
          provider._lastChatVersion = appRefresh.chatVersion;
          if (shouldRefreshConversations) {
            provider.refreshConversations();
          }
        } else if (appRefresh.globalVersion != provider._lastGlobalVersion) {
          provider._lastGlobalVersion = appRefresh.globalVersion;
          if (shouldRefreshConversations) {
            provider.refreshConversations();
          }
        }
        _chatProviderEvaluatePollingCadence(provider);
      } catch (e) {
        debugPrint('ChatProvider.bindToRefresh handler error: $e');
      }
    };
    appRefresh.addListener(provider._refreshListener!);
    _chatProviderEvaluatePollingCadence(provider, forceRestart: true);
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
    _chatProviderEvaluateConversationPolling(provider, forceRestart: true);
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
    _chatProviderEvaluateConversationPolling(provider, forceRestart: true);
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
    _chatProviderEvaluateConversationPolling(provider, forceRestart: true);
  } catch (_) {}
}
