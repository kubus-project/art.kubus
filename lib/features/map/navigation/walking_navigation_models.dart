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
  calculating,
  active,
  arrived,
  error,
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

  Map<String, dynamic> toGeoJson() {
    final lastIndex = points.length - 1;
    final graphStart = graphStartIndex.clamp(0, lastIndex);
    final graphEnd = (graphEndIndex ?? lastIndex).clamp(graphStart, lastIndex);
    final features = <Map<String, dynamic>>[];

    void addLine(String id, String kind, List<LatLng> linePoints) {
      if (linePoints.length < 2) return;
      features.add(<String, dynamic>{
        'type': 'Feature',
        'id': id,
        'properties': <String, dynamic>{'kind': kind},
        'geometry': <String, dynamic>{
          'type': 'LineString',
          'coordinates': linePoints
              .map((point) => <double>[point.longitude, point.latitude])
              .toList(growable: false),
        },
      });
    }

    addLine(
      'walking-route',
      'route',
      points.sublist(graphStart, graphEnd + 1),
    );
    if (graphStart > 0) {
      addLine(
        'walking-origin-connector',
        'connector',
        points.sublist(0, graphStart + 1),
      );
    }
    if (graphEnd < lastIndex) {
      addLine(
        'walking-destination-connector',
        'connector',
        points.sublist(graphEnd),
      );
    }
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
  }
}
