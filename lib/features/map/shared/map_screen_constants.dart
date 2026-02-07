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
  static const String cubeSourceId = 'kubus_marker_cubes';
  static const String cubeLayerId = 'kubus_marker_cubes_layer';
  static const String cubeIconLayerId = 'kubus_marker_cubes_icon_layer';
  static const String locationSourceId = 'kubus_user_location';
  static const String locationLayerId = 'kubus_user_location_layer';
  static const String pendingSourceId = 'kubus_pending_marker';
  static const String pendingLayerId = 'kubus_pending_marker_layer';

  // ---------------------------------------------------------------------------
  // Clustering
  // ---------------------------------------------------------------------------
  static const double clusterMaxZoom = 12.0;

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
  static const Duration cameraUpdateThrottle =
      Duration(milliseconds: 16); // ~60 fps

  // ---------------------------------------------------------------------------
  // Pre-built MapLayersIds (mobile -- no pending marker support)
  // ---------------------------------------------------------------------------
  static const MapLayersIds mobileLayerIds = MapLayersIds(
    markerSourceId: markerSourceId,
    cubeSourceId: cubeSourceId,
    locationSourceId: locationSourceId,
    markerLayerId: markerLayerId,
    markerHitboxLayerId: markerHitboxLayerId,
    cubeLayerId: cubeLayerId,
    cubeIconLayerId: cubeIconLayerId,
    locationLayerId: locationLayerId,
    markerHitboxImageId: markerHitboxImageId,
  );

  // ---------------------------------------------------------------------------
  // Pre-built MapLayersIds (desktop -- with pending marker support)
  // ---------------------------------------------------------------------------
  static const MapLayersIds desktopLayerIds = MapLayersIds(
    markerSourceId: markerSourceId,
    cubeSourceId: cubeSourceId,
    locationSourceId: locationSourceId,
    markerLayerId: markerLayerId,
    markerHitboxLayerId: markerHitboxLayerId,
    cubeLayerId: cubeLayerId,
    cubeIconLayerId: cubeIconLayerId,
    locationLayerId: locationLayerId,
    markerHitboxImageId: markerHitboxImageId,
    pendingSourceId: pendingSourceId,
    pendingLayerId: pendingLayerId,
  );
}
