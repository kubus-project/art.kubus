import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/event.dart';
import '../../models/promotion.dart';
import '../../providers/events_provider.dart';
import '../../screens/collab/invites_inbox_screen.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/map_navigation.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/collaboration_panel.dart';
import '../../widgets/promotion/promotion_builder_sheet.dart';
import '../../widgets/detail/detail_shell_components.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../widgets/glass_components.dart';
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
    try {
      await events.fetchEvent(widget.eventId, force: true);
      await events.loadEventExhibitions(widget.eventId, refresh: true);
    } catch (_) {
      // Provider handles errors.
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final events = context.watch<EventsProvider>();

    final event = events.events.firstWhere(
      (e) => e.id == widget.eventId,
      orElse: () =>
          widget.initialEvent ?? KubusEvent(id: widget.eventId, title: 'Event'),
    );

    final exhibitions = events.exhibitionsForEvent(widget.eventId);
    final canPromote = _canPromoteEvent(event);

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
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(KubusSpacing.md),
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
                          label: 'Promote',
                          onTap: () => _openPromotionFlow(event),
                          tooltip: 'Promote event',
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
                        label: 'Invites',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const InvitesInboxScreen(),
                            ),
                          );
                        },
                        tooltip: 'Invites',
                      ),
                      DetailSecondaryAction(
                        icon: Icons.refresh,
                        label: l10n.commonRefresh,
                        onTap: _load,
                        tooltip: l10n.commonRefresh,
                      ),
                    ],
                  );

                  final collab = CollaborationPanel(
                    entityType: 'events',
                    entityId: widget.eventId,
                    myRole: event.myRole,
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: ListView(
                            children: [
                              secondaryActions,
                              const SizedBox(height: 14),
                              details,
                              const SizedBox(height: 14),
                              _ExhibitionsPreview(
                                exhibitionsCount: exhibitions.length,
                              ),
                              if (events.isLoading)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: LinearProgressIndicator(
                                    color: scheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: collab),
                      ],
                    );
                  }

                  return ListView(
                    children: [
                      secondaryActions,
                      const SizedBox(height: 14),
                      details,
                      const SizedBox(height: 14),
                      collab,
                      const SizedBox(height: 14),
                      _ExhibitionsPreview(exhibitionsCount: exhibitions.length),
                      if (events.isLoading)
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
        : 'Hosted by ${event.host!.displayName ?? event.host!.username ?? 'Unknown'}';

    return DetailCard(
      borderRadius: DetailRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailIdentityBlock(
            title: event.title,
            kicker: l10n.mapMarkerSubjectTypeEvent,
            subtitle: hostLabel,
          ),
          SizedBox(height: DetailSpacing.md),
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
            SizedBox(height: DetailSpacing.md),
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
                  label: _labelForStatus(event.status),
                ),
            ],
          ),
          SizedBox(height: DetailSpacing.md),
          DetailContextCluster(
            compact: true,
            items: [
              DetailContextItem(
                icon: Icons.collections_outlined,
                value: '$exhibitionsCount',
                label: 'Exhibitions',
              ),
            ],
          ),
          if ((event.description ?? '').trim().isNotEmpty) ...[
            SizedBox(height: DetailSpacing.md),
            Text(
              event.description!,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: DetailTypography.body(context),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String _labelForStatus(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty) return 'Unknown';
    if (value == 'published') return 'Published';
    if (value == 'draft') return 'Draft';
    return value;
  }
}

class _ExhibitionsPreview extends StatelessWidget {
  const _ExhibitionsPreview({required this.exhibitionsCount});

  final int exhibitionsCount;

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      borderRadius: DetailRadius.md,
      child: Row(
        children: [
          Icon(
            Icons.collections_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: DetailSpacing.sm),
          Expanded(
            child: Text(
              exhibitionsCount == 0
                  ? 'No exhibitions yet.'
                  : 'This event includes $exhibitionsCount exhibition${exhibitionsCount == 1 ? '' : 's'}.',
              style: DetailTypography.caption(context),
            ),
          ),
        ],
      ),
    );
  }
}
