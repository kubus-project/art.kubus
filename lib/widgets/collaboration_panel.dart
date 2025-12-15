import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/collab_member.dart';
import '../providers/collab_provider.dart';
import '../services/backend_api_service.dart';
import '../widgets/avatar_widget.dart';

class CollaborationPanel extends StatefulWidget {
  final String entityType;
  final String entityId;

  /// Current user's collaboration role for this entity, if known (e.g. event.myRole).
  /// Used to gate role-management controls.
  final String? myRole;

  const CollaborationPanel({
    super.key,
    required this.entityType,
    required this.entityId,
    this.myRole,
  });

  @override
  State<CollaborationPanel> createState() => _CollaborationPanelState();
}

class _CollaborationPanelState extends State<CollaborationPanel> {
  final BackendApiService _api = BackendApiService();
  final TextEditingController _inviteController = TextEditingController();

  Timer? _debounce;
  int _requestSeq = 0;

  bool _loadingSuggestions = false;
  List<_ProfileSuggestion> _suggestions = <_ProfileSuggestion>[];

  String _inviteRole = 'viewer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMembers();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final collab = context.read<CollabProvider>();
    try {
      await collab.loadCollaborators(widget.entityType, widget.entityId);
    } catch (_) {
      // provider handles error state
    }
  }

  int? _rank(String? role) {
    final r = (role ?? '').trim().toLowerCase();
    const ranks = <String, int>{
      'viewer': 0,
      'curator': 1,
      'editor': 2,
      'publisher': 3,
      'admin': 4,
      'owner': 5,
    };
    return ranks[r];
  }

  bool get _canManageMembers {
    final my = _rank(widget.myRole);
    if (my == null) return false;
    return my >= (_rank('admin') ?? 4);
  }

  bool _canAssignRole(String targetRole) {
    final my = _rank(widget.myRole);
    final target = _rank(targetRole);
    if (my == null || target == null) return false;
    if (targetRole.toLowerCase() == 'owner') return false;
    return my >= target;
  }

  Future<void> _onInviteChanged(String raw) async {
    _debounce?.cancel();
    final query = raw.trim().replaceFirst(RegExp(r'^@+'), '');
    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = <_ProfileSuggestion>[];
          _loadingSuggestions = false;
        });
      }
      return;
    }

    final int seq = ++_requestSeq;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _loadingSuggestions = true);

      try {
        // Prefer lightweight autocomplete endpoint; fall back to full profile search.
        final suggestions = await _api.getSearchSuggestions(query: query, limit: 10);
        if (!mounted || seq != _requestSeq) return;

        final profiles = <_ProfileSuggestion>[];
        for (final s in suggestions) {
          final type = (s['type'] ?? '').toString().toLowerCase();
          if (type.isNotEmpty && type != 'profile' && type != 'profiles') continue;

          final username = (s['text'] ?? '').toString();
          if (username.isEmpty) continue;
          profiles.add(_ProfileSuggestion(
            username: username,
            displayName: (s['secondaryText'] ?? s['secondary_text'] ?? '').toString().trim().isEmpty
                ? null
                : (s['secondaryText'] ?? s['secondary_text']).toString(),
            avatarUrl: (s['icon'] ?? '').toString().trim().isEmpty ? null : (s['icon']).toString(),
          ));
        }

        if (profiles.isNotEmpty) {
          setState(() {
            _suggestions = profiles.take(8).toList(growable: false);
            _loadingSuggestions = false;
          });
          return;
        }

        // Fallback: full search endpoint.
        final resp = await _api.search(query: query, type: 'profiles', limit: 8);
        if (!mounted || seq != _requestSeq) return;

        final results = <_ProfileSuggestion>[];
        if (resp['success'] == true) {
          final resultsNode = resp['results'];
          final list = (resultsNode is Map<String, dynamic>) ? (resultsNode['profiles'] as List<dynamic>? ?? const []) : const [];
          for (final item in list) {
            if (item is! Map) continue;
            final m = item.map((k, v) => MapEntry(k.toString(), v));
            final username = (m['username'] ?? '').toString();
            if (username.isEmpty) continue;
            results.add(_ProfileSuggestion(
              username: username,
              displayName: (m['displayName'] ?? m['display_name'])?.toString(),
              avatarUrl: (m['avatarUrl'] ?? m['avatar_url'] ?? m['avatar'])?.toString(),
            ));
          }
        }

        setState(() {
          _suggestions = results;
          _loadingSuggestions = false;
        });
      } catch (_) {
        if (!mounted || seq != _requestSeq) return;
        setState(() {
          _suggestions = <_ProfileSuggestion>[];
          _loadingSuggestions = false;
        });
      }
    });
  }

  Future<void> _sendInvite() async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final collab = context.read<CollabProvider>();

    final raw = _inviteController.text.trim();
    final identifier = raw.replaceFirst(RegExp(r'^@+'), '').trim();

    if (identifier.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Enter a username or email.'),
          backgroundColor: scheme.surface,
        ),
      );
      return;
    }

    // Enforce the UX rule: username/email only.
    // If it looks like a wallet address, nudge the user to use a username/email.
    final looksLikeWallet = identifier.length >= 32 && !identifier.contains('@');
    if (looksLikeWallet) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Use a username or email to invite someone.'),
          backgroundColor: scheme.surface,
        ),
      );
      return;
    }

    try {
      await collab.inviteCollaborator(
        entityType: widget.entityType,
        entityId: widget.entityId,
        invitedIdentifier: identifier,
        role: _canAssignRole(_inviteRole) ? _inviteRole : 'viewer',
      );
      if (!mounted) return;
      setState(() {
        _inviteController.clear();
        _suggestions = <_ProfileSuggestion>[];
        _inviteRole = 'viewer';
      });
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Invite sent.'),
          backgroundColor: scheme.surface,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Could not send invite. Try again.'),
          backgroundColor: scheme.surface,
        ),
      );
    }
  }

  Future<void> _updateMemberRole(CollabMember member, String newRole) async {
    if (!_canManageMembers) return;
    if (!_canAssignRole(newRole)) return;

    final messenger = ScaffoldMessenger.of(context);
    final collab = context.read<CollabProvider>();

    try {
      await collab.updateCollaboratorRole(
        entityType: widget.entityType,
        entityId: widget.entityId,
        memberUserId: member.userId,
        role: newRole,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Role updated.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not update role.')));
    }
  }

  Future<void> _removeMember(CollabMember member) async {
    if (!_canManageMembers) return;

    final messenger = ScaffoldMessenger.of(context);
    final collab = context.read<CollabProvider>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remove collaborator?'),
          content: Text('This will revoke access for ${member.user?.displayName ?? member.user?.username ?? 'this person'}.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await collab.removeCollaborator(
        entityType: widget.entityType,
        entityId: widget.entityId,
        memberUserId: member.userId,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Removed.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not remove collaborator.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final collab = context.watch<CollabProvider>();
    final members = collab.collaboratorsFor(widget.entityType, widget.entityId);

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Collaboration',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (collab.isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadMembers,
                    icon: Icon(Icons.refresh, color: scheme.onSurface.withValues(alpha: 0.75)),
                  ),
              ],
            ),
            if ((collab.error ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Could not load collaborators.',
                  style: GoogleFonts.inter(color: scheme.error, fontSize: 12),
                ),
              ),

            _buildInviteSection(scheme),
            const SizedBox(height: 12),

            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No collaborators yet.',
                  style: GoogleFonts.inter(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              )
            else
              Column(
                children: members.map((m) => _buildMemberRow(m, scheme)).toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteSection(ColorScheme scheme) {
    final canPickRole = _canManageMembers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite someone',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _inviteController,
                    decoration: InputDecoration(
                      hintText: 'Username or email',
                      prefixIcon: const Icon(Icons.person_add_alt_1),
                      suffixIcon: _loadingSuggestions
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              ),
                            )
                          : (_inviteController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear',
                                  onPressed: () {
                                    setState(() {
                                      _inviteController.clear();
                                      _suggestions = <_ProfileSuggestion>[];
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                )
                              : null),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {});
                      unawaited(_onInviteChanged(v));
                    },
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                        itemBuilder: (ctx, i) {
                          final s = _suggestions[i];
                          final seed = s.username.isNotEmpty ? s.username : (s.displayName ?? 'user');
                          return ListTile(
                            dense: true,
                            leading: AvatarWidget(
                              avatarUrl: s.avatarUrl,
                              wallet: seed,
                              radius: 16,
                              allowFabricatedFallback: true,
                              enableProfileNavigation: false,
                            ),
                            title: Text(
                              s.displayName ?? '@${s.username}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '@${s.username}',
                              style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
                            ),
                            onTap: () {
                              setState(() {
                                _inviteController.text = s.username;
                                _suggestions = <_ProfileSuggestion>[];
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: canPickRole ? 160 : 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canPickRole)
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('inviteRole:$_inviteRole'),
                      initialValue: _inviteRole,
                      items: const [
                        DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                        DropdownMenuItem(value: 'curator', child: Text('Curator')),
                        DropdownMenuItem(value: 'editor', child: Text('Editor')),
                        DropdownMenuItem(value: 'publisher', child: Text('Publisher')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        if (!_canAssignRole(v)) return;
                        setState(() => _inviteRole = v);
                      },
                      decoration: InputDecoration(
                        labelText: 'Role',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  if (canPickRole) const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => unawaited(_sendInvite()),
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Invite collaborators by username or email.',
          style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildMemberRow(CollabMember member, ColorScheme scheme) {
    final user = member.user;
    final displayName = (user?.displayName ?? '').trim();
    final username = (user?.username ?? '').trim();
    final title = displayName.isNotEmpty
        ? displayName
        : (username.isNotEmpty ? '@$username' : 'Collaborator');
    final subtitle = username.isNotEmpty ? '@$username' : null;

    final seed = (user?.walletAddress ?? '').trim().isNotEmpty
        ? user!.walletAddress!
        : (username.isNotEmpty ? username : (displayName.isNotEmpty ? displayName : member.userId));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          AvatarWidget(
            avatarUrl: user?.avatarUrl,
            wallet: seed,
            radius: 18,
            allowFabricatedFallback: true,
            enableProfileNavigation: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: scheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_canManageMembers)
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>('memberRole:${member.userId}:${member.role}'),
                initialValue: member.role,
                items: const [
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                  DropdownMenuItem(value: 'curator', child: Text('Curator')),
                  DropdownMenuItem(value: 'editor', child: Text('Editor')),
                  DropdownMenuItem(value: 'publisher', child: Text('Publisher')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  unawaited(_updateMemberRole(member, v));
                },
                decoration: InputDecoration(
                  labelText: 'Role',
                  filled: true,
                  fillColor: scheme.surface.withValues(alpha: 0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            )
          else
            Text(
              _roleLabel(member.role),
              style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.75)),
            ),
          if (_canManageMembers)
            IconButton(
              tooltip: 'Remove',
              onPressed: () => unawaited(_removeMember(member)),
              icon: Icon(Icons.person_remove, color: scheme.onSurface.withValues(alpha: 0.75)),
            ),
        ],
      ),
    );
  }

  String _roleLabel(String raw) {
    final r = raw.trim().toLowerCase();
    switch (r) {
      case 'admin':
        return 'Admin';
      case 'publisher':
        return 'Publisher';
      case 'editor':
        return 'Editor';
      case 'curator':
        return 'Curator';
      case 'viewer':
      default:
        return 'Viewer';
    }
  }
}

@immutable
class _ProfileSuggestion {
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const _ProfileSuggestion({
    required this.username,
    this.displayName,
    this.avatarUrl,
  });
}
