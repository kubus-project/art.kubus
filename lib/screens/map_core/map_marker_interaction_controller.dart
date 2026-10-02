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
    VoidCallback? onMarkerOpenedByTap,
  })  : _mapController = mapController,
        _isWeb = isWeb,
        _onMarkerOpenedByTap = onMarkerOpenedByTap;

  final KubusMapController _mapController;
  final bool _isWeb;

  /// Called when a tap on the map opened a marker that was not already open.
  /// Programmatic selections (deep-link targets, search) never go through
  /// [handleMapClick], so this is a deliberate-interaction signal.
  final VoidCallback? _onMarkerOpenedByTap;

  Future<void> handleMapClick(Object? rawPoint) async {
    final point = _coercePoint(rawPoint);
    if (point == null) return;
    final before = _mapController.selectedMarkerId;
    await _mapController.handleMapClick(point, isWeb: _isWeb);
    final after = _mapController.selectedMarkerId;
    if (after != null && after != before) {
      _onMarkerOpenedByTap?.call();
    }
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

  math.Point<double>? _coercePoint(Object? rawPoint) {
    if (rawPoint is math.Point) {
      final x = (rawPoint.x as num?)?.toDouble();
      final y = (rawPoint.y as num?)?.toDouble();
      if (x == null || y == null || !x.isFinite || !y.isFinite) {
        return null;
      }
      return math.Point<double>(x, y);
    }

    if (rawPoint is Map) {
      final x = (rawPoint['x'] as num?)?.toDouble();
      final y = (rawPoint['y'] as num?)?.toDouble();
      if (x == null || y == null || !x.isFinite || !y.isFinite) {
        return null;
      }
      return math.Point<double>(x, y);
    }

    return null;
  }
}
