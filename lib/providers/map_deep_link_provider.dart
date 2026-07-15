import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../features/map/controller/map_target_coordinator.dart';

typedef MapDeepLinkIntent = MapTargetIntent;

@immutable
class MapDeepLinkClaim {
  const MapDeepLinkClaim({
    required this.token,
    required this.intent,
  });

  final int token;
  final MapDeepLinkIntent intent;
}

/// Queues map targets for an already-mounted map and retains each target until
/// the map explicitly acknowledges a terminal result.
class MapDeepLinkProvider extends ChangeNotifier {
  final List<MapDeepLinkIntent> _pendingQueue = <MapDeepLinkIntent>[];
  MapDeepLinkClaim? _activeClaim;
  int _nextToken = 0;

  MapDeepLinkIntent? get pending =>
      _pendingQueue.isEmpty ? null : _pendingQueue.first;

  MapDeepLinkClaim? get activeClaim => _activeClaim;

  /// Keeps the established exact-marker entry point for callers that already
  /// know the authoritative marker identity.
  void openMarker({
    required String markerId,
    LatLng? center,
    double? zoom,
  }) {
    openTarget(
      exactMarkerId: markerId,
      preferredPosition: center,
      minZoom: zoom,
    );
  }

  void openArtwork({
    required String artworkId,
    String? exactMarkerId,
    LatLng? preferredPosition,
    String? preferredLabel,
    double? minZoom,
  }) {
    openTarget(
      exactMarkerId: exactMarkerId,
      artworkId: artworkId,
      preferredPosition: preferredPosition,
      preferredLabel: preferredLabel,
      minZoom: minZoom,
    );
  }

  void openTarget({
    String? exactMarkerId,
    String? artworkId,
    String? subjectId,
    String? subjectType,
    LatLng? preferredPosition,
    String? preferredLabel,
    double? minZoom,
  }) {
    final next = MapDeepLinkIntent(
      exactMarkerId: exactMarkerId,
      artworkId: artworkId,
      subjectId: subjectId,
      subjectType: subjectType,
      preferredPosition: preferredPosition,
      preferredLabel: preferredLabel,
      minZoom: minZoom ?? 16,
    );
    if (!next.hasIdentity) return;

    final tailIsClaimed = _activeClaim != null && _pendingQueue.length == 1;
    if (_pendingQueue.isNotEmpty &&
        !tailIsClaimed &&
        _pendingQueue.last.identityKey == next.identityKey) {
      _pendingQueue[_pendingQueue.length - 1] = next;
    } else {
      _pendingQueue.add(next);
    }
    notifyListeners();
  }

  /// Claims the oldest target without removing it. Repeated calls return the
  /// same claim until [acknowledge] or [release] is called.
  MapDeepLinkClaim? claimPending() {
    if (_activeClaim != null) return _activeClaim;
    if (_pendingQueue.isEmpty) return null;
    final claim = MapDeepLinkClaim(
      token: ++_nextToken,
      intent: _pendingQueue.first,
    );
    _activeClaim = claim;
    return claim;
  }

  bool acknowledge(int token) {
    final claim = _activeClaim;
    if (claim == null || claim.token != token) return false;
    if (_pendingQueue.isNotEmpty &&
        identical(_pendingQueue.first, claim.intent)) {
      _pendingQueue.removeAt(0);
    }
    _activeClaim = null;
    notifyListeners();
    return true;
  }

  bool release(int token) {
    final claim = _activeClaim;
    if (claim == null || claim.token != token) return false;
    _activeClaim = null;
    notifyListeners();
    return true;
  }

  void clear() {
    if (_pendingQueue.isEmpty && _activeClaim == null) return;
    _pendingQueue.clear();
    _activeClaim = null;
    notifyListeners();
  }

  int get pendingCount => _pendingQueue.length;
}
