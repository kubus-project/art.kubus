import 'package:flutter/foundation.dart';
import '../models/institution.dart';
import '../services/backend_api_service.dart';

class InstitutionProvider extends ChangeNotifier {
  List<Institution> _institutions = [];
  List<Event> _events = [];
  Institution? _selectedInstitution;
  Event? _selectedEvent;
  bool _isLoading = false;

  InstitutionProvider() {
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
      await _loadFromBackend();
    } catch (e) {
      debugPrint('Error loading institution data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromBackend() async {
    try {
      final api = BackendApiService();

      final institutionsJson = await api.listInstitutions(limit: 100, offset: 0);
      _institutions = institutionsJson.map((e) => Institution.fromJson(e)).toList();

      // Fetch events globally; if backend prefers per-institution, this is still fine
      final eventsJson = await api.listEvents(limit: 200, offset: 0);
      _events = eventsJson.map((e) => Event.fromJson(e)).toList();
    } catch (e) {
      debugPrint('InstitutionProvider _loadFromBackend error: $e');
      _institutions = [];
      _events = [];
    }
  }

  // Local mock institution/event loaders removed to ensure backend-driven data only

  // ignore: unused_element
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
    // TODO: Save to backend/IPFS/blockchain
    notifyListeners();
  }

  Future<void> updateEvent(Event event) async {
    // TODO: Update on backend/IPFS/blockchain
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String eventId) async {
    // TODO: Delete from backend/IPFS/blockchain
    _events.removeWhere((event) => event.id == eventId);
    notifyListeners();
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
    // TODO: Save to backend/IPFS/blockchain
    _institutions.add(institution);
    notifyListeners();
  }

  Future<void> updateInstitution(Institution institution) async {
    // TODO: Update on backend/IPFS/blockchain
    final index = _institutions.indexWhere((i) => i.id == institution.id);
    if (index != -1) {
      _institutions[index] = institution;
      notifyListeners();
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
