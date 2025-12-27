import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/event.dart';
import '../../providers/events_provider.dart';
import '../../screens/collab/invites_inbox_screen.dart';
import '../../utils/map_navigation.dart';
import '../../widgets/collaboration_panel.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final events = context.watch<EventsProvider>();

    final event = events.events.firstWhere(
      (e) => e.id == widget.eventId,
      orElse: () => widget.initialEvent ?? KubusEvent(id: widget.eventId, title: 'Event'),
    );

    final exhibitions = events.exhibitionsForEvent(widget.eventId);

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          if (event.lat != null && event.lng != null)
            IconButton(
              tooltip: l10n.commonOpenOnMap,
              onPressed: () {
                MapNavigation.open(
                  context,
                  center: LatLng(event.lat!, event.lng!),
                  zoom: 16,
                  autoFollow: false,
                );
              },
              icon: const Icon(Icons.map_outlined),
            ),
          IconButton(
            tooltip: 'Invites',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvitesInboxScreen()));
            },
            icon: const Icon(Icons.inbox_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final details = _EventDetailsCard(event: event, exhibitionsCount: exhibitions.length);

                final collab = CollaborationPanel(
                  entityType: 'events',
                  entityId: widget.eventId,
                  myRole: event.myRole,
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: details),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: collab),
                    ],
                  );
                }

                return ListView(
                  children: [
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
    );
  }
}

class _EventDetailsCard extends StatelessWidget {
  const _EventDetailsCard({required this.event, required this.exhibitionsCount});

  final KubusEvent event;
  final int exhibitionsCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String? dateRange;
    if (event.startsAt != null || event.endsAt != null) {
      final start = event.startsAt != null ? _fmtDate(event.startsAt!) : null;
      final end = event.endsAt != null ? _fmtDate(event.endsAt!) : null;
      dateRange = [start, end].whereType<String>().join(' • ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final locationBits = <String>[];
    if ((event.locationName ?? '').trim().isNotEmpty) locationBits.add(event.locationName!.trim());
    if ((event.city ?? '').trim().isNotEmpty) locationBits.add(event.city!.trim());
    if ((event.country ?? '').trim().isNotEmpty) locationBits.add(event.country!.trim());
    final location = locationBits.isNotEmpty ? locationBits.join(', ') : null;

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
            Text(
              'Overview',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (dateRange != null)
              _InfoRow(icon: Icons.schedule, label: dateRange),
            if (location != null)
              _InfoRow(icon: Icons.place_outlined, label: location),
            _InfoRow(icon: Icons.collections_outlined, label: 'Exhibitions: $exhibitionsCount'),
            if ((event.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(event.description!, style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.8))),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExhibitionsPreview extends StatelessWidget {
  const _ExhibitionsPreview({required this.exhibitionsCount});

  final int exhibitionsCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.collections_outlined, color: scheme.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                exhibitionsCount == 0
                    ? 'No exhibitions yet.'
                    : 'This event includes $exhibitionsCount exhibition${exhibitionsCount == 1 ? '' : 's'}.',
                style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
