import 'package:flutter/foundation.dart';
import '../models/institution.dart';
import 'mockup_data_provider.dart';

class InstitutionProvider extends ChangeNotifier {
  final MockupDataProvider _mockupDataProvider;
  
  List<Institution> _institutions = [];
  List<Event> _events = [];
  Institution? _selectedInstitution;
  Event? _selectedEvent;
  bool _isLoading = false;

  InstitutionProvider(this._mockupDataProvider) {
    _mockupDataProvider.addListener(_onMockupModeChanged);
    _loadData();
  }

  @override
  void dispose() {
    _mockupDataProvider.removeListener(_onMockupModeChanged);
    super.dispose();
  }

  void _onMockupModeChanged() {
    _loadData();
  }

  // Getters
  List<Institution> get institutions => List.unmodifiable(_institutions);
  List<Event> get events => List.unmodifiable(_events);
  Institution? get selectedInstitution => _selectedInstitution;
  Event? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;

  // Institution methods
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_mockupDataProvider.isMockDataEnabled) {
        await _loadMockInstitutions();
        await _loadMockEvents();
      } else {
        // TODO: Load from IPFS/blockchain
        await _loadFromIPFS();
      }
    } catch (e) {
      debugPrint('Error loading institution data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMockInstitutions() async {
    // Ljubljana mock institutions
    _institutions = [
      Institution(
        id: 'inst_1',
        name: 'Modern Gallery Ljubljana',
        description: 'Contemporary art gallery showcasing local and international artists in the heart of Ljubljana.',
        type: 'gallery',
        address: 'Tomšičeva 14, 1000 Ljubljana, Slovenia',
        latitude: 46.0514,
        longitude: 14.5060,
        contactEmail: 'info@mg-lj.si',
        website: 'https://www.mg-lj.si',
        imageUrls: ['https://example.com/gallery1.jpg'],
        stats: InstitutionStats(
          totalVisitors: 12450,
          activeEvents: 8,
          artworkViews: 45200,
          revenue: 18500.0,
          visitorGrowth: 15.3,
          revenueGrowth: 8.7,
        ),
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
      ),
      Institution(
        id: 'inst_2',
        name: 'National Gallery of Slovenia',
        description: 'The premier art museum of Slovenia, housing the largest fine art collection in the country.',
        type: 'museum',
        address: 'Puharjeva 9, 1000 Ljubljana, Slovenia',
        latitude: 46.0498,
        longitude: 14.5037,
        contactEmail: 'info@ng-slo.si',
        website: 'https://www.ng-slo.si',
        imageUrls: ['https://example.com/gallery2.jpg'],
        stats: InstitutionStats(
          totalVisitors: 25300,
          activeEvents: 12,
          artworkViews: 89400,
          revenue: 35200.0,
          visitorGrowth: 22.1,
          revenueGrowth: 12.4,
        ),
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(days: 500)),
      ),
      Institution(
        id: 'inst_3',
        name: 'Jakopič Gallery',
        description: 'Gallery dedicated to contemporary visual arts and experimental installations.',
        type: 'gallery',
        address: 'Slovenska cesta 9, 1000 Ljubljana, Slovenia',
        latitude: 46.0569,
        longitude: 14.5058,
        contactEmail: 'info@jakopiceva.si',
        website: 'https://www.jakopiceva.si',
        imageUrls: ['https://example.com/gallery3.jpg'],
        stats: InstitutionStats(
          totalVisitors: 8900,
          activeEvents: 5,
          artworkViews: 23100,
          revenue: 12800.0,
          visitorGrowth: 9.2,
          revenueGrowth: 5.1,
        ),
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
      ),
    ];
  }

  Future<void> _loadMockEvents() async {
    final now = DateTime.now();
    
    _events = [
      Event(
        id: 'event_1',
        title: 'Digital Metamorphosis: AR Art Exhibition',
        description: 'Experience cutting-edge augmented reality artworks that blend physical and digital realms.',
        type: EventType.exhibition,
        category: EventCategory.digital,
        institutionId: 'inst_1',
        institution: _institutions.isNotEmpty ? _institutions.first : null,
        startDate: now.add(const Duration(days: 7)),
        endDate: now.add(const Duration(days: 30)),
        location: 'Modern Gallery Ljubljana',
        latitude: 46.0514,
        longitude: 14.5060,
        price: 15.0,
        capacity: 200,
        currentAttendees: 127,
        isPublic: true,
        allowRegistration: true,
        imageUrls: ['https://example.com/event1.jpg'],
        featuredArtworkIds: ['art_1', 'art_2'],
        artistIds: ['artist_1', 'artist_2'],
        createdAt: now.subtract(const Duration(days: 20)),
        createdBy: 'inst_1',
      ),
      Event(
        id: 'event_2',
        title: 'Sculpture Symposium: Stone & Soul',
        description: 'Interactive workshops and exhibitions featuring contemporary sculpture techniques.',
        type: EventType.workshop,
        category: EventCategory.sculpture,
        institutionId: 'inst_2',
        institution: _institutions.length > 1 ? _institutions[1] : null,
        startDate: now.add(const Duration(days: 14)),
        endDate: now.add(const Duration(days: 21)),
        location: 'National Gallery of Slovenia',
        latitude: 46.0498,
        longitude: 14.5037,
        price: 25.0,
        capacity: 50,
        currentAttendees: 32,
        isPublic: true,
        allowRegistration: true,
        imageUrls: ['https://example.com/event2.jpg'],
        featuredArtworkIds: ['art_3', 'art_4'],
        artistIds: ['artist_3'],
        createdAt: now.subtract(const Duration(days: 15)),
        createdBy: 'inst_2',
      ),
      Event(
        id: 'event_3',
        title: 'Photography Collective: Urban Visions',
        description: 'A group exhibition showcasing the diverse perspectives of urban photography.',
        type: EventType.exhibition,
        category: EventCategory.photography,
        institutionId: 'inst_3',
        institution: _institutions.length > 2 ? _institutions[2] : null,
        startDate: now.add(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 28)),
        location: 'Jakopič Gallery',
        latitude: 46.0569,
        longitude: 14.5058,
        price: null, // Free event
        capacity: 150,
        currentAttendees: 89,
        isPublic: true,
        allowRegistration: true,
        imageUrls: ['https://example.com/event3.jpg'],
        featuredArtworkIds: ['art_5', 'art_6'],
        artistIds: ['artist_4', 'artist_5'],
        createdAt: now.subtract(const Duration(days: 10)),
        createdBy: 'inst_3',
      ),
    ];
  }

  Future<void> _loadFromIPFS() async {
    // TODO: Implement IPFS loading
    _institutions = [];
    _events = [];
  }

  // Event management
  List<Event> getEventsByInstitution(String institutionId) {
    return _events.where((event) => event.institutionId == institutionId).toList();
  }

  List<Event> getUpcomingEvents() {
    final now = DateTime.now();
    return _events.where((event) => event.startDate.isAfter(now)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  List<Event> getActiveEvents() {
    return _events.where((event) => event.isActive).toList();
  }

  List<Event> getEventsByCategory(EventCategory category) {
    return _events.where((event) => event.category == category).toList();
  }

  Future<void> createEvent(Event event) async {
    if (_mockupDataProvider.isMockDataEnabled) {
      _events.add(event);
      notifyListeners();
    } else {
      // TODO: Save to IPFS/blockchain
    }
  }

  Future<void> updateEvent(Event event) async {
    if (_mockupDataProvider.isMockDataEnabled) {
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = event;
        notifyListeners();
      }
    } else {
      // TODO: Update on IPFS/blockchain
    }
  }

  Future<void> deleteEvent(String eventId) async {
    if (_mockupDataProvider.isMockDataEnabled) {
      _events.removeWhere((event) => event.id == eventId);
      notifyListeners();
    } else {
      // TODO: Delete from IPFS/blockchain
    }
  }

  Future<void> registerForEvent(String eventId, String userId) async {
    final event = _events.firstWhere((e) => e.id == eventId);
    if (event.hasCapacity && event.allowRegistration) {
      // TODO: Implement registration logic
      notifyListeners();
    }
  }

  // Institution management
  void selectInstitution(Institution? institution) {
    _selectedInstitution = institution;
    notifyListeners();
  }

  void selectEvent(Event? event) {
    _selectedEvent = event;
    notifyListeners();
  }

  Future<void> createInstitution(Institution institution) async {
    if (_mockupDataProvider.isMockDataEnabled) {
      _institutions.add(institution);
      notifyListeners();
    } else {
      // TODO: Save to IPFS/blockchain
    }
  }

  Future<void> updateInstitution(Institution institution) async {
    if (_mockupDataProvider.isMockDataEnabled) {
      final index = _institutions.indexWhere((i) => i.id == institution.id);
      if (index != -1) {
        _institutions[index] = institution;
        notifyListeners();
      }
    } else {
      // TODO: Update on IPFS/blockchain
    }
  }

  Institution? getInstitutionById(String id) {
    try {
      return _institutions.firstWhere((institution) => institution.id == id);
    } catch (e) {
      return null;
    }
  }

  // Analytics methods
  Map<String, dynamic> getInstitutionAnalytics(String institutionId) {
    final institution = getInstitutionById(institutionId);
    if (institution == null) return {};

    final institutionEvents = getEventsByInstitution(institutionId);
    
    return {
      'totalVisitors': institution.stats.totalVisitors,
      'activeEvents': institution.stats.activeEvents,
      'artworkViews': institution.stats.artworkViews,
      'revenue': institution.stats.revenue,
      'visitorGrowth': institution.stats.visitorGrowth,
      'revenueGrowth': institution.stats.revenueGrowth,
      'totalEvents': institutionEvents.length,
      'upcomingEvents': institutionEvents.where((e) => e.isUpcoming).length,
      'activeEventsCount': institutionEvents.where((e) => e.isActive).length,
    };
  }

  Future<void> refreshData() async {
    await _loadData();
  }
}
