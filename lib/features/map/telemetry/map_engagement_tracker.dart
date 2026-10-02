import 'dart:math' as math;

/// Decides when a map session has produced its first *deliberate* interaction.
///
/// The funnel needs to tell a visitor who looked at a rendered map from one who
/// actually used it. "Map initialised", an automatic camera restore and a
/// programmatic `fitBounds` are not use; those never reach this class, because
/// the screens only feed it camera frames the user caused.
///
/// Qualifying, first one wins and nothing is emitted afterwards:
/// * [markerOpened]: the visitor opened a marker by tapping the map,
/// * [searchResultSelected]: the visitor picked a map search result,
/// * [cameraGesture]: the visitor panned or zoomed by an amount no incidental
///   touch produces.
///
/// It is a bounded signal, not a gesture stream: after the first emission every
/// call is a no-op, so a pan cannot cost more than one comparison per frame.
class MapEngagementTracker {
  MapEngagementTracker({required void Function(String kind) onEngaged})
      : _onEngaged = onEngaged;

  static const String kindCameraGesture = 'camera_gesture';
  static const String kindMarkerOpen = 'marker_open';
  static const String kindSearchSelect = 'search_select';

  /// A zoom change of at least this many levels counts as deliberate.
  static const double zoomThresholdLevels = 0.5;

  /// A pan of at least this fraction of one 512px tile's span counts as
  /// deliberate. Span is `360 / 2^zoom` degrees, so the threshold scales with
  /// how far in the visitor is rather than being a fixed distance.
  static const double panThresholdTileFraction = 0.25;

  final void Function(String kind) _onEngaged;

  bool _engaged = false;
  _Frame? _baseline;

  bool get engaged => _engaged;

  void markerOpened() => _engage(kindMarkerOpen);

  void searchResultSelected() => _engage(kindSearchSelect);

  /// Feed a camera frame that was *not* caused by a programmatic move.
  ///
  /// The first frame only sets the baseline; later frames engage once the
  /// camera has travelled far enough from it.
  void cameraGesture({
    required double latitude,
    required double longitude,
    required double zoom,
  }) {
    if (_engaged) return;
    if (!latitude.isFinite || !longitude.isFinite || !zoom.isFinite) return;

    final baseline = _baseline;
    if (baseline == null) {
      _baseline = _Frame(latitude, longitude, zoom);
      return;
    }

    final zoomDelta = (zoom - baseline.zoom).abs();
    final tileSpanDegrees = 360 / math.pow(2, zoom);
    final panDegrees = math.max(
      (latitude - baseline.latitude).abs(),
      _longitudeDistance(longitude, baseline.longitude),
    );

    if (zoomDelta >= zoomThresholdLevels ||
        panDegrees >= tileSpanDegrees * panThresholdTileFraction) {
      _engage(kindCameraGesture);
    }
  }

  /// Forget the baseline without losing the engaged flag. Call when the camera
  /// is repositioned programmatically, so the next gesture measures from there.
  void resetBaseline() => _baseline = null;

  void _engage(String kind) {
    if (_engaged) return;
    _engaged = true;
    _baseline = null;
    _onEngaged(kind);
  }

  static double _longitudeDistance(double a, double b) {
    final raw = (a - b).abs() % 360;
    return raw > 180 ? 360 - raw : raw;
  }
}

class _Frame {
  const _Frame(this.latitude, this.longitude, this.zoom);

  final double latitude;
  final double longitude;
  final double zoom;
}
