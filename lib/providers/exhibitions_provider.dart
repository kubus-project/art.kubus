import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../models/exhibition.dart';
import '../services/backend_api_service.dart';

class ExhibitionsProvider extends ChangeNotifier {
  final BackendApiService _api;

  ExhibitionsProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  final List<Exhibition> _exhibitions = <Exhibition>[];
  final List<Exhibition> _myExhibitions = <Exhibition>[];
  final Map<String, Exhibition> _byId = <String, Exhibition>{};
  final Map<String, ExhibitionPoapStatus> _poapByExhibitionId =
      <String, ExhibitionPoapStatus>{};
  final Map<String, List<KubusEvent>> _programEventsByExhibitionId =
      <String, List<KubusEvent>>{};

  // Operation-specific loading flags. A POAP fetch or a relation sync must
  // never look like a full-page load, and a background sync must never lock
  // the editor's save button.
  bool _isListLoading = false;
  bool _isDetailLoading = false;
  bool _isMutating = false;
  bool _isUploadingCover = false;
  bool _isRelationSyncing = false;
  bool _isPoapLoading = false;
  bool _isPoapClaiming = false;
  bool _isMyExhibitionsLoading = false;

  String? _error;
  bool _initialized = false;
  Exhibition? _selected;

  List<Exhibition> get exhibitions => List.unmodifiable(_exhibitions);
  List<Exhibition> get myExhibitions => List.unmodifiable(_myExhibitions);
  Exhibition? get selectedExhibition => _selected;

  bool get isListLoading => _isListLoading;
  bool get isDetailLoading => _isDetailLoading;
  bool get isMutating => _isMutating;
  bool get isUploadingCover => _isUploadingCover;
  bool get isRelationSyncing => _isRelationSyncing;
  bool get isPoapLoading => _isPoapLoading;
  bool get isPoapClaiming => _isPoapClaiming;
  bool get isMyExhibitionsLoading => _isMyExhibitionsLoading;

  /// Backward-compatible page-level loading (initial/detail loads only).
  bool get isLoading => _isListLoading || _isDetailLoading;

  String? get error => _error;
  bool get initialized => _initialized;

  ExhibitionPoapStatus? poapStatusFor(String exhibitionId) =>
      _poapByExhibitionId[exhibitionId];

  List<KubusEvent> programEventsFor(String exhibitionId) => List.unmodifiable(
      _programEventsByExhibitionId[exhibitionId] ?? const <KubusEvent>[]);

  Future<void> initialize({bool refresh = false}) async {
    if (_initialized && !refresh) return;
    _initialized = true;
    await loadExhibitions(refresh: true);
  }

  Future<void> loadExhibitions({
    bool refresh = false,
    bool mine = false,
    String? eventId,
    String? from,
    String? to,
    double? lat,
    double? lng,
    double? radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    _setFlag(mine ? _Flag.myList : _Flag.list, true);
    _error = null;
    try {
      final next = await _api.listExhibitions(
        eventId: eventId,
        mine: mine,
        from: from,
        to: to,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        limit: limit,
        offset: offset,
      );
      if (mine) {
        if (refresh) {
          _myExhibitions
            ..clear()
            ..addAll(next);
        } else {
          final mergedById = <String, Exhibition>{
            for (final exhibition in _myExhibitions) exhibition.id: exhibition,
          };
          for (final exhibition in next) {
            mergedById[exhibition.id] = exhibition;
          }
          _myExhibitions
            ..clear()
            ..addAll(mergedById.values);
        }
      } else if (refresh) {
        _exhibitions
          ..clear()
          ..addAll(next);
        _byId
          ..clear()
          ..addEntries(next.map((e) => MapEntry(e.id, e)));
      } else {
        for (final ex in next) {
          _upsert(ex, notify: false);
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setFlag(mine ? _Flag.myList : _Flag.list, false);
    }
  }

  Future<Exhibition?> fetchExhibition(String id, {bool force = false}) async {
    if (!force && _byId.containsKey(id)) return _byId[id];

    _setFlag(_Flag.detail, true);
    _error = null;
    try {
      final ex = await _api.getExhibition(id);
      if (ex != null) {
        _upsert(ex, notify: false);
        notifyListeners();
      }
      return ex;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.detail, false);
    }
  }

  Future<void> recordExhibitionView(String id, {String? source}) async {
    if (id.trim().isEmpty) return;
    try {
      await _api.recordExhibitionView(id, source: source);
    } catch (_) {}
  }

  void selectExhibition(String? exhibitionId) {
    if (exhibitionId == null) {
      _selected = null;
    } else {
      _selected = _byId[exhibitionId];
    }
    notifyListeners();
  }

  Future<Exhibition?> createExhibition(Map<String, dynamic> payload) async {
    _setFlag(_Flag.mutating, true);
    _error = null;
    try {
      final created = await _api.createExhibition(payload);
      if (created != null) {
        _upsert(created, notify: false);
        _selected = created;
        notifyListeners();
      }
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.mutating, false);
    }
  }

  Future<Exhibition?> updateExhibition(
      String id, Map<String, dynamic> updates) async {
    _setFlag(_Flag.mutating, true);
    _error = null;
    try {
      final updated = await _api.updateExhibition(id, updates);
      if (updated != null) {
        _upsert(updated, notify: false);
        if (_selected?.id == id) _selected = updated;
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

  Future<String?> uploadExhibitionCover({
    required Uint8List bytes,
    required String fileName,
  }) async {
    _setFlag(_Flag.uploadingCover, true);
    _error = null;
    try {
      final result = await _api.uploadFile(
        fileBytes: bytes,
        fileName: fileName,
        fileType: 'exhibition_cover',
        metadata: const <String, String>{
          'folder': 'exhibitions/covers',
        },
      );
      final url = result['uploadedUrl']?.toString();
      return (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.uploadingCover, false);
    }
  }

  Future<void> deleteExhibition(String id) async {
    _setFlag(_Flag.mutating, true);
    _error = null;
    try {
      await _api.deleteExhibition(id);
      _exhibitions.removeWhere((e) => e.id == id);
      _myExhibitions.removeWhere((e) => e.id == id);
      _byId.remove(id);
      _poapByExhibitionId.remove(id);
      _programEventsByExhibitionId.remove(id);
      if (_selected?.id == id) _selected = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.mutating, false);
    }
  }

  Future<void> linkExhibitionArtworks(
      String exhibitionId, List<String> artworkIds) async {
    _setFlag(_Flag.relation, true);
    _error = null;
    try {
      final result =
          await _api.linkExhibitionArtworks(exhibitionId, artworkIds);

      // Update local exhibition immediately so the UI reflects linked artworks
      // even if the backend detail endpoint doesn't yet return artworkIds.
      final payload = (result['data'] is Map<String, dynamic>)
          ? (result['data'] as Map<String, dynamic>)
          : result;

      final addedRaw =
          payload['addedArtworkIds'] ?? payload['added_artwork_ids'];
      final requestedRaw = payload['requestedArtworkIds'] ??
          payload['requested_artwork_ids'] ??
          artworkIds;

      final added = <String>[];
      if (addedRaw is List) {
        for (final v in addedRaw) {
          final s = v?.toString().trim();
          if (s != null && s.isNotEmpty) added.add(s);
        }
      }

      final requested = <String>[];
      if (requestedRaw is List) {
        for (final v in requestedRaw) {
          final s = v?.toString().trim();
          if (s != null && s.isNotEmpty) requested.add(s);
        }
      } else if (requestedRaw is String) {
        final s = requestedRaw.trim();
        if (s.isNotEmpty) requested.add(s);
      }

      final current = _byId[exhibitionId];
      if (current != null) {
        final merged =
            <String>{...current.artworkIds, ...requested, ...added}.toList();
        final updated = current.copyWith(artworkIds: merged);
        _upsert(updated, notify: false);
        if (_selected?.id == exhibitionId) _selected = updated;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<void> unlinkExhibitionArtwork(
      String exhibitionId, String artworkId) async {
    _setFlag(_Flag.relation, true);
    _error = null;
    try {
      await _api.unlinkExhibitionArtwork(exhibitionId, artworkId);

      // Keep UI responsive by updating local cache immediately.
      final current = _byId[exhibitionId];
      if (current != null) {
        final nextIds =
            current.artworkIds.where((id) => id != artworkId).toList();
        final updated = current.copyWith(artworkIds: nextIds);
        _upsert(updated, notify: false);
        if (_selected?.id == exhibitionId) _selected = updated;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<void> linkExhibitionMarkers(
      String exhibitionId, List<String> markerIds) async {
    _setFlag(_Flag.relation, true);
    _error = null;
    try {
      await _api.linkExhibitionMarkers(exhibitionId, markerIds);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<void> unlinkExhibitionMarker(
      String exhibitionId, String markerId) async {
    _setFlag(_Flag.relation, true);
    _error = null;
    try {
      await _api.unlinkExhibitionMarker(exhibitionId, markerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  /// Load the linked program events (exhibition_events + legacy eventId).
  Future<List<KubusEvent>> listExhibitionEvents(
    String exhibitionId, {
    bool refresh = true,
    int limit = 50,
    int offset = 0,
  }) async {
    _setFlag(_Flag.relation, true);
    try {
      final events = await _api.listExhibitionEvents(exhibitionId,
          limit: limit, offset: offset);
      if (refresh) {
        _programEventsByExhibitionId[exhibitionId] = events;
      } else {
        final existing =
            _programEventsByExhibitionId[exhibitionId] ?? <KubusEvent>[];
        _programEventsByExhibitionId[exhibitionId] = <KubusEvent>[
          ...existing,
          ...events,
        ];
      }
      notifyListeners();
      return events;
    } catch (e) {
      debugPrint('ExhibitionsProvider.listExhibitionEvents failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<void> linkExhibitionEvents(
    String exhibitionId,
    List<String> eventIds, {
    String? relationType,
    int? sortOrder,
  }) async {
    _setFlag(_Flag.relation, true);
    try {
      await _api.linkExhibitionEvents(
        exhibitionId,
        eventIds,
        relationType: relationType,
        sortOrder: sortOrder,
      );
      await listExhibitionEvents(exhibitionId, refresh: true);
    } catch (e) {
      debugPrint('ExhibitionsProvider.linkExhibitionEvents failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<void> unlinkExhibitionEvent(
      String exhibitionId, String eventId) async {
    _setFlag(_Flag.relation, true);
    try {
      await _api.unlinkExhibitionEvent(exhibitionId, eventId);
      final existing = _programEventsByExhibitionId[exhibitionId];
      if (existing != null) {
        _programEventsByExhibitionId[exhibitionId] =
            existing.where((e) => e.id != eventId).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ExhibitionsProvider.unlinkExhibitionEvent failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<ExhibitionPoapStatus?> fetchExhibitionPoap(String exhibitionId,
      {bool force = false}) async {
    if (!force && _poapByExhibitionId.containsKey(exhibitionId)) {
      return _poapByExhibitionId[exhibitionId];
    }

    _setFlag(_Flag.poapLoading, true);
    try {
      final status = await _api.getExhibitionPoap(exhibitionId);
      if (status != null) {
        _poapByExhibitionId[exhibitionId] = status;
        notifyListeners();
      }
      return status;
    } catch (e) {
      debugPrint('ExhibitionsProvider.fetchExhibitionPoap failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.poapLoading, false);
    }
  }

  /// Creator-side POAP badge configuration (enable/update/disable).
  Future<void> upsertExhibitionPoap(
      String exhibitionId, Map<String, dynamic> payload) async {
    _setFlag(_Flag.relation, true);
    try {
      await _api.upsertExhibitionPoap(exhibitionId, payload);
      // Refresh cached status so detail pages show the new config.
      try {
        await fetchExhibitionPoap(exhibitionId, force: true);
      } catch (_) {
        _poapByExhibitionId.remove(exhibitionId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ExhibitionsProvider.upsertExhibitionPoap failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.relation, false);
    }
  }

  Future<Map<String, dynamic>?> createScanClaimProof({
    required String exhibitionId,
    required String markerId,
    required String proofSource,
    required String handoffToken,
  }) async {
    try {
      final response = await _api.createScanClaimProof(
        markerId: markerId,
        subjectType: 'exhibition',
        subjectId: exhibitionId,
        proofSource: proofSource,
        handoffToken: handoffToken,
      );
      final payload = response['data'];
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return Map<String, dynamic>.from(payload);
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> createScanHandoffToken({
    required String exhibitionId,
    required String markerId,
    required String proofSource,
  }) async {
    try {
      final response = await _api.createScanHandoffToken(
        markerId: markerId,
        subjectType: 'exhibition',
        subjectId: exhibitionId,
        proofSource: proofSource,
      );
      final payload = response['data'];
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return Map<String, dynamic>.from(payload);
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<ExhibitionPoapStatus?> claimExhibitionPoap(
    String exhibitionId, {
    String? attendanceMarkerId,
    String? claimProofToken,
    String? proofSource,
  }) async {
    _setFlag(_Flag.poapClaiming, true);
    try {
      final status = await _api.claimExhibitionPoap(
        exhibitionId,
        attendanceMarkerId: attendanceMarkerId,
        claimProofToken: claimProofToken,
        proofSource: proofSource,
      );
      if (status != null) {
        _poapByExhibitionId[exhibitionId] = status;
        notifyListeners();
      }
      return status;
    } catch (e) {
      debugPrint('ExhibitionsProvider.claimExhibitionPoap failed: $e');
      rethrow;
    } finally {
      _setFlag(_Flag.poapClaiming, false);
    }
  }

  void _upsert(Exhibition exhibition, {bool notify = true}) {
    _byId[exhibition.id] = exhibition;
    final idx = _exhibitions.indexWhere((e) => e.id == exhibition.id);
    if (idx >= 0) {
      _exhibitions[idx] = exhibition;
    } else {
      _exhibitions.add(exhibition);
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
      case _Flag.myList:
        changed = _isMyExhibitionsLoading != next;
        _isMyExhibitionsLoading = next;
        break;
      case _Flag.detail:
        changed = _isDetailLoading != next;
        _isDetailLoading = next;
        break;
      case _Flag.mutating:
        changed = _isMutating != next;
        _isMutating = next;
        break;
      case _Flag.uploadingCover:
        changed = _isUploadingCover != next;
        _isUploadingCover = next;
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
  myList,
  detail,
  mutating,
  uploadingCover,
  relation,
  poapLoading,
  poapClaiming,
}
