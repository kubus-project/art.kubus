import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../features/map/controller/kubus_map_controller.dart';
import '../../models/art_marker.dart';

/// Shared marker interaction orchestration for map screens.
///
/// This controller intentionally contains no UI concerns and no MapLibre style
/// queries. All rendered-feature hit testing stays centralized in
/// [KubusMapController.handleMapClick] and [MapLayersManager].
@immutable
class MapMarkerInteractionController {
  const MapMarkerInteractionController({
    required KubusMapController mapController,
    required bool isWeb,
  })  : _mapController = mapController,
        _isWeb = isWeb;

  final KubusMapController _mapController;
  final bool _isWeb;

  Future<void> handleMapClick(math.Point<double> point) {
    return _mapController.handleMapClick(point, isWeb: _isWeb);
  }

  void handleMarkerTap(
    ArtMarker marker, {
    List<ArtMarker> stackedMarkers = const <ArtMarker>[],
    VoidCallback? beforeSelect,
  }) {
    beforeSelect?.call();
    _mapController.selectMarker(
      marker,
      stackedMarkers: stackedMarkers.isEmpty ? null : stackedMarkers,
    );
  }

  void dismissSelection() {
    _mapController.dismissSelection();
  }
}
