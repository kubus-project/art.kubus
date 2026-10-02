import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../models/collab_invite.dart';
import '../../providers/collab_provider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/kubus_color_roles.dart';
import '../art/collection_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/exhibition_detail_screen.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/states/kubus_product_states.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

/// Collaboration inbox: pending invitations to help manage an event,
/// exhibition, artwork or collection.
///
/// Each invitation states what it is (INVITATION · entity type), who sent
/// it, the role offered and when it arrived or expires. Actions follow the
/// product grammar: Accept (primary), Decline (secondary), View (quiet).
/// This is actionable collaboration state, so it is not styled as a generic
/// notification row.
class InvitesInboxScreen extends StatefulWidget {
  final bool embedded;

  const InvitesInboxScreen({super.key, this.embedded = false});

  @override
  State<InvitesInboxScreen> createState() => _InvitesInboxScreenState();
}

class _InvitesInboxScreenState extends State<InvitesInboxScreen> {
  final Set<String> _busy = <String>{};

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

  void _signIn() {
    Navigator.of(context).pushNamed('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CollabProvider>();

    final invites =
        provider.invitesInbox.where((i) => i.isPending).toList(growable: false);
    // Classified from the caught failure (HTTP status or transport error),
    // never from the provider's display string, and never shown raw.
    final loadError = provider.invitesError;
    final hasError = loadError != null;

    Widget body;
    if (provider.isLoading && invites.isEmpty) {
      body = const KubusSectionLoading(rows: 3, rowHeight: 132);
    } else if (hasError && invites.isEmpty) {
      body = KubusStateView.fromError(
        loadError,
        onRetry: _refresh,
        onSignIn: _signIn,
      );
    } else if (invites.isEmpty) {
      body = EmptyStateCard(
        icon: Icons.inbox_outlined,
        title: l10n.collabEmptyTitle,
        description: l10n.collabEmptyDescription,
        showAction: true,
        actionLabel: l10n.commonRefresh,
        onAction: _refresh,
      );
    } else {
      body = ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: invites.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
        itemBuilder: (context, index) {
          final invite = invites[index];
          return InviteRow(
            invite: invite,
            isBusy: _busy.contains(invite.id),
            onAccept: () => _accept(invite),
            onDecline: () => _decline(invite),
            onOpen: () => _openEntity(invite),
          );
        },
      );
    }

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.embedded) ...[
                Text(
                  l10n.collabInboxIntro,
                  style: KubusTextStyles.detailBody.copyWith(
                    color: roles.foregroundMuted,
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
              if (hasError && invites.isNotEmpty) ...[
                KubusStateView.fromError(
                  loadError,
                  compact: true,
                  onRetry: _refresh,
                  onSignIn: _signIn,
                ),
                const SizedBox(height: KubusSpacing.sm),
              ],
              Expanded(child: body),
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
            fontSize: KubusHeaderMetrics.screenTitle,
            fontWeight: FontWeight.w600,
            color: roles.foreground,
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

  Future<void> _runAction(
    CollabInvite invite,
    Future<void> Function() action, {
    required String success,
    required String failure,
  }) async {
    if (_busy.contains(invite.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(invite.id));
    try {
      await action();
      if (!mounted) return;
      messenger.showKubusSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(failure)),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(invite.id));
    }
  }

  Future<void> _accept(CollabInvite invite) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<CollabProvider>();
    return _runAction(
      invite,
      () => provider.acceptInvite(invite.id),
      success: l10n.collabAcceptedToast,
      failure: l10n.collabAcceptFailedToast,
    );
  }

  Future<void> _decline(CollabInvite invite) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<CollabProvider>();
    return _runAction(
      invite,
      () => provider.declineInvite(invite.id),
      success: l10n.collabDeclinedToast,
      failure: l10n.collabDeclineFailedToast,
    );
  }

  void _openEntity(CollabInvite invite) {
    final type = invite.entityType.trim().toLowerCase();
    final id = invite.entityId;

    void cannotOpen() {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.collabCannotOpenItemToast),
        ),
      );
    }

    if (id.trim().isEmpty) {
      cannotOpen();
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

    cannotOpen();
  }
}

/// One pending invitation.
class InviteRow extends StatelessWidget {
  const InviteRow({
    super.key,
    required this.invite,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
    this.isBusy = false,
  });

  final CollabInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;
  final bool isBusy;

  static String entityLabel(AppLocalizations l10n, String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'events':
      case 'event':
        return l10n.collabEntityEvent;
      case 'exhibitions':
      case 'exhibition':
        return l10n.collabEntityExhibition;
      case 'artworks':
      case 'artwork':
        return l10n.collabEntityArtwork;
      case 'collections':
      case 'collection':
        return l10n.collabEntityCollection;
      default:
        return l10n.collabEntityItem;
    }
  }

  static String roleLabel(AppLocalizations l10n, String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'admin':
        return l10n.collabRoleAdmin;
      case 'publisher':
        return l10n.collabRolePublisher;
      case 'editor':
        return l10n.collabRoleEditor;
      case 'curator':
        return l10n.collabRoleCurator;
      case 'viewer':
      default:
        return l10n.collabRoleViewer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final material = MaterialLocalizations.of(context);
    final invitedBy = invite.invitedBy;

    final displayName = (invitedBy?.displayName ?? '').trim();
    final username = (invitedBy?.username ?? '').trim();
    final senderName = displayName.isNotEmpty
        ? displayName
        : (username.isNotEmpty ? '@$username' : l10n.collabUnknownSender);
    final seed = (invitedBy?.walletAddress ??
            invitedBy?.username ??
            invitedBy?.id ??
            senderName)
        .toString();
    final entity = entityLabel(l10n, invite.entityType);
    final role = roleLabel(l10n, invite.role);

    final dates = <String>[
      if (invite.createdAt != null)
        l10n.collabInviteReceived(
            material.formatMediumDate(invite.createdAt!.toLocal())),
      if (invite.expiresAt != null)
        l10n.collabInviteExpires(
            material.formatMediumDate(invite.expiresAt!.toLocal())),
    ];

    return Semantics(
      container: true,
      label: l10n.collabInviteSemantic(entity, role, senderName),
      child: Container(
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          color: roles.surface,
          borderRadius: BorderRadius.circular(KubusRadius.surface),
          border: Border.all(color: roles.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                '${l10n.collabInviteNotion} · $entity'.toUpperCase(),
                style: KubusTextStyles.structuralLabel.copyWith(
                  color: roles.foregroundMuted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            ExcludeSemantics(
              child: Row(
                children: [
                  AvatarWidget(
                    avatarUrl: invitedBy?.avatarUrl,
                    wallet: seed,
                    radius: 18,
                    allowFabricatedFallback: true,
                    enableProfileNavigation: false,
                  ),
                  const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.collabInviteFrom(senderName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KubusTextStyles.detailBody.copyWith(
                            color: roles.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: KubusSpacing.xxs),
                        Text(
                          l10n.collabInviteRole(role),
                          style: KubusTextStyles.detailCaption.copyWith(
                            color: roles.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (dates.isNotEmpty) ...[
              const SizedBox(height: KubusSpacing.sm),
              Text(
                dates.join('  ·  '),
                style: KubusTextStyles.detailCaption.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
            ],
            const SizedBox(height: KubusSpacing.md),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: [
                KubusButton(
                  onPressed: isBusy ? null : onAccept,
                  isLoading: isBusy,
                  label: l10n.collabAccept,
                ),
                KubusButton(
                  onPressed: isBusy ? null : onDecline,
                  label: l10n.collabDecline,
                  variant: KubusButtonVariant.secondary,
                ),
                KubusButton(
                  onPressed: onOpen,
                  label: l10n.commonView,
                  variant: KubusButtonVariant.quiet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
