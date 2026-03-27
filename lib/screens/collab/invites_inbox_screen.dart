import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../models/collab_invite.dart';
import '../../providers/collab_provider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/artwork_navigation.dart';
import '../art/collection_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/exhibition_detail_screen.dart';
import '../../widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class InvitesInboxScreen extends StatefulWidget {
  final bool embedded;

  const InvitesInboxScreen({super.key, this.embedded = false});

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
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CollabProvider>();

    final invites =
        provider.invitesInbox.where((i) => i.isPending).toList(growable: false);
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.embedded) ...[
                Text(
                  l10n.profileInvitesTooltip,
                  style: KubusTextStyles.screenTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  'Accept an invite to help manage an event, exhibition, artwork, or collection.',
                  style: KubusTextStyles.screenSubtitle.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: l10n.commonRefresh,
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              if ((provider.error ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
                  child: Text(
                    'Could not load invites.',
                    style: KubusTextStyles.statChange.copyWith(
                      color: scheme.error,
                    ),
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
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
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.profileInvitesTooltip,
          style: KubusTextStyles.screenTitle.copyWith(
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: content,
    );
  }

  Future<void> _accept(CollabInvite invite) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CollabProvider>();

    try {
      await provider.acceptInvite(invite.id);
      if (!mounted) return;
      messenger
          .showKubusSnackBar(const SnackBar(content: Text('Invite accepted.')));
    } catch (_) {
      messenger.showKubusSnackBar(
          const SnackBar(content: Text('Could not accept invite.')));
    }
  }

  Future<void> _decline(CollabInvite invite) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CollabProvider>();

    try {
      await provider.declineInvite(invite.id);
      if (!mounted) return;
      messenger
          .showKubusSnackBar(const SnackBar(content: Text('Invite declined.')));
    } catch (_) {
      messenger.showKubusSnackBar(
          const SnackBar(content: Text('Could not decline invite.')));
    }
  }

  void _openEntity(CollabInvite invite) {
    final type = invite.entityType.trim().toLowerCase();
    final id = invite.entityId;

    if (id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
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
        MaterialPageRoute(
            builder: (_) => ExhibitionDetailScreen(exhibitionId: id)),
      );
      return;
    }

    if (type == 'artworks' || type == 'artwork') {
      openArtwork(context, id, source: 'collab_invite');
      return;
    }

    if (type == 'collections' || type == 'collection') {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => CollectionDetailScreen(collectionId: id)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(content: Text('Don\'t know how to open ${invite.entityType}.')),
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
        : ((invitedBy?.username ?? '').trim().isNotEmpty
            ? '@${invitedBy!.username}'
            : 'Someone');

    final inviterHandle = (invitedBy?.username ?? '').trim().isNotEmpty
        ? '@${invitedBy!.username}'
        : null;

    final seed = (invitedBy?.walletAddress ??
            invitedBy?.username ??
            invitedBy?.id ??
            inviterName)
        .toString();

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
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
                    style: KubusTextStyles.sectionTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (inviterHandle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: KubusSpacing.xxs),
                      child: Text(
                        inviterHandle,
                        style: KubusTextStyles.navMetaLabel.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: KubusSpacing.sm),
                  Text(
                    'Invited you to: ${_labelForEntity(invite.entityType)}',
                    style: KubusTextStyles.sectionSubtitle.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
                  Text(
                    'Role: ${_labelForRole(invite.role)}',
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
            Column(
              children: [
                ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.sm + KubusSpacing.xxs,
                      vertical: KubusSpacing.sm + KubusSpacing.xxs,
                    ),
                  ),
                  child: const Text('Accept'),
                ),
                const SizedBox(height: KubusSpacing.sm),
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
      case 'artworks':
      case 'artwork':
        return 'Artwork';
      case 'collections':
      case 'collection':
        return 'Collection';
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
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: KubusHeaderMetrics.searchBarHeight - KubusSpacing.xs,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
            Text(
              'No invites right now',
              style: KubusTextStyles.sectionTitle,
            ),
            const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
            Text(
              'When someone invites you, it will show up here.',
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
                height: KubusSpacing.sm + KubusSpacing.xxs + KubusSpacing.xxs),
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
