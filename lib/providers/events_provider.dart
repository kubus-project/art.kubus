import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/exhibition.dart';
import '../services/backend_api_service.dart';

class EventsProvider extends ChangeNotifier {
  final BackendApiService _api;

  EventsProvider({BackendApiService? api}) : _api = api ?? BackendApiService();

  final List<KubusEvent> _events = <KubusEvent>[];
  final Map<String, KubusEvent> _byId = <String, KubusEvent>{};
  final Map<String, List<Exhibition>> _exhibitionsByEventId = <String, List<Exhibition>>{};

  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  KubusEvent? _selected;

  List<KubusEvent> get events => List.unmodifiable(_events);
  KubusEvent? get selectedEvent => _selected;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;

  List<Exhibition> exhibitionsForEvent(String eventId) {
    return List.unmodifiable(_exhibitionsByEventId[eventId] ?? const <Exhibition>[]);
  }

  Future<void> initialize({bool refresh = false}) async {
    if (_initialized && !refresh) return;
    _initialized = true;
    await loadEvents(refresh: true);
  }

  Future<void> loadEvents({
    bool refresh = false,
    String? from,
    String? to,
    double? lat,
    double? lng,
    double? radiusKm,
    String? hostUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final raw = await _api.listEvents(
        from: from,
        to: to,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        hostUserId: hostUserId,
        limit: limit,
        offset: offset,
      );
      final next = raw.map((e) => KubusEvent.fromJson(e)).toList();
      if (refresh) {
        _events
          ..clear()
          ..addAll(next);
        _byId
          ..clear()
          ..addEntries(next.map((e) => MapEntry(e.id, e)));
      } else {
        for (final ev in next) {
          _upsertEvent(ev, notify: false);
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<KubusEvent?> fetchEvent(String id, {bool force = false}) async {
    if (!force && _byId.containsKey(id)) return _byId[id];

    _setLoading(true);
    _error = null;
    try {
      final event = await _api.getEvent(id);
      if (event != null) {
        _upsertEvent(event, notify: false);
        notifyListeners();
      }
      return event;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void selectEvent(String? eventId) {
    if (eventId == null) {
      _selected = null;
    } else {
      _selected = _byId[eventId];
    }
    notifyListeners();
  }

  Future<KubusEvent?> createEvent(Map<String, dynamic> payload) async {
    _setLoading(true);
    _error = null;
    try {
      final created = await _api.createEvent(payload);
      if (created != null) {
        _upsertEvent(created, notify: false);
        _selected = created;
        notifyListeners();
      }
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<KubusEvent?> updateEvent(String id, Map<String, dynamic> updates) async {
    _setLoading(true);
    _error = null;
    try {
      final updated = await _api.updateEvent(id, updates);
      if (updated != null) {
        _upsertEvent(updated, notify: false);
        if (_selected?.id == id) _selected = updated;
        notifyListeners();
      }
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteEvent(String id) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.deleteEvent(id);
      _events.removeWhere((e) => e.id == id);
      _byId.remove(id);
      _exhibitionsByEventId.remove(id);
      if (_selected?.id == id) _selected = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Exhibition>> loadEventExhibitions(
    String eventId, {
    bool refresh = true,
    int limit = 50,
    int offset = 0,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final list = await _api.listEventExhibitions(eventId, limit: limit, offset: offset);
      if (refresh) {
        _exhibitionsByEventId[eventId] = list;
      } else {
        final existing = _exhibitionsByEventId[eventId] ?? <Exhibition>[];
        _exhibitionsByEventId[eventId] = <Exhibition>[...existing, ...list];
      }
      notifyListeners();
      return list;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _upsertEvent(KubusEvent event, {bool notify = true}) {
    _byId[event.id] = event;
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      _events[idx] = event;
    } else {
      _events.add(event);
    }
    if (notify) notifyListeners();
  }

  void _setLoading(bool next) {
    if (_isLoading == next) return;
    _isLoading = next;
    notifyListeners();
  }
}
