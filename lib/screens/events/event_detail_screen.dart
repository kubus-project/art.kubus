// ignore_for_file: kubus_no_raw_progress_indicator
// Grandfathered kubus design-token violations. Remove this header
// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/inline_loading.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/exhibition.dart';
import '../../models/event.dart';
import '../../models/promotion.dart';
import '../../providers/events_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/profile_provider.dart';
import '../../screens/collab/invites_inbox_screen.dart';
import '../../services/backend_api_service.dart'
    show BackendApiRequestException;
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/creator_shell_navigation.dart';
import '../../utils/map_navigation.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/collaboration_panel.dart';
import '../../widgets/promotion/promotion_builder_sheet.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/detail/poap_detail_card.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/kubus_snackbar.dart';
import '../../utils/design_tokens.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final KubusEvent? initialEvent;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.initialEvent,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final events = context.read<EventsProvider>();
      unawaited(events.recordEventView(widget.eventId, source: 'event_detail'));
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    final events = context.read<EventsProvider>();
    final exhibitions = context.read<ExhibitionsProvider>();
    try {
      await events.fetchEvent(widget.eventId, force: true);
    } catch (_) {
      // Provider handles errors.
    }
    // The event's own POAP and linked exhibitions are independent sections;
    // their failures stay local and never block the page.
    try {
      await events.fetchEventPoap(widget.eventId, force: true);
    } catch (e) {
      debugPrint('EventDetailScreen: event POAP load failed: $e');
    }
    try {
      await events.loadEventExhibitions(widget.eventId, refresh: true);
      final loadedExhibitions = events.exhibitionsForEvent(widget.eventId);
      await Future.wait(
        loadedExhibitions.map(
          (exhibition) => exhibitions
              .fetchExhibitionPoap(exhibition.id, force: true)
              .catchError((_) => null),
        ),
      );
    } catch (e) {
      debugPrint('EventDetailScreen: linked exhibitions load failed: $e');
    }
  }

  bool _canManageEvent(KubusEvent event) {
    final role = (event.myRole ?? '').trim().toLowerCase();
    return role == 'owner' ||
        role == 'admin' ||
        role == 'publisher' ||
        role == 'editor' ||
        role == 'curator';
  }

  bool _canPromoteEvent(KubusEvent event) {
    final role = (event.myRole ?? '').trim().toLowerCase();
    final canPublish =
        role == 'owner' || role == 'admin' || role == 'publisher';
    return canPublish && event.isPublished && event.id.trim().isNotEmpty;
  }

  Future<void> _openPromotionFlow(KubusEvent event) async {
    if (!_canPromoteEvent(event)) return;
    await showPromotionBuilderSheet(
      context: context,
      entityType: PromotionEntityType.event,
      entityId: event.id,
      entityLabel: event.title,
    );
  }

  Future<void> _claimEventPoap() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final events = context.read<EventsProvider>();
    final current = events.poapStatusFor(widget.eventId);
    if (current == null || current.claimed || events.isPoapClaiming) return;

    try {
      final status = await events.claimEventPoap(widget.eventId);
      if (!mounted) return;
      if (status == null) {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.eventDetailPoapClaimFailedToast)),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.eventDetailPoapClaimSuccessToast)),
        tone: KubusSnackBarTone.success,
      );
    } on BackendApiRequestException catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(e.userMessage)),
        tone: KubusSnackBarTone.error,
      );
    } catch (e) {
      debugPrint('EventDetailScreen: claim event POAP failed: $e');
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.eventDetailPoapClaimFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  void _openExhibition(Exhibition exhibition) {
    unawaited(
      CreatorShellNavigation.openExhibitionDetailWorkspace(
        context,
        exhibitionId: exhibition.id,
        initialExhibition: exhibition,
        titleOverride: exhibition.title,
      ),
    );
  }

  Future<void> _showLinkExhibitionsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final events = context.read<EventsProvider>();
    final exhibitionsProvider = context.read<ExhibitionsProvider>();

    try {
      await exhibitionsProvider.loadExhibitions(mine: true, refresh: true);
    } catch (_) {
      // Provider reports its own errors; fall through to what we have.
    }
    if (!mounted) return;

    final alreadyLinked =
        events.exhibitionsForEvent(widget.eventId).map((e) => e.id).toSet();
    final candidates = exhibitionsProvider.myExhibitions
        .where((e) => !alreadyLinked.contains(e.id))
        .toList();

    if (candidates.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.eventCreatorNoExhibitionsToLink)),
      );
      return;
    }

    final selectedIds = <String>{};
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return KubusAlertDialog(
              title: Text(l10n.selectExhibitionsDialogTitle,
                  style: KubusTypography.inter(fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final exhibition = candidates[index];
                    final checked = selectedIds.contains(exhibition.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setLocalState(() {
                          if (v == true) {
                            selectedIds.add(exhibition.id);
                          } else {
                            selectedIds.remove(exhibition.id);
                          }
                        });
                      },
                      title: Text(
                        exhibition.title,
                        style:
                            KubusTypography.inter(fontWeight: FontWeight.w600),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child:
                      Text(l10n.commonCancel, style: KubusTypography.inter()),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.commonLink,
                      style:
                          KubusTypography.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedIds.isEmpty) return;

    try {
      await events.linkEventExhibitions(widget.eventId, selectedIds.toList());
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonSavedToast)),
        tone: KubusSnackBarTone.success,
      );
    } on BackendApiRequestException catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(e.userMessage)),
        tone: KubusSnackBarTone.error,
      );
    } catch (e) {
      debugPrint('EventDetailScreen: link exhibitions failed: $e');
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Future<void> _unlinkExhibition(Exhibition exhibition) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final events = context.read<EventsProvider>();
    try {
      await events.unlinkEventExhibition(widget.eventId, exhibition.id);
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonSavedToast)),
        tone: KubusSnackBarTone.success,
      );
    } catch (e) {
      debugPrint('EventDetailScreen: unlink exhibition failed: $e');
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Future<void> _createExhibitionForEvent() async {
    await CreatorShellNavigation.openExhibitionCreatorWorkspace(
      context,
      eventId: widget.eventId,
    );
    if (!mounted) return;
    unawaited(
      context
          .read<EventsProvider>()
          .loadEventExhibitions(widget.eventId, refresh: true)
          .catchError((_) => const <Exhibition>[]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final events = context.watch<EventsProvider>();
    final isSignedIn = context.watch<ProfileProvider>().isSignedIn;

    final event = events.events.firstWhere(
      (e) => e.id == widget.eventId,
      orElse: () =>
          widget.initialEvent ??
          KubusEvent(id: widget.eventId, title: l10n.mapMarkerSubjectTypeEvent),
    );

    final exhibitions = events.exhibitionsForEvent(widget.eventId);
    final exhibitionsProvider = context.watch<ExhibitionsProvider>();
    final canPromote = _canPromoteEvent(event);
    final canManage = _canManageEvent(event);
    final eventPoap = events.poapStatusFor(widget.eventId);

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(event.title,
              style: KubusTypography.inter(fontWeight: FontWeight.w600)),
          actions: const [],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.all(DetailSpacing.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final details = _EventDetailsCard(
                    event: event,
                    exhibitionsCount: exhibitions.length,
                  );
                  final secondaryActions = DetailSecondaryActionCluster(
                    maxVisible: 5,
                    actions: [
                      if (event.lat != null && event.lng != null)
                        DetailSecondaryAction(
                          icon: Icons.map_outlined,
                          label: l10n.commonOpenOnMap,
                          onTap: () {
                            MapNavigation.open(
                              context,
                              center: LatLng(event.lat!, event.lng!),
                              zoom: 16,
                              autoFollow: false,
                            );
                          },
                          tooltip: l10n.commonOpenOnMap,
                        ),
                      if (canPromote)
                        DetailSecondaryAction(
                          icon: Icons.campaign_outlined,
                          label: l10n.eventDetailPromoteLabel,
                          onTap: () => _openPromotionFlow(event),
                          tooltip: l10n.eventDetailPromoteTooltip,
                        ),
                      DetailSecondaryAction(
                        icon: Icons.share_outlined,
                        label: l10n.commonShare,
                        onTap: () {
                          ShareService().showShareSheet(
                            context,
                            target: ShareTarget.event(
                              eventId: widget.eventId,
                              title: event.title,
                            ),
                            sourceScreen: 'event_detail',
                          );
                        },
                        tooltip: l10n.commonShare,
                      ),
                      DetailSecondaryAction(
                        icon: Icons.inbox_outlined,
                        label: l10n.eventDetailInvitesLabel,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const InvitesInboxScreen(),
                            ),
                          );
                        },
                        tooltip: l10n.eventDetailInvitesTooltip,
                      ),
                      DetailSecondaryAction(
                        icon: Icons.refresh,
                        label: l10n.commonRefresh,
                        onTap: _load,
                        tooltip: l10n.commonRefresh,
                      ),
                    ],
                  );

                  final eventPoapCard = _EventPoapCard(
                    poap: eventPoap,
                    isLoading: events.isPoapLoading,
                    isClaiming: events.isPoapClaiming,
                    isSignedIn: isSignedIn,
                    onClaim: _claimEventPoap,
                  );

                  final exhibitionPoapSection = _LinkedExhibitionPoapSection(
                    exhibitions: exhibitions,
                    exhibitionsProvider: exhibitionsProvider,
                  );

                  final linkedExhibitionsSection = _LinkedExhibitionsSection(
                    exhibitions: exhibitions,
                    canManage: canManage,
                    isSyncing: events.isRelationSyncing,
                    onOpen: _openExhibition,
                    onLink: _showLinkExhibitionsDialog,
                    onCreate: _createExhibitionForEvent,
                    onUnlink: _unlinkExhibition,
                  );

                  final collab = CollaborationPanel(
                    entityType: 'events',
                    entityId: widget.eventId,
                    myRole: event.myRole,
                  );

                  final mainChildren = <Widget>[
                    secondaryActions,
                    const SizedBox(height: DetailSpacing.cardGap),
                    details,
                    const SizedBox(height: DetailSpacing.cardGap),
                    eventPoapCard,
                    const SizedBox(height: DetailSpacing.cardGap),
                    linkedExhibitionsSection,
                    const SizedBox(height: DetailSpacing.cardGap),
                    exhibitionPoapSection,
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: ListView(
                            children: [
                              ...mainChildren,
                              if (events.isDetailLoading)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: LinearProgressIndicator(
                                    color: scheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DetailSpacing.xl),
                        Expanded(
                          flex: 3,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: collab,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    children: [
                      ...mainChildren,
                      const SizedBox(height: DetailSpacing.cardGap),
                      collab,
                      if (events.isDetailLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(color: scheme.primary),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDetailsCard extends StatelessWidget {
  const _EventDetailsCard(
      {required this.event, required this.exhibitionsCount});

  final KubusEvent event;
  final int exhibitionsCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = MediaUrlResolver.resolve(event.coverUrl);

    String? dateRange;
    if (event.startsAt != null || event.endsAt != null) {
      final start = event.startsAt != null ? _fmtDate(event.startsAt!) : null;
      final end = event.endsAt != null ? _fmtDate(event.endsAt!) : null;
      dateRange = [start, end].whereType<String>().join(' • ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final locationBits = <String>[];
    if ((event.locationName ?? '').trim().isNotEmpty) {
      locationBits.add(event.locationName!.trim());
    }
    if ((event.city ?? '').trim().isNotEmpty) {
      locationBits.add(event.city!.trim());
    }
    if ((event.country ?? '').trim().isNotEmpty) {
      locationBits.add(event.country!.trim());
    }
    final location = locationBits.isNotEmpty ? locationBits.join(', ') : null;
    final hostLabel = event.host == null
        ? null
        : l10n.exhibitionDetailHostedBy(
            event.host!.displayName ??
                event.host!.username ??
                l10n.commonUnknown,
          );

    // Editorial overview: identity, cover, schedule/location metadata and the
    // linked-exhibitions count grouped in one calm zone.
    final overviewCard = DetailCard(
      borderRadius: DetailRadius.md,
      padding: DetailSpacing.editorialCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailIdentityBlock(
            title: event.title,
            kicker: l10n.mapMarkerSubjectTypeEvent,
            subtitle: hostLabel,
          ),
          const SizedBox(height: DetailSpacing.heroGap),
          if (coverUrl != null && coverUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(DetailRadius.sm),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 46,
                      color: scheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: DetailSpacing.heroGap),
          ],
          DetailMetadataBlock(
            items: [
              if (dateRange != null)
                DetailMetaItem(icon: Icons.schedule, label: dateRange),
              if (location != null)
                DetailMetaItem(icon: Icons.place_outlined, label: location),
              if ((event.status ?? '').trim().isNotEmpty)
                DetailMetaItem(
                  icon: Icons.event_available_outlined,
                  label: _labelForStatus(l10n, event.status),
                ),
            ],
          ),
          const SizedBox(height: DetailSpacing.lg),
          DetailContextCluster(
            compact: true,
            items: [
              DetailContextItem(
                icon: AppColorUtils.exhibitionIcon,
                value: '$exhibitionsCount',
                label: l10n.eventDetailLinkedExhibitionsLabel,
              ),
            ],
          ),
        ],
      ),
    );

    final hasDescription = (event.description ?? '').trim().isNotEmpty;
    if (!hasDescription) return overviewCard;

    // Editorial description gets its own roomy card so it reads long-form and
    // can expand cleanly without crowding the overview metadata.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        overviewCard,
        const SizedBox(height: DetailSpacing.cardGap),
        DetailCard(
          borderRadius: DetailRadius.md,
          padding: DetailSpacing.editorialCardPadding,
          child: ExpandableDetailText(
            text: event.description!.trim(),
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String _labelForStatus(AppLocalizations l10n, String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return l10n.commonUnknown;
    if (value == 'published') return l10n.commonPublished;
    if (value == 'draft') return l10n.commonDraft;
    return value;
  }
}

/// The event's own POAP badge — visible whenever it is configured, even when
/// no exhibition POAPs exist.
class _EventPoapCard extends StatelessWidget {
  const _EventPoapCard({
    required this.poap,
    required this.isLoading,
    required this.isClaiming,
    required this.isSignedIn,
    required this.onClaim,
  });

  final EventPoapStatus? poap;
  final bool isLoading;
  final bool isClaiming;
  final bool isSignedIn;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (poap == null) {
      if (!isLoading) return const SizedBox.shrink();
      return const DetailCard(
        borderRadius: DetailRadius.md,
        padding: DetailSpacing.editorialCardPadding,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: InlineLoading(tileSize: 4),
          ),
        ),
      );
    }

    final status = poap!;

    String eligibilityLabel() {
      if (status.claimed) return l10n.exhibitionDetailPoapEligibilityClaimed;
      if (status.canClaim) return l10n.exhibitionDetailPoapEligibilityVerified;
      switch ((status.eligibilityReason ?? '').trim().toLowerCase()) {
        case 'sign_in_required':
          return l10n.exhibitionDetailPoapEligibilitySignedOut;
        case 'event_not_published':
          return l10n.eventDetailPoapEligibilityNotPublished;
        case 'scan_proof_required':
          return l10n.eventDetailPoapScanProofRequired;
        case 'marker_link_required':
          return l10n.exhibitionDetailPoapEligibilityMarkerLinkRequired;
        case 'marker_attendance_required':
          return l10n.exhibitionDetailPoapEligibilityAttendanceRequired;
        default:
          return l10n.exhibitionDetailPoapEligibilityVisitRequired;
      }
    }

    String? eligibilityHint() {
      if (status.claimed) return null;
      if (status.canClaim) {
        return l10n.exhibitionDetailPoapEligibilityClaimReadyHint;
      }
      switch ((status.eligibilityReason ?? '').trim().toLowerCase()) {
        case 'sign_in_required':
          return l10n.exhibitionDetailPoapSignedOutHint;
        case 'event_not_published':
          return l10n.eventDetailPoapEligibilityNotPublishedHint;
        case 'scan_proof_required':
          return l10n.eventDetailPoapScanProofRequiredHint;
        case 'marker_link_required':
          return l10n.exhibitionDetailPoapEligibilityMarkerLinkHint;
        case 'marker_attendance_required':
          return l10n.eventDetailPoapCheckInFirstHint;
        default:
          return l10n.eventDetailPoapCheckInFirstHint;
      }
    }

    final contextItems = <DetailContextItem>[];
    if (status.linkedMarkerCount > 0) {
      contextItems.add(
        DetailContextItem(
          icon: Icons.route_outlined,
          value: status.linkedMarkerCount.toString(),
          label: l10n.exhibitionDetailPoapLinkedMarkersLabel,
        ),
      );
    }
    if (status.latestAttendanceAt != null) {
      contextItems.add(
        DetailContextItem(
          icon: Icons.schedule_outlined,
          value: MaterialLocalizations.of(context)
              .formatMediumDate(status.latestAttendanceAt!.toLocal()),
          label: l10n.exhibitionDetailPoapLatestCheckInLabel,
        ),
      );
    }

    return DetailCard(
      borderRadius: DetailRadius.md,
      padding: DetailSpacing.editorialCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailSectionLabel(label: l10n.eventDetailPoapTitle),
          const SizedBox(height: DetailSpacing.md),
          PoapDetailCard(
            title: status.poap.title.trim().isNotEmpty
                ? status.poap.title
                : l10n.eventDetailPoapTitle,
            description: status.poap.description?.trim().isNotEmpty == true
                ? status.poap.description!.trim()
                : l10n.eventDetailPoapDescription,
            code: status.poap.code,
            iconUrl: status.poap.iconUrl,
            rarityLabel: status.poap.rarity,
            rewardLabel: status.poap.rewardKub8 > 0
                ? '+${status.poap.rewardKub8} KUB8'
                : null,
            stateLabel: status.claimed
                ? l10n.exhibitionDetailPoapClaimedStatus
                : l10n.exhibitionDetailPoapNotClaimedStatus,
            eligibilityLabel: eligibilityLabel(),
            eligibilityHint: eligibilityHint(),
            signedOutHint:
                isSignedIn ? null : l10n.exhibitionDetailPoapSignedOutHint,
            contextItems: contextItems,
            isClaimed: status.claimed,
            canClaim: !status.claimed && status.canClaim && isSignedIn,
            isClaiming: isClaiming,
            onClaim: onClaim,
            claimActionLabel: l10n.exhibitionDetailPoapClaimAction,
            claimingActionLabel: l10n.exhibitionDetailPoapClaimingAction,
          ),
        ],
      ),
    );
  }
}

class _LinkedExhibitionsSection extends StatelessWidget {
  const _LinkedExhibitionsSection({
    required this.exhibitions,
    required this.canManage,
    required this.isSyncing,
    required this.onOpen,
    required this.onLink,
    required this.onCreate,
    required this.onUnlink,
  });

  final List<Exhibition> exhibitions;
  final bool canManage;
  final bool isSyncing;
  final ValueChanged<Exhibition> onOpen;
  final VoidCallback onLink;
  final VoidCallback onCreate;
  final ValueChanged<Exhibition> onUnlink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DetailCard(
      borderRadius: DetailRadius.md,
      padding: DetailSpacing.editorialCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DetailSectionLabel(
                    label: l10n.eventDetailLinkedExhibitionsTitle),
              ),
              if (isSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: InlineLoading(tileSize: 4),
                ),
            ],
          ),
          const SizedBox(height: DetailSpacing.lg),
          if (exhibitions.isEmpty)
            Text(
              l10n.eventDetailLinkedExhibitionsEmpty,
              style: DetailTypography.caption(context),
            )
          else
            ...exhibitions.expand((exhibition) sync* {
              yield _LinkedExhibitionCard(
                exhibition: exhibition,
                canManage: canManage,
                onOpen: () => onOpen(exhibition),
                onUnlink: () => onUnlink(exhibition),
              );
              if (exhibition != exhibitions.last) {
                yield const SizedBox(height: DetailSpacing.lg);
              }
            }),
          if (canManage) ...[
            const SizedBox(height: DetailSpacing.lg),
            Wrap(
              spacing: DetailSpacing.sm,
              runSpacing: DetailSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: onLink,
                  icon: const Icon(Icons.link_outlined, size: 18),
                  label: Text(l10n.eventDetailLinkExhibition),
                ),
                OutlinedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_outlined, size: 18),
                  label: Text(l10n.eventDetailCreateExhibition),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkedExhibitionCard extends StatelessWidget {
  const _LinkedExhibitionCard({
    required this.exhibition,
    required this.canManage,
    required this.onOpen,
    required this.onUnlink,
  });

  final Exhibition exhibition;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = MediaUrlResolver.resolve(exhibition.coverUrl);

    String? dateRange;
    if (exhibition.startsAt != null || exhibition.endsAt != null) {
      final localizations = MaterialLocalizations.of(context);
      final start = exhibition.startsAt != null
          ? localizations.formatMediumDate(exhibition.startsAt!.toLocal())
          : null;
      final end = exhibition.endsAt != null
          ? localizations.formatMediumDate(exhibition.endsAt!.toLocal())
          : null;
      dateRange = [start, end].whereType<String>().join(' → ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final statusLabel =
        (exhibition.status ?? '').trim().toLowerCase() == 'published'
            ? l10n.commonPublished
            : ((exhibition.status ?? '').trim().toLowerCase() == 'draft'
                ? l10n.commonDraft
                : null);

    return DetailCard(
      borderRadius: DetailRadius.sm,
      padding: const EdgeInsets.symmetric(
        horizontal: DetailSpacing.lg,
        vertical: DetailSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(DetailRadius.sm),
                child: Container(
                  width: 64,
                  height: 64,
                  color: scheme.surfaceContainerHighest,
                  child: coverUrl != null && coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            AppColorUtils.exhibitionIcon,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        )
                      : Icon(
                          AppColorUtils.exhibitionIcon,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                ),
              ),
              const SizedBox(width: DetailSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exhibition.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DetailTypography.cardTitle(context),
                    ),
                    const SizedBox(height: DetailSpacing.md),
                    Wrap(
                      spacing: DetailSpacing.md,
                      runSpacing: DetailSpacing.sm,
                      children: [
                        if (dateRange != null)
                          Text(dateRange,
                              style: DetailTypography.caption(context)),
                        if (statusLabel != null)
                          Text(statusLabel,
                              style: DetailTypography.caption(context)),
                      ],
                    ),
                  ],
                ),
              ),
              if (canManage)
                IconButton(
                  tooltip: l10n.eventDetailUnlinkExhibition,
                  onPressed: onUnlink,
                  icon: const Icon(Icons.link_off_outlined, size: 18),
                ),
            ],
          ),
          const SizedBox(height: DetailSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(AppColorUtils.exhibitionIcon, size: 18),
              label: Text(l10n.eventDetailOpenExhibitionCta),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aggregated POAPs of linked exhibitions (claims happen on the exhibition
/// pages); kept distinct from the event's own first-class POAP above.
class _LinkedExhibitionPoapSection extends StatelessWidget {
  const _LinkedExhibitionPoapSection({
    required this.exhibitions,
    required this.exhibitionsProvider,
  });

  final List<Exhibition> exhibitions;
  final ExhibitionsProvider exhibitionsProvider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    List<DetailContextItem> contextItemsFor(ExhibitionPoapStatus poap) {
      final items = <DetailContextItem>[];
      if (poap.proofType?.trim().isNotEmpty == true) {
        items.add(
          DetailContextItem(
            icon: Icons.verified_outlined,
            value: l10n.exhibitionDetailPoapProofTypeMarkerAttendance,
          ),
        );
      }
      if (poap.linkedMarkerCount > 0) {
        items.add(
          DetailContextItem(
            icon: Icons.route_outlined,
            value: poap.linkedMarkerCount.toString(),
            label: l10n.exhibitionDetailPoapLinkedMarkersLabel,
          ),
        );
      }
      if (poap.latestAttendanceAt != null) {
        items.add(
          DetailContextItem(
            icon: Icons.schedule_outlined,
            value: MaterialLocalizations.of(context)
                .formatMediumDate(poap.latestAttendanceAt!.toLocal()),
            label: l10n.exhibitionDetailPoapLatestCheckInLabel,
          ),
        );
      }
      return items;
    }

    String poapEligibilityLabel(ExhibitionPoapStatus poap) {
      if (poap.claimed) return l10n.exhibitionDetailPoapEligibilityClaimed;
      if (poap.canClaim) return l10n.exhibitionDetailPoapEligibilityVerified;
      switch ((poap.eligibilityReason ?? '').trim().toLowerCase()) {
        case 'sign_in_required':
          return l10n.exhibitionDetailPoapEligibilitySignedOut;
        case 'exhibition_not_published':
          return l10n.exhibitionDetailPoapEligibilityNotPublished;
        case 'marker_link_required':
          return l10n.exhibitionDetailPoapEligibilityMarkerLinkRequired;
        case 'marker_attendance_required':
          return l10n.exhibitionDetailPoapEligibilityAttendanceRequired;
        default:
          return l10n.exhibitionDetailPoapEligibilityVisitRequired;
      }
    }

    String? poapEligibilityHint(ExhibitionPoapStatus poap) {
      if (poap.claimed) return null;
      if (poap.canClaim) {
        return l10n.eventDetailPoapAggregationHint;
      }
      switch ((poap.eligibilityReason ?? '').trim().toLowerCase()) {
        case 'sign_in_required':
          return l10n.exhibitionDetailPoapSignedOutHint;
        case 'exhibition_not_published':
          return l10n.exhibitionDetailPoapEligibilityNotPublishedHint;
        case 'marker_link_required':
          return l10n.exhibitionDetailPoapEligibilityMarkerLinkHint;
        case 'marker_attendance_required':
          return l10n.exhibitionDetailPoapEligibilityAttendanceHint;
        default:
          return l10n.eventDetailPoapAggregationHint;
      }
    }

    final cards = <Widget>[];
    for (final exhibition in exhibitions) {
      final poap = exhibitionsProvider.poapStatusFor(exhibition.id);
      if (poap?.poap == null) continue;

      final descriptionParts = <String>[
        if ((poap!.poap.title).trim().isNotEmpty) poap.poap.title.trim(),
        if ((poap.poap.description ?? '').trim().isNotEmpty)
          poap.poap.description!.trim(),
      ];

      cards.add(
        PoapDetailCard(
          title: exhibition.title,
          description: descriptionParts.join(' • '),
          code: poap.poap.code,
          iconUrl: poap.poap.iconUrl,
          rarityLabel: poap.poap.rarity,
          rewardLabel:
              poap.poap.rewardKub8 > 0 ? '+${poap.poap.rewardKub8} KUB8' : null,
          stateLabel: poap.claimed
              ? l10n.exhibitionDetailPoapClaimedStatus
              : l10n.exhibitionDetailPoapNotClaimedStatus,
          eligibilityLabel: poapEligibilityLabel(poap),
          eligibilityHint: poapEligibilityHint(poap),
          signedOutHint: null,
          contextItems: contextItemsFor(poap),
          isClaimed: poap.claimed,
          canClaim: false,
          isClaiming: false,
          onClaim: null,
          claimActionLabel: l10n.exhibitionDetailPoapClaimAction,
          claimingActionLabel: l10n.exhibitionDetailPoapClaimingAction,
        ),
      );
      cards.add(const SizedBox(height: DetailSpacing.md));
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    cards.removeLast();

    return DetailCard(
      borderRadius: DetailRadius.md,
      padding: DetailSpacing.editorialCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailSectionLabel(label: l10n.exhibitionDetailPoapTitle),
          const SizedBox(height: DetailSpacing.sm),
          Text(
            l10n.eventDetailPoapAggregationHint,
            style: DetailTypography.caption(context),
          ),
          const SizedBox(height: DetailSpacing.lg),
          ...cards,
        ],
      ),
    );
  }
}
