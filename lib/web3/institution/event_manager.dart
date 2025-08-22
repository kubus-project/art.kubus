import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';

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
  List<Event> _events = [];

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
    
    _loadEvents();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadEvents() {
    // Simulate loading events
    _events = [
      Event(
        id: '1',
        title: 'Digital Dreams Exhibition',
        description: 'A showcase of contemporary digital art from emerging artists',
        startDate: DateTime.now().add(const Duration(days: 3)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        location: 'Main Gallery',
        status: EventStatus.upcoming,
        capacity: 200,
        registeredCount: 156,
        price: 25.0,
        imageUrl: 'https://example.com/digital-dreams.jpg',
      ),
      Event(
        id: '2',
        title: 'Modern Art Workshop',
        description: 'Interactive workshop on modern art techniques',
        startDate: DateTime.now().subtract(const Duration(days: 2)),
        endDate: DateTime.now().add(const Duration(days: 1)),
        location: 'Workshop Room A',
        status: EventStatus.active,
        capacity: 30,
        registeredCount: 28,
        price: 50.0,
        imageUrl: 'https://example.com/workshop.jpg',
      ),
      Event(
        id: '3',
        title: 'Artist Talk Series',
        description: 'Monthly talk with renowned contemporary artists',
        startDate: DateTime.now().add(const Duration(days: 15)),
        endDate: DateTime.now().add(const Duration(days: 15)),
        location: 'Auditorium',
        status: EventStatus.upcoming,
        capacity: 100,
        registeredCount: 67,
        price: 15.0,
        imageUrl: 'https://example.com/artist-talk.jpg',
      ),
      Event(
        id: '4',
        title: 'Virtual Reality Art Experience',
        description: 'Immerse yourself in virtual art installations',
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        location: 'VR Room',
        status: EventStatus.completed,
        capacity: 15,
        registeredCount: 15,
        price: 35.0,
        imageUrl: 'https://example.com/vr-art.jpg',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _getFilteredEvents();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: const Color(0xFF0A0A0A),
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            _buildStatsRow(),
            Expanded(child: _buildEventsList(filteredEvents)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Event Manager',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Manage your institution\'s events',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => _showNotifications(),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
              backgroundColor: Colors.transparent,
              selectedColor: Provider.of<ThemeProvider>(context).accentColor,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalEvents = _events.length;
    final activeEvents = _events.where((e) => e.status == EventStatus.active).length;
    final totalRegistrations = _events.fold<int>(0, (sum, event) => sum + event.registeredCount);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(child: _buildStatItem('Total Events', totalEvents.toString())),
          Expanded(child: _buildStatItem('Active Now', activeEvents.toString())),
          Expanded(child: _buildStatItem('Total Registrations', totalRegistrations.toString())),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<Event> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No events found',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            Text(
              'Create your first event to get started',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return _buildEventCard(events[index]);
      },
    );
  }

  Widget _buildEventCard(Event event) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final statusColor = _getStatusColor(event.status);
    final occupancyPercentage = event.registeredCount / event.capacity;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  event.status.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white.withOpacity(0.6), size: 16),
              const SizedBox(width: 4),
              Text(
                event.location,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule, color: Colors.white.withOpacity(0.6), size: 16),
              const SizedBox(width: 4),
              Text(
                _formatDate(event.startDate),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Occupancy: ${event.registeredCount}/${event.capacity}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: occupancyPercentage,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        occupancyPercentage > 0.8 ? Colors.red : themeProvider.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '\$${event.price.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton('Edit', Icons.edit, () => _editEvent(event)),
              _buildActionButton('View', Icons.visibility, () => _viewEvent(event)),
              _buildActionButton('Share', Icons.share, () => _shareEvent(event)),
              _buildActionButton('Delete', Icons.delete, () => _deleteEvent(event)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white.withOpacity(0.7), size: 16),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return Colors.blue;
      case EventStatus.active:
        return Colors.green;
      case EventStatus.completed:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  List<Event> _getFilteredEvents() {
    switch (_selectedFilter) {
      case 'Upcoming':
        return _events.where((e) => e.status == EventStatus.upcoming).toList();
      case 'Active':
        return _events.where((e) => e.status == EventStatus.active).toList();
      case 'Completed':
        return _events.where((e) => e.status == EventStatus.completed).toList();
      default:
        return _events;
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationItem('Workshop capacity at 93%', '2 hours ago'),
            _buildNotificationItem('New registration for Digital Dreams', '4 hours ago'),
            _buildNotificationItem('Artist Talk rescheduled', '1 day ago'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
              color: Provider.of<ThemeProvider>(context).accentColor,
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
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
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Search Events', style: TextStyle(color: Colors.white)),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter event name or keyword...',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            // Implement search functionality
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editing ${event.title}')),
    );
  }

  void _viewEvent(Event event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing ${event.title}')),
    );
  }

  void _shareEvent(Event event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing ${event.title}')),
    );
  }

  void _deleteEvent(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Event', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _events.removeWhere((e) => e.id == event.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${event.title} deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Event model
class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final EventStatus status;
  final int capacity;
  final int registeredCount;
  final double price;
  final String imageUrl;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.status,
    required this.capacity,
    required this.registeredCount,
    required this.price,
    required this.imageUrl,
  });
}

enum EventStatus {
  upcoming,
  active,
  completed,
  cancelled,
}
