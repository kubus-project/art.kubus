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

  Future<void> handleMapClick(Object? rawPoint) {
    final point = _coercePoint(rawPoint);
    if (point == null) {
      return Future<void>.value();
    }
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
