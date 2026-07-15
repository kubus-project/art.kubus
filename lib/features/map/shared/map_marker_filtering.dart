import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import '../filters/map_filter_state.dart';

/// Runtime inputs that accompany the persistent typed map filter state.
///
/// Search text and the current geographic anchor change independently from the
/// user's semantic filter choices, so they remain request context rather than
/// becoming part of [KubusMapFilterState].
@immutable
class KubusMapFilterContext {
  const KubusMapFilterContext({
    required this.state,
    this.query = '',
    this.basePosition,
    this.strictNearMeWithoutBase = false,
  });

  final KubusMapFilterState state;

  /// Free-text search query matched against the supported content fields.
  final String query;

  /// User/camera position used only by [KubusMapScope.nearMe].
  final LatLng? basePosition;

  /// Whether near-me filtering hides all content until [basePosition] exists.
  ///
  /// The map normally keeps loaded content visible while location is pending,
  /// while callers that require an exact location may opt into strict mode.
  final bool strictNearMeWithoutBase;
}

/// Default AR-capability heuristic that relies only on [ArtMarker] fields.
///
/// A marker is considered AR-capable when it is an experience marker or carries
/// 3-D model content. Callers can pass their own predicate (for example, to
/// honour a linked artwork's `arEnabled` flag) via [filterVisibleMapMarkers].
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

bool _markerMatchesScope(ArtMarker marker, KubusMapFilterContext context) {
  switch (context.state.scope) {
    case KubusMapScope.currentViewport:
    case KubusMapScope.travel:
      // The loaded marker set already represents the active map viewport.
      return true;
    case KubusMapScope.nearMe:
      final base = context.basePosition;
      if (base == null) return !context.strictNearMeWithoutBase;
      final radiusMeters = math.max(0.0, context.state.nearMeRadiusKm) * 1000.0;
      return marker.getDistanceFrom(base) <= radiusMeters;
  }
}

/// Returns whether [marker] passes every independent filter dimension.
///
/// Composition order is content layer, search, geographic scope, discovery,
/// AR capability, then favorite state. This function deliberately has no
/// special selection behavior; pinning is a list-level concern handled by
/// [filterVisibleMapMarkers].
bool mapMarkerMatchesFilters({
  required ArtMarker marker,
  required KubusMapFilterContext context,
  bool Function(ArtMarker marker)? isDiscovered,
  bool Function(ArtMarker marker)? isFavorite,
  bool Function(ArtMarker marker)? isArCapable,
}) {
  if (!marker.hasValidPosition) return false;

  final state = context.state;
  if (!state.visibleContentLayers.contains(marker.type)) return false;
  if (!_markerMatchesQuery(marker, context.query.trim().toLowerCase())) {
    return false;
  }
  if (!_markerMatchesScope(marker, context)) return false;

  final discovered = isDiscovered?.call(marker) ?? false;
  switch (state.discoveryStatus) {
    case KubusMapDiscoveryStatus.all:
      break;
    case KubusMapDiscoveryStatus.undiscovered:
      if (discovered) return false;
    case KubusMapDiscoveryStatus.discovered:
      if (!discovered) return false;
  }

  if (state.arOnly && !(isArCapable ?? defaultMarkerIsArCapable)(marker)) {
    return false;
  }
  if (state.favoritesOnly && !(isFavorite?.call(marker) ?? false)) {
    return false;
  }
  return true;
}

/// Filters [markers] to the content rendered by the map and cluster engine.
///
/// A position-valid ID in [alwaysIncludeMarkerIds] intentionally bypasses the
/// content-layer, search, scope, discovery, AR, and favorite predicates. This
/// preserves the established selection/search-navigation contract: changing a
/// filter must not remove the marker the user is actively interacting with.
/// Invalid-position markers are never rendered, including when pinned.
List<ArtMarker> filterVisibleMapMarkers({
  required List<ArtMarker> markers,
  required KubusMapFilterContext context,
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
      context: context,
      isDiscovered: isDiscovered,
      isFavorite: isFavorite,
      isArCapable: isArCapable,
    );
  }).toList(growable: false);
}
