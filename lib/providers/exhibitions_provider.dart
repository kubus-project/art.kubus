import 'package:flutter/foundation.dart';

import '../models/exhibition.dart';
import '../services/backend_api_service.dart';

class ExhibitionsProvider extends ChangeNotifier {
  final BackendApiService _api;

  ExhibitionsProvider({BackendApiService? api}) : _api = api ?? BackendApiService();

  final List<Exhibition> _exhibitions = <Exhibition>[];
  final Map<String, Exhibition> _byId = <String, Exhibition>{};
  final Map<String, ExhibitionPoapStatus> _poapByExhibitionId = <String, ExhibitionPoapStatus>{};

  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  Exhibition? _selected;

  List<Exhibition> get exhibitions => List.unmodifiable(_exhibitions);
  Exhibition? get selectedExhibition => _selected;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;

  ExhibitionPoapStatus? poapStatusFor(String exhibitionId) => _poapByExhibitionId[exhibitionId];

  Future<void> initialize({bool refresh = false}) async {
    if (_initialized && !refresh) return;
    _initialized = true;
    await loadExhibitions(refresh: true);
  }

  Future<void> loadExhibitions({
    bool refresh = false,
    String? eventId,
    String? from,
    String? to,
    double? lat,
    double? lng,
    double? radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final next = await _api.listExhibitions(
        eventId: eventId,
        from: from,
        to: to,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        limit: limit,
        offset: offset,
      );
      if (refresh) {
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
      _setLoading(false);
    }
  }

  Future<Exhibition?> fetchExhibition(String id, {bool force = false}) async {
    if (!force && _byId.containsKey(id)) return _byId[id];

    _setLoading(true);
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
      _setLoading(false);
    }
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
    _setLoading(true);
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
      _setLoading(false);
    }
  }

  Future<Exhibition?> updateExhibition(String id, Map<String, dynamic> updates) async {
    _setLoading(true);
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
      _setLoading(false);
    }
  }

  Future<void> deleteExhibition(String id) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.deleteExhibition(id);
      _exhibitions.removeWhere((e) => e.id == id);
      _byId.remove(id);
      _poapByExhibitionId.remove(id);
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

  Future<void> linkExhibitionArtworks(String exhibitionId, List<String> artworkIds) async {
    _setLoading(true);
    _error = null;
    try {
      final result = await _api.linkExhibitionArtworks(exhibitionId, artworkIds);

      // Update local exhibition immediately so the UI reflects linked artworks
      // even if the backend detail endpoint doesn't yet return artworkIds.
      final payload = (result['data'] is Map<String, dynamic>)
          ? (result['data'] as Map<String, dynamic>)
          : result;

      final addedRaw = payload['addedArtworkIds'] ?? payload['added_artwork_ids'];
      final requestedRaw = payload['requestedArtworkIds'] ?? payload['requested_artwork_ids'] ?? artworkIds;

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
        final merged = <String>{...current.artworkIds, ...requested, ...added}.toList();
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
      _setLoading(false);
    }
  }

  Future<void> unlinkExhibitionArtwork(String exhibitionId, String artworkId) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.unlinkExhibitionArtwork(exhibitionId, artworkId);

      // Keep UI responsive by updating local cache immediately.
      final current = _byId[exhibitionId];
      if (current != null) {
        final nextIds = current.artworkIds.where((id) => id != artworkId).toList();
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
      _setLoading(false);
    }
  }

  Future<void> linkExhibitionMarkers(String exhibitionId, List<String> markerIds) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.linkExhibitionMarkers(exhibitionId, markerIds);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> unlinkExhibitionMarker(String exhibitionId, String markerId) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.unlinkExhibitionMarker(exhibitionId, markerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<ExhibitionPoapStatus?> fetchExhibitionPoap(String exhibitionId, {bool force = false}) async {
    if (!force && _poapByExhibitionId.containsKey(exhibitionId)) {
      return _poapByExhibitionId[exhibitionId];
    }

    _setLoading(true);
    _error = null;
    try {
      final status = await _api.getExhibitionPoap(exhibitionId);
      if (status != null) {
        _poapByExhibitionId[exhibitionId] = status;
        notifyListeners();
      }
      return status;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<ExhibitionPoapStatus?> claimExhibitionPoap(String exhibitionId) async {
    _setLoading(true);
    _error = null;
    try {
      final status = await _api.claimExhibitionPoap(exhibitionId);
      if (status != null) {
        _poapByExhibitionId[exhibitionId] = status;
        notifyListeners();
      }
      return status;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
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

  void _setLoading(bool next) {
    if (_isLoading == next) return;
    _isLoading = next;
    notifyListeners();
  }
}
