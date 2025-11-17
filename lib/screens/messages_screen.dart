import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../services/user_service.dart';
import '../services/backend_api_service.dart';
import '../models/user.dart';
import 'conversation_screen.dart';
import '../widgets/avatar_widget.dart';
import 'package:file_picker/file_picker.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late ChatProvider _chatProvider;
  final Map<String, String?> _conversationAvatars = {};
  final Map<String, String?> _conversationNames = {};
  final Map<String, List<String>> _convToWalletList = {};
  final Set<String> _pendingMemberLoads = {};

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _chatProvider.initialize();
    _chatProvider.refreshConversations();
    _chatProvider.addListener(_onChatProviderChanged);
    // Proactively ensure members are loaded for existing conversations immediately
    // (removed short delay to avoid flicker when opening the messages screen)
    try {
      final convs = _chatProvider.conversations;
      // Defer heavy member/avatar prefetch slightly so navigation can complete
      Future.delayed(const Duration(milliseconds: 20), () {
        for (final c in convs) {
          if ((_conversationAvatars[c.id] ?? '').isEmpty || (_conversationNames[c.id] ?? '').isEmpty) {
            // fire-and-forget per-conversation load
            _ensureConversationMembersLoaded(c.id);
          }
        }
        // Also attempt to load avatars in batch (non-blocking)
        _loadConversationAvatars();
      });
    } catch (_) {}
  }

  void _onChatProviderChanged() {
    try {
      _loadConversationAvatars();
    } catch (_) {}
  }

  Future<void> _loadConversationAvatars() async {
    try {
      final convs = _chatProvider.conversations;
      if (convs.isEmpty) return;
      // Determine wallets to fetch (for one-to-one conversations use other member
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final myWallet = (profile.currentUser?.walletAddress ?? '');
      final Map<String, List<String>> convToWallet = {};
      final Set<String> wallets = {};
      final futures = <Future>[];
      // Avoid fetching members for all conversations at once (throttle to avoid rate limits)
      final toFetch = convs.take(25).toList();
      for (final c in toFetch) {
        // fetch members for this conversation
          futures.add(_chatProvider.fetchMembers(c.id).then((mbrs) {
          final others = (mbrs as List).map((e) => (e['wallet_address'] as String?)?.toString() ?? '').where((w) => w.isNotEmpty && w != myWallet).toList();
          if (others.isNotEmpty) {
            convToWallet[c.id] = others;
            for (final w in others) {
              wallets.add(w);
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
      try { Provider.of<ChatProvider>(context, listen: false).mergeUserCache(users); } catch (_) {}
      for (final c in convToWallet.keys) {
        final walletsForConv = convToWallet[c]!;
        _convToWalletList[c] = walletsForConv;
        // For direct conv, find first other participant for avatar; for group, we'll use composite later
          if (walletsForConv.isNotEmpty) {
          final wallet = walletsForConv.first;
          final match = users.where((u) => u.id == wallet).toList();
          final avatar = match.isNotEmpty ? (match.first.profileImageUrl ?? '') : '';
          _conversationAvatars[c] = avatar.isNotEmpty ? avatar : UserService.safeAvatarUrl(wallet);
            final name = match.isNotEmpty ? match.first.name : '';
            _conversationNames[c] = name.isNotEmpty ? name : wallet;
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
    final safe = wallets.map((w) => UserService.safeAvatarUrl(w)).toList();
    // Positioning for 1..4 avatars
    if (count == 1) {
      return SizedBox(width: size, height: size, child: ClipOval(child: Image.network(safe[0], width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => AvatarWidget(avatarUrl: safe[0], wallet: wallets[0], radius: size/2))));
    }
    // For 2 avatars: left/right
    if (count == 2) {
      return SizedBox(width: size, height: size, child: Stack(children: [
        Positioned(left: 0, top: size * 0.15, child: AvatarWidget(avatarUrl: safe[0], wallet: wallets[0], radius: size * 0.35)),
        Positioned(right: 0, top: size * 0.15, child: AvatarWidget(avatarUrl: safe[1], wallet: wallets[1], radius: size * 0.35)),
      ]));
    }
    // For 3 avatars: triangle
    if (count == 3) {
      return SizedBox(width: size, height: size, child: Stack(children: [
        Positioned(left: size * 0.25, top: 0, child: AvatarWidget(avatarUrl: safe[0], wallet: wallets[0], radius: size * 0.28)),
        Positioned(left: 0, bottom: 0, child: AvatarWidget(avatarUrl: safe[1], wallet: wallets[1], radius: size * 0.28)),
        Positioned(right: 0, bottom: 0, child: AvatarWidget(avatarUrl: safe[2], wallet: wallets[2], radius: size * 0.28)),
      ]));
    }
    // 4 or more: 2x2 grid using first 4
    return SizedBox(width: size, height: size, child: Stack(children: [
      Positioned(left: 0, top: 0, child: AvatarWidget(avatarUrl: safe[0], wallet: wallets[0], radius: size * 0.28)),
      Positioned(right: 0, top: 0, child: AvatarWidget(avatarUrl: safe[1], wallet: wallets[1], radius: size * 0.28)),
      Positioned(left: 0, bottom: 0, child: AvatarWidget(avatarUrl: safe[2], wallet: wallets[2], radius: size * 0.28)),
      Positioned(right: 0, bottom: 0, child: AvatarWidget(avatarUrl: safe[3], wallet: wallets[3], radius: size * 0.28)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Messages'),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, cp, _) {
          final convs = cp.conversations;
          if (convs.isEmpty) {
            return const Center(child: Text('No conversations')); 
          }
          return ListView.builder(
            itemCount: convs.length,
            itemBuilder: (context, idx) {
              final c = convs[idx];
              String? avatar = c.displayAvatar ?? _conversationAvatars[c.id];
              // Normalize relative avatar URLs returned by backend (start with '/') to absolute using backend baseUrl
              String? normalizeAvatar(String? a) {
                if (a == null || a.isEmpty) return null;
                try {
                  if (a.startsWith('/')) {
                    final base = BackendApiService().baseUrl.replaceAll(RegExp(r'/$'), '');
                    return base + a;
                  }
                } catch (_) {}
                return a;
              }
              avatar = normalizeAvatar(avatar);
              Widget leading;
              if (avatar != null && avatar.isNotEmpty) {
                leading = AvatarWidget(avatarUrl: avatar, wallet: c.id, radius: 20);
              } else if (c.isGroup) {
                final listWallets = _convToWalletList[c.id] ?? [];
                if (listWallets.isNotEmpty) {
                  leading = _buildGroupAvatar(listWallets, 48);
                } else {
                  leading = CircleAvatar(radius: 20, child: Icon(Icons.group));
                }
              } else {
                // Fallback for one-to-one: use other participant's wallet if available
                final fallbackWallet = (_convToWalletList[c.id] != null && _convToWalletList[c.id]!.isNotEmpty) ? _convToWalletList[c.id]!.first : '';
                if (fallbackWallet.isNotEmpty) {
                  // Prefer cached user profile avatar if available
                  final cached = cp.getCachedUser(fallbackWallet);
                  final fallbackAvatar = (cached != null && (cached.profileImageUrl ?? '').isNotEmpty) ? cached.profileImageUrl! : UserService.safeAvatarUrl(fallbackWallet);
                  leading = AvatarWidget(avatarUrl: fallbackAvatar, wallet: fallbackWallet, radius: 20);
                } else {
                  // No wallet available: render initials locally to avoid network call
                  final name = c.title ?? (c.isGroup ? 'Group' : c.title ?? 'Conversation');
                  final parts = name.trim().split(RegExp(r'\s+'));
                  final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
                  leading = CircleAvatar(child: Text(initials.isNotEmpty ? initials : 'C'));
                }
              // If we still don't have avatar/name, try to proactively load members for this conversation
              if ((avatar == null || avatar.isEmpty) && !_pendingMemberLoads.contains(c.id)) {
                _ensureConversationMembersLoaded(c.id);
              }
              }
              // Determine title preferring conversation title, then cached user name for direct chats, then precomputed conversation name
              String titleText = c.title ?? '';
              if (titleText.isEmpty) {
                if (!c.isGroup) {
                  final fallbackWallet = (_convToWalletList[c.id] != null && _convToWalletList[c.id]!.isNotEmpty) ? _convToWalletList[c.id]!.first : '';
                  final cached = (fallbackWallet.isNotEmpty) ? cp.getCachedUser(fallbackWallet) : null;
                  if (cached != null && cached.name.isNotEmpty) titleText = cached.name;
                }
                if (titleText.isEmpty) titleText = c.isGroup ? 'Group' : (_conversationNames[c.id] ?? 'Conversation');
              }
              return ListTile(
                leading: leading,
                title: Text(titleText),
                subtitle: Text(c.lastMessage ?? ''),
                trailing: (cp.unreadCounts[c.id] ?? 0) > 0 ? CircleAvatar(child: Text('${cp.unreadCounts[c.id]}')) : null,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: c)));
                },
              );
            },
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
        child: const Icon(Icons.chat),
        onPressed: () async {
          // Simple create conversation: members entry (comma separated wallets)
          final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => _CreateConversationDialog());
          if (!mounted) return;
          if (result != null && result['members'] != null) {
            await _chatProvider.createConversation(result['title'] as String? ?? '', result['isGroup'] as bool? ?? false, (result['members'] as List<String>));
          }
        },
      ),
    );
  }

  // Proactively fetch members and resolve avatars/names for a single conversation row.
  Future<void> _ensureConversationMembersLoaded(String conversationId) async {
    if (_pendingMemberLoads.contains(conversationId)) return;
    _pendingMemberLoads.add(conversationId);
    try {
      final mbrs = await _chatProvider.fetchMembers(conversationId);
    
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final myWallet = (profile.currentUser?.walletAddress ?? '');
      final wallets = (mbrs as List).map((e) => (e['wallet_address'] as String?)?.toString() ?? '').where((w) => w.isNotEmpty && w != myWallet).toList();
      if (wallets.isEmpty) return;
      _convToWalletList[conversationId] = wallets;
      try {
        // Prefer cached user profiles from ChatProvider to avoid duplicate network calls
        User? cachedUser;
        for (final w in wallets) {
          final cu = _chatProvider.getCachedUser(w);
          if (cu != null) { cachedUser = cu; break; }
        }
        if (cachedUser != null) {
          final avatar = cachedUser.profileImageUrl ?? '';
          _conversationAvatars[conversationId] = avatar.isNotEmpty ? avatar : UserService.safeAvatarUrl(cachedUser.id);
          _conversationNames[conversationId] = cachedUser.name.isNotEmpty ? cachedUser.name : cachedUser.id;
        } else {
          final users = await UserService.getUsersByWallets(wallets);
          try { Provider.of<ChatProvider>(context, listen: false).mergeUserCache(users); } catch (_) {}
          if (users.isNotEmpty) {
            final u = users.firstWhere((x) => wallets.contains(x.id), orElse: () => users.first);
            final avatar = u.profileImageUrl ?? '';
            _conversationAvatars[conversationId] = avatar.isNotEmpty ? avatar : UserService.safeAvatarUrl(u.id);
            _conversationNames[conversationId] = u.name.isNotEmpty ? u.name : u.id;
            debugPrint('MessagesScreen: loaded members for $conversationId -> name=${_conversationNames[conversationId]}, avatar=${_conversationAvatars[conversationId]}');
          }
        }
      } catch (e) {
        // best-effort: use safe avatar for first wallet
        final fallback = wallets.isNotEmpty ? UserService.safeAvatarUrl(wallets.first) : null;
        if (fallback != null) _conversationAvatars[conversationId] = fallback;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('MessagesScreen: _ensureConversationMembersLoaded failed for $conversationId: $e');
    } finally {
      _pendingMemberLoads.remove(conversationId);
    }
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
    return AlertDialog(
      title: const Text('Create Conversation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title (optional)')),
          Wrap(children: _memberList.map((m) => Chip(label: Text(m), onDeleted: () => setState(() => _memberList.remove(m)))).toList()),
          TextField(controller: _members, decoration: const InputDecoration(labelText: 'Members (username or wallet)'), onChanged: (v) async {
            if (v.trim().isEmpty) {
              setState(() => _memberSuggestions.clear());
              return;
            }
            try {
              final resp = await _api.search(query: v.trim(), type: 'profiles', limit: 6);
              final list = <Map<String, dynamic>>[];
              if (resp['success'] == true && resp['data'] != null) {
                for (final d in resp['data']) {
                  try { list.add(d as Map<String, dynamic>); } catch (_) {}
                }
              }
              setState(() => _memberSuggestions.clear());
              setState(() => _memberSuggestions.addAll(list));
            } catch (e) {
              debugPrint('CreateConversationDialog: profile search error: $e');
            }
          }),
              if (_memberSuggestions.isNotEmpty) SizedBox(height: 120, child: ListView.builder(itemBuilder: (ctx, idx) {
            final s = _memberSuggestions[idx];
            final username = s['username'] ?? s['wallet_address'] ?? s['wallet'];
            final display = s['displayName'] ?? s['display_name'] ?? '';
            final avatar = s['avatar'] ?? s['avatar_url'] ?? '';
            final effectiveAvatar = (avatar != null && avatar.toString().isNotEmpty) ? avatar.toString() : UserService.safeAvatarUrl((username ?? '').toString());
            return ListTile(title: Text(display ?? username), subtitle: Text(username ?? ''), leading: AvatarWidget(avatarUrl: effectiveAvatar, wallet: (username ?? '').toString(), radius: 20), onTap: () {
              if ((username ?? '').isNotEmpty) setState(() { _memberList.add(username.toString()); _members.clear(); _memberSuggestions.clear(); });
            });
          }, itemCount: _memberSuggestions.length)),
          Row(children: [
            ElevatedButton.icon(icon: Icon(Icons.upload_file), label: Text('Group avatar (optional)'), onPressed: () async {
              try {
                final result = await FilePicker.platform.pickFiles(withData: true);
                if (result?.files.isNotEmpty ?? false) {
                  final file = result!.files.first;
                  setState(() { _avatarBytes = file.bytes; });
                }
              } catch (e) { debugPrint('CreateConversationDialog: avatar pick error: $e'); }
            }),
            const SizedBox(width: 8),
            if (_avatarBytes != null) CircleAvatar(backgroundImage: MemoryImage(_avatarBytes!))
          ]),
          SwitchListTile(value: _isGroup, onChanged: (v) => setState(() => _isGroup = v), title: const Text('Group')),
        ],
      ),
      actions: [
        TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
        TextButton(child: const Text('Create'), onPressed: () async {
          final manualMembers = _members.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final members = [..._memberList, ...manualMembers];
          final res = await Provider.of<ChatProvider>(context, listen: false).createConversation(_title.text, _isGroup, members);
          if (res != null && _avatarBytes != null) {
            try {
              await Provider.of<ChatProvider>(context, listen: false).uploadConversationAvatar(res.id, _avatarBytes!, 'group_avatar.png', 'image/png');
            } catch (e) { debugPrint('Failed to upload group avatar after create: $e'); }
          }
          Navigator.of(context).pop({'title': _title.text, 'isGroup': _isGroup, 'members': members});
        }),
      ],
    );
  }
}
