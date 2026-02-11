import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../models/institution.dart';
import '../../../providers/institution_provider.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/creator/creator_kit.dart';
import 'event_creator.dart';
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
  String _selectedFilter = 'All';
  String _searchQuery = '';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final institutionProvider = context.watch<InstitutionProvider>();
    final filteredEvents = _getFilteredEvents(institutionProvider.events);

    Widget body = FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            _buildStatsRow(institutionProvider.events),
            Expanded(child: _buildEventsList(filteredEvents)),
          ],
        ),
      ),
    );

    if (widget.embedded) return CreatorGlassBody(child: body);
    return body;
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Manager',
            style: KubusTextStyles.screenTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            'Manage your institution\'s events',
            style: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.notifications,
                    color: scheme.onSurface, size: 20),
                onPressed: () => _showNotifications(),
              ),
              IconButton(
                icon: Icon(Icons.search,
                    color: scheme.onSurface, size: 20),
                onPressed: () => _showSearchDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All', 'Upcoming', 'Active', 'Completed'];

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
                  filter,
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

  Widget _buildStatsRow(List<Event> events) {
    final totalEvents = events.length;
    final activeEvents = events.where((e) => e.isActive).length;
    final totalRegistrations =
        events.fold<int>(0, (sum, event) => sum + event.currentAttendees);

    return Padding(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Row(
        children: [
          Expanded(
              child: _buildStatItem('Total Events', totalEvents.toString())),
          Expanded(
              child: _buildStatItem('Active Now', activeEvents.toString())),
          Expanded(
              child: _buildStatItem(
                  'Registrations', totalRegistrations.toString())),
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

  Widget _buildEventsList(List<Event> events) {
    if (events.isEmpty) {
      return Center(
        child: EmptyStateCard(
          icon: Icons.event_busy,
          title: 'No events found',
          description: 'Create your first event to get started',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return _buildEventCard(events[index]);
      },
    );
  }

  Widget _buildEventCard(Event event) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statusForEvent(event);
    final statusColor = _statusColor(status, scheme);

    final capacity = event.capacity ?? 0;
    final hasCapacity = capacity > 0;
    final occupancyPercentage =
        hasCapacity ? (event.currentAttendees / capacity) : 0.0;

    return LiquidGlassCard(
      margin: const EdgeInsets.only(bottom: KubusSpacing.sm),
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
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
                label: _statusLabel(status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            event.description,
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
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  size: 14),
              const SizedBox(width: KubusSpacing.xs),
              Flexible(
                child: Text(
                  event.location,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Icon(Icons.schedule,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  size: 14),
              const SizedBox(width: KubusSpacing.xs),
              Flexible(
                child: Text(
                  _formatDate(event.startDate),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCapacity
                          ? 'Occupancy: ${event.currentAttendees}/$capacity'
                          : 'Attendees: ${event.currentAttendees}',
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    if (hasCapacity)
                      SizedBox(
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(KubusRadius.xs),
                          child: InlineLoading(
                            progress: occupancyPercentage,
                            tileSize: 6.0,
                            color: occupancyPercentage > 0.8
                                ? scheme.error
                                : KubusColorRoles.of(context)
                                    .web3InstitutionAccent,
                            duration: const Duration(milliseconds: 700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Text(
                event.formattedPrice,
                style: KubusTextStyles.detailLabel.copyWith(
                  fontWeight: FontWeight.bold,
                  color: KubusColorRoles.of(context).web3InstitutionAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton('Edit', Icons.edit, () => _editEvent(event)),
              _buildActionButton(
                  'View', Icons.visibility, () => _viewEvent(event)),
              _buildActionButton(
                  'Share', Icons.share, () => _shareEvent(event)),
              _buildActionButton(
                  'Delete', Icons.delete, () => _deleteEvent(event)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon,
          color: scheme.onSurface.withValues(alpha: 0.7),
          size: 16),
      label: Text(
        label,
        style: KubusTextStyles.detailCaption.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  _EventStatus _statusForEvent(Event event) {
    if (event.isActive) return _EventStatus.active;
    if (event.isUpcoming) return _EventStatus.upcoming;
    return _EventStatus.completed;
  }

  String _statusLabel(_EventStatus status) {
    switch (status) {
      case _EventStatus.upcoming:
        return 'UPCOMING';
      case _EventStatus.active:
        return 'ACTIVE';
      case _EventStatus.completed:
        return 'COMPLETED';
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  List<Event> _getFilteredEvents(List<Event> events) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = events.where((e) {
      if (query.isEmpty) return true;
      return e.title.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query) ||
          e.location.toLowerCase().contains(query);
    }).toList();

    switch (_selectedFilter) {
      case 'Upcoming':
        return filtered.where((e) => e.isUpcoming).toList();
      case 'Active':
        return filtered.where((e) => e.isActive).toList();
      case 'Completed':
        return filtered.where((e) => !e.isUpcoming && !e.isActive).toList();
      default:
        return filtered;
    }
  }

  void _showNotifications() {
    final provider = context.read<InstitutionProvider>();
    final now = DateTime.now();
    final alerts = <Map<String, String>>[];

    for (final event in provider.events) {
      final capacity = event.capacity;
      if (capacity != null && capacity > 0) {
        final pct = event.currentAttendees / capacity;
        if (pct >= 0.9) {
          alerts.add({
            'message':
                '"${event.title}" capacity at ${(pct * 100).toStringAsFixed(0)}%',
            'time': 'Now'
          });
        }
      }
      final diff = event.startDate.difference(now);
      if (diff.inHours >= 0 && diff.inHours <= 48) {
        alerts.add({
          'message': '"${event.title}" starts in ${diff.inHours}h',
          'time': 'Soon'
        });
      }
    }

    final scheme = Theme.of(context).colorScheme;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: Text('Notifications',
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
                  'No alerts right now.',
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

  void _showSearchDialog() {
    final scheme = Theme.of(context).colorScheme;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: Text('Search Events',
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            )),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Enter event name or keyword...',
            hintStyle: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.54),
            ),
            filled: true,
            fillColor: scheme.onSurface.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(color: scheme.primary),
            ),
          ),
          style: KubusTextStyles.detailBody.copyWith(
            color: scheme.onSurface,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _editEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventCreator(initialEvent: event)),
    );
  }

  void _viewEvent(Event event) {
    showKubusDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return KubusAlertDialog(
          backgroundColor: scheme.surfaceContainerHighest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(KubusRadius.lg)),
          title: Text(event.title,
              style: KubusTextStyles.detailSectionTitle.copyWith(
                color: scheme.onSurface,
              )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.description,
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  )),
              const SizedBox(height: KubusSpacing.sm),
              Text('Location: ${event.location}',
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  )),
              Text(
                  'Dates: ${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  )),
              Text('Price: ${event.formattedPrice}',
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  )),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.commonClose)),
          ],
        );
      },
    );
  }

  void _shareEvent(Event event) {
    ShareService().showShareSheet(
      context,
      target: ShareTarget.event(eventId: event.id, title: event.title),
      sourceScreen: 'institution_event_manager',
    );
  }

  void _deleteEvent(Event event) {
    final scheme = Theme.of(context).colorScheme;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: Text('Delete Event',
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            )),
        content: Text(
          'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
          style: KubusTextStyles.detailBody.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: scheme.error),
            onPressed: () {
              context.read<InstitutionProvider>().deleteEvent(event.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(content: Text('${event.title} deleted')),
              );
            },
            child: Text('Delete',
                style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }
}

enum _EventStatus { upcoming, active, completed }
