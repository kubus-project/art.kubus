import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/collab_member.dart';
import '../models/user.dart';
import '../providers/collab_provider.dart';
import '../providers/profile_provider.dart';
import '../services/backend_api_service.dart';
import '../services/user_service.dart';
import '../utils/creator_display_format.dart';
import '../utils/design_tokens.dart';
import '../utils/wallet_utils.dart';
import '../utils/user_profile_navigation.dart';
import '../widgets/avatar_widget.dart';
import 'glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

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
  Timer? _memberProfileResolveDebounce;
  bool _memberProfileResolutionQueued = false;
  String _lastResolvedWalletsSignature = '';
  List<String> _pendingResolveWallets = const <String>[];
  bool _pendingResolveForceRefresh = false;
  int _requestSeq = 0;

  bool _loadingSuggestions = false;
  List<_ProfileSuggestion> _suggestions = <_ProfileSuggestion>[];

  String _inviteRole = 'viewer';

  final Map<String, User> _resolvedUsersByWallet = <String, User>{};
  bool _memberProfileResolutionInFlight = false;

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
    _memberProfileResolveDebounce?.cancel();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final collab = context.read<CollabProvider>();
    try {
      await collab.loadCollaborators(widget.entityType, widget.entityId);
      if (!mounted) return;
      final members = collab.collaboratorsFor(widget.entityType, widget.entityId);
      _queueMemberProfileResolution(members, forceRefresh: true);
    } catch (_) {
      // provider handles error state
    }
  }

  void _queueMemberProfileResolution(
    List<CollabMember> members, {
    required bool forceRefresh,
  }) {
    if (members.isEmpty) return;

    final wallets = members
        .map((m) => WalletUtils.canonical(m.user?.walletAddress ?? m.userId))
        .where((w) => w.isNotEmpty && WalletUtils.looksLikeWallet(w))
        .toSet()
        .toList(growable: false)
      ..sort();

    if (wallets.isEmpty) return;

    final signature = wallets.join('|');
    if (!forceRefresh && signature == _lastResolvedWalletsSignature) {
      return;
    }
    _lastResolvedWalletsSignature = signature;
    _pendingResolveWallets = wallets;
    _pendingResolveForceRefresh = forceRefresh;

    if (_memberProfileResolutionQueued) return;
    _memberProfileResolutionQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _memberProfileResolutionQueued = false;
      if (!mounted) return;
      final pending = _pendingResolveWallets;
      final pendingForceRefresh = _pendingResolveForceRefresh;
      _pendingResolveWallets = const <String>[];
      _pendingResolveForceRefresh = false;
      _scheduleWalletProfileResolution(
        pending,
        forceRefresh: pendingForceRefresh,
      );
    });
  }

  void _scheduleWalletProfileResolution(
    List<String> wallets, {
    required bool forceRefresh,
  }) {
    if (wallets.isEmpty) return;
    if (_memberProfileResolutionInFlight) {
      // Avoid dropping updates while a previous resolve call is still in flight.
      // Store the latest requested wallets and retry once the current call settles.
      _pendingResolveWallets = wallets;
      _pendingResolveForceRefresh = _pendingResolveForceRefresh || forceRefresh;
      return;
    }

    _memberProfileResolveDebounce?.cancel();
    _memberProfileResolveDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      unawaited(_resolveMemberProfiles(wallets, forceRefresh: forceRefresh));
    });
  }

  Future<void> _resolveMemberProfiles(
    List<String> wallets, {
    required bool forceRefresh,
  }) async {
    if (wallets.isEmpty) return;
    if (_memberProfileResolutionInFlight) return;
    _memberProfileResolutionInFlight = true;
    try {
      final users = await UserService.getUsersByWallets(
        wallets,
        forceRefresh: forceRefresh,
        batchFirstThreshold: 2,
      );
      if (!mounted) return;
      setState(() {
        for (final u in users) {
          final key = WalletUtils.canonical(u.id);
          if (key.isEmpty) continue;
          _resolvedUsersByWallet[key] = u;
        }
      });
    } finally {
      _memberProfileResolutionInFlight = false;
      if (!mounted) return;
      final pending = _pendingResolveWallets;
      if (pending.isEmpty) return;
      final pendingForceRefresh = _pendingResolveForceRefresh;
      _pendingResolveWallets = const <String>[];
      _pendingResolveForceRefresh = false;
      _scheduleWalletProfileResolution(
        pending,
        forceRefresh: pendingForceRefresh,
      );
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
      // Some backends use synonyms for the top role.
      'author': 5,
      'creator': 5,
    };
    return ranks[r];
  }

  String? _resolveMyRole(
    String? explicit,
    List<CollabMember> members,
    String viewerWallet,
  ) {
    final safeExplicit = (explicit ?? '').trim();
    if (safeExplicit.isNotEmpty) return safeExplicit;
    final viewer = WalletUtils.canonical(viewerWallet);
    if (viewer.isEmpty) return null;

    for (final m in members) {
      final wallet = WalletUtils.canonical(m.user?.walletAddress);
      if (wallet.isNotEmpty && WalletUtils.equals(wallet, viewer)) {
        return m.role;
      }
      if (WalletUtils.equals(m.userId, viewer)) {
        return m.role;
      }
    }
    return null;
  }

  bool _canManageMembers(String? myRole) {
    final my = _rank(myRole);
    if (my == null) return false;
    return my >= (_rank('admin') ?? 4);
  }

  bool _canAssignRole(String? myRole, String targetRole) {
    final my = _rank(myRole);
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

    final profile = context.read<ProfileProvider>();
    if (profile.isSignedIn != true) {
      // Collaboration actions require authentication; this panel should be hidden
      // when signed out, but guard defensively.
      return;
    }
    final members = collab.collaboratorsFor(widget.entityType, widget.entityId);
    final viewerWallet = (profile.currentUser?.walletAddress ?? '').trim();
    final myRole = _resolveMyRole(widget.myRole, members, viewerWallet);
    if (!_canManageMembers(myRole)) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: const Text('You do not have permission to invite collaborators.'),
          backgroundColor: scheme.surface,
        ),
      );
      return;
    }

    final raw = _inviteController.text.trim();
    final identifier = raw.replaceFirst(RegExp(r'^@+'), '').trim();

    if (identifier.isEmpty) {
      messenger.showKubusSnackBar(
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
      messenger.showKubusSnackBar(
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
        role: _canAssignRole(myRole, _inviteRole) ? _inviteRole : 'viewer',
      );
      if (!mounted) return;
      setState(() {
        _inviteController.clear();
        _suggestions = <_ProfileSuggestion>[];
        _inviteRole = 'viewer';
      });
      messenger.showKubusSnackBar(
        SnackBar(
          content: const Text('Invite sent.'),
          backgroundColor: scheme.surface,
        ),
      );
    } catch (_) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: const Text('Could not send invite. Try again.'),
          backgroundColor: scheme.surface,
        ),
      );
    }
  }

  Future<void> _updateMemberRole(CollabMember member, String newRole) async {
    final collab = context.read<CollabProvider>();
    final profile = context.read<ProfileProvider>();
    final members = collab.collaboratorsFor(widget.entityType, widget.entityId);
    final viewerWallet = (profile.currentUser?.walletAddress ?? '').trim();
    final myRole = _resolveMyRole(widget.myRole, members, viewerWallet);

    if (!_canManageMembers(myRole)) return;
    if (!_canAssignRole(myRole, newRole)) return;

    final messenger = ScaffoldMessenger.of(context);
    // collab already read above

    try {
      await collab.updateCollaboratorRole(
        entityType: widget.entityType,
        entityId: widget.entityId,
        memberUserId: member.userId,
        role: newRole,
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(const SnackBar(content: Text('Role updated.')));
    } catch (_) {
      messenger.showKubusSnackBar(const SnackBar(content: Text('Could not update role.')));
    }
  }

  Future<void> _removeMember(CollabMember member) async {
    final collab = context.read<CollabProvider>();
    final profile = context.read<ProfileProvider>();
    final members = collab.collaboratorsFor(widget.entityType, widget.entityId);
    final viewerWallet = (profile.currentUser?.walletAddress ?? '').trim();
    final myRole = _resolveMyRole(widget.myRole, members, viewerWallet);
    if (!_canManageMembers(myRole)) return;

    final messenger = ScaffoldMessenger.of(context);

    final ok = await showKubusDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return KubusAlertDialog(
          title: const Text('Remove collaborator?'),
          content: Text('This will revoke access for ${member.user?.displayName ?? member.user?.username ?? 'this person'}.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.commonCancel)),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.commonRemove)),
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
      messenger.showKubusSnackBar(const SnackBar(content: Text('Removed.')));
    } catch (_) {
      messenger.showKubusSnackBar(const SnackBar(content: Text('Could not remove collaborator.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = context.watch<ProfileProvider>();
    if (profile.isSignedIn != true) {
      // Hide collaboration UI when the user is not authenticated.
      return const SizedBox.shrink();
    }

    final collab = context.watch<CollabProvider>();
    final members = collab.collaboratorsFor(widget.entityType, widget.entityId);
    final viewerWallet = (profile.currentUser?.walletAddress ?? '').trim();
    final myRole = _resolveMyRole(widget.myRole, members, viewerWallet);
    final canManageMembers = _canManageMembers(myRole);

    // Keep member identities fresh (e.g. username/displayName changes).
    _queueMemberProfileResolution(members, forceRefresh: false);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      margin: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Collaboration',
                  style: KubusTextStyles.detailSectionTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (collab.isLoading)
                SizedBox(
                  width: KubusSizes.trailingChevron + KubusSpacing.xxs,
                  height: KubusSizes.trailingChevron + KubusSpacing.xxs,
                  child: CircularProgressIndicator(
                    strokeWidth: KubusSizes.hairline + KubusSpacing.xxs,
                    color: scheme.primary,
                  ),
                )
              else
                IconButton(
                  tooltip: AppLocalizations.of(context)!.commonRefresh,
                  onPressed: _loadMembers,
                  icon: Icon(
                    Icons.refresh,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
          if ((collab.error ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
              child: Text(
                'Could not load collaborators.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              ),
            ),
          if (canManageMembers) ...[
            _buildInviteSection(scheme, myRole: myRole),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
          ],
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
              child: Text(
                'No collaborators yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
            )
          else
            Column(
              children: members
                  .map((m) => _buildMemberRow(
                        m,
                        scheme,
                        canManageMembers: canManageMembers,
                        myRole: myRole,
                      ))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildInviteSection(ColorScheme scheme, {required String? myRole}) {
    final canPickRole = _canManageMembers(myRole);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite someone',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: KubusSpacing.sm),
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
                              padding: const EdgeInsets.all(
                                KubusSpacing.sm + KubusSpacing.xs,
                              ),
                              child: SizedBox(
                                width: KubusSizes.trailingChevron - KubusSpacing.xxs,
                                height: KubusSizes.trailingChevron - KubusSpacing.xxs,
                                child: CircularProgressIndicator(
                                  strokeWidth: KubusSizes.hairline + KubusSizes.hairline,
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
                        borderRadius: BorderRadius.circular(
                          KubusRadius.md + KubusSpacing.xxs,
                        ),
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
                      margin: const EdgeInsets.only(top: KubusSpacing.sm),
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
                              style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurface,
                                  ),
                            ),
                            subtitle: Text(
                              '@${s.username}',
                              style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurface.withValues(alpha: 0.65),
                                  ),
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
                        if (!_canAssignRole(myRole, v)) return;
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
                    label: Text(AppLocalizations.of(context)!.commonSend),
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  Widget _buildMemberRow(
    CollabMember member,
    ColorScheme scheme, {
    required bool canManageMembers,
    required String? myRole,
  }) {
    final user = member.user;
    final wallet = WalletUtils.canonical(user?.walletAddress ?? member.userId);
    final resolved = wallet.isNotEmpty ? _resolvedUsersByWallet[wallet] : null;

    final formatted = CreatorDisplayFormat.format(
      fallbackLabel: 'Collaborator',
      displayName: resolved?.name ?? user?.displayName,
      username: resolved?.username ?? user?.username,
      wallet: wallet,
    );

    final title = formatted.primary;
    final subtitle = formatted.secondary;

    final seed = wallet.isNotEmpty
        ? wallet
        : (subtitle ?? title).replaceFirst('@', '').trim();

    final avatarUrl = (resolved?.profileImageUrl ?? '').trim().isNotEmpty
        ? resolved!.profileImageUrl
        : user?.avatarUrl;

    final canOpenProfile = wallet.isNotEmpty;
    final navUserId = wallet.isNotEmpty ? wallet : member.userId;
    final navUsername = subtitle == null
        ? (title.startsWith('@') ? title.substring(1) : null)
        : subtitle.substring(1);

    return LiquidGlassPanel(
      margin: const EdgeInsets.only(bottom: KubusSpacing.sm),
      padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      blurSigma: KubusGlassEffects.blurSigmaLight,
      showBorder: true,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.16),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(KubusRadius.md),
                onTap: canOpenProfile
                    ? () => unawaited(
                          UserProfileNavigation.open(
                            context,
                            userId: navUserId,
                            username: navUsername,
                          ),
                        )
                    : null,
                child: Row(
                  children: [
                    AvatarWidget(
                      avatarUrl: avatarUrl,
                      wallet: seed,
                      radius: KubusSizes.sidebarActionIcon - KubusSpacing.xxs,
                      allowFabricatedFallback: true,
                      enableProfileNavigation: false,
                    ),
                    const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: scheme.onSurface,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurface.withValues(alpha: 0.65),
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          if (canManageMembers)
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            )
          else
            Text(
              _roleLabel(member.role),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
            ),
          if (canManageMembers)
            IconButton(
              tooltip: AppLocalizations.of(context)!.commonRemove,
              onPressed: () => unawaited(_removeMember(member)),
              icon: Icon(
                Icons.person_remove,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
    );
  }

  String _roleLabel(String raw) {
    final r = raw.trim().toLowerCase();
    switch (r) {
      case 'owner':
      case 'author':
      case 'creator':
        return 'Owner';
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
