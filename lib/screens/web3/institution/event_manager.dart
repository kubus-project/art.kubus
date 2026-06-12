import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../models/event.dart';
import '../../../providers/events_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/creator_shell_navigation.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../events/event_detail_screen.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/creator/creator_kit.dart';
import '../../../widgets/common/subject_options_sheet.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/glass_components.dart';

class EventManager extends StatefulWidget {
  /// When `true` the screen wraps in a frosted glass body because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides a header
  /// and gradient background.
  final bool embedded;

  const EventManager({super.key, this.embedded = false});

  @override
  State<EventManager> createState() => _EventManagerState();
}

class _EventManagerState extends State<EventManager>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _refreshing = false;
  final Set<String> _deleteDialogOpenEventIds = <String>{};
  final Set<String> _deleteInFlightEventIds = <String>{};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshEvents() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<EventsProvider>().loadEvents(refresh: true);
    } catch (_) {
      // Provider keeps its own error state.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _createEvent() {
    unawaited(CreatorShellNavigation.openEventCreatorWorkspace(context));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eventsProvider = context.watch<EventsProvider>();
    final filteredEvents = _getFilteredEvents(eventsProvider.events);

    Widget body = FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            _buildHeader(l10n),
            _buildFilterBar(l10n),
            _buildStatsRow(eventsProvider.events, l10n),
            Expanded(child: _buildEventsList(filteredEvents, l10n)),
          ],
        ),
      ),
    );

    if (widget.embedded) return CreatorGlassBody(child: body);
    return body;
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.eventManagerTitle,
                      style: KubusTextStyles.mobileAppBarTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      l10n.eventManagerSubtitle,
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              IconButton(
                tooltip: l10n.commonNotifications,
                icon: Icon(Icons.notifications_outlined,
                    color: scheme.onSurface, size: 20),
                onPressed: () => _showNotifications(),
              ),
              IconButton(
                tooltip: l10n.commonRefresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh, color: scheme.onSurface, size: 20),
                onPressed: _refreshing ? null : _refreshEvents,
              ),
              if (isWide) ...[
                const SizedBox(width: KubusSpacing.xs),
                FilledButton.icon(
                  onPressed: _createEvent,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.eventCreatorShellCreateTitle),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        KubusColorRoles.of(context).web3InstitutionAccent,
                  ),
                ),
              ] else
                IconButton(
                  tooltip: l10n.eventCreatorShellCreateTitle,
                  icon: Icon(Icons.add, color: scheme.onSurface, size: 20),
                  onPressed: _createEvent,
                ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          CreatorSearchField(
            controller: _searchController,
            hint: l10n.eventManagerSearchHint,
            accentColor: KubusColorRoles.of(context).web3InstitutionAccent,
            onChanged: (value) => setState(() => _searchQuery = value),
            onClear: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n) {
    final filters = ['all', 'upcoming', 'active', 'completed'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: KubusSpacing.sm),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  _filterLabel(filter, l10n),
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                backgroundColor: Colors.transparent,
                selectedColor:
                    KubusColorRoles.of(context).web3InstitutionAccent,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<KubusEvent> events, AppLocalizations l10n) {
    final totalEvents = events.length;
    final activeEvents = events.where(_eventIsActive).length;

    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Row(
        children: [
          Expanded(
              child: _buildStatItem(
                  l10n.eventManagerStatTotalEvents, totalEvents.toString())),
          Expanded(
              child: _buildStatItem(
                  l10n.eventManagerStatActiveNow, activeEvents.toString())),
          Expanded(
              child: _buildStatItem(l10n.eventManagerStatRegistrations,
                  '0')),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      margin: const EdgeInsets.only(right: KubusSpacing.xs),
      padding: const EdgeInsets.all(KubusSpacing.sm),
      borderRadius: BorderRadius.circular(KubusRadius.md),
      child: Column(
        children: [
          Text(
            value,
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            label,
            style: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<KubusEvent> events, AppLocalizations l10n) {
    if (events.isEmpty) {
      return Center(
        child: EmptyStateCard(
          icon: Icons.event_busy,
          title: l10n.eventManagerEmptyTitle,
          description: l10n.eventManagerEmptyDescription,
          showAction: true,
          actionLabel: l10n.eventCreatorShellCreateTitle,
          onAction: _createEvent,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1280
            ? 3
            : (constraints.maxWidth >= 880 ? 2 : 1);

        if (columns == 1) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
            itemCount: events.length,
            itemBuilder: (context, index) {
              return _buildEventCard(events[index], l10n);
            },
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 200,
            crossAxisSpacing: KubusSpacing.md,
            mainAxisSpacing: KubusSpacing.md,
          ),
          itemCount: events.length,
          itemBuilder: (context, index) {
            return _buildEventCard(events[index], l10n);
          },
        );
      },
    );
  }

  Widget _buildEventCard(KubusEvent event, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statusForEvent(event);
    final statusColor = _statusColor(status, scheme);
    final linkedExhibitions =
        context.read<EventsProvider>().exhibitionsForEvent(event.id);

    return LiquidGlassCard(
      margin: const EdgeInsets.only(bottom: KubusSpacing.sm),
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      onTap: () => _viewEvent(event),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: KubusTextStyles.actionTileTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              CreatorStatusBadge(
                label: _statusLabel(status, l10n),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            event.description ?? '',
            style: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: KubusSpacing.sm),
          Row(
            children: [
              Icon(Icons.location_on,
                  color: scheme.onSurface.withValues(alpha: 0.6), size: 14),
              const SizedBox(width: KubusSpacing.xs),
              Flexible(
                child: Text(
                  event.locationName ?? '',
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Icon(Icons.schedule,
                  color: scheme.onSurface.withValues(alpha: 0.6), size: 14),
              const SizedBox(width: KubusSpacing.xs),
              Flexible(
                child: Text(
                  _formatDate(event.startsAt),
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          Row(
            children: [
              if (linkedExhibitions.isNotEmpty)
                Flexible(
                  child: CreatorStatusBadge(
                    label: l10n.eventDetailLinkedExhibitionsSummary(
                        linkedExhibitions.length),
                    color: scheme.tertiary,
                  ),
                ),
              const Spacer(),
              if (_canManageEvent(event))
                IconButton(
                  tooltip: l10n.commonEdit,
                  onPressed: () => _editEvent(event),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              IconButton(
                tooltip: l10n.commonMore,
                onPressed: () => _showEventOptions(event),
                icon: Icon(
                  Icons.more_horiz,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _EventStatus _statusForEvent(KubusEvent event) {
    if (_eventIsActive(event)) return _EventStatus.active;
    if (_eventIsUpcoming(event)) return _EventStatus.upcoming;
    return _EventStatus.completed;
  }

  String _statusLabel(_EventStatus status, AppLocalizations l10n) {
    switch (status) {
      case _EventStatus.upcoming:
        return l10n.eventManagerStatusUpcoming;
      case _EventStatus.active:
        return l10n.eventManagerStatusActive;
      case _EventStatus.completed:
        return l10n.eventManagerStatusCompleted;
    }
  }

  String _filterLabel(String filter, AppLocalizations l10n) {
    switch (filter) {
      case 'upcoming':
        return l10n.eventManagerFilterUpcoming;
      case 'active':
        return l10n.eventManagerFilterActive;
      case 'completed':
        return l10n.eventManagerFilterCompleted;
      case 'all':
      default:
        return l10n.eventManagerFilterAll;
    }
  }

  Color _statusColor(_EventStatus status, ColorScheme scheme) {
    switch (status) {
      case _EventStatus.upcoming:
        return scheme.primary;
      case _EventStatus.active:
        return KubusColorRoles.of(context).web3InstitutionAccent;
      case _EventStatus.completed:
        return scheme.outline;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return MaterialLocalizations.of(context).formatShortDate(date);
  }

  List<KubusEvent> _getFilteredEvents(List<KubusEvent> events) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = events.where((e) {
      if (query.isEmpty) return true;
      return e.title.toLowerCase().contains(query) ||
          (e.description ?? '').toLowerCase().contains(query) ||
          (e.locationName ?? '').toLowerCase().contains(query);
    }).toList();

    switch (_selectedFilter) {
      case 'upcoming':
        return filtered.where(_eventIsUpcoming).toList();
      case 'active':
        return filtered.where(_eventIsActive).toList();
      case 'completed':
        return filtered
            .where((e) => !_eventIsUpcoming(e) && !_eventIsActive(e))
            .toList();
      default:
        return filtered;
    }
  }

  Future<void> _showEventOptions(KubusEvent event) async {
    final l10n = AppLocalizations.of(context)!;
    final canManage = _canManageEvent(event);
    await showSubjectOptionsSheet(
      context: context,
      title: event.title,
      subtitle: l10n.eventManagerOptionsSubtitle,
      actions: [
        if (canManage)
          SubjectOptionsAction(
            id: 'edit',
            icon: Icons.edit_outlined,
            label: l10n.commonEdit,
            onSelected: () => _editEvent(event),
          ),
        SubjectOptionsAction(
          id: 'view',
          icon: Icons.visibility_outlined,
          label: l10n.commonViewDetails,
          onSelected: () => _viewEvent(event),
        ),
        SubjectOptionsAction(
          id: 'share',
          icon: Icons.share_outlined,
          label: l10n.commonShare,
          onSelected: () => _shareEvent(event),
        ),
        if (canManage)
          SubjectOptionsAction(
            id: 'linked_exhibition',
            icon: Icons.museum_outlined,
            label: l10n.eventCreatorCreateExhibitionForEvent,
            onSelected: () => _createLinkedExhibition(event),
          ),
        if (canManage)
          SubjectOptionsAction(
            id: 'delete',
            icon: Icons.delete_outline,
            label: l10n.commonDelete,
            isDestructive: true,
            onSelected: () => _deleteEvent(event),
          ),
      ],
    );
  }

  bool _canManageEvent(KubusEvent event) {
    final role = (event.myRole ?? '').trim().toLowerCase();
    return role.isEmpty ||
        role == 'owner' ||
        role == 'admin' ||
        role == 'publisher' ||
        role == 'editor';
  }

  void _showNotifications() {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<EventsProvider>();
    final now = DateTime.now();
    final alerts = <Map<String, String>>[];

    for (final event in provider.events) {
      final startsAt = event.startsAt;
      if (startsAt == null) continue;
      final diff = startsAt.difference(now);
      if (diff.inHours >= 0 && diff.inHours <= 48) {
        alerts.add({
          'message':
              l10n.eventManagerStartsSoonAlert(event.title, diff.inHours),
          'time': l10n.eventManagerSoonLabel,
        });
      }
    }

    final scheme = Theme.of(context).colorScheme;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: Text(l10n.commonNotifications,
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.sm),
                child: Text(
                  l10n.eventManagerNoAlerts,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              )
            else
              ...alerts.take(6).map(
                  (a) => _buildNotificationItem(a['message']!, a['time']!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String message, String time) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: KubusColorRoles.of(context).web3InstitutionAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  time,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editEvent(KubusEvent event) {
    unawaited(
      CreatorShellNavigation.openEventCreatorWorkspace(
        context,
        initialEvent: event,
      ),
    );
  }

  void _viewEvent(KubusEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
    );
  }

  void _shareEvent(KubusEvent event) {
    ShareService().showShareSheet(
      context,
      target: ShareTarget.event(eventId: event.id, title: event.title),
      sourceScreen: 'institution_event_manager',
    );
  }

  void _createLinkedExhibition(KubusEvent event) {
    unawaited(
      CreatorShellNavigation.openExhibitionCreatorWorkspace(
        context,
        eventId: event.id,
      ),
    );
  }

  Future<void> _deleteEvent(KubusEvent event) async {
    if (_deleteDialogOpenEventIds.contains(event.id) ||
        _deleteInFlightEventIds.contains(event.id)) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    _deleteDialogOpenEventIds.add(event.id);
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: Text(l10n.eventManagerDeleteTitle,
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            )),
        content: Text(
          l10n.eventManagerDeleteBody(event.title),
          style: KubusTextStyles.detailBody.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete,
                style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    ).whenComplete(() {
      _deleteDialogOpenEventIds.remove(event.id);
    });
    if (confirmed != true || !mounted) {
      return;
    }
    await _performEventDelete(event);
  }

  Future<void> _performEventDelete(KubusEvent event) async {
    if (_deleteInFlightEventIds.contains(event.id)) {
      return;
    }

    _deleteInFlightEventIds.add(event.id);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final provider = context.read<EventsProvider>();
      await provider.deleteEvent(event.id);
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.eventManagerDeletedToast(event.title))),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is BackendApiRequestException
          ? e.userMessage
          : l10n.commonActionFailedToast;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      _deleteInFlightEventIds.remove(event.id);
    }
  }
}

enum _EventStatus { upcoming, active, completed }

bool _eventIsUpcoming(KubusEvent event) {
  final startsAt = event.startsAt;
  if (startsAt == null) return false;
  return DateTime.now().isBefore(startsAt);
}

bool _eventIsActive(KubusEvent event) {
  final startsAt = event.startsAt;
  final endsAt = event.endsAt;
  if (startsAt == null || endsAt == null) return event.isPublished;
  final now = DateTime.now();
  return now.isAfter(startsAt) && now.isBefore(endsAt);
}
