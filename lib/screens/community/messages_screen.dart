import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/themeprovider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/cache_provider.dart';
import '../../services/user_service.dart';
import '../../services/backend_api_service.dart';
import '../../models/user.dart';
import '../../models/conversation.dart';
import '../../core/conversation_navigator.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/empty_state_card.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/event_bus.dart';
import '../../utils/wallet_utils.dart';
import '../../utils/media_url_resolver.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late ChatProvider _chatProvider;
  late CacheProvider _cacheProvider;
  final Map<String, String?> _conversationAvatars = {};
  final Map<String, String?> _conversationNames = {};
  final Map<String, List<String>> _convToWalletList = {};
  final Set<String> _pendingMemberLoads = {};

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _cacheProvider = Provider.of<CacheProvider>(context, listen: false);
    _chatProvider.initialize();
    _chatProvider.refreshConversations();
    _chatProvider.addListener(_onChatProviderChanged);
    // Persisted user cache initialization moved to profile/wallet flows; MessagesScreen reads cache if available.
    // However, to avoid flicker we ensure that the persisted cache is initialized here as soon as we detect a persisted wallet
    // and the in-memory cache is empty for that wallet (defensive initialization only).
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    Future(() async {
      try {
        final wallet = profileProvider.currentUser?.walletAddress ??
            (await SharedPreferences.getInstance()).getString('wallet_address');
        if (wallet != null && wallet.isNotEmpty) {
          // If we don't have a cached entry for any displayed participant, initialize persisted cache
          final cached = UserService.getCachedUser(wallet);
          if (cached == null) {
            try { await UserService.initialize(); } catch (_) {}
          }
        }
      } catch (_) {}
      // After ensuring persisted cache is available, seed our per-screen maps for immediate render
      try { _seedInitialConversationMaps(); } catch (_) {}
    });
      try {
        final allConvs = _chatProvider.conversations;
        for (final c in allConvs) {
            try {
            final pre = _chatProvider.getPreloadedProfileMapsForConversation(c.id);
            final avatars = (pre['avatars'] as Map<String, String?>?) ?? {};
            final names = (pre['names'] as Map<String, String?>?) ?? {};
            final membersList = (pre['members'] as List<dynamic>? ?? const []);
            if (membersList.isNotEmpty) {
              _setConversationMembers(c.id, membersList);
            }
            // Seed with provider preloaded maps first
            if (avatars.isNotEmpty) {
              final firstKey = avatars.keys.isNotEmpty ? avatars.keys.first : null;
              if (firstKey != null) {
                _storeConversationAvatar(c.id, avatars[firstKey], walletHint: firstKey);
              }
            }
            if (names.isNotEmpty) {
              final firstKey = names.keys.isNotEmpty ? names.keys.first : null;
              if (firstKey != null) _conversationNames[c.id] = names[firstKey] ?? '';
            }
            // Then attempt to pick values from persisted UserService cache to reduce flicker
            final convMap = _conversationAvatars[c.id];
            if (convMap == null || convMap.isEmpty) {
              if (membersList.isNotEmpty) {
                final firstWallet = _resolveMemberWallet(membersList.first);
                final cachedUser = UserService.getCachedUser(firstWallet) ?? _chatProvider.getCachedUser(firstWallet);
                if (cachedUser != null) {
                  // Prefer an explicit profile image from cache; do not fabricate a placeholder here.
                  if (cachedUser.profileImageUrl != null && cachedUser.profileImageUrl!.isNotEmpty) {
                    _storeConversationAvatar(c.id, cachedUser.profileImageUrl, walletHint: cachedUser.id);
                  }
                  _conversationNames[c.id] = cachedUser.name;
                }
              }
            }
          } catch (_) {}
        }
        if (mounted) setState(() {});
      } catch (_) {}
    // Proactively ensure members are loaded only for conversations that matter immediately.
    // Strategy: prefetch for conversations with unread messages plus N most recent conversations.
    try {
      final allConvs = _chatProvider.conversations;
      if (allConvs.isNotEmpty) {
        // Synchronously populate our per-screen caches from provider preloaded maps so
        // the UI shows avatars and names immediately on first build, avoiding flicker.
        for (final c in allConvs) {
          try {
            final pre = _chatProvider.getPreloadedProfileMapsForConversation(c.id);
            final avatars = (pre['avatars'] as Map<String, String?>?) ?? {};
            final names = (pre['names'] as Map<String, String?>?) ?? {};
            final membersList = (pre['members'] as List<dynamic>? ?? const []);
            if (membersList.isNotEmpty) {
              _setConversationMembers(c.id, membersList);
            }
            if (avatars.isNotEmpty) {
              // For direct conversations choose the avatar associated with the first avatar entry
              final firstKey = avatars.keys.isNotEmpty ? avatars.keys.first : null;
              if (firstKey != null) {
                _storeConversationAvatar(c.id, avatars[firstKey], walletHint: firstKey);
              }
            }
            if (names.isNotEmpty) {
              final firstKey = names.keys.isNotEmpty ? names.keys.first : null;
              if (firstKey != null) _conversationNames[c.id] = names[firstKey] ?? '';
            }
              // Do not set generated safe avatars here; let AvatarWidget render a safe fallback when needed.
          } catch (_) {}
        }
        final unreadIds = <String>{};
        final unreadMap = _chatProvider.unreadCounts;
        for (final c in allConvs) {
          if ((unreadMap[c.id] ?? 0) > 0) unreadIds.add(c.id);
        }
        // Also prefetch for the most recent conversations (top 5) as a fallback for immediate UI
        final recentIds = allConvs.take(5).map((c) => c.id).toSet();
        final toPrefetchIds = <String>{...unreadIds, ...recentIds};
        for (final c in allConvs) {
          if (!toPrefetchIds.contains(c.id)) continue; // skip uninteresting convs
          if ((_conversationAvatars[c.id] ?? '').isEmpty || (_conversationNames[c.id] ?? '').isEmpty) {
            // fire-and-forget per-conversation load
            _ensureConversationMembersLoaded(c.id);
          }
        }
        // Also attempt to load avatars in batch (non-blocking) only for convs we selected
        final toPrefetchConvs = allConvs.where((c) => toPrefetchIds.contains(c.id)).toList();
        _loadConversationAvatars(targetConvs: toPrefetchConvs);
      }
    } catch (_) {}
  }

  void _onChatProviderChanged() {
    try {
      final allConvs = _chatProvider.conversations;
      // Seed avatars and display names synchronously from provider preloads and persisted cache
      try {
        for (final c in allConvs) {
          try {
            final pre = _chatProvider.getPreloadedProfileMapsForConversation(c.id);
            final avatars = (pre['avatars'] as Map<String, String?>?) ?? {};
            final names = (pre['names'] as Map<String, String?>?) ?? {};
            final membersList = (pre['members'] as List<dynamic>? ?? const []);
            if (membersList.isNotEmpty) {
              _setConversationMembers(c.id, membersList);
            }
            if (avatars.isNotEmpty) {
              final firstKey = avatars.keys.isNotEmpty ? avatars.keys.first : null;
              if (firstKey != null) {
                _storeConversationAvatar(c.id, avatars[firstKey], walletHint: firstKey);
              }
            }
            if (names.isNotEmpty) {
              final firstKey = names.keys.isNotEmpty ? names.keys.first : null;
              if (firstKey != null) _conversationNames[c.id] = names[firstKey] ?? '';
            }
            if ((_conversationAvatars[c.id] ?? '').isEmpty) {
              if (membersList.isNotEmpty) {
                final firstWallet = _resolveMemberWallet(membersList.first);
                final cached = UserService.getCachedUser(firstWallet) ?? _chatProvider.getCachedUser(firstWallet);
                if (cached != null) {
                  _storeConversationAvatar(c.id, cached.profileImageUrl, walletHint: cached.id);
                  _conversationNames[c.id] = cached.name;
                }
              }
            }
          } catch (_) {}
        }
        if (mounted) setState(() {});
      } catch (_) {}
      if (allConvs.isNotEmpty) {
        final unreadIds = <String>{};
        final unreadMap = _chatProvider.unreadCounts;
        for (final c in allConvs) {
          if ((unreadMap[c.id] ?? 0) > 0) unreadIds.add(c.id);
        }
        final recentIds = allConvs.take(5).map((c) => c.id).toSet();
        final toPrefetchIds = <String>{...unreadIds, ...recentIds};
        final toPrefetchConvs = allConvs.where((c) => toPrefetchIds.contains(c.id)).toList();
        _loadConversationAvatars(targetConvs: toPrefetchConvs);
      }
    } catch (_) {}
  }

  void _seedInitialConversationMaps() {
    try {
      final allConvs = _chatProvider.conversations;
      for (final c in allConvs) {
        try {
          final pre = _chatProvider.getPreloadedProfileMapsForConversation(c.id);
          final avatars = (pre['avatars'] as Map<String, String?>?) ?? {};
          final names = (pre['names'] as Map<String, String?>?) ?? {};
          final membersList = (pre['members'] as List<dynamic>? ?? const []);
          if (membersList.isNotEmpty) {
            _setConversationMembers(c.id, membersList);
          }
          if (avatars.isNotEmpty) {
            final firstKey = avatars.keys.isNotEmpty ? avatars.keys.first : null;
            if (firstKey != null) {
              _storeConversationAvatar(c.id, avatars[firstKey], walletHint: firstKey);
            }
          }
          if (names.isNotEmpty) {
            final firstKey = names.keys.isNotEmpty ? names.keys.first : null;
            if (firstKey != null) _conversationNames[c.id] = names[firstKey] ?? '';
          }
            if ((_conversationAvatars[c.id] ?? '').isEmpty) {
              if (membersList.isNotEmpty) {
                final firstWallet = _resolveMemberWallet(membersList.first);
                final cachedUser = UserService.getCachedUser(firstWallet) ?? _chatProvider.getCachedUser(firstWallet);
              if (cachedUser != null) {
                _storeConversationAvatar(c.id, cachedUser.profileImageUrl, walletHint: cachedUser.id);
                _conversationNames[c.id] = cachedUser.name;
              }
            }

          }
        } catch (_) {}
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _setConversationMembers(String conversationId, Iterable<dynamic> members) {
    final normalized = _normalizeWalletEntries(members);
    if (normalized.isEmpty) return;
    _convToWalletList[conversationId] = normalized;
  }

  List<String> _normalizeWalletEntries(Iterable<dynamic> source) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final entry in source) {
      final wallet = _resolveMemberWallet(entry);
      if (wallet.isEmpty) continue;
      final canonical = WalletUtils.canonical(wallet);
      if (canonical.isEmpty) continue;
      if (seen.add(canonical)) normalized.add(wallet);
    }
    return normalized;
  }

  String _resolveMemberWallet(dynamic entry, {String? fallback}) {
    if (entry == null) return WalletUtils.normalize(fallback);
    if (entry is String) return WalletUtils.normalize(entry);
    if (entry is Map<String, dynamic>) {
      return WalletUtils.resolveFromMap(entry, fallback: fallback);
    }
    try {
      return WalletUtils.normalize(entry.toString());
    } catch (_) {
      return WalletUtils.normalize(fallback);
    }
  }

  String? _normalizeAvatarUrl(String? raw) {
    return MediaUrlResolver.resolve(raw);
  }

  bool _storeConversationAvatar(String conversationId, String? avatarUrl, {String? walletHint}) {
    final normalized = _normalizeAvatarUrl(avatarUrl);
    if (normalized == null || normalized.isEmpty) {
      _conversationAvatars.remove(conversationId);
      return false;
    }
    if (_isFabricatedAvatar(normalized, walletHint)) {
      _conversationAvatars.remove(conversationId);
      return false;
    }
    _conversationAvatars[conversationId] = normalized;
    return true;
  }

  bool _isFabricatedAvatar(String? url, String? wallet) {
    if (url == null || url.isEmpty) return false;
    if (UserService.isPlaceholderAvatarUrl(url)) {
      return true;
    }
    try {
      final normalizedWallet = WalletUtils.canonical(wallet);
      if (normalizedWallet.isNotEmpty && url == UserService.safeAvatarUrl(normalizedWallet)) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _loadConversationAvatars({List<Conversation>? targetConvs}) async {
    try {
      final convs = targetConvs ?? _chatProvider.conversations;
      if (convs.isEmpty) return;
      // Determine wallets to fetch (for one-to-one conversations use other member
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final myWallet = WalletUtils.normalize(profile.currentUser?.walletAddress);
      final Map<String, List<String>> convToWallet = {};
      final Set<String> wallets = {};
      final Set<String> walletCanonicals = {};
      final futures = <Future>[];
      // Avoid fetching members for all conversations at once (throttle to avoid rate limits)
      final toFetch = convs.take(25).toList();
      for (final c in toFetch) {
        // fetch members for this conversation
          futures.add(_chatProvider.fetchMembers(c.id).then((mbrs) {
          final others = (mbrs as List)
              .map((entry) => _resolveMemberWallet(entry))
              .where((w) => w.isNotEmpty && !WalletUtils.equals(w, myWallet))
              .toList();
          if (others.isNotEmpty) {
            convToWallet[c.id] = others;
            for (final w in others) {
              final canonical = WalletUtils.canonical(w);
              if (canonical.isEmpty) continue;
              if (walletCanonicals.add(canonical)) {
                wallets.add(w);
              }
            }
          }
        }).catchError((_) {}));
      }
      // Limit concurrency: process in batches of 6
      const int batchSize = 6;
      for (var i = 0; i < futures.length; i += batchSize) {
        final batch = futures.skip(i).take(batchSize).toList();
        await Future.wait(batch);
      }
      if (wallets.isEmpty) return;
        final users = await UserService.getUsersByWallets(wallets.toList());
      if (!mounted) return;
      try { EventBus().emitProfilesUpdated(users); } catch (_) {}
      for (final c in convToWallet.keys) {
        final walletsForConv = convToWallet[c]!;
        _setConversationMembers(c, walletsForConv);
        // For direct conv, find first other participant for avatar; for group, we'll use composite later
          if (walletsForConv.isNotEmpty) {
            for (final wallet in walletsForConv) {
              _hydrateConversationFromCache(c, wallet);
            }
            final wallet = walletsForConv.first;
            User? matchedUser;
            for (final candidate in users) {
              if (WalletUtils.equals(candidate.id, wallet)) {
                matchedUser = candidate;
                break;
              }
            }
            final avatar = matchedUser?.profileImageUrl ?? '';
            final name = matchedUser?.name ?? '';
            // Only set avatar from a real profileImageUrl. Do not fabricate placeholders here — AvatarWidget will handle safe fallbacks.
            final currentAvatar = _conversationAvatars[c];
            final currentName = _conversationNames[c];
            if ((currentAvatar == null || currentAvatar.isEmpty) && avatar.isNotEmpty) {
              _storeConversationAvatar(c, avatar, walletHint: wallet);
            }
            final shouldReplaceName = (currentName == null || currentName.isEmpty || WalletUtils.equals(currentName, wallet));
            if (shouldReplaceName) {
              _conversationNames[c] = name.isNotEmpty ? name : wallet;
            }
            _persistWalletProfile(wallet, avatar: avatar, displayName: name);
        }
      }
      setState(() {});
    } catch (e) {
      debugPrint('MessagesScreen: _loadConversationAvatars failed: $e');
    }
  }

  Widget _buildGroupAvatar(List<String> wallets, double size) {
    // Build a composite avatar widget from up to 4 member avatars.
    final count = wallets.length;
    if (count == 0) return CircleAvatar(radius: size / 2, child: Icon(Icons.group));
    // Positioning for 1..4 avatars
    if (count == 1) {
      // Let AvatarWidget handle loading and fallback; pass null for avatarUrl so it resolves the user's avatar via wallet.
      return SizedBox(width: size, height: size, child: AvatarWidget(avatarUrl: null, wallet: wallets[0], radius: size/2, allowFabricatedFallback: false));
    }
    // For 2 avatars: left/right
    if (count == 2) {
      return SizedBox(width: size, height: size, child: Stack(children: [
        Positioned(left: 0, top: size * 0.15, child: AvatarWidget(avatarUrl: null, wallet: wallets[0], radius: size * 0.35, allowFabricatedFallback: false)),
        Positioned(right: 0, top: size * 0.15, child: AvatarWidget(avatarUrl: null, wallet: wallets[1], radius: size * 0.35, allowFabricatedFallback: false)),
      ]));
    }
    // For 3 avatars: triangle
    if (count == 3) {
      return SizedBox(width: size, height: size, child: Stack(children: [
        Positioned(left: size * 0.25, top: 0, child: AvatarWidget(avatarUrl: null, wallet: wallets[0], radius: size * 0.28, allowFabricatedFallback: false)),
        Positioned(left: 0, bottom: 0, child: AvatarWidget(avatarUrl: null, wallet: wallets[1], radius: size * 0.28, allowFabricatedFallback: false)),
        Positioned(right: 0, bottom: 0, child: AvatarWidget(avatarUrl: null, wallet: wallets[2], radius: size * 0.28, allowFabricatedFallback: false)),
      ]));
    }
    // 4 or more: 2x2 grid using first 4
    return SizedBox(width: size, height: size, child: Stack(children: [
      Positioned(left: 0, top: 0, child: AvatarWidget(avatarUrl: null, wallet: wallets[0], radius: size * 0.28, allowFabricatedFallback: false)),
      Positioned(right: 0, top: 0, child: AvatarWidget(avatarUrl: null, wallet: wallets[1], radius: size * 0.28, allowFabricatedFallback: false)),
      Positioned(left: 0, bottom: 0, child: AvatarWidget(avatarUrl: null, wallet: wallets[2], radius: size * 0.28, allowFabricatedFallback: false)),
      Positioned(right: 0, bottom: 0, child: AvatarWidget(avatarUrl: null, wallet: wallets[3], radius: size * 0.28, allowFabricatedFallback: false)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text(l10n.messagesTitle),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, cp, _) {
          final convs = cp.conversations;
          if (convs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: EmptyStateCard(
                  icon: Icons.chat_bubble_outline,
                  title: l10n.messagesEmptyNoConversationsTitle,
                  description: l10n.messagesEmptyNoConversationsDescription,
                  showAction: true,
                  actionLabel: l10n.messagesEmptyStartChatAction,
                  onAction: () async {
                    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => _CreateConversationDialog());
                    if (!mounted) return;
                    if (result != null && result['members'] != null) {
                      await _chatProvider.createConversation(result['title'] as String? ?? '', result['isGroup'] as bool? ?? false, (result['members'] as List<String>));
                    }
                  },
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: convs.length,
            itemBuilder: (context, idx) {
              final c = convs[idx];
              String? avatar = c.displayAvatar ?? _conversationAvatars[c.id];
              final memberWallets = _convToWalletList[c.id] ?? <String>[];
              if (memberWallets.isNotEmpty) {
                for (final wallet in memberWallets) {
                  _hydrateConversationFromCache(c.id, wallet);
                }
              }
              final otherWallet = (!c.isGroup && memberWallets.isNotEmpty) ? memberWallets.first : '';
              String widgetWallet = otherWallet.isNotEmpty ? otherWallet : c.id;
              // Prefer provider preloaded avatars when available (avoid local per-screen duplication)
              if ((avatar == null || avatar.isEmpty)) {
                try {
                  final pre = Provider.of<ChatProvider>(context, listen: false).getPreloadedProfileMapsForConversation(c.id);
                  final avatars = (pre['avatars'] as Map<String, String?>?) ?? {};
                  if (avatars.isNotEmpty) {
                    final firstKey = avatars.keys.isNotEmpty ? avatars.keys.first : '';
                    if (firstKey.isNotEmpty) avatar = avatars[firstKey];
                  }
                } catch (_) {}
              }
              avatar = _normalizeAvatarUrl(avatar);
              if (_isFabricatedAvatar(avatar, widgetWallet)) {
                avatar = null;
              }
              Widget leading;
              if (avatar != null && avatar.isNotEmpty) {
                final isLoading = false; // explicit avatar provided -> not loading
                // If this is a direct conversation, prefer to associate the avatar
                // with the other participant's wallet so AvatarWidget can fetch
                // the authoritative profile. Fall back to conversation id when
                // unknown (group avatars or server-provided URLs).
                leading = AvatarWidget(avatarUrl: avatar, wallet: widgetWallet, radius: 20, isLoading: isLoading, allowFabricatedFallback: false);
              } else if (c.isGroup) {
                if (memberWallets.isNotEmpty) {
                  leading = _buildGroupAvatar(memberWallets, 48);
                } else {
                  leading = CircleAvatar(radius: 20, child: Icon(Icons.group));
                }
              } else {
                // Fallback for one-to-one: use other participant's wallet if available
                if (otherWallet.isNotEmpty) {
                  // Prefer cached user profile avatar if available (ChatProvider cache first, then persisted cache)
                  final cached = cp.getCachedUser(otherWallet);
                  String? fallbackAvatar;
                  if (cached != null && (cached.profileImageUrl ?? '').isNotEmpty) {
                    fallbackAvatar = cached.profileImageUrl!;
                  } else {
                    try {
                      final pre = cp.getPreloadedProfileMapsForConversation(c.id);
                      final avatars = (pre['avatars'] as Map<String, String?>?) ?? {};
                      if (avatars.containsKey(otherWallet)) fallbackAvatar = avatars[otherWallet];
                    } catch (_) {}
                    // As a last-resort, check persisted UserService cache synchronously
                    if (fallbackAvatar == null || fallbackAvatar.isEmpty) {
                      final persisted = UserService.getCachedUser(otherWallet);
                      if (persisted != null && (persisted.profileImageUrl ?? '').isNotEmpty) fallbackAvatar = persisted.profileImageUrl;
                    }
                  }
                  // Prefer any explicit avatar; do not fabricate a placeholder here — AvatarWidget will render a safe fallback.
                  final effectiveFallbackAvatar = _normalizeAvatarUrl(fallbackAvatar);
                  final sanitizedFallback = _isFabricatedAvatar(effectiveFallbackAvatar, otherWallet) ? null : effectiveFallbackAvatar;
                  final isLoading = (otherWallet.isNotEmpty && cp.getCachedUser(otherWallet) == null && UserService.getCachedUser(otherWallet) == null && (_conversationAvatars[c.id] == null || _conversationAvatars[c.id]!.isEmpty));
                  leading = AvatarWidget(avatarUrl: sanitizedFallback, wallet: otherWallet, radius: 20, isLoading: isLoading, allowFabricatedFallback: false);
                } else {
                  // No wallet available: render initials locally to avoid network call
                  final name = c.title ?? (c.isGroup ? l10n.messagesFallbackGroupTitle : c.title ?? l10n.messagesFallbackConversationTitle);
                  final parts = name.trim().split(RegExp(r'\s+'));
                  final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
                  final isLoading = (_conversationNames[c.id] == null || _conversationNames[c.id]!.isEmpty) && (_convToWalletList[c.id]?.isNotEmpty ?? false);
                  leading = Stack(alignment: Alignment.center, children: [
                    CircleAvatar(child: Text(initials.isNotEmpty ? initials : l10n.messagesFallbackConversationInitial)),
                    if (isLoading) SizedBox(width: 20, height: 20, child: InlineLoading(expand: true, shape: BoxShape.circle, tileSize: 4.0, duration: Duration(milliseconds: 700)))
                  ]);
                }
              // If we still don't have avatar/name, try to proactively load members for this conversation
              }
              if ((avatar == null || avatar.isEmpty) && !_pendingMemberLoads.contains(c.id)) {
                _ensureConversationMembersLoaded(c.id);
              }
              // Determine title preferring conversation title, then cached user name for direct chats, then precomputed conversation name
              String titleText = c.title ?? '';
              if (titleText.isEmpty) {
                if (!c.isGroup) {
                  final fallbackWallet = (_convToWalletList[c.id] != null && _convToWalletList[c.id]!.isNotEmpty) ? _convToWalletList[c.id]!.first : '';
                  final cached = (fallbackWallet.isNotEmpty) ? cp.getCachedUser(fallbackWallet) : null;
                  if (cached != null && cached.name.isNotEmpty) {
                    titleText = cached.name;
                  } else {
                    final persisted = UserService.getCachedUser(fallbackWallet);
                    if (persisted != null && persisted.name.isNotEmpty) titleText = persisted.name;
                  }
                }
                if (titleText.isEmpty) {
                  titleText = c.isGroup
                      ? l10n.messagesFallbackGroupTitle
                      : (_conversationNames[c.id] ?? l10n.messagesFallbackConversationTitle);
                }
              }
              Widget titleWidget;
              if ((titleText.isEmpty || titleText == l10n.messagesFallbackConversationTitle) && _convToWalletList[c.id]?.isNotEmpty == true) {
                final first = memberWallets.isNotEmpty ? memberWallets.first : '';
                final cached = cp.getCachedUser(first);
                if (cached == null && (_conversationNames[c.id] == null || _conversationNames[c.id]!.isEmpty)) {
                  titleWidget = SizedBox(height: 16, width: 120, child: InlineLoading(expand: true, borderRadius: BorderRadius.circular(6), tileSize: 6.0));
                } else {
                  titleWidget = Text(titleText.isNotEmpty ? titleText : l10n.messagesFallbackConversationTitle);
                }
              } else {
                titleWidget = Text(titleText);
              }
              final unreadCount = (cp.unreadCounts[c.id] ?? 0);
              return ListTile(
                leading: leading,
                title: titleWidget,
                subtitle: Text(c.lastMessage ?? ''),
                trailing: unreadCount > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeProvider>(context).accentColor,
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        constraints: const BoxConstraints(minWidth: 28),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Provider.of<ThemeProvider>(context).onAccentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                onTap: () async {
                  // Ensure member avatars/names are preloaded into ChatProvider cache; give a short timeout so navigation flows fast
                  List<String> wallets = [];
                  try {
                    await _ensureConversationMembersLoaded(c.id).timeout(const Duration(milliseconds: 700));
                    wallets = _convToWalletList[c.id] ?? [];
                  } catch (_) {
                    wallets = _convToWalletList[c.id] ?? [];
                  }
                  // Capture context-friendly variables before any more async awaits
                  // keep reference of provider 'cp' in closure if needed (no-op)
                  // Build preloaded maps for avatars and display names from cached users and our screen-level caches
                  final Map<String, String?> preAvatars = {};
                  final Map<String, String?> preNames = {};
                  for (final w in wallets) {
                    final cached = cp.getCachedUser(w);
                    if (cached != null) {
                      if (cached.profileImageUrl != null && cached.profileImageUrl!.isNotEmpty) preAvatars[w] = cached.profileImageUrl;
                      if (cached.name.isNotEmpty) preNames[w] = cached.name;
                    }
                    // also allow our screen-level maps as fallback
                    if (!preAvatars.containsKey(w) && (_conversationAvatars[c.id] ?? '').isNotEmpty) preAvatars[w] = _conversationAvatars[c.id];
                    if (!preNames.containsKey(w) && (_conversationNames[c.id] ?? '').isNotEmpty) preNames[w] = _conversationNames[c.id];
                    if (!preAvatars.containsKey(w)) {
                      final cachedAvatar = _cacheProvider.getAvatar(w);
                      if ((cachedAvatar ?? '').isNotEmpty) preAvatars[w] = cachedAvatar;
                    }
                    if (!preNames.containsKey(w)) {
                      final cachedName = _cacheProvider.getDisplayName(w);
                      if ((cachedName ?? '').isNotEmpty) preNames[w] = cachedName;
                    }
                  }
                  // Defensive preloads: ensure we don't pass an empty members list (which blocks
                  // ConversationScreen from falling back to provider-level preloads). If wallets
                  // is empty, try provider preloads or cached conv-to-wallet list. Also ensure
                  // avatar/name entries exist for the primary member when possible.
                  if (!mounted) return;
                  List<String>? finalMembers = wallets.isNotEmpty ? wallets : null;
                  if (finalMembers == null) {
                    try {
                      final p = cp.getPreloadedProfileMapsForConversation(c.id);
                      final inferred = (p['members'] as List<dynamic>?)?.cast<String>() ?? <String>[];
                      if (inferred.isNotEmpty) finalMembers = inferred;
                    } catch (_) {}
                  }
                  // As last-resort, try screen-level conv->wallet mapping
                  if ((finalMembers == null || finalMembers.isEmpty) && (_convToWalletList[c.id]?.isNotEmpty ?? false)) {
                    finalMembers = List<String>.from(_convToWalletList[c.id]!);
                  }

                  // Ensure avatars/names include an entry for the primary member when available
                  if (finalMembers != null && finalMembers.isNotEmpty) {
                    final primary = finalMembers.first;
                    if (!preAvatars.containsKey(primary) || (preAvatars[primary] == null || preAvatars[primary]!.isEmpty)) {
                      // prefer ChatProvider cache, then our screen-level avatar cache
                      final cached = cp.getCachedUser(primary);
                      if (cached != null && (cached.profileImageUrl ?? '').isNotEmpty) {
                        preAvatars[primary] = cached.profileImageUrl;
                      } else if ((_conversationAvatars[c.id] ?? '').isNotEmpty) {
                        preAvatars[primary] ??= _conversationAvatars[c.id];
                      }
                    }
                    if (!preNames.containsKey(primary) || (preNames[primary] == null || preNames[primary]!.isEmpty)) {
                      final cached = cp.getCachedUser(primary);
                      if (cached != null && cached.name.isNotEmpty) {
                        preNames[primary] = cached.name;
                      } else if ((_conversationNames[c.id] ?? '').isNotEmpty) {
                        preNames[primary] ??= _conversationNames[c.id];
                      }
                    }
                  }

                  if (!context.mounted) return;
                  ConversationNavigator.openConversationWithPreload(
                    context,
                    c,
                    preloadedMembers: finalMembers,
                    preloadedAvatars: preAvatars.isNotEmpty ? preAvatars : null,
                    preloadedDisplayNames: preNames.isNotEmpty ? preNames : null,
                  );
                },
              );
            },
          );
        }
      ),
    );
  }

  // Proactively fetch members and resolve avatars/names for a single conversation row.
  Future<void> _ensureConversationMembersLoaded(String conversationId) async {
    if (_pendingMemberLoads.contains(conversationId)) return;
    _pendingMemberLoads.add(conversationId);
    try {
      final mbrs = await _chatProvider.fetchMembers(conversationId);
      if (!mounted) return;
    
        final profile = Provider.of<ProfileProvider>(context, listen: false);
        final myWallet = WalletUtils.normalize(profile.currentUser?.walletAddress);
        final wallets = (mbrs as List)
          .map((entry) => _resolveMemberWallet(entry))
          .where((w) => w.isNotEmpty && !WalletUtils.equals(w, myWallet))
          .toList();
        if (wallets.isEmpty) return;
        _setConversationMembers(conversationId, wallets);
      for (final wallet in wallets) {
        _hydrateConversationFromCache(conversationId, wallet);
      }
      try {
        // Prefer cached user profiles from ChatProvider to avoid duplicate network calls
        User? cachedUser;
        for (final w in wallets) {
          final cu = _chatProvider.getCachedUser(w);
          if (cu != null) { cachedUser = cu; break; }
        }
        if (cachedUser != null) {
          final avatar = cachedUser.profileImageUrl ?? '';
          final currentAvatar = _conversationAvatars[conversationId];
          final currentName = _conversationNames[conversationId];
          final shouldReplaceAvatar = (currentAvatar == null || currentAvatar.isEmpty);
          if (shouldReplaceAvatar && avatar.isNotEmpty) {
            _storeConversationAvatar(conversationId, avatar, walletHint: cachedUser.id);
          }
          final shouldReplaceName = (currentName == null || currentName.isEmpty || WalletUtils.equals(currentName, cachedUser.id));
          if (shouldReplaceName) {
            _conversationNames[conversationId] = cachedUser.name.isNotEmpty ? cachedUser.name : cachedUser.id;
          }
          _persistWalletProfile(cachedUser.id, avatar: avatar, displayName: cachedUser.name);
        } else {
          final users = await UserService.getUsersByWallets(wallets);
            try { EventBus().emitProfilesUpdated(users); } catch (_) {}
          if (users.isNotEmpty) {
            final u = users.firstWhere((x) => wallets.contains(x.id), orElse: () => users.first);
            final avatar = u.profileImageUrl ?? '';
            final currentAvatar = _conversationAvatars[conversationId];
            final currentName = _conversationNames[conversationId];
            final shouldReplaceAvatar = (currentAvatar == null || currentAvatar.isEmpty);
            if (shouldReplaceAvatar && avatar.isNotEmpty) {
              _storeConversationAvatar(conversationId, avatar, walletHint: u.id);
            }
            final shouldReplaceName = (currentName == null || currentName.isEmpty || WalletUtils.equals(currentName, u.id));
            if (shouldReplaceName) {
              _conversationNames[conversationId] = u.name.isNotEmpty ? u.name : u.id;
            }
            _persistWalletProfile(u.id, avatar: avatar, displayName: u.name);
            debugPrint('MessagesScreen: loaded members for $conversationId -> name=${_conversationNames[conversationId]}, avatar=${_conversationAvatars[conversationId]}');
          }
        }
      } catch (e) {
        // best-effort: no synthetic fallback assigned here — leave null so AvatarWidget shows a safe fallback.
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('MessagesScreen: _ensureConversationMembersLoaded failed for $conversationId: $e');
    } finally {
      _pendingMemberLoads.remove(conversationId);
    }
  }

  void _hydrateConversationFromCache(String conversationId, String wallet) {
    final normalizedWallet = WalletUtils.normalize(wallet);
    if (normalizedWallet.isEmpty) return;
    final cachedAvatar = _cacheProvider.getAvatar(normalizedWallet);
    if ((cachedAvatar ?? '').isNotEmpty && ((_conversationAvatars[conversationId] ?? '').isEmpty)) {
      _storeConversationAvatar(conversationId, cachedAvatar, walletHint: normalizedWallet);
    }
    final cachedName = _cacheProvider.getDisplayName(normalizedWallet);
    if ((cachedName ?? '').isNotEmpty && ((_conversationNames[conversationId] ?? '').isEmpty || WalletUtils.equals(_conversationNames[conversationId], normalizedWallet))) {
      _conversationNames[conversationId] = cachedName;
    }
  }

  void _persistWalletProfile(String wallet, {String? avatar, String? displayName}) {
    final normalizedWallet = WalletUtils.normalize(wallet);
    if (normalizedWallet.isEmpty) return;
    final avatarPayload = <String, String?>{};
    final namePayload = <String, String?>{};
    if ((avatar ?? '').trim().isNotEmpty) avatarPayload[normalizedWallet] = avatar!.trim();
    if ((displayName ?? '').trim().isNotEmpty) namePayload[normalizedWallet] = displayName!.trim();
    if (avatarPayload.isEmpty && namePayload.isEmpty) return;
    unawaited(_cacheProvider.mergeProfiles(
      avatars: avatarPayload.isEmpty ? null : avatarPayload,
      displayNames: namePayload.isEmpty ? null : namePayload,
    ));
  }

  @override
  void dispose() {
    try { _chatProvider.removeListener(_onChatProviderChanged); } catch (_) {}
    super.dispose();
  }
}

class _CreateConversationDialog extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _CreateConversationDialogState();
}

class _CreateConversationDialogState extends State<_CreateConversationDialog> {
  final _members = TextEditingController();
  final _title = TextEditingController();
  final BackendApiService _api = BackendApiService();
  final List<String> _memberList = [];
  final List<Map<String, dynamic>> _memberSuggestions = [];
  Uint8List? _avatarBytes;
  bool _isGroup = true;

  @override
  void dispose() {
    _members.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.messagesCreateConversationTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l10n.messagesCreateConversationTitleOptionalLabel),
          ),
          Wrap(children: _memberList.map((m) => Chip(label: Text(m), onDeleted: () => setState(() => _memberList.remove(m)))).toList()),
          TextField(
            controller: _members,
            decoration: InputDecoration(labelText: l10n.messagesCreateConversationMembersLabel),
            onChanged: (v) async {
            if (v.trim().isEmpty) {
              setState(() => _memberSuggestions.clear());
              return;
            }
            try {
              final resp = await _api.search(query: v.trim(), type: 'profiles', limit: 6);
              final list = <Map<String, dynamic>>[];
              if (resp['success'] == true) {
                // search may return results in different shapes; handle both
                if (resp['results'] is Map<String, dynamic>) {
                  final data = resp['results'] as Map<String, dynamic>;
                  final profiles = (data['profiles'] as List<dynamic>?) ?? (data['results'] as List<dynamic>?) ?? [];
                  for (final d in profiles) {
                    try { list.add(d as Map<String, dynamic>); } catch (_) {}
                  }
                } else if (resp['data'] is List) {
                  for (final d in resp['data']) {
                    try { list.add(d as Map<String, dynamic>); } catch (_) {}
                  }
                } else if (resp['data'] is Map<String, dynamic>) {
                  final data = resp['data'] as Map<String, dynamic>;
                  final profiles = (data['profiles'] as List<dynamic>?) ?? [];
                  for (final d in profiles) {
                    try { list.add(d as Map<String, dynamic>); } catch (_) {}
                  }
                }
              }
              if (!mounted) return;
              setState(() {
                _memberSuggestions.clear();
                _memberSuggestions.addAll(list);
              });
            } catch (e) {
              debugPrint('CreateConversationDialog: profile search error: $e');
            }
          },
          ),
              if (_memberSuggestions.isNotEmpty) SizedBox(
                height: 200,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (ctx, idx) {
            final s = _memberSuggestions[idx];
            final username = s['username'] ?? s['wallet_address'] ?? s['wallet'];
            final display = s['displayName'] ?? s['display_name'] ?? '';
            final avatar = s['avatar'] ?? s['avatar_url'] ?? '';
            final effectiveAvatar = (avatar != null && avatar.toString().isNotEmpty) ? avatar.toString() : null;
            // Prefer adding the wallet address when available; otherwise fall back to username
            final walletAddr = (s['wallet_address'] ?? s['wallet'] ?? s['walletAddress'])?.toString() ?? '';
            final addValue = walletAddr.isNotEmpty ? walletAddr : (username ?? '').toString();
            return ListTile(title: Text(display ?? username), subtitle: Text(walletAddr.isNotEmpty ? walletAddr : (username ?? '')), leading: AvatarWidget(avatarUrl: effectiveAvatar, wallet: (walletAddr.isNotEmpty ? walletAddr : (username ?? '')).toString(), radius: 20, allowFabricatedFallback: false, enableProfileNavigation: false), onTap: () {
              if ((addValue).isNotEmpty) setState(() { _memberList.add(addValue); _members.clear(); _memberSuggestions.clear(); });
            });
                  },
                  itemCount: _memberSuggestions.length,
                ),
              ),
          Row(children: [
            ElevatedButton.icon(icon: Icon(Icons.upload_file), label: Text(l10n.messagesCreateConversationGroupAvatarOptionalLabel), onPressed: () async {
                try {
                  final result = await FilePicker.platform.pickFiles(withData: true);
                  if (!mounted) return;
                  if (result?.files.isNotEmpty ?? false) {
                    final file = result!.files.first;
                    setState(() { _avatarBytes = file.bytes; });
                  }
                } catch (e) { debugPrint('CreateConversationDialog: avatar pick error: $e'); }
            }),
            const SizedBox(width: 8),
            if (_avatarBytes != null) CircleAvatar(backgroundImage: MemoryImage(_avatarBytes!))
          ]),
          SwitchListTile(value: _isGroup, onChanged: (v) => setState(() => _isGroup = v), title: Text(l10n.messagesCreateConversationIsGroupLabel)),
        ],
      ),
      actions: [
        TextButton(child: Text(l10n.commonCancel), onPressed: () => Navigator.of(context).pop()),
        TextButton(child: Text(l10n.commonCreate), onPressed: () async {
          final manualMembers = _members.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final members = [..._memberList, ...manualMembers];
          final cp = Provider.of<ChatProvider>(context, listen: false);
          final navigator = Navigator.of(context);
          final res = await cp.createConversation(_title.text, _isGroup, members);
          if (!mounted) return;
          if (res != null && _avatarBytes != null) {
            try {
              await cp.uploadConversationAvatar(res.id, _avatarBytes!, 'group_avatar.png', 'image/png');
            } catch (e) { debugPrint('Failed to upload group avatar after create: $e'); }
          }
          if (!mounted) return;
          navigator.pop({'title': _title.text, 'isGroup': _isGroup, 'members': members});
        }),
      ],
    );
  }
}
