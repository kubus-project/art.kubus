import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../models/conversation.dart';
import '../models/user.dart';
import '../models/message.dart';
import 'messages_screen.dart';
import '../providers/chat_provider.dart';
import '../services/socket_service.dart';
import '../services/push_notification_service.dart';
import '../providers/profile_provider.dart';
import '../services/user_service.dart';
import '../services/backend_api_service.dart';
import '../widgets/avatar_widget.dart';

// Use AvatarWidget from widgets to render avatars safely

class ConversationScreen extends StatefulWidget {
  final Conversation conversation;
  const ConversationScreen({super.key, required this.conversation});

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  late ChatProvider _chatProvider;
  final SocketService _socketService = SocketService();
  List<ChatMessage> _messages = [];
  bool _isUploading = false;
  final ScrollController _scrollController = ScrollController();
  // Use index-based keys to avoid duplicate GlobalKey instances when message ids
  // are missing, invalid, or duplicated by the backend (which can crash the app).
  final Map<int, GlobalKey> _messageKeys = {};
  final Map<String, String?> _avatarUrlCache = {};
  final Map<String, String?> _displayNameCache = {};
  Timer? _scrollDebounce;
  final Set<String> _pendingReadMarks = {};
  Timer? _readQueueTimer;
  final List<String> _readQueue = [];
  final int _readQueueDelayMs = 150; // milliseconds between queued read sends
  String? _conversationAvatar;
  List<String> _conversationMembers = [];
  String _normWallet(String? w) => (w ?? '').toString().toLowerCase().trim();
  // Removed UserService cache listener usage; we now fetch user profiles directly.

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _load();
    _chatProvider.addListener(_onChatProviderUpdated);
    // We no longer rely on a global cache notifier to refresh avatar/profile data.
    // Instead, we fetch profiles directly via UserService.getUsersByWallets or
    // UserService.getUserById as needed in background and update local caches.
    if (!mounted) return;

    // Load messages and other conversation initialization off the main path
    Future(() async { try { await _load(); } catch (e) { debugPrint('ConversationScreen.initState: _load error: $e'); } });
    
    // Continue initState: add scroll + socket listeners
    _scrollController.addListener(_onScroll);
    _socketService.addConnectListener(_onSocketConnected);
  }

  Future<void> _fetchAvatarsForMessages(List<ChatMessage> list, [String? myWallet]) async {
    final String currentWallet = myWallet ?? (Provider.of<ProfileProvider>(context, listen: false).currentUser?.walletAddress ?? '');
    final Set<String> wallets = {};
    for (final m in list) {
      final w = m.senderWallet;
      if (w.isEmpty) continue;
      if (_normWallet(w) == _normWallet(currentWallet)) continue;
      // If message supplies avatar/displayName, prefer it to avoid extra lookup
      if (m.senderAvatar != null && m.senderAvatar!.isNotEmpty) {
        _avatarUrlCache[w] = _normalizeAvatar(m.senderAvatar) ?? UserService.safeAvatarUrl(w);
      }
      if (m.senderDisplayName != null && m.senderDisplayName!.isNotEmpty) {
        _displayNameCache[w] = m.senderDisplayName;
      }
      if (!_avatarUrlCache.containsKey(w)) wallets.add(w);
    }
    if (wallets.isNotEmpty) {
      try {
        final users = await UserService.getUsersByWallets(wallets.toList());
        try { _chatProvider.mergeUserCache(users); } catch (_) {}
        if (!mounted) return;
            for (final u in users) {
              final key = (u.id);
                if (key.isNotEmpty) {
                final p = _normalizeAvatar(u.profileImageUrl) ?? UserService.safeAvatarUrl(key);
                _avatarUrlCache[key] = p;
                _displayNameCache[key] = u.name;
              }
            }
        } catch (e) {
        // fallback to per-user fetching
            for (final w in wallets) {
          try {
            final u = await UserService.getUserById(w);
              if (!mounted) return;
            final pUrl = _normalizeAvatar(u?.profileImageUrl) ?? '';
            _avatarUrlCache[w] = (pUrl.isEmpty) ? UserService.safeAvatarUrl(w) : pUrl;
            _displayNameCache[w] = u?.name ?? '';
          } catch (_) {
            _avatarUrlCache[w] = null;
            _displayNameCache[w] = null;
          }
        }
      }
    }
    // setState to repaint avatars
    if (mounted) setState(() {});
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
          if (m.senderAvatar != null && m.senderAvatar!.isNotEmpty) {
            _avatarUrlCache[w] = _normalizeAvatar(m.senderAvatar) ?? UserService.safeAvatarUrl(w);
          }
          if (m.senderDisplayName != null && m.senderDisplayName!.isNotEmpty) {
            _displayNameCache[w] = m.senderDisplayName;
          }
        }
      } catch (_) {}

      // Update UI with messages immediately
      if (mounted) {
        setState(() {
          _messages = list;
          // Ensure keys align to current messages so index-based keys are stable
          _messageKeys.clear();
        });
      }
      debugPrint('ConversationScreen._load: ${_messages.length} messages loaded for ${widget.conversation.id}');

      // Fetch missing avatars/display names in background (non-blocking)
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

          _conversationMembers = wallets;

          // Fetch display name and avatar for header from user service (prefer caches first)
          if (wallets.isNotEmpty) {
            try {
              final missing = <String>[];
              for (final w in wallets) {
                final cu = _chatProvider.getCachedUser(w);
                if (cu != null) {
                  if (cu.profileImageUrl != null && cu.profileImageUrl!.isNotEmpty) _avatarUrlCache[cu.id] = _normalizeAvatar(cu.profileImageUrl) ?? UserService.safeAvatarUrl(cu.id);
                  if (cu.name.isNotEmpty) _displayNameCache[cu.id] = cu.name;
                } else {
                  missing.add(w);
                }
              }
              if (missing.isNotEmpty) {
                final users = await UserService.getUsersByWallets(missing);
                try { _chatProvider.mergeUserCache(users); } catch (_) {}
                for (final u in users) {
                  final key = u.id;
                  if (u.profileImageUrl != null && u.profileImageUrl!.isNotEmpty) _avatarUrlCache[key] = _normalizeAvatar(u.profileImageUrl) ?? UserService.safeAvatarUrl(key);
                  if (u.name.isNotEmpty) _displayNameCache[key] = u.name;
                }
              }
            } catch (_) {}
          }

          // Prefer conversation display avatar from model if present
          _conversationAvatar = _normalizeAvatar(widget.conversation.displayAvatar) ?? widget.conversation.displayAvatar;
          if (_conversationAvatar == null || _conversationAvatar!.isEmpty) {
            if (!widget.conversation.isGroup && wallets.isNotEmpty) {
              final cached = _chatProvider.getCachedUser(wallets.first);
              _conversationAvatar = (cached != null && (cached.profileImageUrl ?? '').isNotEmpty)
                ? (_normalizeAvatar(cached.profileImageUrl) ?? UserService.safeAvatarUrl(cached.id))
                  : (_avatarUrlCache[wallets.first] ?? UserService.safeAvatarUrl(wallets.first));
            }
          }

          if (mounted) {
            debugPrint('ConversationScreen._load: header avatar=$_conversationAvatar, members=${_conversationMembers.length}, display cache keys=${_displayNameCache.keys.length}');
            setState(() {});
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
    await _chatProvider.sendMessage(widget.conversation.id, text);
    if (!mounted) return;
    // Optional: show local notification to user
    PushNotificationService().showCommunityInteractionNotification(postId: widget.conversation.id, type: 'message', userName: 'You', comment: text);
  }

  Widget _buildReadersAvatars(List<Map<String, dynamic>> readers) {
    if (readers.isEmpty) return const SizedBox.shrink();
    final items = readers;
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
                  final effectiveAvatar = (avatar != null && avatar.isNotEmpty) ? (_normalizeAvatar(avatar) ?? UserService.safeAvatarUrl(wallet)) : UserService.safeAvatarUrl(wallet);
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

  Widget _buildAvatar(String? avatarUrl, String wallet, {double radius = 18}) {
    // Delegate to safeAvatarWidget which handles network errors and fallbacks.
    final normalized = _normalizeAvatar(avatarUrl) ?? avatarUrl;
    try {
      debugPrint('ConversationScreen._buildAvatar: wallet=$wallet, avatarUrl=$normalized');
      return AvatarWidget(avatarUrl: normalized, wallet: wallet, radius: radius);
    } catch (e, st) {
      debugPrint('ConversationScreen._buildAvatar: AvatarWidget build failed for $wallet, avatarUrl=$normalized: $e\n$st');
      // Return a simple initials-based fallback to avoid crash
      final parts = wallet.trim().split(RegExp(r'\\s+'));
      final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
      return CircleAvatar(radius: radius, backgroundColor: Colors.grey[300], child: Text(initials.isNotEmpty ? initials : 'U', style: TextStyle(fontSize: (radius * 0.7).clamp(10, 14).toDouble(), fontWeight: FontWeight.w600)));
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

  @override
  void dispose() {
    try { _chatProvider.removeListener(_onChatProviderUpdated); } catch (_) {}
    // No UserService.cacheVersion listener registered here; the variables and listener were removed.
    try { _chatProvider.closeConversation(widget.conversation.id); } catch (_) {}
    _controller.dispose();
    _scrollDebounce?.cancel();
    try { _scrollController.removeListener(_onScroll); } catch (_) {}
    _scrollController.dispose();
    _socketService.removeConnectListener(_onSocketConnected);
    super.dispose();
  }

  void _onScroll() {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 200), () { _checkVisibleMessages(); });
  }

  void _checkVisibleMessages() {
    if (!mounted) return;
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final myWallet = (profile.currentUser?.walletAddress ?? '');
    if (myWallet.isEmpty) return;

    final viewportHeight = MediaQuery.of(context).size.height - (kToolbarHeight + MediaQuery.of(context).padding.top);
    // Iterate by message index so mapping is stable even when message ids are not unique
    for (var i = 0; i < _messages.length; i++) {
      final key = _messageKeys[i];
      if (key == null) continue;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero).dy;
      final height = box.size.height;
      final visible = (pos + height) > 0 && (pos < viewportHeight);
      if (!visible) continue;
      final m = _messages[i];
        if (_normWallet(m.senderWallet) != _normWallet(myWallet) && !m.readByCurrent) {
        // Optimistic UI update
        _chatProvider.markMessageReadLocal(widget.conversation.id, m.id);
        if (!_pendingReadMarks.contains(m.id)) {
          _pendingReadMarks.add(m.id);
          // Queue server-side read marking (throttled to avoid many network calls rapidly)
          _queueMarkMessageRead(m.id);
        }
      }
    }
  }

  void _queueMarkMessageRead(String messageId) {
    if (_readQueue.contains(messageId)) return;
    _readQueue.add(messageId);
    // Start timer to flush queue if not already running
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
        debugPrint('ConversationScreen._queueMarkMessageRead: markMessageRead failed for $id: $e');
      } finally {
        _pendingReadMarks.remove(id);
      }
    });
  }

  void _onChatProviderUpdated() async {
    final msgs = _chatProvider.messages[widget.conversation.id];
    debugPrint('ConversationScreen._onChatProviderUpdated: convId=${widget.conversation.id}, msgsInProvider=${msgs?.length ?? 0}, localMsgs=${_messages.length}');
    debugPrint('ConversationScreen._onChatProviderUpdated: pendingReadMarks=${_pendingReadMarks.length}, readQueue=${_readQueue.length}');
    if (msgs != null) {
      bool equal = false;
      try {
        if (_messages.length == msgs.length) {
          equal = true;
          for (var i = 0; i < msgs.length; i++) {
            final local = _messages[i];
            final remote = msgs[i];
            // If IDs differ, lists changed
            if (local.id != remote.id) { equal = false; break; }
            // If message content changed, or readers changed, we should update UI
            if (local.message != remote.message) { equal = false; break; }
            if (local.readersCount != remote.readersCount) { equal = false; break; }
            if (local.readByCurrent != remote.readByCurrent) { equal = false; break; }
            // Also check basic data equality (attachments etc.)
            final ld = local.data ?? <String, dynamic>{};
            final rd = remote.data ?? <String, dynamic>{};
            if (ld.length != rd.length) { equal = false; break; }
            // shallow compare keys and simple values
            for (final k in ld.keys) {
              if (!rd.containsKey(k) || rd[k].toString() != ld[k].toString()) { equal = false; break; }
            }
            if (!equal) break;
          }
        }
      } catch (_) {}
      if (!equal) {
        setState(() {
          _messages = msgs;
          // Clear keys so they get recreated for new message list indices
          _messageKeys.clear();
        });
      }
      // Check newly visible messages after provider update
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibleMessages());
      // Try to fetch avatars, but avoid blocking the UI; run fetch in background so updates are non-blocking
      Future(() async { try { await _fetchAvatarsForMessages(msgs); } catch (e) { debugPrint('ConversationScreen._onChatProviderUpdated: _fetchAvatarsForMessages failed: $e'); } });
    }
    // If provider has no messages for this conversation but unread count shows new items, try to fetch explicitly
    final providerUnread = Provider.of<ChatProvider>(context, listen: false).unreadCounts[widget.conversation.id] ?? 0;
    if ((msgs == null || msgs.isEmpty) && providerUnread > 0) {
      debugPrint('ConversationScreen: No provider messages found but unreadCount=$providerUnread, reloading messages from API');
      try {
        await _load();
      } catch (e) {
        debugPrint('ConversationScreen: reload due to unread count failed: $e');
      }
    }
  }

  void _onSocketConnected() async {
    // When socket reconnects we want to reload messages for this conversation to ensure latest messages are present
    if (!mounted) return;
    try { await _load(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    String headerInitials() {
      final name = widget.conversation.title ?? (widget.conversation.isGroup ? 'Group' : (_conversationMembers.isNotEmpty ? (_displayNameCache[_conversationMembers.first] ?? _conversationMembers.first) : 'Conversation'));
      final parts = name.trim().split(RegExp(r'\s+'));
      final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
      return initials.isNotEmpty ? initials : 'C';
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
            if (widget.conversation.isGroup)
            // show group/composite or group avatar
            (_conversationAvatar != null && _conversationAvatar!.isNotEmpty)
              ? _buildAvatar(_conversationAvatar, _conversationMembers.isNotEmpty ? _conversationMembers.first : '', radius: 16)
                : SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(children: [
                      if (_conversationMembers.isNotEmpty)
                        Positioned(left: 0, top: 8, child: _buildAvatar(UserService.safeAvatarUrl(_conversationMembers[0]), _conversationMembers[0], radius: 8)),
                      if (_conversationMembers.length > 1)
                        Positioned(left: 12, top: 0, child: _buildAvatar(UserService.safeAvatarUrl(_conversationMembers[1]), _conversationMembers[1], radius: 8)),
                      if (_conversationMembers.length > 2)
                        Positioned(left: 24, top: 8, child: _buildAvatar(UserService.safeAvatarUrl(_conversationMembers[2]), _conversationMembers[2], radius: 8)),
                    ]))
          else
            (_conversationAvatar != null && _conversationAvatar!.isNotEmpty)
              ? _buildAvatar(_conversationAvatar, _conversationMembers.isNotEmpty ? _conversationMembers.first : '', radius: 16)
                : CircleAvatar(radius: 16, child: Text(headerInitials(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Expanded(child: Builder(builder: (ctx) {
            // Prefer provider cache for header display name
            if (widget.conversation.title != null && widget.conversation.title!.isNotEmpty) return Text(widget.conversation.title!);
            if (widget.conversation.isGroup) return const Text('Group');
            if (_conversationMembers.isNotEmpty) {
              final first = _conversationMembers.first;
              final cu = _chatProvider.getCachedUser(first);
              final display = cu != null && cu.name.isNotEmpty ? cu.name : (_displayNameCache[first] ?? first);
              return Text(display);
            }
            return const Text('Conversation');
          })),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.group_add), onPressed: () async {
            final identifier = await showDialog<String?>(context: context, builder: (ctx) => _AddMemberDialog());
            if (!mounted) return;
            if (identifier != null && identifier.isNotEmpty) {
              await _chatProvider.addMember(widget.conversation.id, identifier);
            }
          }),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'members':
                  final profile = Provider.of<ProfileProvider>(context, listen: false);
                  final currentWallet = (profile.currentUser?.walletAddress ?? '');
                  final isOwner = (widget.conversation.createdBy ?? '').toString() == currentWallet;
                  final dialogContext = context;
                  final members = await _chatProvider.fetchMembers(widget.conversation.id);
                  if (!mounted) return;
                  // Resolve display names and avatars for members
                  final wallets = members.map((m) => (m['wallet_address'] as String?) ?? '').where((w) => w.isNotEmpty).toList();
                  List<User> users = [];
                  try { users = await UserService.getUsersByWallets(wallets); } catch (_) {}
                  try { _chatProvider.mergeUserCache(users); } catch (_) {}
                  final memberItems = members.map((m) {
                    final w = (m['wallet_address'] as String?) ?? '';
                    final match = users.where((u) => u.id == w).toList();
                    final user = match.isNotEmpty ? match.first : null;
                    return {'user': user, 'role': m['role'], 'wallet': w};
                  }).toList();
                  // Use dialogContext captured above; we're intentionally awaiting this call and verifying mounted after.
                  // ignore: use_build_context_synchronously
                  final selected = await showDialog<String?>(context: dialogContext, builder: (_) => MembersDialog(members: memberItems, conversationId: widget.conversation.id, isOwner: isOwner));
                  if (!mounted) return;
                  if (selected != null) {
                    await _chatProvider.removeMember(widget.conversation.id, selected);
                    await _load();
                  }
                  break;
                case 'change_group_avatar':
                  if (!widget.conversation.isGroup) break;
                  try {
                    final result = await FilePicker.platform.pickFiles(withData: true);
                    if (result == null || result.files.isEmpty) break;
                    final file = result.files.first;
                    if (file.bytes == null) break;
                    await _chatProvider.uploadConversationAvatar(widget.conversation.id, file.bytes!, file.name, file.extension ?? 'image/png');
                    await _chatProvider.refreshConversations();
                    await _load();
                  } catch (e) { debugPrint('ConversationScreen: change group avatar failed: $e'); }
                  break;
                case 'messages_overlay':
                  // Open messages overlay full-screen modal
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
              if (widget.conversation.isGroup) const PopupMenuItem(value: 'change_group_avatar', child: Text('Change group avatar')),
              const PopupMenuItem(value: 'messages_overlay', child: Text('Open Messages')),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, idx) {
              final m = _messages[idx];
              try {
                final key = _messageKeys.putIfAbsent(idx, () => GlobalKey());
                final profile = Provider.of<ProfileProvider>(context, listen: false);
                  final isMe = profile.currentUser != null && (_normWallet(profile.currentUser!.walletAddress) == _normWallet(m.senderWallet));
              final attachment = m.data?['attachment'] as Map<String, dynamic>?;
              final senderWallet = m.senderWallet;
              final cachedUser = _chatProvider.getCachedUser(senderWallet);
              final senderAvatar = isMe
                ? (_normalizeAvatar(profile.currentUser?.avatar) ?? UserService.safeAvatarUrl(profile.currentUser?.walletAddress ?? senderWallet))
                : (cachedUser != null && (cachedUser.profileImageUrl ?? '').isNotEmpty
                    ? (_normalizeAvatar(cachedUser.profileImageUrl) ?? UserService.safeAvatarUrl(cachedUser.id))
                    : (_avatarUrlCache[senderWallet] ?? UserService.safeAvatarUrl(senderWallet)));
              final senderDisplayName = isMe
                ? (profile.currentUser?.displayName ?? profile.currentUser?.username ?? '')
                : (m.senderDisplayName ?? (cachedUser?.name) ?? _displayNameCache[senderWallet] ?? m.senderUsername ?? '');
              if (attachment != null && attachment['url'] != null) {
                final url = attachment['url'] as String;
                // Render attachment as bubble with file action and optional avatar/readers
                return Container(
                  key: key,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe) _buildAvatar(senderAvatar, senderWallet),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: Theme.of(context).colorScheme.outline.withAlpha((0.1 * 255).round())),
                            boxShadow: Theme.of(context).brightness == Brightness.light ? [BoxShadow(color: Colors.black.withAlpha((0.04 * 255).round()), blurRadius: 4.0, offset: const Offset(0,2))] : null,
                          ),
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                      Text('${m.senderWallet} - Attachment', style: GoogleFonts.inter(fontSize: 13, color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface)),
                              const SizedBox(height: 8),
                              Row(children: [
                                IconButton(icon: const Icon(Icons.open_in_new), onPressed: () async { if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url)); }),
                                Expanded(child: Text('${attachment['filename'] ?? ''}', style: GoogleFonts.inter(fontSize: 13, color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface))),
                              ]),
                              const SizedBox(height: 6),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                if (isMe) Row(children: [
                                    Icon(m.readersCount > 0 ? Icons.done_all : Icons.done,
                                      color: m.readersCount > 0 ? Colors.blue : Theme.of(context).colorScheme.onPrimary.withAlpha((0.95 * 255).round()),
                                      size: 18),
                                  const SizedBox(width: 6),
                                  _buildReadersAvatars(m.readers),
                                ]),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      if (isMe) const SizedBox(width: 8),
                      if (isMe) _buildAvatar(senderAvatar, senderWallet),
                    ],
                  ),
                );
              }
              // Regular text message bubble
              return Container(
                key: key,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe) _buildAvatar(senderAvatar, senderWallet),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                          decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.conversation.isGroup && !isMe && (senderDisplayName.isNotEmpty)) Text(senderDisplayName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isMe ? Theme.of(context).colorScheme.onPrimary.withAlpha((0.85 * 255).round()) : Theme.of(context).colorScheme.onSurface)),
                            if (widget.conversation.isGroup && !isMe && (senderDisplayName.isNotEmpty)) const SizedBox(height: 6),
                            Text(m.message, style: GoogleFonts.inter(fontSize: 14, color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(height: 6),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('${senderDisplayName.isNotEmpty ? senderDisplayName : m.senderWallet} • ${_formatTimeAgo(m.createdAt)}', style: GoogleFonts.inter(fontSize: 10, color: isMe ? Theme.of(context).colorScheme.onPrimary.withAlpha((0.85 * 255).round()) : Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()))),
                              if (isMe) Row(children: [
                                Icon(m.readersCount > 0 ? Icons.done_all : Icons.done,
                                  color: m.readersCount > 0 ? Colors.blue : Theme.of(context).colorScheme.onPrimary.withAlpha((0.95 * 255).round()),
                                  size: 14),
                                const SizedBox(width: 6),
                                _buildReadersAvatars(m.readers),
                              ]),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    if (isMe) const SizedBox(width: 8),
                    if (isMe) _buildAvatar(senderAvatar, senderWallet),
                  ],
                ),
              );
              } catch (e, st) {
                debugPrint('ConversationScreen.itemBuilder: build error for message index=$idx, messageId=${m.id}: $e\n$st');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(children: [const Icon(Icons.error), const SizedBox(width: 8), Expanded(child: Text('Failed to render message'))]),
                );
              }
            },
          )),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Write a message...'))),
                IconButton(icon: const Icon(Icons.attach_file), onPressed: _attachAndSend),
                _isUploading ? const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton(icon: const Icon(Icons.send), onPressed: _send),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _ctrl = TextEditingController();
  final _api = BackendApiService();
  final List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add member by username'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _ctrl, decoration: const InputDecoration(labelText: 'Username (e.g. maya_3d)'), onChanged: (v) {
          _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () async {
            try {
              if (v.trim().isEmpty) {
                if (_suggestions.isNotEmpty) setState(() { _suggestions.clear(); });
                return;
              }
              final resp = await _api.search(query: v.trim(), type: 'profiles', limit: 8);
              List<Map<String, dynamic>> list = [];
              if (resp['success'] == true) {
                final results = resp['results'] as Map<String, dynamic>?;
                final profiles = results != null ? (results['profiles'] as List<dynamic>? ?? []) : (resp['data'] as List<dynamic>? ?? []);
                for (final d in profiles) {
                  try { list.add(d as Map<String, dynamic>); } catch (_) {}
                }
              }
              setState(() { _suggestions.clear(); _suggestions.addAll(list); });
            } catch (e) {
              debugPrint('AddMemberDialog: search failure: $e');
            }
          });
        }),
        if (_suggestions.isNotEmpty) SizedBox(height: 160, child: ListView.builder(itemCount: _suggestions.length, itemBuilder: (ctx, idx) {
            final s = _suggestions[idx];
            final username = s['username'] ?? s['walletAddress'] ?? s['wallet_address'] ?? '';
            final display = s['displayName'] ?? s['display_name'] ?? '';
            final avatar = s['avatar'] ?? s['avatar_url'] ?? '';
            // Use default avatar url if none available to avoid initials-only avatars
            final effectiveAvatar = (avatar != null && avatar.toString().isNotEmpty) ? avatar.toString() : UserService.safeAvatarUrl((username ?? '').toString());
            return ListTile(
              leading: AvatarWidget(avatarUrl: effectiveAvatar, wallet: (username ?? '').toString()),
              title: Text(display ?? username),
              subtitle: Text(username ?? ''),
              onTap: () => Navigator.of(context).pop(username.toString()),
            );
        }))
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()), child: const Text('Add')),
      ],
    );
  }
}

class MembersDialog extends StatelessWidget {
  final List<Map<String, dynamic>> members; // each map contains 'user' (User or null), 'role', 'wallet'
  final String conversationId;
  final bool isOwner;
  const MembersDialog({super.key, required this.members, required this.conversationId, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conversation Members'),
      content: SizedBox(
        width: 320,
        child: ListView.builder(
          itemCount: members.length,
            itemBuilder: (ctx, idx) {
            final m = members[idx];
            final user = m['user'] as User?;
            final role = m['role'] as String? ?? '';
            final wallet = (m['wallet'] as String?) ?? (user?.id ?? '');
            final avatarUrl = (user != null && (user.profileImageUrl?.isNotEmpty ?? false))
              ? (user.profileImageUrl!.startsWith('/') ? BackendApiService().baseUrl.replaceAll(RegExp(r'/$'), '') + user.profileImageUrl! : user.profileImageUrl)
              : UserService.safeAvatarUrl(wallet);
            final avatarUrlStr = avatarUrl ?? UserService.safeAvatarUrl(wallet);
            return ListTile(
              leading: AvatarWidget(avatarUrl: avatarUrlStr, wallet: wallet),
              title: Text(user?.name ?? wallet),
              subtitle: Text(role),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isOwner && wallet != (Provider.of<ProfileProvider>(ctx, listen: false).currentUser?.walletAddress ?? '')) IconButton(icon: const Icon(Icons.person_add), onPressed: () async {
                  final provider = Provider.of<ChatProvider>(ctx, listen: false);
                  final messenger = ScaffoldMessenger.of(ctx);
                  final navigator = Navigator.of(ctx);
                  final confirmed = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
                    title: const Text('Transfer ownership'),
                    content: Text('Transfer conversation ownership to $wallet?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Transfer')),
                    ],
                  ));
                  if (confirmed != true) return;
                  try {
                    await provider.transferOwnership(conversationId, wallet);
                    navigator.pop();
                  } catch (e) {
                    // Show failure and close
                    messenger.showSnackBar(SnackBar(content: Text('Transfer failed: $e')));
                    navigator.pop();
                  }
                }),
                IconButton(icon: const Icon(Icons.remove_circle), onPressed: () {
                  // return removed wallet
                  Navigator.of(ctx).pop(wallet);
                }),
              ]),
            );
          }
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
