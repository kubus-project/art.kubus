import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/art_marker.dart';
import '../services/backend_api_service.dart';

class MarkerManagementProvider extends ChangeNotifier {
  MarkerManagementProvider();

  final BackendApiService _api = BackendApiService();

  String? _boundWallet;
  bool _initialized = false;
  bool _loading = false;
  String? _error;
  List<ArtMarker> _markers = const <ArtMarker>[];

  bool get initialized => _initialized;
  bool get isLoading => _loading;
  String? get error => _error;
  List<ArtMarker> get markers => List<ArtMarker>.unmodifiable(_markers);

  void bindWallet(String? walletAddress) {
    final normalized = (walletAddress ?? '').trim();
    if (normalized == (_boundWallet ?? '')) return;
    _boundWallet = normalized.isEmpty ? null : normalized;
    _initialized = false;
    _error = null;
    _markers = const <ArtMarker>[];
    notifyListeners();
  }

  Future<void> initialize({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    if ((_api.getAuthToken() ?? '').trim().isEmpty) {
      return;
    }
    await refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    if (!_initialized) {
      _initialized = true;
    }
    if ((_api.getAuthToken() ?? '').trim().isEmpty) {
      _markers = const <ArtMarker>[];
      _error = null;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await _api.getMyArtMarkers().timeout(const Duration(seconds: 20));
      _markers = results;
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

  Future<ArtMarker?> createMarker(Map<String, dynamic> payload) async {
    try {
      final created = await _api.createArtMarkerRecord(payload).timeout(const Duration(seconds: 20));
      if (created == null) return null;
      _markers = <ArtMarker>[created, ..._markers.where((m) => m.id != created.id)];
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ArtMarker?> updateMarker(String markerId, Map<String, dynamic> updates) async {
    try {
      final updated = await _api
          .updateArtMarkerRecord(markerId, updates)
          .timeout(const Duration(seconds: 20));
      if (updated == null) return null;
      _markers = _markers
          .map((m) => m.id == markerId ? updated : m)
          .toList(growable: false);
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteMarker(String markerId) async {
    try {
      final ok = await _api.deleteArtMarkerRecord(markerId).timeout(const Duration(seconds: 20));
      if (!ok) return false;
      _markers = _markers.where((m) => m.id != markerId).toList(growable: false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}

