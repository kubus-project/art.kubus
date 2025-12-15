import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/collab_invite.dart';
import '../../providers/collab_provider.dart';
import '../events/event_detail_screen.dart';
import '../events/exhibition_detail_screen.dart';
import '../../widgets/avatar_widget.dart';

class InvitesInboxScreen extends StatefulWidget {
  const InvitesInboxScreen({super.key});

  @override
  State<InvitesInboxScreen> createState() => _InvitesInboxScreenState();
}

class _InvitesInboxScreenState extends State<InvitesInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final provider = context.read<CollabProvider>();
    try {
      await provider.refreshInvites();
    } catch (_) {
      // Provider keeps error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<CollabProvider>();

    final invites = provider.invitesInbox.where((i) => i.isPending).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Invites', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collaboration invites',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Accept an invite to help manage an event or exhibition.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                if ((provider.error ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Could not load invites.',
                      style: GoogleFonts.inter(color: scheme.error, fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: provider.isLoading && invites.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(color: scheme.primary),
                        )
                      : invites.isEmpty
                          ? _EmptyState(onRefresh: _refresh)
                          : ListView.separated(
                              itemCount: invites.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final invite = invites[index];
                                return _InviteCard(
                                  invite: invite,
                                  onAccept: () => _accept(invite),
                                  onDecline: () => _decline(invite),
                                  onOpen: () => _openEntity(invite),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept(CollabInvite invite) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CollabProvider>();

    try {
      await provider.acceptInvite(invite.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Invite accepted.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not accept invite.')));
    }
  }

  Future<void> _decline(CollabInvite invite) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CollabProvider>();

    try {
      await provider.declineInvite(invite.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Invite declined.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not decline invite.')));
    }
  }

  void _openEntity(CollabInvite invite) {
    final type = invite.entityType.trim().toLowerCase();
    final id = invite.entityId;

    if (id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This invite is missing an item id.')),
      );
      return;
    }

    if (type == 'events' || type == 'event') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: id)),
      );
      return;
    }

    if (type == 'exhibitions' || type == 'exhibition') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ExhibitionDetailScreen(exhibitionId: id)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Don\'t know how to open “${invite.entityType}”.')),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
  });

  final CollabInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final invitedBy = invite.invitedBy;

    final inviterName = (invitedBy?.displayName ?? '').trim().isNotEmpty
        ? invitedBy!.displayName!
        : ((invitedBy?.username ?? '').trim().isNotEmpty ? '@${invitedBy!.username}' : 'Someone');

    final inviterHandle = (invitedBy?.username ?? '').trim().isNotEmpty ? '@${invitedBy!.username}' : null;

    final seed = (invitedBy?.walletAddress ?? invitedBy?.username ?? invitedBy?.id ?? inviterName).toString();

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarWidget(
              avatarUrl: invitedBy?.avatarUrl,
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
                    inviterName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (inviterHandle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        inviterHandle,
                        style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Invited you to: ${_labelForEntity(invite.entityType)}',
                    style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Role: ${_labelForRole(invite.role)}',
                    style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  child: const Text('Accept'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _labelForEntity(String raw) {
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'events':
      case 'event':
        return 'Event';
      case 'exhibitions':
      case 'exhibition':
        return 'Exhibition';
      default:
        return v.isEmpty ? 'Item' : v;
    }
  }

  static String _labelForRole(String raw) {
    final v = raw.trim().toLowerCase();
    switch (v) {
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: scheme.onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 10),
            Text(
              'No invites right now',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'When someone invites you, it will show up here.',
              style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.65)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => onRefresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
