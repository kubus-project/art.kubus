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

  /// Cluster grid level for the current zoom, shared by mobile + desktop.
  ///
  /// Markers merge into a cluster when they fall inside the same diagonal grid
  /// cell. The level is derived from a target on-screen cell size that tapers
  /// with zoom (see [clusterTargetSpacingPx]): wide grouping far out, so the
  /// world reads as a few coherent groups, narrowing as the camera approaches
  /// a place so individual markers separate before [clusterMaxZoom].
  /// A grid cell measures `256 * 2^(zoom - level)` screen px, so levels must
  /// track the camera zoom; fixed small levels produce cells thousands of
  /// pixels wide and collapse the whole viewport into one cluster.
  static int clusterGridLevelForZoom(double zoom) {
    final level = GridUtils.resolvePrimaryGridLevel(
      zoom,
      targetScreenSpacing: clusterTargetSpacingPx(zoom),
    );
    return level.clamp(3, 14);
  }

  /// Target on-screen grouping distance for [zoom], in logical px.
  ///
  /// Banded rather than continuous: the grid level is an integer, and a
  /// continuous target would move the rounding point with every frame of a
  /// zoom and make the topology flicker between levels. Bands step down
  /// monotonically (far > mid > near).
  static double clusterTargetSpacingPx(double zoom) {
    if (!zoom.isFinite || zoom < 5.0) return 116.0;
    if (zoom < 7.5) return 100.0;
    if (zoom < 10.0) return 84.0;
    return 68.0;
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
