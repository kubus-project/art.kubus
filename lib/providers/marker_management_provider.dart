import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';
import '../services/backend_api_service.dart';
import '../services/map_marker_service.dart';

class MarkerManagementProvider extends ChangeNotifier {
  MarkerManagementProvider({
    MarkerBackendApi? api,
    MapMarkerService? mapMarkerService,
  })  : _api = api ?? BackendApiService(),
        _mapMarkerService = mapMarkerService ?? MapMarkerService();

  final MarkerBackendApi _api;
  final MapMarkerService _mapMarkerService;

  String? _boundWallet;
  bool _initialized = false;
  bool _loading = false;
  String? _error;
  List<ArtMarker> _markers = const <ArtMarker>[];

  // Cache + de-dupe for /mine marker list.
  static const Duration _cacheTtl = Duration(seconds: 30);
  DateTime? _lastFetch;
  Future<void>? _inFlightRefresh;

  bool get initialized => _initialized;
  bool get isLoading => _loading;
  String? get error => _error;
  List<ArtMarker> get markers => List<ArtMarker>.unmodifiable(_markers);

  /// Merge a marker into the local list (used when markers are created/updated
  /// from other surfaces like the map screen).
  void ingestMarker(ArtMarker marker) {
    _markers = <ArtMarker>[marker, ..._markers.where((m) => m.id != marker.id)];
    notifyListeners();
  }

  void bindWallet(String? walletAddress) {
    final normalized = (walletAddress ?? '').trim();
    if (normalized == (_boundWallet ?? '')) return;
    _boundWallet = normalized.isEmpty ? null : normalized;

    // Ensure the API layer knows which wallet should be considered "active"
    // for ownership-gated endpoints like marker update/delete.
    final api = _api;
    if (api is BackendApiService) {
      api.setPreferredWalletAddress(_boundWallet);
    }

    _initialized = false;
    _error = null;
    _markers = const <ArtMarker>[];
    _lastFetch = null;
    _inFlightRefresh = null;
    // Schedule notifyListeners in microtask to avoid synchronous notification
    // during ProxyProvider update callback, which could cause infinite recursion.
    Future.microtask(notifyListeners);
  }

  Future<void> initialize({bool force = false}) async {
    if (_loading) return;

    final token = (_api.getAuthToken() ?? '').trim();
    if (token.isEmpty) {
      // Important: do NOT permanently mark initialized when auth isn't ready yet.
      // This provider is wired via ProxyProvider update() and will be called
      // again once auth is loaded.
      _initialized = false;
      return;
    }

    if (_initialized && !force) return;
    _initialized = true;
    await refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    // If a refresh is already running, await it so callers don't race / return early.
    final inflight = _inFlightRefresh;
    if (inflight != null) {
      await inflight;
      return;
    }

    final token = (_api.getAuthToken() ?? '').trim();
    if (token.isEmpty) {
      // Auth not ready (or user signed out). Keep provider re-initializable.
      _initialized = false;
      if (_markers.isNotEmpty || _error != null) {
        _markers = const <ArtMarker>[];
        _error = null;
        notifyListeners();
      }
      return;
    }

    _initialized = true;

    if (!force && _markers.isNotEmpty && _lastFetch != null) {
      final age = DateTime.now().difference(_lastFetch!);
      if (age <= _cacheTtl) {
        return;
      }
    }

    Future<void> run() async {
      _loading = true;
      _error = null;
      notifyListeners();
      try {
        final results = await _api.getMyArtMarkers().timeout(const Duration(seconds: 20));
        _markers = results;
        _lastFetch = DateTime.now();
      } catch (e) {
        _error = e.toString();
        if (kDebugMode) {
          debugPrint('MarkerManagementProvider: refresh failed: $e');
        }
      } finally {
        _loading = false;
        notifyListeners();
      }
    }

    _inFlightRefresh = run();
    try {
      await _inFlightRefresh;
    } finally {
      _inFlightRefresh = null;
    }
  }

  ArtMarker _applyUpdatesToMarker(ArtMarker base, Map<String, dynamic> updates) {
    String? name;
    String? description;
    String? category;

    if (updates.containsKey('name')) name = updates['name']?.toString();
    if (updates.containsKey('description')) description = updates['description']?.toString();
    if (updates.containsKey('category')) category = updates['category']?.toString();

    // Coordinate updates can arrive in a few shapes.
    final latRaw = updates['latitude'] ?? updates['lat'] ?? updates['position']?['lat'];
    final lngRaw = updates['longitude'] ?? updates['lng'] ?? updates['position']?['lng'];
    final lat = latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw?.toString() ?? '');
    final lng = lngRaw is num ? lngRaw.toDouble() : double.tryParse(lngRaw?.toString() ?? '');
    final hasNewPos = lat != null && lng != null;

    final isPublic = updates.containsKey('isPublic') ? updates['isPublic'] == true : null;
    final isActive = updates.containsKey('isActive') ? updates['isActive'] == true : null;
    final requiresProximity = updates.containsKey('requiresProximity') ? updates['requiresProximity'] == true : null;
    final activationRadiusRaw = updates['activationRadius'];
    final activationRadius = activationRadiusRaw is num
        ? activationRadiusRaw.toDouble()
        : double.tryParse(activationRadiusRaw?.toString() ?? '');

    final metadata = updates.containsKey('metadata') && updates['metadata'] is Map<String, dynamic>
        ? <String, dynamic>{...(base.metadata ?? const {}), ...(updates['metadata'] as Map<String, dynamic>)}
        : base.metadata;

    return base.copyWith(
      name: name,
      description: description,
      category: category,
      position: hasNewPos ? LatLng(lat, lng) : null,
      isPublic: isPublic,
      isActive: isActive,
      requiresProximity: requiresProximity,
      activationRadius: activationRadius,
      metadata: metadata,
      updatedAt: DateTime.now(),
    );
  }

  Future<ArtMarker?> createMarker(Map<String, dynamic> payload) async {
    try {
      final created = await _api.createArtMarkerRecord(payload).timeout(const Duration(seconds: 20));
      if (created == null) return null;
      _markers = <ArtMarker>[created, ..._markers.where((m) => m.id != created.id)];
      _mapMarkerService.notifyMarkerUpserted(created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ArtMarker?> updateMarker(String markerId, Map<String, dynamic> updates) async {
    final id = markerId.trim();
    if (id.isEmpty) return null;
    final index = _markers.indexWhere((m) => m.id == id);
    if (index < 0) return null;

    final before = _markers[index];
    final optimistic = _applyUpdatesToMarker(before, updates);
    _markers = _markers
        .map((m) => m.id == id ? optimistic : m)
        .toList(growable: false);
    _mapMarkerService.notifyMarkerUpserted(optimistic);
    notifyListeners();

    try {
      final updated = await _api.updateArtMarkerRecord(id, updates).timeout(const Duration(seconds: 20));
      if (updated == null) {
        // Revert when backend returns no marker.
        _markers = _markers
            .map((m) => m.id == id ? before : m)
            .toList(growable: false);
        _mapMarkerService.notifyMarkerUpserted(before);
        notifyListeners();
        return null;
      }
      _markers = _markers
          .map((m) => m.id == id ? updated : m)
          .toList(growable: false);
      _mapMarkerService.notifyMarkerUpserted(updated);
      _lastFetch = DateTime.now();
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      // Revert optimistic change.
      _markers = _markers
          .map((m) => m.id == id ? before : m)
          .toList(growable: false);
      _mapMarkerService.notifyMarkerUpserted(before);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteMarker(String markerId) async {
    final id = markerId.trim();
    if (id.isEmpty) return false;
    final before = _markers;
    if (!_markers.any((m) => m.id == id)) return false;

    // Optimistic removal.
    _markers = _markers.where((m) => m.id != id).toList(growable: false);
    _mapMarkerService.notifyMarkerDeleted(id);
    notifyListeners();

    try {
      final ok = await _api.deleteArtMarkerRecord(id).timeout(const Duration(seconds: 20));
      if (!ok) {
        _markers = before;
        _mapMarkerService.notifyMarkerUpserted(before.firstWhere((m) => m.id == id));
        notifyListeners();
        return false;
      }
      _lastFetch = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _markers = before;
      try {
        _mapMarkerService.notifyMarkerUpserted(before.firstWhere((m) => m.id == id));
      } catch (_) {}
      notifyListeners();
      return false;
    }
  }
}
