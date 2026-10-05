import 'dart:math' as math;

import '../../../utils/grid_utils.dart';
import '../map_layers_manager.dart';

/// Shared constants for mobile + desktop map screens.
///
/// Intentionally contains no state, no lifecycle, and no BuildContext.
/// This file exists to eliminate duplicated `static const` declarations
/// across MapScreen and DesktopMapScreen.
abstract final class MapScreenConstants {
  // ---------------------------------------------------------------------------
  // Layer / source IDs (must match MapLayersManager expectations)
  // ---------------------------------------------------------------------------
  static const String markerSourceId = 'kubus_markers';
  static const String markerLayerId = 'kubus_marker_layer';
  static const String markerHitboxLayerId = 'kubus_marker_hitbox_layer';
  static const String markerHitboxImageId = 'kubus_hitbox_square_transparent';
  static const String markerDotLayerId = 'kubus_marker_dot_layer';
  static const String markerPulseLayerId = 'kubus_marker_pulse_layer';
  static const String cubeLayerId = 'kubus_marker_cubes_layer';
  static const String cubeIconLayerId = 'kubus_marker_cubes_icon_layer';
  static const String locationSourceId = 'kubus_user_location';
  static const String locationLayerId = 'kubus_user_location_layer';
  static const String walkingRouteSourceId = 'kubus_walking_route';
  static const String walkingRouteCasingLayerId =
      'kubus_walking_route_casing_layer';
  static const String walkingRouteLayerId = 'kubus_walking_route_layer';
  static const String walkingRouteConnectorLayerId =
      'kubus_walking_route_connector_layer';
  static const String walkingLocationSymbolLayerId =
      'kubus_walking_location_symbol_layer';
  static const String walkingLocationImageId = 'kubus_walking_location_person';
  static const String pendingSourceId = 'kubus_pending_marker';
  static const String pendingLayerId = 'kubus_pending_marker_layer';

  // ---------------------------------------------------------------------------
  // Clustering
  // ---------------------------------------------------------------------------
  static const double clusterMaxZoom = 12.0;

  /// Cluster grid level for the current zoom, shared by mobile + desktop, the
  /// web globe and the flat maps.
  ///
  /// Markers merge into a cluster when they fall inside the same diagonal grid
  /// cell, so a cluster never spans more than the cell's diagonal. The level is
  /// derived from a target on-screen cell size ([clusterTargetSpacingPx]).
  /// Clustering exists to stop markers colliding, not to erase where they are:
  /// the world must read as a distributed field of regional groups and
  /// isolated records, and regroup progressively into region, country, city
  /// and neighbourhood clusters before individual records at [clusterMaxZoom].
  /// A grid cell measures `256 * 2^(zoom - level)` screen px, so levels must
  /// track the camera zoom.
  static int clusterGridLevelForZoom(double zoom) {
    final level = GridUtils.resolvePrimaryGridLevel(
      zoom,
      targetScreenSpacing: clusterTargetSpacingPx(zoom),
    );
    return level.clamp(3, 14);
  }

  /// Widest geographic span (projected metres at the equator, so a Mercator
  /// pixel measure) one world-scale cluster may represent. It is what keeps a
  /// zoomed-out map from folding Lisbon and Ljubljana into one dot just
  /// because the camera is far away.
  static const double clusterMaxSpanMeters = 1500000;

  /// Narrowest grouping distance the span rule may force, in logical px.
  static const double clusterMinSpacingPx = 20;

  /// Target on-screen grouping distance for [zoom], in logical px.
  ///
  /// A continuous, piecewise-linear curve, so the integer grid level is a
  /// monotonic function of zoom (no topology flicker, deterministic membership
  /// when zooming out and back in). It deliberately does **not** widen with
  /// distance: far out it starts tight (~48-56 px) and settles at 64-68 px for
  /// regions and countries, then 60-64 px for cities.
  ///
  /// On top of the curve, [clusterMaxSpanMeters] caps the cell so that at world
  /// scale a cluster is a coherent geographic region (see
  /// [clusterSpanCapPx]). The cap only binds below about zoom 3.
  static double clusterTargetSpacingPx(double zoom) {
    final z = zoom.isFinite ? zoom : 0.0;
    final base = _lerp(z, const <List<double>>[
      [0, 48],
      [3, 56],
      [5, 64],
      [8, 68],
      [10, 64],
      [12, 60],
    ]);
    return math.min(base, math.max(clusterMinSpacingPx, clusterSpanCapPx(z)));
  }

  /// The grouping distance, in px at [zoom], that corresponds to
  /// [clusterMaxSpanMeters] on the ground (equatorial Mercator scale).
  static double clusterSpanCapPx(double zoom) =>
      clusterMaxSpanMeters / (156543.03392 / math.pow(2.0, zoom));

  static double _lerp(double x, List<List<double>> points) {
    if (x <= points.first[0]) return points.first[1];
    for (var i = 1; i < points.length; i++) {
      if (x <= points[i][0]) {
        final a = points[i - 1];
        final b = points[i];
        return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0]);
      }
    }
    return points.last[1];
  }

  // ---------------------------------------------------------------------------
  // Marker refresh thresholds
  // ---------------------------------------------------------------------------
  static const double markerRefreshDistanceMeters = 1200;
  static const Duration markerRefreshInterval = Duration(minutes: 5);

  // ---------------------------------------------------------------------------
  // Cube / 3-D mode
  // ---------------------------------------------------------------------------
  static const double cubePitchThreshold = 5.0;
  static const int markerVisualSyncThrottleMs = 60;

  // ---------------------------------------------------------------------------
  // Camera throttle
  // ---------------------------------------------------------------------------
  static const Duration cameraUpdateThrottle = Duration(
    milliseconds: 16,
  ); // ~60 fps

  // ---------------------------------------------------------------------------
  // Web MapLibre attribution
  // ---------------------------------------------------------------------------
  /// Desktop bottom offset (in CSS px) for the MapLibre attribution control.
  ///
  /// This must be small so the control remains near the bottom edge while still
  /// clearing desktop UI chrome.
  static const double desktopAttributionBottomPx = 12.0;

  // ---------------------------------------------------------------------------
  // Pre-built MapLayersIds (mobile -- no pending marker support)
  // ---------------------------------------------------------------------------
  static const MapLayersIds mobileLayerIds = MapLayersIds(
    markerSourceId: markerSourceId,
    locationSourceId: locationSourceId,
    markerLayerId: markerLayerId,
    markerHitboxLayerId: markerHitboxLayerId,
    markerDotLayerId: markerDotLayerId,
    markerPulseLayerId: markerPulseLayerId,
    cubeLayerId: cubeLayerId,
    cubeIconLayerId: cubeIconLayerId,
    locationLayerId: locationLayerId,
    walkingRouteSourceId: walkingRouteSourceId,
    walkingRouteCasingLayerId: walkingRouteCasingLayerId,
    walkingRouteLayerId: walkingRouteLayerId,
    walkingRouteConnectorLayerId: walkingRouteConnectorLayerId,
    walkingLocationSymbolLayerId: walkingLocationSymbolLayerId,
    walkingLocationImageId: walkingLocationImageId,
    markerHitboxImageId: markerHitboxImageId,
  );

  // ---------------------------------------------------------------------------
  // Pre-built MapLayersIds (desktop -- with pending marker support)
  // ---------------------------------------------------------------------------
  static const MapLayersIds desktopLayerIds = MapLayersIds(
    markerSourceId: markerSourceId,
    locationSourceId: locationSourceId,
    markerLayerId: markerLayerId,
    markerHitboxLayerId: markerHitboxLayerId,
    markerDotLayerId: markerDotLayerId,
    markerPulseLayerId: markerPulseLayerId,
    cubeLayerId: cubeLayerId,
    cubeIconLayerId: cubeIconLayerId,
    locationLayerId: locationLayerId,
    walkingRouteSourceId: walkingRouteSourceId,
    walkingRouteCasingLayerId: walkingRouteCasingLayerId,
    walkingRouteLayerId: walkingRouteLayerId,
    walkingRouteConnectorLayerId: walkingRouteConnectorLayerId,
    walkingLocationSymbolLayerId: walkingLocationSymbolLayerId,
    walkingLocationImageId: walkingLocationImageId,
    markerHitboxImageId: markerHitboxImageId,
    pendingSourceId: pendingSourceId,
    pendingLayerId: pendingLayerId,
  );
}
