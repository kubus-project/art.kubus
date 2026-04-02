import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/institution.dart';
import '../../../providers/institution_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/inline_loading.dart';
import '../../events/event_detail_screen.dart';

class InstitutionDetailScreen extends StatefulWidget {
  const InstitutionDetailScreen({
    super.key,
    required this.institutionId,
    this.embedded = false,
  });

  final String institutionId;
  final bool embedded;

  @override
  State<InstitutionDetailScreen> createState() => _InstitutionDetailScreenState();
}

class _InstitutionDetailScreenState extends State<InstitutionDetailScreen> {
  final BackendApiService _api = BackendApiService();

  Institution? _institution;
  List<Event> _events = const <Event>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstitution();
    });
  }

  Future<void> _loadInstitution() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final provider = context.read<InstitutionProvider>();
      Institution? institution = provider.getInstitutionById(widget.institutionId);
      var events = provider.getEventsByInstitution(widget.institutionId);

      if (institution == null || events.isEmpty) {
        await provider.refreshData();
        if (!mounted) return;
        institution ??= provider.getInstitutionById(widget.institutionId);
        if (events.isEmpty) {
          events = provider.getEventsByInstitution(widget.institutionId);
        }
      }

      if (institution == null) {
        final rawInstitution = await _api.getInstitution(widget.institutionId);
        if (!mounted) return;
        if (rawInstitution != null) {
          institution = _tryParseInstitution(rawInstitution);
        }
      }

      if (events.isEmpty) {
        final rawEvents = await _api.listEvents(
          institutionId: widget.institutionId,
          limit: 20,
          offset: 0,
        );
        if (!mounted) return;
        events = rawEvents.map(_tryParseEvent).whereType<Event>().toList();
      }

      events.sort((a, b) => a.startDate.compareTo(b.startDate));

      if (!mounted) return;
      setState(() {
        _institution = institution;
        _events = List<Event>.unmodifiable(events);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Institution? _tryParseInstitution(Map<String, dynamic> json) {
    try {
      return Institution.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Event? _tryParseEvent(Map<String, dynamic> json) {
    try {
      return Event.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  String _formatDateRange(BuildContext context, Event event) {
    final localizations = MaterialLocalizations.of(context);
    final start = localizations.formatShortDate(event.startDate);
    final end = localizations.formatShortDate(event.endDate);
    if (start == end) return start;
    return '$start - $end';
  }

  Future<void> _openEvent(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(eventId: event.id),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Institution institution) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedImage = MediaUrlResolver.resolve(
      institution.imageUrls.isNotEmpty ? institution.imageUrls.first : null,
    );

    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KubusRadius.lg),
            ),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: resolvedImage == null || resolvedImage.isEmpty
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withValues(alpha: 0.22),
                            scheme.secondary.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.apartment_outlined,
                        size: 48,
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    )
                  : Image.network(
                      resolvedImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary.withValues(alpha: 0.22),
                              scheme.secondary.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.apartment_outlined,
                          size: 48,
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  institution.name,
                  style: KubusTextStyles.screenTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Wrap(
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.sm,
                  children: [
                    _DetailChip(label: institution.type),
                    if (institution.isVerified)
                      const _DetailChip(
                        label: 'Verified',
                        icon: Icons.verified_outlined,
                      ),
                    if (institution.address.trim().isNotEmpty)
                      _DetailChip(
                        label: institution.address.trim(),
                        icon: Icons.place_outlined,
                      ),
                  ],
                ),
                if (institution.description.trim().isNotEmpty) ...[
                  const SizedBox(height: KubusSpacing.lg),
                  Text(
                    institution.description.trim(),
                    style: KubusTextStyles.sectionSubtitle.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ],
                const SizedBox(height: KubusSpacing.lg),
                Wrap(
                  spacing: KubusSpacing.md,
                  runSpacing: KubusSpacing.md,
                  children: [
                    _StatTile(
                      label: 'Active events',
                      value: institution.stats.activeEvents.toString(),
                    ),
                    _StatTile(
                      label: 'Artwork views',
                      value: institution.stats.artworkViews.toString(),
                    ),
                    _StatTile(
                      label: 'Visitors',
                      value: institution.stats.totalVisitors.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_events.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.event_busy_outlined,
        title: 'No events yet',
        description: 'This institution does not have public events scheduled right now.',
      );
    }

    final visibleEvents = _events.take(6).toList(growable: false);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events',
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          ...visibleEvents.map(
                (event) => Padding(
                  padding: EdgeInsets.only(
                    bottom: identical(event, visibleEvents.last)
                        ? 0
                        : KubusSpacing.sm,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.sm,
                      vertical: KubusSpacing.xs,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                    tileColor: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
                    leading: Icon(
                      Icons.event_outlined,
                      color: scheme.primary,
                    ),
                    title: Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_formatDateRange(context, event)}\n${event.location}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openEvent(event),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final body = _loading
        ? const Center(child: InlineLoading(expand: false))
        : _institution == null
            ? EmptyStateCard(
                icon: Icons.apartment_outlined,
                title: _error == null
                    ? 'Institution not found'
                    : 'Unable to load institution',
                description: _error == null
                    ? 'We could not find this institution.'
                    : 'We could not load this institution right now.',
                showAction: true,
                actionLabel: l10n.commonRetry,
                onAction: _loadInstitution,
              )
            : ListView(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                children: [
                  _buildHeaderCard(context, _institution!),
                  const SizedBox(height: KubusSpacing.lg),
                  _buildEventsSection(context),
                ],
              );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _institution?.name ?? 'Institution',
          style: KubusTextStyles.mobileAppBarTitle,
        ),
      ),
      body: body,
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: KubusSpacing.xs),
          ],
          Text(label),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            label,
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
        ],
      ),
    );
  }
}
