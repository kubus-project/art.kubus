import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A one-shot intent consumed by the already-mounted MapScreen.
///
/// This is used so marker deep links open *inside* the existing map tab instead
/// of pushing a standalone MapScreen route that would hide the app shell.
class MapDeepLinkIntent {
  final String markerId;
  final LatLng? center;
  final double? zoom;

  const MapDeepLinkIntent({
    required this.markerId,
    this.center,
    this.zoom,
  });
}

class MapDeepLinkProvider extends ChangeNotifier {
  final List<MapDeepLinkIntent> _pendingQueue = <MapDeepLinkIntent>[];

  MapDeepLinkIntent? get pending =>
      _pendingQueue.isEmpty ? null : _pendingQueue.first;

  /// Schedules a marker to be opened by the MapScreen.
  void openMarker({
    required String markerId,
    LatLng? center,
    double? zoom,
  }) {
    final normalizedId = markerId.trim();
    if (normalizedId.isEmpty) return;

    final next = MapDeepLinkIntent(
      markerId: normalizedId,
      center: center,
      zoom: zoom,
    );

    if (_pendingQueue.isNotEmpty &&
        _pendingQueue.last.markerId == normalizedId) {
      _pendingQueue[_pendingQueue.length - 1] = next;
    } else {
      _pendingQueue.add(next);
    }
    notifyListeners();
  }

  /// Returns and removes the oldest pending intent.
  MapDeepLinkIntent? consumePending() {
    if (_pendingQueue.isEmpty) return null;
    return _pendingQueue.removeAt(0);
  }

  /// Clears all pending marker intents.
  void clear() {
    if (_pendingQueue.isEmpty) return;
    _pendingQueue.clear();
    notifyListeners();
  }

  int get pendingCount => _pendingQueue.length;
}
