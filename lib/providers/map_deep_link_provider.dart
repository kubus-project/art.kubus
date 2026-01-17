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
  MapDeepLinkIntent? _pending;

  /// Schedules a marker to be opened by the MapScreen.
  void openMarker({
    required String markerId,
    LatLng? center,
    double? zoom,
  }) {
    _pending = MapDeepLinkIntent(
      markerId: markerId,
      center: center,
      zoom: zoom,
    );
    notifyListeners();
  }

  /// Returns and clears the pending intent.
  MapDeepLinkIntent? consumePending() {
    final value = _pending;
    _pending = null;
    return value;
  }
}
