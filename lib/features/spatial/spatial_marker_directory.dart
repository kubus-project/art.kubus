import 'package:flutter/foundation.dart';

import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../providers/marker_management_provider.dart';
import '../../services/map_marker_service.dart';

/// Read-only lookup for the markers a spatial capture can be linked to.
///
/// A marker id is a durable reference, not a label. This resolves the id
/// against whatever the app already knows — the user's own markers and the
/// markers already fetched for the map — and returns null when it genuinely
/// does not know. It never invents a marker and never substitutes a different
/// one, because a wrong marker on an archived capture is worse than a missing
/// one.
class SpatialMarkerDirectory {
  SpatialMarkerDirectory({
    MarkerManagementProvider? management,
    MapMarkerService? mapMarkers,
  })  : _management = management,
        _injectedMapMarkers = mapMarkers;

  final MarkerManagementProvider? _management;
  final MapMarkerService? _injectedMapMarkers;

  /// Resolved on demand, never in the constructor.
  ///
  /// [MapMarkerService] is an app-wide singleton that owns a socket bridge and
  /// telemetry; building one just to render a label would start real
  /// background work for a widget that may only need the artwork title.
  MapMarkerService get _mapMarkers => _injectedMapMarkers ?? MapMarkerService();

  /// Every marker currently known to the app, own markers first.
  List<ArtMarker> get known {
    final seen = <String>{};
    final markers = <ArtMarker>[];
    for (final marker in <ArtMarker>[
      ...?_management?.markers,
      ..._mapMarkers.cachedMarkers,
    ]) {
      if (marker.id.isEmpty || !seen.add(marker.id)) continue;
      markers.add(marker);
    }
    return markers;
  }

  /// Resolves one marker, or null when the reference cannot be resolved.
  ArtMarker? resolve(String? markerId) {
    final id = (markerId ?? '').trim();
    if (id.isEmpty) return null;
    for (final marker in known) {
      if (marker.id == id) return marker;
    }
    return null;
  }

  /// The markers a capture of [artwork] could reasonably be linked to.
  ///
  /// Includes the artwork's configured AR marker even when it is not in the
  /// fetched set, so the obvious choice is never missing from the list.
  List<ArtMarker> candidatesFor(Artwork artwork) {
    final linked = <ArtMarker>[];
    final seen = <String>{};
    for (final marker in known) {
      final belongs = marker.artworkId == artwork.id ||
          (artwork.arMarkerId != null && marker.id == artwork.arMarkerId);
      if (!belongs || !seen.add(marker.id)) continue;
      linked.add(marker);
    }
    return linked;
  }

  /// A display label for a marker reference, or null when unresolved.
  ///
  /// Callers render their own "unavailable" copy for null rather than falling
  /// back to the raw id, which means nothing to a reader.
  String? labelFor(String? markerId) {
    final marker = resolve(markerId);
    if (marker == null) return null;
    final name = marker.name.trim();
    return name.isEmpty ? null : name;
  }
}

/// Whether a marker reference points at something with a place on the map.
///
/// Not every marker is a map pin: printable AR configuration markers carry no
/// meaningful geography, and offering "View on map" for one is a dead end.
bool markerHasMapLocation(ArtMarker marker) {
  if (!marker.requiresProximity && marker.type == ArtMarkerType.experience) {
    // An experience with no proximity requirement is a configuration, not a
    // located work.
    return false;
  }
  final position = marker.position;
  if (position.latitude == 0 && position.longitude == 0) return false;
  return position.latitude.abs() <= 90 && position.longitude.abs() <= 180;
}

/// A localizable description of what kind of marker a reference points at.
@immutable
class SpatialMarkerKind {
  const SpatialMarkerKind._(this.isGeographic);

  /// A pin with a real location, which can be opened on the map.
  static const SpatialMarkerKind geographic = SpatialMarkerKind._(true);

  /// An AR configuration or printable marker with no map position.
  static const SpatialMarkerKind configuration = SpatialMarkerKind._(false);

  final bool isGeographic;

  static SpatialMarkerKind of(ArtMarker marker) =>
      markerHasMapLocation(marker) ? geographic : configuration;
}
