import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';

/// Immutable description of the active quick-filter / search / radius state used
/// to decide which loaded markers are actually rendered on the map.
///
/// This is intentionally decoupled from any provider or widget so the predicate
/// stays pure and unit-testable. The discovered/favorite/AR signals are injected
/// as callbacks because they depend on linked artwork state that lives outside
/// the [ArtMarker] model.
@immutable
class MapMarkerFilterState {
  const MapMarkerFilterState({
    this.quickFilterKey = 'all',
    this.query = '',
    this.basePosition,
    this.radiusKm = 1.0,
    this.strictNearbyWithoutBase = false,
  });

  /// One of: `all`, `public`, `nearby`, `discovered`, `undiscovered`, `ar`,
  /// `favorites`. Unknown keys fall back to "show everything eligible".
  final String quickFilterKey;

  /// Free-text search query (matched against marker name/description/category/
  /// tags/subject title).
  final String query;

  /// Position used for the `nearby` radius filter (user location or camera).
  final LatLng? basePosition;

  /// Radius in kilometres for the `nearby` filter.
  final double radiusKm;

  /// When `true`, a `nearby` filter with no [basePosition] hides everything.
  /// Defaults to `false` for markers so the map never goes empty just because
  /// the device location is not available yet.
  final bool strictNearbyWithoutBase;
}

/// Default AR-capability heuristic that relies only on [ArtMarker] fields.
///
/// A marker is considered AR-capable when it is an experience marker or carries
/// 3-D model content. Callers can pass their own predicate (e.g. to also honour
/// the linked artwork's `arEnabled` flag) via [filterVisibleMapMarkers].
bool defaultMarkerIsArCapable(ArtMarker marker) {
  if (marker.type == ArtMarkerType.experience) return true;
  if (marker.modelCID?.trim().isNotEmpty ?? false) return true;
  if (marker.modelURL?.trim().isNotEmpty ?? false) return true;
  return false;
}

bool _markerMatchesQuery(ArtMarker marker, String normalizedQuery) {
  if (normalizedQuery.isEmpty) return true;
  bool contains(String? value) =>
      value != null && value.toLowerCase().contains(normalizedQuery);

  if (contains(marker.name)) return true;
  if (contains(marker.description)) return true;
  if (contains(marker.category)) return true;
  if (contains(marker.subjectTitle)) return true;
  for (final tag in marker.tags) {
    if (tag.toLowerCase().contains(normalizedQuery)) return true;
  }
  return false;
}

/// Returns whether a single [marker] passes the current [state] and the
/// injected discovered/favorite/AR predicates.
///
/// Composition order: base eligibility -> search text -> quick filter.
bool mapMarkerMatchesFilters({
  required ArtMarker marker,
  required MapMarkerFilterState state,
  bool Function(ArtMarker marker)? isDiscovered,
  bool Function(ArtMarker marker)? isFavorite,
  bool Function(ArtMarker marker)? isArCapable,
}) {
  // Base eligibility mirrors the controller's render gate (valid coordinate).
  if (!marker.hasValidPosition) return false;

  final normalizedQuery = state.query.trim().toLowerCase();
  if (!_markerMatchesQuery(marker, normalizedQuery)) return false;

  final arCapable = isArCapable ?? defaultMarkerIsArCapable;

  switch (state.quickFilterKey) {
    case 'nearby':
      final base = state.basePosition;
      if (base == null) {
        return !state.strictNearbyWithoutBase;
      }
      final radiusMeters = math.max(0.0, state.radiusKm) * 1000.0;
      return marker.getDistanceFrom(base) <= radiusMeters;
    case 'discovered':
      return isDiscovered?.call(marker) ?? false;
    case 'undiscovered':
      // When discovery state is unavailable, treat everything as undiscovered
      // (explore) rather than hiding the whole map.
      return !(isDiscovered?.call(marker) ?? false);
    case 'ar':
      return arCapable(marker);
    case 'favorites':
      return isFavorite?.call(marker) ?? false;
    case 'all':
    case 'public':
    default:
      return true;
  }
}

/// Filters [markers] down to the set that should be rendered on the map / fed
/// into clustering for the current [state].
///
/// [alwaysIncludeMarkerIds] lets the caller pin markers that must stay visible
/// regardless of the active filter (e.g. the currently selected marker or a
/// pending/temporary marker), so an active selection is never hidden out from
/// under the user when they switch filters.
List<ArtMarker> filterVisibleMapMarkers({
  required List<ArtMarker> markers,
  required MapMarkerFilterState state,
  bool Function(ArtMarker marker)? isDiscovered,
  bool Function(ArtMarker marker)? isFavorite,
  bool Function(ArtMarker marker)? isArCapable,
  Set<String>? alwaysIncludeMarkerIds,
}) {
  final always = alwaysIncludeMarkerIds ?? const <String>{};
  return markers.where((marker) {
    if (always.contains(marker.id) && marker.hasValidPosition) return true;
    return mapMarkerMatchesFilters(
      marker: marker,
      state: state,
      isDiscovered: isDiscovered,
      isFavorite: isFavorite,
      isArCapable: isArCapable,
    );
  }).toList(growable: false);
}
