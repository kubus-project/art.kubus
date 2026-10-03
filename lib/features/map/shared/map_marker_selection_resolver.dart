import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';

final Distance _markerSelectionDistance = const Distance();

/// Picks the best marker candidate when multiple markers can refer to the same
/// linked artwork or subject.
///
/// Selection order:
/// 1. authoritative artwork/subject relation filters
/// 2. exact marker hint within that candidate set
/// 3. exact label match among the candidate set
/// 4. nearest marker to the preferred position
/// 5. deterministic fallback by id
ArtMarker? resolveBestMarkerCandidate(
  Iterable<ArtMarker> markers, {
  String? exactMarkerId,
  String? artworkId,
  String? subjectId,
  String? subjectType,
  String? preferredLabel,
  LatLng? preferredPosition,
}) {
  final markerList = markers.toList(growable: false);
  final normalizedArtworkId = artworkId?.trim() ?? '';
  var candidates = markerList;
  if (normalizedArtworkId.isNotEmpty) {
    candidates = markerList
        .where(
            (marker) => (marker.artworkId ?? '').trim() == normalizedArtworkId)
        .toList(growable: false);
    if (candidates.isEmpty) return null;
  }

  final normalizedSubjectId = subjectId?.trim() ?? '';
  if (normalizedSubjectId.isNotEmpty) {
    candidates = candidates
        .where(
            (marker) => (marker.subjectId ?? '').trim() == normalizedSubjectId)
        .toList(growable: false);
    if (candidates.isEmpty) return null;
  }

  final normalizedSubjectType = subjectType?.trim().toLowerCase() ?? '';
  if (normalizedSubjectType.isNotEmpty) {
    candidates = candidates
        .where(
          (marker) =>
              (marker.subjectType ?? '').trim().toLowerCase() ==
              normalizedSubjectType,
        )
        .toList(growable: false);
    if (candidates.isEmpty) return null;
  }

  if (candidates.isEmpty) return null;

  final normalizedMarkerId = exactMarkerId?.trim() ?? '';
  if (normalizedMarkerId.isNotEmpty) {
    for (final marker in candidates) {
      if (marker.id == normalizedMarkerId) {
        return marker;
      }
    }
  }

  final normalizedLabel = preferredLabel?.trim().toLowerCase() ?? '';
  final selectionPosition = preferredPosition;

  ArtMarker? bestMarker;
  _MarkerCandidateRank? bestRank;

  for (final candidate in candidates) {
    final rank = _MarkerCandidateRank(
      labelMatch: normalizedLabel.isNotEmpty &&
          candidate.name.trim().toLowerCase() == normalizedLabel,
      distanceMeters: selectionPosition != null
          ? _markerSelectionDistance.as(
              LengthUnit.Meter,
              selectionPosition,
              candidate.position,
            )
          : double.infinity,
      id: candidate.id,
    );

    if (bestRank == null || rank.compareTo(bestRank) < 0) {
      bestMarker = candidate;
      bestRank = rank;
    }
  }

  return bestMarker;
}

class _MarkerCandidateRank implements Comparable<_MarkerCandidateRank> {
  const _MarkerCandidateRank({
    required this.labelMatch,
    required this.distanceMeters,
    required this.id,
  });

  final bool labelMatch;
  final double distanceMeters;
  final String id;

  @override
  int compareTo(_MarkerCandidateRank other) {
    if (labelMatch != other.labelMatch) {
      return labelMatch ? -1 : 1;
    }

    final distanceComparison = distanceMeters.compareTo(other.distanceMeters);
    if (distanceComparison != 0) {
      return distanceComparison;
    }

    return id.compareTo(other.id);
  }
}

/// Prefix of the temporary markers the map creates for a search result whose
/// artwork has no loaded marker yet.
const String kSearchTemporaryMarkerPrefix = 'search_temp_';

/// The already-loaded markers a viewport (bounds) refresh must carry over.
///
/// A bounds query replaces the loaded set with whatever the new viewport
/// holds. Three kinds of marker are not allowed to fall out of it: the
/// **selected** marker (it is on screen as the selection, and a pan must not
/// dismiss it just because the new bounds no longer contain it), the direct
/// deep-link target, and the temporary markers created for a search result.
///
/// The selected marker is carried over only when the response [fetched] does
/// not contain it: when the backend returned it, the fresh record (position,
/// metadata, presentation) is the one that must win over the loaded copy.
Iterable<ArtMarker> markersPreservedAcrossViewportRefresh(
  Iterable<ArtMarker> current, {
  String? selectedMarkerId,
  String? directTargetMarkerId,
  Iterable<ArtMarker> fetched = const <ArtMarker>[],
}) {
  final selected = selectedMarkerId?.trim() ?? '';
  final direct = directTargetMarkerId?.trim() ?? '';
  final selectedWasFetched =
      selected.isNotEmpty && fetched.any((marker) => marker.id == selected);
  return current.where(
    (marker) =>
        (selected.isNotEmpty && marker.id == selected && !selectedWasFetched) ||
        (direct.isNotEmpty && marker.id == direct) ||
        marker.id.startsWith(kSearchTemporaryMarkerPrefix),
  );
}
