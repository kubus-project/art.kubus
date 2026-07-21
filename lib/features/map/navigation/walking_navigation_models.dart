import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

@immutable
class WalkingNavigationIntent {
  const WalkingNavigationIntent({
    required this.destinationId,
    required this.destinationLabel,
    required this.destination,
  });

  final String destinationId;
  final String destinationLabel;
  final LatLng destination;
}

enum WalkingNavigationStatus {
  idle,
  awaitingLocation,
  requestingPermission,
  calculating,
  active,
  rerouting,
  arrived,
  error,
}

enum WalkingNavigationFailureKind {
  locationPermissionDenied,
  locationPermissionDeniedPermanently,
  locationServicesDisabled,
  locationUnavailable,
  locationTimedOut,
  noRoute,
  routeTooLong,
  routeSourceTimeout,
  routeNetwork,
  routeMalformed,
}

enum WalkingLocationAccessStatus {
  available,
  permissionNotRequested,
  requestingPermission,
  permissionDenied,
  permissionDeniedPermanently,
  serviceDisabled,
  liveLocationUnavailable,
  timedOut,
}

@immutable
class WalkingNavigationSessionLease {
  const WalkingNavigationSessionLease(this.generation);

  final int generation;
}

@immutable
class WalkingRouteStep {
  const WalkingRouteStep({
    required this.type,
    required this.modifier,
    required this.roadName,
    required this.location,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometryIndex,
  });

  final String type;
  final String modifier;
  final String roadName;
  final LatLng location;
  final double distanceMeters;
  final double durationSeconds;
  final int geometryIndex;
}

/// Renderable extent of a walking route, used for route-overview camera fits.
@immutable
class WalkingRouteBounds {
  const WalkingRouteBounds({
    required this.southWest,
    required this.northEast,
  });

  final LatLng southWest;
  final LatLng northEast;
}

@immutable
class WalkingRoute {
  const WalkingRoute({
    required this.points,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
    this.graphStartIndex = 0,
    this.graphEndIndex,
  });

  final List<LatLng> points;
  final List<WalkingRouteStep> steps;
  final double distanceMeters;
  final double durationSeconds;
  final int graphStartIndex;
  final int? graphEndIndex;

  /// Kind value matched by the primary walking-route line layers.
  static const String routeFeatureKind = 'route';

  /// Kind value matched by the dashed graph-snap connector layer.
  static const String connectorFeatureKind = 'connector';

  /// Builds the FeatureCollection consumed by the MapLibre walking-route
  /// source.
  ///
  /// Invalid, non-finite, out-of-bounds, and consecutively duplicated points
  /// are discarded so MapLibre never receives geometry it silently refuses to
  /// draw. When the routable graph slice collapses to fewer than two distinct
  /// points the complete route is emitted as the primary route instead: a
  /// connector-only collection matches no `kind == 'route'` layer filter and
  /// would render as no line at all.
  Map<String, dynamic> toGeoJson() {
    final complete = _sanitizeLine(points);
    if (complete.length < 2) return _emptyCollection();

    final lastIndex = points.length - 1;
    final graphStart = graphStartIndex.clamp(0, lastIndex);
    final graphEnd = (graphEndIndex ?? lastIndex).clamp(graphStart, lastIndex);
    final main = _sanitizeLine(points.sublist(graphStart, graphEnd + 1));

    final features = <Map<String, dynamic>>[];
    if (main.length < 2) {
      features.add(_lineFeature('walking-route', routeFeatureKind, complete));
      return <String, dynamic>{
        'type': 'FeatureCollection',
        'features': features,
      };
    }

    features.add(_lineFeature('walking-route', routeFeatureKind, main));
    if (graphStart > 0) {
      final origin = _sanitizeLine(points.sublist(0, graphStart + 1));
      if (origin.length >= 2) {
        features.add(
          _lineFeature(
            'walking-origin-connector',
            connectorFeatureKind,
            origin,
          ),
        );
      }
    }
    if (graphEnd < lastIndex) {
      final destination = _sanitizeLine(points.sublist(graphEnd));
      if (destination.length >= 2) {
        features.add(
          _lineFeature(
            'walking-destination-connector',
            connectorFeatureKind,
            destination,
          ),
        );
      }
    }
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// South-west/north-east extent of everything that can actually be drawn.
  ///
  /// Returns null when the route has no renderable geometry, so callers never
  /// move the camera to an empty or degenerate box.
  WalkingRouteBounds? get renderableBounds {
    final usable = _sanitizeLine(points);
    if (usable.length < 2) return null;
    var minLat = usable.first.latitude;
    var maxLat = usable.first.latitude;
    var minLng = usable.first.longitude;
    var maxLng = usable.first.longitude;
    for (final point in usable.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return WalkingRouteBounds(
      southWest: LatLng(minLat, minLng),
      northEast: LatLng(maxLat, maxLng),
    );
  }

  static Map<String, dynamic> _emptyCollection() => <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

  static Map<String, dynamic> _lineFeature(
    String id,
    String kind,
    List<LatLng> linePoints,
  ) =>
      <String, dynamic>{
        'type': 'Feature',
        'id': id,
        'properties': <String, dynamic>{'kind': kind},
        'geometry': <String, dynamic>{
          'type': 'LineString',
          'coordinates': linePoints
              .map((point) => <double>[point.longitude, point.latitude])
              .toList(growable: false),
        },
      };

  /// Drops unusable coordinates and collapses consecutive duplicates so every
  /// emitted LineString has at least two visibly distinct vertices.
  static List<LatLng> _sanitizeLine(List<LatLng> source) {
    final result = <LatLng>[];
    for (final point in source) {
      if (!isRenderablePoint(point)) continue;
      final previous = result.isEmpty ? null : result.last;
      if (previous != null &&
          (previous.latitude - point.latitude).abs() < _coordinateEpsilon &&
          (previous.longitude - point.longitude).abs() < _coordinateEpsilon) {
        continue;
      }
      result.add(point);
    }
    return result;
  }

  /// Roughly 1 cm at the equator: below MapLibre's rendering resolution.
  static const double _coordinateEpsilon = 1e-7;

  static bool isRenderablePoint(LatLng point) {
    final latitude = point.latitude;
    final longitude = point.longitude;
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
