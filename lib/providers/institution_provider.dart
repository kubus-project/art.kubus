import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/institution.dart';
import '../services/account_identity.dart';
import '../services/backend_api_service.dart';
import '../services/institution_storage.dart';

class InstitutionProvider extends ChangeNotifier {
  final InstitutionStorage _storage = InstitutionStorage();

  List<Institution> _institutions = [];
  List<Event> _events = [];
  Institution? _selectedInstitution;
  Event? _selectedEvent;
  bool _isLoading = false;
  bool _initialized = false;

  InstitutionProvider() {
    AccountIdentity.addListener(_handleAccountIdentityChanged);
  }

  // Bumped on every identity change, so a load that started under an earlier
  // account is discarded when it lands.
  int _accountEpoch = 0;

  void _handleAccountIdentityChanged() => clearAccountScopedState();

  /// Drops the institutions and events held in memory for the account that
  /// just signed out. The device storage they came from is purged on the same
  /// change, and the next [initialize] rebuilds the lists from the public read.
  void clearAccountScopedState() {
    final wasInitialized = _initialized;
    _accountEpoch += 1;
    final epoch = _accountEpoch;
    _institutions = [];
    _events = [];
    _selectedInstitution = null;
    _selectedEvent = null;
    _isLoading = false;
    notifyListeners();
    if (wasInitialized) {
      // Screens read these lists without loading them, so the public lists are
      // requested again for the account now in use.
      unawaited(_reloadPublicLists(epoch));
    }
  }

  /// Requests the public institution and event lists again. The device storage
  /// is not read here: it is purged on the same identity change and may still
  /// hold the previous account's records when this runs.
  Future<void> _reloadPublicLists(int epoch) async {
    await _tryLoadFromBackendAndPersist(epoch);
  }

  // Getters
  List<Institution> get institutions =>
      List.unmodifiable(_mergedInstitutions());
  List<Event> get events => List.unmodifiable(
      _events.map(_hydrateEventInstitution).toList(growable: false));
  Institution? get selectedInstitution {
    final selected = _selectedInstitution;
    if (selected == null) return null;
    return getInstitutionById(selected.id) ?? selected;
  }

  Event? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;

  Institution? getInstitutionById(String id) {
    final target = id.trim();
    if (target.isEmpty) return null;
    try {
      return institutions.firstWhere((i) => i.id == target);
    } catch (_) {
      return null;
    }
  }

  // Institution methods
  Future<void> initialize({bool seedMockIfEmpty = false}) async {
    if (_initialized) return;
    _initialized = true;
    await _loadData(seedMockIfEmpty: seedMockIfEmpty, tryBackend: true);
  }

  Future<void> _loadData(
      {required bool seedMockIfEmpty, required bool tryBackend}) async {
    final epoch = _accountEpoch;
    _isLoading = true;
    notifyListeners();

    try {
      // Load local cache first for instant UI and offline mode.
      final localInstitutions = await _storage.loadInstitutions();
      final localEvents = await _storage.loadEvents();
      // Read for an account that has since signed out: nothing is kept.
      if (epoch != _accountEpoch) return;
      _institutions = localInstitutions;
      _events = localEvents;

      if (_institutions.isEmpty && seedMockIfEmpty) {
        _seedMockData();
        await _persist();
      }

      if (tryBackend) {
        await _tryLoadFromBackendAndPersist(epoch);
      }
      if (epoch != _accountEpoch) return;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('InstitutionProvider: Error loading institution data: $e');
      }
    } finally {
      // A stale load must not clear the loading flag of a newer one.
      if (epoch == _accountEpoch) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _tryLoadFromBackendAndPersist(int epoch) async {
    try {
      final api = BackendApiService();

      final institutionsJson =
          await api.listInstitutions(limit: 100, offset: 0);
      final nextInstitutions =
          institutionsJson.map((e) => Institution.fromJson(e)).toList();

      // Fetch events globally; backend validates limit max=100, so request max allowed.
      final eventsJson = await api.listEvents(limit: 100, offset: 0);
      final nextEvents = eventsJson
          .map(_eventFromBackendJson)
          .where((e) => e.id.isNotEmpty)
          .toList();
      // A response for an account that has since signed out is not kept.
      if (epoch != _accountEpoch) return;

      // If backend endpoints are unavailable (404) the API returns empty lists.
      // Only overwrite local state when the backend returns real data.
      if (nextInstitutions.isNotEmpty || nextEvents.isNotEmpty) {
        if (nextInstitutions.isNotEmpty) {
          _institutions = nextInstitutions;
        }
        if (nextEvents.isNotEmpty) {
          _events = nextEvents;
        }
        await _persist();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('InstitutionProvider: backend load failed (ignored): $e');
      }
    }
  }

  Event _eventFromBackendJson(Map<String, dynamic> json) {
    final institutionId = (json['institutionId'] ??
            json['institution_id'] ??
            (json['institution'] is Map ? json['institution']['id'] : null) ??
            '')
        .toString()
        .trim();
    final institution =
        institutionId.isEmpty ? null : getInstitutionById(institutionId);
    return Event.fromBackendJson(json, institution: institution);
  }

  void _seedMockData() {
    final now = DateTime.now();

    _institutions = [
      Institution(
        id: 'inst_demo_1',
        name: 'kubus Contemporary',
        description:
            'A digital-first gallery exploring AR-native installations and generative work.',
        type: 'gallery',
        address: 'Central District',
        latitude: 52.2297,
        longitude: 21.0122,
        contactEmail: 'hello@kubus.site',
        website: 'https://art.kubus.site',
        stats: InstitutionStats(
          totalVisitors: 1200,
          activeEvents: 1,
          artworkViews: 8450,
          revenue: 12500,
          visitorGrowth: 0.12,
          revenueGrowth: 0.08,
        ),
        isVerified: true,
        createdAt: now.subtract(const Duration(days: 180)),
      ),
    ];

    _events = [
      Event(
        id: 'evt_demo_1',
        title: 'Digital Dreams Exhibition',
        description:
            'A curated showcase of contemporary digital art from emerging artists.',
        type: EventType.exhibition,
        category: EventCategory.digital,
        institutionId: 'inst_demo_1',
        institution: _institutions.first,
        startDate: now.add(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 10)),
        location: 'Main Gallery',
        latitude: 52.2297,
        longitude: 21.0122,
        price: 25.0,
        capacity: 200,
        currentAttendees: 156,
        isPublic: true,
        allowRegistration: true,
        featuredArtworkIds: const [],
        artistIds: const [],
        createdAt: now.subtract(const Duration(days: 7)),
        createdBy: 'system',
      ),
      Event(
        id: 'evt_demo_2',
        title: 'Modern Art Workshop',
        description:
            'Hands-on workshop on modern art techniques and AR presentation.',
        type: EventType.workshop,
        category: EventCategory.mixedMedia,
        institutionId: 'inst_demo_1',
        institution: _institutions.first,
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 1)),
        location: 'Workshop Room A',
        latitude: 52.2297,
        longitude: 21.0122,
        price: 50.0,
        capacity: 30,
        currentAttendees: 28,
        isPublic: true,
        allowRegistration: true,
        featuredArtworkIds: const [],
        artistIds: const [],
        createdAt: now.subtract(const Duration(days: 14)),
        createdBy: 'system',
      ),
      Event(
        id: 'evt_demo_3',
        title: 'Artist Talk Series',
        description: 'Monthly talk with contemporary artists and collectors.',
        type: EventType.conference,
        category: EventCategory.art,
        institutionId: 'inst_demo_1',
        institution: _institutions.first,
        startDate: now.add(const Duration(days: 15)),
        endDate: now.add(const Duration(days: 15, hours: 2)),
        location: 'Auditorium',
        latitude: 52.2297,
        longitude: 21.0122,
        price: 15.0,
        capacity: 100,
        currentAttendees: 67,
        isPublic: true,
        allowRegistration: true,
        featuredArtworkIds: const [],
        artistIds: const [],
        createdAt: now.subtract(const Duration(days: 30)),
        createdBy: 'system',
      ),
    ];
  }

  Future<void> _persist() async {
    await _storage.saveInstitutions(_institutions);
    await _storage.saveEvents(_events);
  }

  // Institutions come only from the backend (and its device cache). A listing is
  // never fabricated from a wallet or a profile flag: authority over a listing is
  // an institution membership, read from AccountVerificationProvider.
  List<Institution> _mergedInstitutions() =>
      List<Institution>.from(_institutions);

  Event _hydrateEventInstitution(Event event) {
    final institution = getInstitutionById(event.institutionId);
    if (institution == null ||
        _institutionsEqual(event.institution, institution)) {
      return event;
    }
    return event.copyWith(institution: institution);
  }

  bool _institutionsEqual(Institution? a, Institution? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;

    return a.id == b.id &&
        a.name == b.name &&
        a.description == b.description &&
        a.type == b.type &&
        a.address == b.address &&
        a.latitude == b.latitude &&
        a.longitude == b.longitude &&
        a.contactEmail == b.contactEmail &&
        a.website == b.website &&
        a.coverImageUrl == b.coverImageUrl &&
        a.logoUrl == b.logoUrl &&
        a.logoAttribution == b.logoAttribution &&
        a.coverAttribution == b.coverAttribution &&
        a.visitorAccess == b.visitorAccess &&
        listEquals(a.disciplines, b.disciplines) &&
        a.stats.totalVisitors == b.stats.totalVisitors &&
        a.stats.activeEvents == b.stats.activeEvents &&
        a.stats.artworkViews == b.stats.artworkViews &&
        a.stats.revenue == b.stats.revenue &&
        a.stats.visitorGrowth == b.stats.visitorGrowth &&
        a.stats.revenueGrowth == b.stats.revenueGrowth &&
        a.isVerified == b.isVerified &&
        a.createdAt == b.createdAt;
  }

  // Event management
  List<Event> getEventsByInstitution(String institutionId) {
    return events
        .where((event) => event.institutionId == institutionId)
        .toList();
  }

  List<Event> getUpcomingEvents() {
    final now = DateTime.now();
    return events.where((event) => event.startDate.isAfter(now)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  List<Event> getActiveEvents() {
    return events.where((event) => event.isActive).toList();
  }

  List<Event> getEventsByCategory(EventCategory category) {
    return events.where((event) => event.category == category).toList();
  }

  Future<void> createEvent(Event event) async {
    // Events are persisted locally only. Backend endpoints for event management
    // may not be available or fully implemented. Always treat event mutations
    // as local-only unless explicitly wired to backend endpoints.
    _events.add(event);
    await _storage.saveEvents(_events);
    notifyListeners();
  }

  Future<void> updateEvent(Event event) async {
    // Events are persisted locally only. Backend endpoints for event management
    // may not be available or fully implemented. Always treat event mutations
    // as local-only unless explicitly wired to backend endpoints.
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
      await _storage.saveEvents(_events);
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String eventId) async {
    // Events are persisted locally only. Backend endpoints for event management
    // may not be available or fully implemented. Always treat event mutations
    // as local-only unless explicitly wired to backend endpoints.
    _events.removeWhere((event) => event.id == eventId);
    if (_selectedEvent?.id == eventId) {
      _selectedEvent = null;
    }
    await _storage.saveEvents(_events);
    notifyListeners();
  }

  Future<void> registerForEvent(String eventId, String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    final index = _events.indexWhere((e) => e.id == eventId);
    if (index == -1) {
      throw StateError('Event not found');
    }
    final event = _events[index];
    if (event.hasCapacity && event.allowRegistration) {
      final registrations =
          await _storage.loadRegistrationsForUser(normalizedUserId);
      if (registrations.contains(eventId)) return;

      registrations.add(eventId);
      await _storage.saveRegistrationsForUser(normalizedUserId, registrations);

      _events[index] =
          event.copyWith(currentAttendees: event.currentAttendees + 1);
      await _storage.saveEvents(_events);
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
    _institutions.add(institution);
    await _storage.saveInstitutions(_institutions);
    notifyListeners();
  }

  Future<void> updateInstitution(Institution institution) async {
    final index = _institutions.indexWhere((i) => i.id == institution.id);
    if (index != -1) {
      _institutions[index] = institution;
      await _storage.saveInstitutions(_institutions);
      notifyListeners();
    }
  }

  Future<void> deleteInstitution(String institutionId) async {
    _institutions.removeWhere((institution) => institution.id == institutionId);
    _events.removeWhere((event) => event.institutionId == institutionId);
    if (_selectedInstitution?.id == institutionId) {
      _selectedInstitution = null;
    }
    if (_selectedEvent?.institutionId == institutionId) {
      _selectedEvent = null;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> refreshData() async {
    await _loadData(seedMockIfEmpty: false, tryBackend: true);
  }

  @override
  void dispose() {
    AccountIdentity.removeListener(_handleAccountIdentityChanged);
    super.dispose();
  }
}
