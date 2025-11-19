import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:math' as math;
import '../models/conversation.dart';
import '../models/user.dart';
import '../models/message.dart';
import 'messages_screen.dart';
import '../providers/chat_provider.dart';
import '../services/socket_service.dart';
import '../providers/profile_provider.dart';
import '../providers/cache_provider.dart';
import '../services/user_service.dart';
import '../services/backend_api_service.dart';
import '../services/event_bus.dart';
import '../services/push_notification_service.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/inline_loading.dart';

// Use AvatarWidget from widgets to render avatars safely

class ConversationScreen extends StatefulWidget {
  final Conversation conversation;
  final List<String>? preloadedMembers;
  final Map<String, String?>? preloadedAvatars;
  final Map<String, String?>? preloadedDisplayNames;
  const ConversationScreen({super.key, required this.conversation, this.preloadedMembers, this.preloadedAvatars, this.preloadedDisplayNames});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  late ChatProvider _chatProvider;
  late CacheProvider _cacheProvider;
  final SocketService _socketService = SocketService();
  List<ChatMessage> _messages = [];
  bool _isUploading = false;
  final ScrollController _scrollController = ScrollController();
  // Use index-based keys to avoid duplicate GlobalKey instances when message ids
  // are missing, invalid, or duplicated by the backend (which can crash the app).
  final Map<String, GlobalKey> _messageKeys = {};
  final Map<String, String?> _avatarUrlCache = {};
  final Map<String, String?> _displayNameCache = {};
  Timer? _scrollDebounce;
  final Set<String> _pendingReadMarks = {};
  final Set<String> _animatedMessageIds = {}; // Track which messages have been animated
  Timer? _readQueueTimer;
  final List<String> _readQueue = [];
  final int _readQueueDelayMs = 150; // milliseconds between queued read sends
  String? _conversationAvatar;
  List<String> _conversationMembers = [];
  String _normWallet(String? w) => (w ?? '').toString().toLowerCase().trim();
  // Removed UserService cache listener usage; we now fetch user profiles directly.
  
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _cacheProvider = Provider.of<CacheProvider>(context, listen: false);
    // Defer initial load to a microtask to allow widget to fully initialize
    _chatProvider.addListener(_onChatProviderUpdated);
    // We no longer rely on a global cache notifier to refresh avatar/profile data.
    // Instead, we fetch profiles directly via UserService.getUsersByWallets or
    // UserService.getUserById as needed in background and update local caches.
    if (!mounted) return;

    _seedFromConversationMetadata();

    // Initialize caches from optional preloaded values to avoid network fetch
    if (widget.preloadedAvatars != null) {
      _avatarUrlCache.addAll(widget.preloadedAvatars!);
    }
    if (widget.preloadedDisplayNames != null) {
      _displayNameCache.addAll(widget.preloadedDisplayNames!);
    }
    if (widget.preloadedMembers != null && widget.preloadedMembers!.isNotEmpty) {
      _conversationMembers = List<String>.from(widget.preloadedMembers!);
      for (final wallet in _conversationMembers) {
        _hydrateFromGlobalCache(wallet);
      }
      // If a preloaded avatar is present for the header, set it too
      if (_conversationMembers.isNotEmpty) {
        final w = _conversationMembers.first;
            if (_avatarUrlCache.containsKey(w) && (_avatarUrlCache[w]?.isNotEmpty ?? false)) {
              _conversationAvatar = _avatarUrlCache[w];
            }
      }
    }
    // As a fallback, use provider-level preloaded maps if we didn't receive explicit preloaded data.
    if ((_conversationMembers.isEmpty || _conversationAvatar == null) && _avatarUrlCache.isEmpty && _displayNameCache.isEmpty) {
      try {
        final map = _chatProvider.getPreloadedProfileMapsForConversation(widget.conversation.id);
        final members = (map['members'] as List<dynamic>?)?.cast<String>() ?? [];
        final avatars = (map['avatars'] as Map<String, String?>?) ?? {};
        final names = (map['names'] as Map<String, String?>?) ?? {};
        if (members.isNotEmpty) {
          _conversationMembers = members;
          if (_avatarUrlCache.isEmpty && avatars.isNotEmpty) _avatarUrlCache.addAll(avatars);
          if (_displayNameCache.isEmpty && names.isNotEmpty) _displayNameCache.addAll(names);
          if (_conversationAvatar == null && _avatarUrlCache.containsKey(members.first)) {
            _conversationAvatar = _avatarUrlCache[members.first];
          }
        }
      } catch (_) {}
    }

    // Load messages and other conversation initialization off the main path
    _persistCacheSnapshots();
    Future(() async { try { await _load(); } catch (e) { debugPrint('ConversationScreen.initState: _load error: $e'); } });
    
    // Continue initState: add scroll + socket listeners
    _scrollController.addListener(_onScroll);
    _socketService.addConnectListener(_onSocketConnected);
  }

  void _seedFromConversationMetadata() {
    final conv = widget.conversation;
    final seen = <String>{};
    final seededMembers = <String>[];

    void addMember(String wallet, {String? displayName, String? avatarUrl}) {
      final trimmed = wallet.trim();
      if (trimmed.isEmpty) return;
      final lower = trimmed.toLowerCase();
      if (seen.add(lower)) {
        seededMembers.add(trimmed);
        _hydrateFromGlobalCache(trimmed);
      }
      if (displayName != null && displayName.trim().isNotEmpty) {
        final existing = _displayNameCache[trimmed];
        if (existing == null || existing.isEmpty || existing == trimmed) {
          _displayNameCache[trimmed] = displayName.trim();
        }
      }
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
        final existing = _avatarUrlCache[trimmed];
        if (existing == null || existing.isEmpty) {
          _avatarUrlCache[trimmed] = _normalizeAvatar(avatarUrl.trim()) ?? avatarUrl.trim();
        }
      }
    }

    for (final profile in conv.memberProfiles) {
      addMember(profile.wallet, displayName: profile.displayName, avatarUrl: profile.avatarUrl);
    }
    if (conv.counterpartProfile != null) {
      addMember(conv.counterpartProfile!.wallet, displayName: conv.counterpartProfile!.displayName, avatarUrl: conv.counterpartProfile!.avatarUrl);
    }
    if (conv.memberWallets.isNotEmpty) {
      for (final wallet in conv.memberWallets) {
        addMember(wallet);
      }
    }

    if (_conversationMembers.isEmpty && seededMembers.isNotEmpty) {
      _conversationMembers = seededMembers;
    }

    _conversationAvatar ??= _normalizeAvatar(conv.displayAvatar) ?? conv.displayAvatar ??
        (conv.counterpartProfile?.avatarUrl != null && conv.counterpartProfile!.avatarUrl!.isNotEmpty
            ? _normalizeAvatar(conv.counterpartProfile!.avatarUrl)
            : null);

    if ((_conversationAvatar == null || _conversationAvatar!.isEmpty) && _conversationMembers.isNotEmpty) {
      final primary = _conversationMembers.first;
      final candidate = _avatarUrlCache[primary];
      if (candidate != null && candidate.isNotEmpty) {
        _conversationAvatar = candidate;
      }
    }
  }

  void _hydrateFromGlobalCache(String wallet) {
    if (wallet.isEmpty) return;
    try {
      final cachedAvatar = _cacheProvider.getAvatar(wallet);
      if (cachedAvatar != null && cachedAvatar.isNotEmpty) {
        final current = _avatarUrlCache[wallet];
        if (current == null || current.isEmpty || _isPlaceholderAvatar(current, wallet)) {
          _avatarUrlCache[wallet] = cachedAvatar;
        }
      }
      final cachedName = _cacheProvider.getDisplayName(wallet);
      if (cachedName != null && cachedName.isNotEmpty && _isPlaceholderName(_displayNameCache[wallet], wallet)) {
        _displayNameCache[wallet] = cachedName;
      }
    } catch (_) {}
  }

  void _persistCacheSnapshots() {
    if (!mounted || !_cacheProvider.isInitialized) return;
    final avatarPayload = <String, String?>{};
    final displayPayload = <String, String?>{};
    _avatarUrlCache.forEach((wallet, url) {
      if ((url ?? '').trim().isEmpty) return;
      avatarPayload[wallet] = url!.trim();
    });
    _displayNameCache.forEach((wallet, name) {
      if ((name ?? '').trim().isEmpty || name == wallet) return;
      displayPayload[wallet] = name!.trim();
    });
    if (avatarPayload.isEmpty && displayPayload.isEmpty) return;
    unawaited(_cacheProvider.mergeProfiles(
      avatars: avatarPayload.isEmpty ? null : avatarPayload,
      displayNames: displayPayload.isEmpty ? null : displayPayload,
    ));
  }

  Future<void> _fetchAvatarsForMessages(List<ChatMessage> list, [String? myWallet]) async {
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final String currentWallet = myWallet ?? (profile.currentUser?.walletAddress ?? '');
    final Set<String> walletsNeedingResolution = {};

    for (final message in list) {
      final wallet = message.senderWallet;
      if (wallet.isEmpty) continue;
      if (_normWallet(wallet) == _normWallet(currentWallet)) continue;
      _hydrateFromGlobalCache(wallet);

      final senderAvatar = message.senderAvatar;
      if (senderAvatar != null && senderAvatar.isNotEmpty) {
        _avatarUrlCache[wallet] = _normalizeAvatar(senderAvatar) ?? senderAvatar;
      }

      final senderName = message.senderDisplayName;
      if (senderName != null && senderName.isNotEmpty) {
        _displayNameCache[wallet] = senderName;
      }

      if (!_avatarUrlCache.containsKey(wallet)) {
        walletsNeedingResolution.add(wallet);
      }
    }

    if (walletsNeedingResolution.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final cached = UserService.getCachedUsers(walletsNeedingResolution.toList());
      final resolved = <String>{};
      for (final entry in cached.entries) {
        final wallet = entry.key;
        final user = entry.value;
        final avatarCandidate = (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
            ? (_normalizeAvatar(user.profileImageUrl) ?? user.profileImageUrl)
            : null;

        if (avatarCandidate != null && _isPlaceholderAvatar(_avatarUrlCache[wallet], wallet)) {
          _avatarUrlCache[wallet] = avatarCandidate;
        }
        if (_isPlaceholderName(_displayNameCache[wallet], wallet)) {
          _displayNameCache[wallet] = user.name;
        }
        resolved.add(wallet);
      }
      walletsNeedingResolution.removeAll(resolved);
    } catch (_) {}

    if (walletsNeedingResolution.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final users = await UserService.getUsersByWallets(walletsNeedingResolution.toList());
      try {
        EventBus().emitProfilesUpdated(users);
      } catch (_) {}
      if (!mounted) return;

      final resolved = <String>{};
      for (final user in users) {
        final wallet = user.id;
        if (wallet.isEmpty) continue;
        final avatarCandidate = (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
            ? (_normalizeAvatar(user.profileImageUrl) ?? user.profileImageUrl)
            : null;
        if (avatarCandidate != null && _isPlaceholderAvatar(_avatarUrlCache[wallet], wallet)) {
          _avatarUrlCache[wallet] = avatarCandidate;
        }
        if (_isPlaceholderName(_displayNameCache[wallet], wallet)) {
          _displayNameCache[wallet] = user.name;
        }
        resolved.add(wallet);
      }
      walletsNeedingResolution.removeAll(resolved);
    } catch (_) {
      // Ignore and fallback to per-wallet lookups below
    }

    if (walletsNeedingResolution.isNotEmpty) {
      final remaining = walletsNeedingResolution.toList();
      for (final wallet in remaining) {
        try {
          final user = await UserService.getUserById(wallet);
          if (!mounted) return;
          final avatarCandidate = (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
              ? (_normalizeAvatar(user.profileImageUrl) ?? user.profileImageUrl)
              : null;
          _avatarUrlCache[wallet] = (avatarCandidate != null && avatarCandidate.isNotEmpty) ? avatarCandidate : null;
          _displayNameCache[wallet] = user?.name ?? '';
        } catch (_) {
          _avatarUrlCache[wallet] = null;
          _displayNameCache[wallet] = null;
        }
      }
    }

    if (mounted) setState(() {});
    _persistCacheSnapshots();
  }

    /// Load the messages and associated member data for this conversation.
    Future<void> _load() async {
      // Capture current wallet synchronously to avoid using BuildContext inside background async futures
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final myWallet = (profile.currentUser?.walletAddress ?? '');

      // Load messages and return quickly to render UI. Heavy follow-ups run in background.
      List<ChatMessage> list = [];
      try {
        list = await _chatProvider.loadMessages(widget.conversation.id);
      } catch (e) {
        debugPrint('ConversationScreen._load: loadMessages failed: $e');
        list = [];
      }
      if (!mounted) return;

      // Pre-populate avatar and display name caches from message rows when available
      try {
        for (final m in list) {
          final w = m.senderWallet;
          if (w.isEmpty) continue;
          _hydrateFromGlobalCache(w);
              if (m.senderAvatar != null && m.senderAvatar!.isNotEmpty) {
                _avatarUrlCache[w] = _normalizeAvatar(m.senderAvatar) ?? m.senderAvatar;
              }
          if (m.senderDisplayName != null && m.senderDisplayName!.isNotEmpty) {
            _displayNameCache[w] = m.senderDisplayName;
          }
        }
      } catch (_) {}

      // Build a set of wallets mentioned in messages (non-blocking users will be fetched)
      final Set<String> walletsToFetch = {};
      for (final m in list) {
        final w = m.senderWallet;
        if (w.isEmpty) continue;
        // skip current user
        if (_normWallet(w) == _normWallet(myWallet)) continue;
        _hydrateFromGlobalCache(w);
        walletsToFetch.add(w);
      }

      // Prepopulate caches from local ChatProvider cache and persistent cache to minimize lookups and ensure immediate UI availability
      final List<String> missingWallets = [];
      for (final w in walletsToFetch) {
        final cu = _chatProvider.getCachedUser(w);
        if (cu != null) {
          if (cu.profileImageUrl != null && cu.profileImageUrl!.isNotEmpty) {
            final cur = _avatarUrlCache[w];
              final candidate = (cu.profileImageUrl != null && cu.profileImageUrl!.isNotEmpty) ? (_normalizeAvatar(cu.profileImageUrl) ?? cu.profileImageUrl) : null;
              if (candidate != null && _isPlaceholderAvatar(cur, w)) _avatarUrlCache[w] = candidate;
          }
          if (cu.name.isNotEmpty) {
            final cur = _displayNameCache[w];
            if (_isPlaceholderName(cur, w)) _displayNameCache[w] = cu.name;
          }
        } else {
          // Attempt to read from persisted UserService cache sync to avoid network fetch and flicker
          final persisted = UserService.getCachedUser(w);
          if (persisted != null) {
            if (persisted.profileImageUrl != null && persisted.profileImageUrl!.isNotEmpty) {
              final cur = _avatarUrlCache[w];
              final candidate = (persisted.profileImageUrl != null && persisted.profileImageUrl!.isNotEmpty) ? (_normalizeAvatar(persisted.profileImageUrl) ?? persisted.profileImageUrl) : null;
              if (candidate != null && _isPlaceholderAvatar(cur, w)) _avatarUrlCache[w] = candidate;
            }
            if (persisted.name.isNotEmpty) {
              final cur = _displayNameCache[w];
              if (_isPlaceholderName(cur, w)) _displayNameCache[w] = persisted.name;
            }
            continue;
          }
          if (!_avatarUrlCache.containsKey(w) || !(_displayNameCache.containsKey(w) && (_displayNameCache[w]?.isNotEmpty ?? false))) {
            missingWallets.add(w);
          }
        }
      }

      // Fetch missing user profiles in one call so the UI can display names/avatars on first render
      // If we have preloaded members from the previous screen, don't trigger a network fetch
      final hasPreloadedMembers = widget.preloadedMembers != null && widget.preloadedMembers!.isNotEmpty;
      if (!hasPreloadedMembers && missingWallets.isNotEmpty) {
        try {
          final users = await UserService.getUsersByWallets(missingWallets);
          try { EventBus().emitProfilesUpdated(users); } catch (_) {}
          for (final u in users) {
            final key = u.id;
              final p = (u.profileImageUrl != null && u.profileImageUrl!.isNotEmpty) ? (_normalizeAvatar(u.profileImageUrl) ?? u.profileImageUrl) : null;
            final curAv = _avatarUrlCache[key];
            final curName = _displayNameCache[key];
              if (p != null && _isPlaceholderAvatar(curAv, key)) _avatarUrlCache[key] = p;
            if (_isPlaceholderName(curName, key)) _displayNameCache[key] = u.name;
          }
        } catch (e) {
          // ignore and proceed; fallback background fetch will still occur
          debugPrint('ConversationScreen._load: prefetch profiles failed: $e');
        }
      }

      // Update UI with messages (and now with pre-fetched avatars/names)
      // Prefer to set conversation header info from first other participant if available
      final firstOther = walletsToFetch.isNotEmpty ? walletsToFetch.first : null;
      if (firstOther != null && !_conversationMembers.contains(firstOther)) {
        _conversationMembers = [firstOther];
        // prefer cached avatar & name if available
        if (_avatarUrlCache.containsKey(firstOther) && (_avatarUrlCache[firstOther]?.isNotEmpty ?? false)) {
            if (_isPlaceholderAvatar(_conversationAvatar, firstOther)) _conversationAvatar = _avatarUrlCache[firstOther];
        }
      }

      if (mounted) {
        setState(() {
          _messages = list;
          // Ensure keys align to current messages so index-based keys are stable
          _messageKeys.clear();
        });
      }
      debugPrint('ConversationScreen._load: ${_messages.length} messages loaded for ${widget.conversation.id}');
      _persistCacheSnapshots();

      // Fetch any remaining missing avatars/display names in background (non-blocking fallback)
      Future(() async {
        try {
          await _fetchAvatarsForMessages(list, myWallet);
        } catch (e) {
          debugPrint('ConversationScreen._load: _fetchAvatarsForMessages error: $e');
        }
      });

      // Open conversation subscription, mark read, and fetch members in background; don't block initial render.
      Future(() async {
        try {
          await _chatProvider.openConversation(widget.conversation.id);
        } catch (e) {
          debugPrint('ConversationScreen._load: openConversation failed: $e');
        }
        try {
          await _chatProvider.markRead(widget.conversation.id);
        } catch (e) {
          debugPrint('ConversationScreen._load: markRead failed: $e');
        }

        try {
          final mems = await _chatProvider.fetchMembers(widget.conversation.id);
          final wallets = (mems as List)
              .map((e) => (e['wallet_address'] as String?) ?? '')
              .where((w) => w.isNotEmpty && _normWallet(w) != _normWallet(myWallet))
              .toList();

          // If backend returned no members, infer from messages
          if (wallets.isEmpty) {
            for (final m in _messages) {
              try {
                final w = m.senderWallet;
                if (w.isNotEmpty && _normWallet(w) != _normWallet(myWallet)) {
                  wallets.add(w);
                  break;
                }
              } catch (_) {}
            }
          }

          if (wallets.isNotEmpty) {
            _conversationMembers = wallets;
            for (final wallet in wallets) {
              _hydrateFromGlobalCache(wallet);
            }
          }

          // Fetch display name and avatar for header from user service (prefer caches first)
          if (wallets.isNotEmpty) {
            try {
              final missing = <String>[];
              for (final w in wallets) {
                final cu = _chatProvider.getCachedUser(w);
                if (cu != null) {
                  if (cu.profileImageUrl != null && cu.profileImageUrl!.isNotEmpty) {
                    final cur = _avatarUrlCache[cu.id];
                      final candidate = (cu.profileImageUrl != null && cu.profileImageUrl!.isNotEmpty) ? (_normalizeAvatar(cu.profileImageUrl) ?? cu.profileImageUrl) : null;
                      if (candidate != null && _isPlaceholderAvatar(cur, cu.id)) _avatarUrlCache[cu.id] = candidate;
                  }
                  if (cu.name.isNotEmpty) {
                    final cur = _displayNameCache[cu.id];
                    if (_isPlaceholderName(cur, cu.id)) _displayNameCache[cu.id] = cu.name;
                  }
                } else {
                  missing.add(w);
                }
              }
              if (missing.isNotEmpty) {
                final users = await UserService.getUsersByWallets(missing);
                try { EventBus().emitProfilesUpdated(users); } catch (_) {}
                for (final u in users) {
                  final key = u.id;
                  final curAv = _avatarUrlCache[key];
                  final curName = _displayNameCache[key];
                  if (u.profileImageUrl != null && u.profileImageUrl!.isNotEmpty) {
                        final candidate = (u.profileImageUrl != null && u.profileImageUrl!.isNotEmpty) ? (_normalizeAvatar(u.profileImageUrl) ?? u.profileImageUrl) : null;
                        if (candidate != null && _isPlaceholderAvatar(curAv, key)) _avatarUrlCache[key] = candidate;
                  }
                  if (u.name.isNotEmpty) if (_isPlaceholderName(curName, key)) _displayNameCache[key] = u.name;
                }
              }
            } catch (_) {}
          }

          // Prefer conversation display avatar from model if present
          _conversationAvatar = _normalizeAvatar(widget.conversation.displayAvatar) ?? widget.conversation.displayAvatar;
          if (_conversationAvatar == null || _conversationAvatar!.isEmpty) {
            if (!widget.conversation.isGroup && wallets.isNotEmpty) {
              final cached = _chatProvider.getCachedUser(wallets.first);
                if (cached != null && (cached.profileImageUrl ?? '').isNotEmpty) {
                  _conversationAvatar = _normalizeAvatar(cached.profileImageUrl) ?? cached.profileImageUrl;
                } else if (_avatarUrlCache[wallets.first]?.isNotEmpty ?? false) {
                  _conversationAvatar = _avatarUrlCache[wallets.first];
                }
            }
          }

          if (mounted) {
            debugPrint('ConversationScreen._load: header avatar=$_conversationAvatar, members=${_conversationMembers.length}, display cache keys=${_displayNameCache.keys.length}');
            setState(() {});
            _persistCacheSnapshots();
          }
        } catch (e) {
          debugPrint('ConversationScreen: failed to fetch members for header: $e');
        }
      });

      // Defer per-message marking to viewport-based detection
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibleMessages());
    }

    /// Normalize avatar URLs returned by backend to absolute URLs or gateways.
    String? _normalizeAvatar(String? a) {
      if (a == null || a.isEmpty) return null;
      try {
        if (a.startsWith('/')) {
          final base = BackendApiService().baseUrl.replaceAll(RegExp(r'/$'), '');
          return base + a;
        }
        if (a.startsWith('ipfs://')) {
          final cid = a.replaceFirst('ipfs://', '');
          return 'https://ipfs.io/ipfs/$cid';
        }
      } catch (_) {}
      return a;
    }


    bool _isPlaceholderAvatar(String? current, String wallet) {
      if (current == null || current.isEmpty) return true;
      if (UserService.isPlaceholderAvatarUrl(current)) return true;
      try { return current == UserService.safeAvatarUrl(wallet); } catch (_) { return false; }
    }
    bool _isPlaceholderName(String? current, String wallet) {
      if (current == null || current.isEmpty) return true;
      return current == wallet || current == 'Conversation' || current == 'Group';
    }

    /// Simple time-ago formatter used in chat bubbles and tooltips.
    String _formatTimeAgo(DateTime dt) {
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    
    final replyToId = _replyingTo?.id;
    setState(() => _replyingTo = null);
    
    await _chatProvider.sendMessage(widget.conversation.id, text, replyToId: replyToId);
    // Fire a lightweight local notification so background listeners stay aware
    try {
      PushNotificationService().showCommunityInteractionNotification(
        postId: widget.conversation.id,
        type: 'message',
        userName: 'You',
        comment: text,
      );
    } catch (_) {}
  }

  Widget _buildReadersAvatars(List<Map<String, dynamic>> readers, String senderWallet) {
    if (readers.isEmpty) return const SizedBox.shrink();
    final items = readers.where((r) {
      final wallet = (r['wallet_address'] as String? ?? r['wallet'] as String? ?? '');
      return _normWallet(wallet) != _normWallet(senderWallet);
    }).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final count = items.length;
    final visible = items.take(3).toList();
    final double avatarSize = 16.0;
    final double overlap = 6.0;
    final totalWidth = (visible.length * (avatarSize - overlap)) + avatarSize;
    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(children: [
        for (var i = 0; i < visible.length; i++)
          Positioned(
            left: i * (avatarSize - overlap),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 20 + (i * 40)),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Builder(
                key: ValueKey('${visible[i]['wallet_address'] ?? visible[i]['wallet'] ?? i}'),
                builder: (ctx) {
                  final r = visible[i];
                  final avatar = r['avatar_url'] as String?;
                  final wallet = (r['wallet_address'] as String? ?? r['wallet'] as String? ?? '');
                      final effectiveAvatar = (avatar != null && avatar.isNotEmpty) ? (_normalizeAvatar(avatar) ?? avatar) : null;
                  final display = (r['displayName'] as String?) ?? wallet;
                  String suffix = '';
                  final readAtStr = r['read_at'] as String? ?? r['readAt'] as String?;
                  if (readAtStr != null && readAtStr.isNotEmpty) {
                    try {
                      final dt = DateTime.parse(readAtStr);
                      suffix = ' • ${_formatTimeAgo(dt)}';
                    } catch (_) {}
                  }
                  return Tooltip(
                    message: '$display$suffix',
                    child: _buildAvatar(effectiveAvatar, wallet, radius: avatarSize / 2),
                  );
                }
              ),
            ),
          ),
        if (count > 3)
          Positioned(
            left: visible.length * (avatarSize - overlap),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.0),
              ),
              child: Text('+${count - visible.length}', style: GoogleFonts.inter(fontSize: 10, color: Theme.of(context).colorScheme.onSurface)),
            ),
          ),
      ]),
    );
  }

  bool _hasReceivedRead(List<Map<String, dynamic>> readers, String senderWallet) {
    if (readers.isEmpty) return false;
    final senderNorm = _normWallet(senderWallet);
    for (final entry in readers) {
      final wallet = (entry['wallet_address'] as String?) ?? (entry['wallet'] as String?) ?? '';
      if (wallet.isEmpty) continue;
      if (_normWallet(wallet) != senderNorm) {
        return true;
      }
    }
    return false;
  }

  Color _readIndicatorColor(BuildContext context, {required bool isMine, required bool isRead}) {
    final scheme = Theme.of(context).colorScheme;
    final Color contrast = isMine ? scheme.onPrimary : scheme.onPrimaryContainer;
    if (!isRead) {
      return contrast.withValues(alpha: 0.72);
    }
    return contrast;
  }

  Widget _wrapWithAnimation(Widget child, bool shouldAnimate, {required String messageId}) {
    if (!shouldAnimate) return child;
    
    try {
      return TweenAnimationBuilder<double>(
        key: ValueKey('anim_$messageId'),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, value, animChild) {
          final slideOffset = (1 - value) * 12;
          final scale = 0.96 + (value * 0.04);
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, slideOffset),
              child: Transform.scale(
                scale: scale,
                child: animChild ?? child,
              ),
            ),
          );
        },
        child: child,
      );
    } catch (e) {
      debugPrint('ConversationScreen._wrapWithAnimation error: $e');
      return child; // Fallback to non-animated widget
    }
  }

  Widget _buildAvatar(String? avatarUrl, String wallet, {double radius = 18}) {
    // Delegate to safeAvatarWidget which handles network errors and fallbacks.
    final normalized = _normalizeAvatar(avatarUrl) ?? avatarUrl;
    try {
      debugPrint('ConversationScreen._buildAvatar: wallet=$wallet, avatarUrl=$normalized');
      final isLoading = (!_avatarUrlCache.containsKey(wallet) && _chatProvider.getCachedUser(wallet) == null && UserService.getCachedUser(wallet) == null && (avatarUrl == null || avatarUrl.isEmpty));
      return AvatarWidget(avatarUrl: normalized, wallet: wallet, radius: radius, isLoading: isLoading, allowFabricatedFallback: true);
    } catch (e, st) {
      debugPrint('ConversationScreen._buildAvatar: AvatarWidget build failed for $wallet, avatarUrl=$normalized: $e\n$st');
      // Return a simple initials-based fallback to avoid crash
      final parts = wallet.trim().split(RegExp(r'\\s+'));
      final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
      final base = Container(width: radius * 2, height: radius * 2, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(radius * 0.5)), alignment: Alignment.center, child: Text(initials.isNotEmpty ? initials : 'U', style: TextStyle(fontSize: (radius * 0.7).clamp(10, 14).toDouble(), fontWeight: FontWeight.w600)));
      final isLoading = (!_avatarUrlCache.containsKey(wallet) && _chatProvider.getCachedUser(wallet) == null && UserService.getCachedUser(wallet) == null && (avatarUrl == null || avatarUrl.isEmpty));
      if (isLoading) return Stack(alignment: Alignment.center, children: [base, SizedBox(width: radius, height: radius, child: InlineLoading(expand: true, shape: BoxShape.circle, tileSize: (radius * 0.25).clamp(4.0, 10.0)))]);
      return base;
    }
  }

  Future<void> _attachAndSend() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      List<int> bytes;
      if (kIsWeb) {
        if (file.bytes == null) return;
        bytes = file.bytes!;
      } else {
        final path = file.path;
        if (path == null) return;
        final f = io.File(path);
        bytes = await f.readAsBytes();
      }
      final filename = file.name;
      final ext = file.extension?.toLowerCase() ?? '';
      String contentType = 'application/octet-stream';
      if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext)) contentType = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
      if (['mp4', 'mov', 'webm', 'avi'].contains(ext)) contentType = 'video/$ext';
      setState(() => _isUploading = true);
      await _chatProvider.uploadAttachment(widget.conversation.id, bytes, filename, contentType);
      setState(() => _isUploading = false);
      // The socket should push the new message; we refresh local list just in case
      await _load();
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint('Attachment upload error: $e');
    }
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    final isMe = _replyingTo!.senderWallet == (Provider.of<ProfileProvider>(context, listen: false).currentUser?.walletAddress ?? '');
    final senderName = isMe ? 'You' : (_displayNameCache[_replyingTo!.senderWallet] ?? _replyingTo!.senderWallet);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $senderName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _replyingTo!.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageReactions(ChatMessage message, bool isMe) {
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final reactionCounts = <String, int>{};
    final myReactions = <String>{};
    final currentUserWallet = Provider.of<ProfileProvider>(context, listen: false).currentUser?.walletAddress;

    for (final r in message.reactions) {
      reactionCounts[r.emoji] = r.count;
      if (currentUserWallet != null && r.reactors.contains(currentUserWallet)) {
        myReactions.add(r.emoji);
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
      children: reactionCounts.entries.map((entry) {
        final isSelected = myReactions.contains(entry.key);
        return GestureDetector(
          onTap: () => _chatProvider.toggleReaction(widget.conversation.id, message.id, entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primaryContainer 
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Text(
              '${entry.key} ${entry.value}',
              style: TextStyle(
                fontSize: 12,
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimaryContainer 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '😡'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _chatProvider.toggleReaction(widget.conversation.id, message.id, emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  );
                }).toList(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = message);
                // Focus text field after a short delay to allow UI to update
                Future.delayed(const Duration(milliseconds: 100), () {
                  // We don't have a FocusNode attached to the TextField yet, 
                  // but the user will likely tap it anyway. 
                  // Ideally we should add a FocusNode to the TextField.
                });
              },
            ),
            // Add copy option
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                // Clipboard implementation would go here
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scroll to bottom on new message arrival if not already at bottom
    if (_messages.isNotEmpty && _scrollController.hasClients) {
      final pos = _scrollController.position;
      if (pos.maxScrollExtent - pos.pixels <= 100) {
        // Near bottom, allow scroll
        _scrollController.jumpTo(pos.maxScrollExtent);
      } else {
        // Far from bottom, debounce scroll to avoid flicker
        _scrollDebounce?.cancel();
        _scrollDebounce = Timer(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            final pos = _scrollController.position;
            if (pos.maxScrollExtent - pos.pixels <= 100) {
              _scrollController.jumpTo(pos.maxScrollExtent);
            }
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: _buildHeaderTitle(),
        actions: _buildHeaderActions(),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildMessageInput(),
          if (_isUploading) LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildHeaderTitle() {
    final isGroup = widget.conversation.isGroup;
    final title = widget.conversation.title?.trim().isNotEmpty == true
        ? widget.conversation.title!.trim()
        : _conversationMembers.isNotEmpty
            ? _displayNameCache[_conversationMembers.first] ?? _conversationMembers.first
            : 'Conversation';

    Widget avatar;
    if (isGroup) {
      if (_conversationAvatar != null && _conversationAvatar!.isNotEmpty) {
        avatar = _buildAvatar(
          _conversationAvatar,
          _conversationMembers.isNotEmpty ? _conversationMembers.first : widget.conversation.id,
          radius: 18,
        );
      } else if (_conversationMembers.length >= 2) {
        avatar = SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            children: List.generate(math.min(3, _conversationMembers.length), (index) {
              final wallet = _conversationMembers[index];
              final offset = 12.0 * index;
              return Positioned(
                left: offset,
                top: index.isOdd ? 0 : 8,
                child: _buildAvatar(UserService.safeAvatarUrl(wallet), wallet, radius: 10),
              );
            }),
          ),
        );
      } else {
        avatar = CircleAvatar(radius: 18, child: Text(_headerInitials(), style: const TextStyle(fontWeight: FontWeight.w600)));
      }
    } else {
      if (_conversationAvatar != null && _conversationAvatar!.isNotEmpty) {
        avatar = _buildAvatar(
          _conversationAvatar,
          _conversationMembers.isNotEmpty ? _conversationMembers.first : widget.conversation.id,
          radius: 18,
        );
      } else {
        avatar = CircleAvatar(radius: 18, child: Text(_headerInitials(), style: const TextStyle(fontWeight: FontWeight.w600)));
      }
    }

    return Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _headerInitials() {
    final name = widget.conversation.title?.trim().isNotEmpty == true
        ? widget.conversation.title!.trim()
        : _conversationMembers.isNotEmpty
            ? _displayNameCache[_conversationMembers.first] ?? _conversationMembers.first
            : 'Conversation';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return initials.isNotEmpty ? initials : 'C';
  }

  List<Widget> _buildHeaderActions() {
    return [
      PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'members':
              try {
                final dialogContext = context;
                final profile = Provider.of<ProfileProvider>(dialogContext, listen: false);
                final isOwner = (widget.conversation.createdBy ?? '') == (profile.currentUser?.walletAddress ?? '');

                final members = await _chatProvider.fetchMembers(widget.conversation.id);
                if (!mounted) return;
                final wallets = members
                    .map((m) => (m['wallet_address'] as String?) ?? '')
                    .where((w) => w.isNotEmpty)
                    .toList();
                List<User> users = [];
                try {
                  users = await UserService.getUsersByWallets(wallets);
                  _chatProvider.mergeUserCache(users);
                } catch (e) {
                  debugPrint('ConversationScreen: fetching users for members dialog failed: $e');
                }
                final mappedMembers = members.map((m) {
                  final wallet = (m['wallet_address'] as String?) ?? '';
                  User? matchedUser;
                  for (final candidate in users) {
                    if (candidate.id == wallet) {
                      matchedUser = candidate;
                      break;
                    }
                  }
                  return {
                    'user': matchedUser,
                    'role': m['role'] as String? ?? '',
                    'wallet': wallet,
                  };
                }).toList();
                if (!mounted || !dialogContext.mounted) return;
                final selected = await showDialog<String?>(
                  context: dialogContext,
                  builder: (_) => MembersDialog(
                    members: mappedMembers,
                    conversationId: widget.conversation.id,
                    isOwner: isOwner,
                  ),
                );
                if (!mounted) return;
                if (selected == null || selected.isEmpty) return;
                await _chatProvider.removeMember(widget.conversation.id, selected);
                if (!mounted) return;
                await _load();
              } catch (e) {
                debugPrint('ConversationScreen: members dialog failed: $e');
              }
              break;
            case 'add_member':
              if (!widget.conversation.isGroup) break;
              try {
                final identifier = await showDialog<String?>(
                  context: context,
                  builder: (ctx) => const _AddMemberDialog(),
                );
                if (!context.mounted) return;
                if (identifier == null || identifier.trim().isEmpty) return;
                await _chatProvider.addMember(widget.conversation.id, identifier.trim());
                if (!mounted) return;
                await _load();
              } catch (e) {
                debugPrint('ConversationScreen: add member via menu failed: $e');
              }
              break;
            case 'change_group_avatar':
              if (!widget.conversation.isGroup) break;
              try {
                final result = await FilePicker.platform.pickFiles(withData: true);
                if (result == null || result.files.isEmpty) break;
                final file = result.files.first;
                if (file.bytes == null) break;
                await _chatProvider.uploadConversationAvatar(
                  widget.conversation.id,
                  file.bytes!,
                  file.name,
                  file.extension ?? 'image/png',
                );
                await _chatProvider.refreshConversations();
                if (!mounted) return;
                await _load();
              } catch (e) {
                debugPrint('ConversationScreen: change group avatar failed: $e');
              }
              break;
            case 'messages_overlay':
              if (!mounted) break;
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Messages',
                barrierColor: Colors.black54,
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (ctx, a1, a2) => const MessagesScreen(),
                transitionBuilder: (ctx, anim1, anim2, child) {
                  final curved = Curves.easeOut.transform(anim1.value);
                  return Transform.translate(
                    offset: Offset(0, (1 - curved) * MediaQuery.of(context).size.height),
                    child: Opacity(opacity: anim1.value, child: child),
                  );
                },
              );
              break;
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'members', child: Text('Members')),
          if (widget.conversation.isGroup)
            const PopupMenuItem(value: 'add_member', child: Text('Add member')),
          if (widget.conversation.isGroup)
            const PopupMenuItem(value: 'change_group_avatar', child: Text('Change group avatar')),
        ],
        icon: const Icon(Icons.more_vert),
      ),
    ];
  }

  Widget _buildMessagesList() {
    final profile = Provider.of<ProfileProvider>(context);
    final myWallet = profile.currentUser?.walletAddress ?? '';
    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = _normWallet(message.senderWallet) == _normWallet(myWallet);
        final showAvatar = index == 0 || _messages[index - 1].senderWallet != message.senderWallet;
        final shouldAnimate = !_animatedMessageIds.contains(message.id);
        final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());
        final built = _wrapWithAnimation(
          KeyedSubtree(
            key: key,
            child: _buildMessageItem(message, isMe, showAvatar),
          ),
          shouldAnimate,
          messageId: message.id,
        );
        if (shouldAnimate) {
          _animatedMessageIds.add(message.id);
        }
        return built;
      },
    );
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      // Debounce visible check
      _scrollDebounce?.cancel();
      _scrollDebounce = Timer(const Duration(milliseconds: 150), _checkVisibleMessages);
    }
  }

  Widget _buildMessageItem(ChatMessage message, bool isMe, bool showAvatar) {
    final isFirst = message == _messages.first;
    final isLast = message == _messages.last;
    String? avatarUrl;
    String? displayName;
    if (!isMe) {
      avatarUrl = _avatarUrlCache[message.senderWallet];
      if (avatarUrl == null || avatarUrl.isEmpty) {
        final cached = _cacheProvider.getAvatar(message.senderWallet);
        if (cached != null && cached.isNotEmpty) {
          avatarUrl = cached;
          _avatarUrlCache[message.senderWallet] = cached;
        }
      }
      displayName = _displayNameCache[message.senderWallet];
      if (displayName == null || displayName.isEmpty) {
        final cached = _cacheProvider.getDisplayName(message.senderWallet);
        if (cached != null && cached.isNotEmpty) {
          displayName = cached;
          _displayNameCache[message.senderWallet] = cached;
        }
      }
    }
    final double avatarRadius = 16;
    final bubbleMaxWidth = MediaQuery.of(context).size.width * 0.78;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && showAvatar && displayName != null && displayName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
              ),
            _buildMessageContent(message, isMe),
            const SizedBox(height: 4),
            _buildMessageMeta(message, isMe),
            if (message.reactions.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildMessageReactions(message, isMe),
            ],
          ],
        ),
      ),
    );

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: EdgeInsets.only(
          top: isFirst ? 12 : 6,
          bottom: isLast ? 12 : 6,
          left: 12,
          right: 12,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                SizedBox(
                  width: avatarRadius * 2,
                  height: avatarRadius * 2,
                  child: showAvatar
                      ? _buildAvatar(avatarUrl, message.senderWallet, radius: avatarRadius)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
              ],
              bubble,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageMeta(ChatMessage message, bool isMe) {
    final timeColor = isMe
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final isRead = _hasReceivedRead(message.readers, message.senderWallet);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTimeAgo(message.createdAt),
          style: TextStyle(fontSize: 10, color: timeColor),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: _readIndicatorColor(context, isMine: true, isRead: isRead),
          ),
          const SizedBox(width: 4),
          _buildReadersAvatars(message.readers, message.senderWallet),
        ],
      ],
    );
  }

  Widget _buildReplyOverlay(ChatMessage message, bool isMe) {
    final reply = message.replyTo!;
    final scheme = Theme.of(context).colorScheme;
    final senderWallet = reply.senderWallet;
    final fallbackName = reply.senderDisplayName ?? reply.messageId;
    final nameSource = reply.senderDisplayName ??
      _displayNameCache[senderWallet] ??
      _cacheProvider.getDisplayName(senderWallet) ??
      fallbackName;
    final resolvedName = nameSource.isNotEmpty ? nameSource : 'User';
    final overlayBase = (isMe ? scheme.primary : scheme.surfaceContainerHighest).withValues(alpha: 0.25);
    final accent = scheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: overlayBase,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolvedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reply.message ?? 'Message',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  border: Border(
                    left: BorderSide(color: accent, width: 3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    final textColor = isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface;
    final bgColor = isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest;
    final attachment = message.data?['attachment'] as Map<String, dynamic>?;
    final hasAttachment = attachment != null && ((attachment['url'] ?? attachment['remoteUrl'] ?? '').toString().isNotEmpty);

    final replyPreview = message.replyTo != null
        ? Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildReplyOverlay(message, isMe),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (replyPreview != null) replyPreview,
        if (attachment != null && hasAttachment) _buildAttachmentBubble(attachment, isMe),
        if (!hasAttachment || message.message.trim().isNotEmpty)
          Container(
            margin: hasAttachment ? const EdgeInsets.only(top: 8) : EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasAttachment ? Theme.of(context).colorScheme.surfaceContainerHighest : bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              message.message,
              style: TextStyle(
                color: hasAttachment ? Theme.of(context).colorScheme.onSurface : textColor,
                fontSize: 14,
              ),
              showCursor: true,
              cursorWidth: 2,
              cursorColor: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentBubble(Map<String, dynamic> attachment, bool isMe) {
    final url = (attachment['url'] ?? attachment['remoteUrl'] ?? '').toString();
    final fileName = (attachment['filename'] ?? attachment['name'] ?? 'Attachment').toString();
    final sizeLabel = attachment['size']?.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (sizeLabel != null)
            Text(
              sizeLabel,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: url.isEmpty
                    ? null
                    : () async {
                        try {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          debugPrint('ConversationScreen: failed to launch attachment $url - $e');
                        }
                      },
              ),
              Expanded(
                child: Text(
                  url,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Column(
      children: [
        _buildReplyPreview(),
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: _attachAndSend,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _send,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _syncMessagesFromProvider({bool refreshAvatars = false}) {
    try {
      final providerMessages = _chatProvider.messages[widget.conversation.id];
      if (providerMessages == null) return;
      if (identical(providerMessages, _messages)) return;

      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final myWallet = profile.currentUser?.walletAddress ?? '';

      if (mounted) {
        setState(() {
          _messages = providerMessages;
          _pruneMessageKeys(providerMessages);
        });
      }

      if (refreshAvatars) {
        Future(() async {
          try {
            await _fetchAvatarsForMessages(providerMessages, myWallet);
          } catch (e) {
            debugPrint('ConversationScreen._syncMessagesFromProvider: avatar refresh failed: $e');
          }
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibleMessages());
      _persistCacheSnapshots();
    } catch (e) {
      debugPrint('ConversationScreen._syncMessagesFromProvider error: $e');
    }
  }

  void _pruneMessageKeys(List<ChatMessage> activeMessages) {
    final activeIds = activeMessages.map((m) => m.id).toSet();
    _messageKeys.removeWhere((id, _) => !activeIds.contains(id));
    _animatedMessageIds.removeWhere((id) => !activeIds.contains(id));
  }

  void _checkVisibleMessages() {
    if (!mounted) return;
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final myWallet = profile.currentUser?.walletAddress ?? '';
    if (myWallet.isEmpty) return;

    final availableHeight = MediaQuery.of(context).size.height -
        (kToolbarHeight + MediaQuery.of(context).padding.top);

    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final key = _messageKeys[message.id];
      if (key == null) continue;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final renderObject = ctx.findRenderObject();
      if (renderObject is! RenderBox) continue;
      final position = renderObject.localToGlobal(Offset.zero).dy;
      final height = renderObject.size.height;
      final visible = (position + height) > 0 && position < availableHeight;
      if (!visible) continue;

      final isMine = _normWallet(message.senderWallet) == _normWallet(myWallet);
      if (isMine || message.readByCurrent) continue;
      if (_pendingReadMarks.contains(message.id)) continue;

      _pendingReadMarks.add(message.id);
      _chatProvider.markMessageReadLocal(widget.conversation.id, message.id);
      _queueMarkMessageRead(message.id);
    }
  }

  void _queueMarkMessageRead(String messageId) {
    if (_readQueue.contains(messageId)) return;
    _readQueue.add(messageId);
    _readQueueTimer ??= Timer.periodic(Duration(milliseconds: _readQueueDelayMs), (_) async {
      if (_readQueue.isEmpty) {
        _readQueueTimer?.cancel();
        _readQueueTimer = null;
        return;
      }
      final id = _readQueue.removeAt(0);
      try {
        await _chatProvider.markMessageRead(widget.conversation.id, id);
      } catch (e) {
        debugPrint('ConversationScreen: markMessageRead failed for $id: $e');
      } finally {
        _pendingReadMarks.remove(id);
      }
    });
  }

  @override
  void dispose() {
    try { _chatProvider.removeListener(_onChatProviderUpdated); } catch (_) {}
    try { _chatProvider.closeConversation(widget.conversation.id); } catch (_) {}
    _scrollDebounce?.cancel();
    try { _scrollController.removeListener(_onScroll); } catch (_) {}
    _scrollController.dispose();
    _controller.dispose();
    _socketService.removeConnectListener(_onSocketConnected);
    _readQueueTimer?.cancel();
    super.dispose();
  }

  void _onChatProviderUpdated() {
    _syncMessagesFromProvider(refreshAvatars: true);
  }

  void _onSocketConnected() {
    // Resubscribe to conversation updates on socket reconnect
    Future(() async {
      try {
        await _chatProvider.openConversation(widget.conversation.id);
      } catch (e) {
        debugPrint('ConversationScreen._onSocketConnected: openConversation failed: $e');
      }
    });
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final TextEditingController _controller = TextEditingController();
  final BackendApiService _api = BackendApiService();
  final List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add member by username'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: 'Username or wallet'),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () async {
                final query = value.trim();
                if (query.isEmpty) {
                  if (_suggestions.isNotEmpty) {
                    setState(() {
                      _suggestions.clear();
                    });
                  }
                  return;
                }
                try {
                  final resp = await _api.search(query: query, type: 'profiles', limit: 8);
                  final results = <Map<String, dynamic>>[];
                  if (resp['success'] == true) {
                    final data = resp['results'] as Map<String, dynamic>?;
                    final profiles = data != null ? (data['profiles'] as List<dynamic>? ?? []) : (resp['data'] as List<dynamic>? ?? []);
                    for (final entry in profiles) {
                      if (entry is Map<String, dynamic>) results.add(entry);
                    }
                  }
                  setState(() {
                    _suggestions
                      ..clear()
                      ..addAll(results);
                  });
                } catch (e) {
                  debugPrint('AddMemberDialog: search failed $e');
                }
              });
            },
          ),
          if (_suggestions.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (ctx, index) {
                  final suggestion = _suggestions[index];
                  final username = suggestion['username']?.toString() ?? '';
                  final wallet = suggestion['walletAddress']?.toString() ?? suggestion['wallet_address']?.toString() ?? '';
                  final displayName = suggestion['displayName']?.toString() ?? suggestion['display_name']?.toString() ?? username;
                  final avatarCandidate = suggestion['avatar'] ?? suggestion['avatar_url'];
                  final effectiveAvatar = avatarCandidate != null && avatarCandidate.toString().isNotEmpty
                      ? avatarCandidate.toString()
                      : UserService.safeAvatarUrl(wallet.isNotEmpty ? wallet : username);
                  return ListTile(
                    leading: AvatarWidget(
                      avatarUrl: effectiveAvatar,
                      wallet: wallet.isNotEmpty ? wallet : username,
                    ),
                    title: Text(displayName.isNotEmpty ? displayName : username),
                    subtitle: Text(wallet.isNotEmpty ? wallet : username),
                    onTap: () => Navigator.of(context).pop(wallet.isNotEmpty ? wallet : username),
                  );
                },
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text.trim()), child: const Text('Add')),
      ],
    );
  }
}

class MembersDialog extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final String conversationId;
  final bool isOwner;

  const MembersDialog({super.key, required this.members, required this.conversationId, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conversation Members'),
      content: SizedBox(
        width: 360,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: members.length,
          itemBuilder: (ctx, index) {
            final member = members[index];
            final user = member['user'] as User?;
            final role = member['role'] as String? ?? '';
            final wallet = (member['wallet'] as String?) ?? (user?.id ?? '');
            final avatarUrl = user?.profileImageUrl;
            final effectiveAvatar = (avatarUrl != null && avatarUrl.isNotEmpty)
                ? avatarUrl
                : UserService.safeAvatarUrl(wallet);

            return ListTile(
              leading: AvatarWidget(avatarUrl: effectiveAvatar, wallet: wallet),
              title: Text(user?.name ?? wallet),
              subtitle: Text(role.isNotEmpty ? role : 'Member'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOwner && wallet != (Provider.of<ProfileProvider>(context, listen: false).currentUser?.walletAddress ?? ''))
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1),
                      tooltip: 'Transfer ownership',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Transfer ownership'),
                            content: Text('Transfer conversation ownership to $wallet?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Transfer')),
                            ],
                          ),
                        );
                        if (!context.mounted) return;
                        if (confirmed == true) {
                          try {
                            await Provider.of<ChatProvider>(context, listen: false).transferOwnership(conversationId, wallet);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Transfer failed: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => Navigator.of(context).pop(wallet),
                    tooltip: 'Remove member',
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
