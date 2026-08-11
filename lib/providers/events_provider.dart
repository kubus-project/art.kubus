import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/exhibition.dart';
import '../services/backend_api_service.dart';
import '../services/profile_package_mutation_tracker.dart';
import '../services/telemetry/contribution_type.dart';
import '../services/telemetry/telemetry_service.dart';

class EventsProvider extends ChangeNotifier {
  final BackendApiService _api;
  final TelemetryService _telemetry;

  EventsProvider({BackendApiService? api, TelemetryService? telemetry})
      : _api = api ?? BackendApiService(),
        _telemetry = telemetry ?? TelemetryService();

  final List<KubusEvent> _events = <KubusEvent>[];
  final Map<String, KubusEvent> _byId = <String, KubusEvent>{};

  /// Ids whose cached entry came from a detail endpoint rather than a list
  /// page. List payloads omit detail-only fields, so callers that need the full
  /// record must still fetch even though `_byId` already has an entry.
  final Set<String> _detailHydratedIds = <String>{};
  final Map<String, List<Exhibition>> _exhibitionsByEventId =
      <String, List<Exhibition>>{};
  final Map<String, EventPoapStatus> _poapByEventId =
      <String, EventPoapStatus>{};

  // Operation-specific flags so POAP/relation work never reads as a
  // page-level load and never blocks save buttons.
  bool _isListLoading = false;
  bool _isDetailLoading = false;
  bool _isMutating = false;
  bool _isRelationSyncing = false;
  bool _isPoapLoading = false;
  bool _isPoapClaiming = false;

  String? _error;
  bool _initialized = false;
  KubusEvent? _selected;

  List<KubusEvent> get events => List.unmodifiable(_events);
  KubusEvent? get selectedEvent => _selected;
  KubusEvent? eventById(String id) => _byId[id.trim()];

  /// Whether [eventById] would return a detail-loaded record for [id].
  bool isEventDetailHydrated(String id) =>
      _detailHydratedIds.contains(id.trim());

  bool get isListLoading => _isListLoading;
  bool get isDetailLoading => _isDetailLoading;
  bool get isMutating => _isMutating;
  bool get isRelationSyncing => _isRelationSyncing;
  bool get isPoapLoading => _isPoapLoading;
  bool get isPoapClaiming => _isPoapClaiming;

  /// Backward-compatible page-level loading (initial/detail loads only).
  bool get isLoading => _isListLoading || _isDetailLoading;

  String? get error => _error;
  bool get initialized => _initialized;

  List<Exhibition> exhibitionsForEvent(String eventId) {
    return List.unmodifiable(
        _exhibitionsByEventId[eventId] ?? const <Exhibition>[]);
  }

  EventPoapStatus? poapStatusFor(String eventId) => _poapByEventId[eventId];

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
    _setFlag(_Flag.list, true);
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
        _detailHydratedIds.clear();
      } else {
        for (final ev in next) {
          _upsertEvent(ev, notify: false, detailHydrated: false);
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setFlag(_Flag.list, false);
    }
  }

  Future<KubusEvent?> fetchEvent(String id, {bool force = false}) async {
    // A list-cache entry is not a substitute for the detail payload: only skip
    // the request when this id was already loaded from the detail endpoint.
    if (!force && _detailHydratedIds.contains(id.trim())) {
      return _byId[id.trim()];
    }

    _setFlag(_Flag.detail, true);
    _error = null;
    try {
      final event = await _api.getEvent(id);
      if (event != null) {
        _upsertEvent(event, notify: false, detailHydrated: true);
        notifyListeners();
      }
      return event;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.detail, false);
    }
  }

  Future<void> recordEventView(String id, {String? source}) async {
    if (id.trim().isEmpty) return;
    try {
      await _api.recordEventView(id, source: source);
    } catch (_) {}
  }

  void selectEvent(String? eventId) {
    if (eventId == null) {
      _selected = null;
    } else {
      _selected = _byId[eventId];
    }
    notifyListeners();
  }

  /// Creates an event. This is the domain success boundary for the contribution
  /// funnel, instrumented here rather than in `EventCreator` so every caller is
  /// measured and the UI keeps no telemetry knowledge.
  ///
  /// Exhibition links and POAP synchronisation run after this returns and are
  /// explicitly not required for the event to count as created — an event with
  /// a failed POAP sync is still an event the member published.
  Future<KubusEvent?> createEvent(Map<String, dynamic> payload) async {
    _setFlag(_Flag.mutating, true);
    _error = null;
    _noteContributionStarted();
    try {
      final created = await _api.createEvent(payload);
      // A successful envelope without an event identity is not a confirmed
      // durable creation. In particular, it must not advance campaign
      // activation while an API rollout or malformed response is investigated.
      if (created != null && created.id.trim().isNotEmpty) {
        _upsertEvent(created, notify: false, detailHydrated: true);
        _selected = created;
        ProfilePackageMutationTracker.eventChanged(
          created,
          kind: ProfilePackageMutationKind.eventCreated,
        );
        _noteContributionPublished();
        notifyListeners();
      }
      return created?.id.trim().isNotEmpty == true ? created : null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.mutating, false);
    }
  }

  /// Telemetry is fire-and-forget so an unavailable queue or sender can never
  /// fail an event the backend already created.
  void _noteContributionStarted() {
    unawaited(
      _telemetry
          .trackContributionStarted(type: ContributionType.event)
          .catchError((_) {}),
    );
  }

  void _noteContributionPublished() {
    unawaited(
      _telemetry
          .trackSuccessfulContribution(ContributionType.event)
          .catchError((_) {}),
    );
  }

  /// Editing an existing event is not a new contribution, so it emits nothing:
  /// activation counts things brought into existence, and a member who renames
  /// last month's opening has not activated again.
  Future<KubusEvent?> updateEvent(
      String id, Map<String, dynamic> updates) async {
    _setFlag(_Flag.mutating, true);
    _error = null;
    try {
      final updated = await _api.updateEvent(id, updates);
      if (updated != null) {
        _upsertEvent(updated, notify: false, detailHydrated: true);
        if (_selected?.id == id) _selected = updated;
        ProfilePackageMutationTracker.eventChanged(updated);
        notifyListeners();
      }
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.mutating, false);
    }
  }

  Future<void> deleteEvent(String id) async {
    _setFlag(_Flag.mutating, true);
    _error = null;
    try {
      await _api.deleteEvent(id);
      final previous = _byId[id];
      _events.removeWhere((e) => e.id == id);
      _byId.remove(id);
      _detailHydratedIds.remove(id.trim());
      _exhibitionsByEventId.remove(id);
      _poapByEventId.remove(id);
      if (_selected?.id == id) _selected = null;
      if (previous != null) {
        ProfilePackageMutationTracker.eventChanged(
          previous,
          kind: ProfilePackageMutationKind.eventDeleted,
        );
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.mutating, false);
    }
  }

  Future<List<Exhibition>> loadEventExhibitions(
    String eventId, {
    bool refresh = true,
    int limit = 50,
    int offset = 0,
  }) async {
    _setFlag(_Flag.relation, true);
    try {
      final list = await _api.listEventExhibitions(eventId,
          limit: limit, offset: offset);
      if (refresh) {
        _exhibitionsByEventId[eventId] = list;
      } else {
        final existing = _exhibitionsByEventId[eventId] ?? <Exhibition>[];
        _exhibitionsByEventId[eventId] = <Exhibition>[...existing, ...list];
      }
      notifyListeners();
      return list;
    } catch (e) {
      debugPrint('EventsProvider.loadEventExhibitions failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<void> linkEventExhibitions(
    String eventId,
    List<String> exhibitionIds, {
    String? relationType,
  }) async {
    _setFlag(_Flag.relation, true);
    try {
      await _api.linkEventExhibitions(
        eventId,
        exhibitionIds,
        relationType: relationType,
      );
      await loadEventExhibitions(eventId, refresh: true);
    } catch (e) {
      debugPrint('EventsProvider.linkEventExhibitions failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<void> unlinkEventExhibition(
      String eventId, String exhibitionId) async {
    _setFlag(_Flag.relation, true);
    try {
      await _api.unlinkEventExhibition(eventId, exhibitionId);
      final existing = _exhibitionsByEventId[eventId];
      if (existing != null) {
        _exhibitionsByEventId[eventId] =
            existing.where((e) => e.id != exhibitionId).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('EventsProvider.unlinkEventExhibition failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<EventPoapStatus?> fetchEventPoap(String eventId,
      {bool force = false}) async {
    if (!force && _poapByEventId.containsKey(eventId)) {
      return _poapByEventId[eventId];
    }

    _setFlag(_Flag.poapLoading, true);
    try {
      final status = await _api.getEventPoap(eventId);
      if (status != null) {
        _poapByEventId[eventId] = status;
        notifyListeners();
      }
      return status;
    } catch (e) {
      debugPrint('EventsProvider.fetchEventPoap failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.poapLoading, false);
    }
  }

  Future<EventPoapStatus?> claimEventPoap(
    String eventId, {
    String? attendanceMarkerId,
    String? claimProofToken,
    String? proofSource,
  }) async {
    _setFlag(_Flag.poapClaiming, true);
    try {
      final status = await _api.claimEventPoap(
        eventId,
        attendanceMarkerId: attendanceMarkerId,
        claimProofToken: claimProofToken,
        proofSource: proofSource,
      );
      if (status != null) {
        _poapByEventId[eventId] = status;
        notifyListeners();
      }
      return status;
    } catch (e) {
      debugPrint('EventsProvider.claimEventPoap failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.poapClaiming, false);
    }
  }

  /// Creator-side POAP badge configuration (enable/update/disable).
  Future<void> upsertEventPoap(
      String eventId, Map<String, dynamic> payload) async {
    _setFlag(_Flag.relation, true);
    try {
      await _api.upsertEventPoap(eventId, payload);
      try {
        await fetchEventPoap(eventId, force: true);
      } catch (_) {
        _poapByEventId.remove(eventId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('EventsProvider.upsertEventPoap failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  /// [detailHydrated] records whether [event] carries the detail payload.
  /// `null` keeps whatever the cached entry was already marked as, for callers
  /// that patch an existing record in place.
  void _upsertEvent(
    KubusEvent event, {
    bool notify = true,
    bool? detailHydrated,
  }) {
    _byId[event.id] = event;
    if (detailHydrated == true) {
      _detailHydratedIds.add(event.id.trim());
    } else if (detailHydrated == false) {
      _detailHydratedIds.remove(event.id.trim());
    }
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      _events[idx] = event;
    } else {
      _events.add(event);
    }
    if (notify) notifyListeners();
  }

  void _setFlag(_Flag flag, bool next) {
    bool changed = false;
    switch (flag) {
      case _Flag.list:
        changed = _isListLoading != next;
        _isListLoading = next;
        break;
      case _Flag.detail:
        changed = _isDetailLoading != next;
        _isDetailLoading = next;
        break;
      case _Flag.mutating:
        changed = _isMutating != next;
        _isMutating = next;
        break;
      case _Flag.relation:
        changed = _isRelationSyncing != next;
        _isRelationSyncing = next;
        break;
      case _Flag.poapLoading:
        changed = _isPoapLoading != next;
        _isPoapLoading = next;
        break;
      case _Flag.poapClaiming:
        changed = _isPoapClaiming != next;
        _isPoapClaiming = next;
        break;
    }
    if (changed) notifyListeners();
  }
}

enum _Flag {
  list,
  detail,
  mutating,
  relation,
  poapLoading,
  poapClaiming,
}
