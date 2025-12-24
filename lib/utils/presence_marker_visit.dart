import 'package:latlong2/latlong.dart';

import '../models/art_marker.dart';

const double kPresenceMarkerVisitRadiusMeters = 10.0;

({String type, String id})? presenceVisitFromMarker(ArtMarker marker) {
  final subjectType = (marker.subjectType ?? '').trim().toLowerCase();
  final subjectId = (marker.subjectId ?? '').trim();

  if (subjectType.isNotEmpty && subjectId.isNotEmpty) {
    if (subjectType.contains('artwork')) {
      final artworkId = (marker.artworkId ?? '').trim();
      return (type: 'artwork', id: artworkId.isNotEmpty ? artworkId : subjectId);
    }

    if (subjectType.contains('exhibition')) {
      final resolved = marker.resolvedExhibitionSummary;
      final exhibitionId = (resolved?.id ?? subjectId).trim();
      if (exhibitionId.isNotEmpty) {
        return (type: 'exhibition', id: exhibitionId);
      }
    }

    if (subjectType.contains('event')) {
      return (type: 'event', id: subjectId);
    }

    if (subjectType.contains('collection')) {
      return (type: 'collection', id: subjectId);
    }
  }

  if (marker.isExhibitionMarker) {
    final resolved = marker.resolvedExhibitionSummary;
    final exhibitionId = (resolved?.id ?? '').trim();
    if (exhibitionId.isNotEmpty) {
      return (type: 'exhibition', id: exhibitionId);
    }
    if (subjectId.isNotEmpty) {
      return (type: 'exhibition', id: subjectId);
    }
  }

  final artworkId = (marker.artworkId ?? '').trim();
  if (artworkId.isNotEmpty) {
    return (type: 'artwork', id: artworkId);
  }

  return null;
}

bool shouldRecordPresenceVisitForMarker({
  required ArtMarker marker,
  required LatLng? userLocation,
  double radiusMeters = kPresenceMarkerVisitRadiusMeters,
}) {
  if (userLocation == null) return false;
  if (!marker.hasValidPosition) return false;

  final visit = presenceVisitFromMarker(marker);
  if (visit == null) return false;

  final meters = marker.getDistanceFrom(userLocation);
  return meters <= radiusMeters;
}

