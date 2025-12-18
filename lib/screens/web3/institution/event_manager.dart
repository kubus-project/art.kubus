import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/institution.dart';
import '../../../providers/institution_provider.dart';
import '../../../utils/app_color_utils.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/empty_state_card.dart';
import 'event_creator.dart';

class EventManager extends StatefulWidget {
  const EventManager({super.key});

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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
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
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Manager',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your institution\'s events',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.notifications,
                    color: Theme.of(context).colorScheme.onSurface, size: 20),
                onPressed: () => _showNotifications(),
              ),
              IconButton(
                icon: Icon(Icons.search,
                    color: Theme.of(context).colorScheme.onSurface, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: Colors.transparent,
                selectedColor: AppColorUtils.purpleAccent,
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
      padding: const EdgeInsets.all(16),
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
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  _statusLabel(status),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            event.description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  event.location,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.schedule,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _formatDate(event.startDate),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasCapacity)
                      SizedBox(
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: InlineLoading(
                            progress: occupancyPercentage,
                            tileSize: 6.0,
                            color: occupancyPercentage > 0.8
                                ? scheme.error
                                : AppColorUtils.purpleAccent,
                            duration: const Duration(milliseconds: 700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                event.formattedPrice,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColorUtils.purpleAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          size: 16),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
        return AppColorUtils.purpleAccent;
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Notifications',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No alerts right now.',
                  style: GoogleFonts.inter(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColorUtils.purpleAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Search Events',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Enter event name or keyword...',
            hintStyle: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.54)),
            border: OutlineInputBorder(),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
            child: Text('Search'),
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
    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHighest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(event.title,
              style: GoogleFonts.inter(
                  color: scheme.onSurface, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.description,
                  style: GoogleFonts.inter(
                      color: scheme.onSurface.withValues(alpha: 0.8))),
              const SizedBox(height: 12),
              Text('Location: ${event.location}',
                  style: GoogleFonts.inter(
                      color: scheme.onSurface.withValues(alpha: 0.8))),
              Text(
                  'Dates: ${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                  style: GoogleFonts.inter(
                      color: scheme.onSurface.withValues(alpha: 0.8))),
              Text('Price: ${event.formattedPrice}',
                  style: GoogleFonts.inter(
                      color: scheme.onSurface.withValues(alpha: 0.8))),
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
    final shareText =
        '${event.title}\n${event.location}\n${_formatDate(event.startDate)}';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied "${event.title}" to clipboard')));
  }

  void _deleteEvent(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Delete Event',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              context.read<InstitutionProvider>().deleteEvent(event.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${event.title} deleted')),
              );
            },
            child: Text('Delete',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}

enum _EventStatus { upcoming, active, completed }
