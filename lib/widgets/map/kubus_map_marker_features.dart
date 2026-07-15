import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../models/art_marker.dart';
import '../../features/map/controller/kubus_map_controller.dart';
import '../../features/map/shared/map_marker_collision_config.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/map_marker_icon_ids.dart';
import '../../utils/maplibre_style_utils.dart';
import '../art_marker_cube.dart';
import 'kubus_map_marker_rendering.dart';

/// Shared feature builders for marker and cluster GeoJSON.
///
/// These helpers are used by both mobile (`MapScreen`) and desktop
/// (`DesktopMapScreen`) to keep GeoJSON feature properties stable.
Future<Map<String, dynamic>> kubusMarkerFeatureFor({
  required ml.MapLibreMapController controller,
  required Set<String> registeredMapImages,
  required ArtMarker marker,
  required bool isDark,
  required ColorScheme scheme,
  required KubusColorRoles roles,
  required double pixelRatio,
  required bool Function() shouldAbort,
  required IconData Function(ArtMarkerType type) resolveMarkerIcon,
  required Color Function(ArtMarker marker) resolveMarkerBaseColor,
  LatLng? positionOverride,
  double entryScale = 1.0,
  double entryOpacity = 1.0,
  bool spiderfied = false,
  String? coordinateKey,
  int entrySerial = 0,
}) async {
  if (shouldAbort()) return const <String, dynamic>{};

  final typeName = marker.type.name;
  final tier = marker.signalTier;
  final shape = ArtMapMarkerShape.forType(marker.type);
  final baseColor = resolveMarkerBaseColor(marker);
  final colorHex = MapLibreStyleUtils.hexRgb(baseColor);
  final iconId = MapMarkerIconIds.markerBase(
    typeName: typeName,
    tierName: tier.name,
    isDark: isDark,
    promoted: marker.isPromoted,
  );
  final selectedIconId = MapMarkerIconIds.markerSelected(
    typeName: typeName,
    tierName: tier.name,
    isDark: isDark,
    promoted: marker.isPromoted,
  );

  if (!registeredMapImages.contains(iconId)) {
    final bytes = await ArtMarkerCubeIconRenderer.renderMarkerPng(
      baseColor: baseColor,
      icon: resolveMarkerIcon(marker.type),
      tier: tier,
      shape: shape,
      scheme: scheme,
      roles: roles,
      isDark: isDark,
      forceGlow: false,
      showPromotionStar: marker.isPromoted,
      pixelRatio: pixelRatio,
    );

    if (shouldAbort()) return const <String, dynamic>{};
    try {
      await controller.addImage(iconId, bytes);
      registeredMapImages.add(iconId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('kubusMarkerFeatureFor: addImage failed ($iconId): $e');
      }
      return const <String, dynamic>{};
    }
  }

  final position = positionOverride ?? marker.position;

  return <String, dynamic>{
    'type': 'Feature',
    'id': marker.id,
    'properties': <String, dynamic>{
      'id': marker.id,
      'markerId': marker.id,
      'kind': 'marker',
      'icon': iconId,
      'iconSelected': selectedIconId,
      'markerType': typeName,
      'color': colorHex,
      'entryScale': entryScale.clamp(
        MapMarkerCollisionConfig.entryStartScale,
        1.2,
      ),
      'entryOpacity': entryOpacity.clamp(0.0, 1.0),
      'isSpiderfied': spiderfied,
      'coordinateKey': coordinateKey,
      'entrySerial': entrySerial,
    },
    'geometry': <String, dynamic>{
      'type': 'Point',
      'coordinates': <double>[position.longitude, position.latitude],
    },
  };
}

@immutable
class KubusClusterEntryValues {
  const KubusClusterEntryValues({required this.scale, required this.opacity});

  final double scale;
  final double opacity;
}

/// Entry-animation values for a cluster, derived from its member markers.
///
/// Uses the MAX scale/opacity across members so a cluster that absorbs an
/// already-visible marker never blinks out, while clusters made only of
/// still-animating markers pop in alongside them. Falls back to fully visible
/// when member render state is unavailable.
KubusClusterEntryValues kubusClusterEntryValues(
  KubusClusterBucket cluster,
  Map<String, KubusRenderedMarker>? renderById,
) {
  if (renderById == null || renderById.isEmpty) {
    return const KubusClusterEntryValues(scale: 1.0, opacity: 1.0);
  }
  var scale = 0.0;
  var opacity = 0.0;
  var any = false;
  for (final marker in cluster.markers) {
    final rendered = renderById[marker.id];
    if (rendered == null) continue;
    any = true;
    if (rendered.entryScale > scale) scale = rendered.entryScale;
    if (rendered.entryOpacity > opacity) opacity = rendered.entryOpacity;
  }
  if (!any) return const KubusClusterEntryValues(scale: 1.0, opacity: 1.0);
  return KubusClusterEntryValues(scale: scale, opacity: opacity);
}

Future<Map<String, dynamic>> kubusClusterFeatureFor({
  required ml.MapLibreMapController controller,
  required Set<String> registeredMapImages,
  required KubusClusterBucket cluster,
  required bool isDark,
  required ColorScheme scheme,
  required KubusColorRoles roles,
  required double pixelRatio,
  required bool Function() shouldAbort,
  required IconData Function(ArtMarkerType type) resolveMarkerIcon,
  double entryScale = 1.0,
  double entryOpacity = 1.0,
}) async {
  if (shouldAbort()) return const <String, dynamic>{};

  final label =
      cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
  final renderData = kubusClusterBadgeRenderData(
    cluster.markers,
    scheme: scheme,
    roles: roles,
    resolveIcon: resolveMarkerIcon,
  );
  final iconId = MapMarkerIconIds.cluster(
    categorySignature: renderData.signature,
    label: label,
    isDark: isDark,
  );
  final baseColor = renderData.baseColor;
  final colorHex = MapLibreStyleUtils.hexRgb(baseColor);

  if (!registeredMapImages.contains(iconId)) {
    final bytes = await ArtMarkerCubeIconRenderer.renderClusterPng(
      count: cluster.markers.length,
      baseColor: baseColor,
      scheme: scheme,
      isDark: isDark,
      categories: renderData.badges,
      pixelRatio: pixelRatio,
    );

    if (shouldAbort()) return const <String, dynamic>{};
    try {
      await controller.addImage(iconId, bytes);
      registeredMapImages.add(iconId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('kubusClusterFeatureFor: addImage failed ($iconId): $e');
      }
      return const <String, dynamic>{};
    }
  }

  final center = cluster.centroid;
  final isSameCoordinateCluster =
      cluster.sameCoordinateKey != null && cluster.markers.length > 1;
  final id = isSameCoordinateCluster
      ? 'cluster_same:${cluster.sameCoordinateKey}'
      : 'cluster:${cluster.cell.anchorKey}';
  return <String, dynamic>{
    'type': 'Feature',
    'id': id,
    'properties': <String, dynamic>{
      'id': id,
      'kind': 'cluster',
      'icon': iconId,
      'color': colorHex,
      'lat': center.latitude,
      'lng': center.longitude,
      'renderMode': 'cluster',
      'sameCoordinateKey': cluster.sameCoordinateKey,
      'clusterCount': cluster.markers.length,
      'clusterMemberIds': <String>[
        for (final marker in cluster.markers) marker.id,
      ]..sort(),
      // Clusters take part in the shared entry animation (viewport entry and
      // soft regroup) via the same expression-driven properties as markers.
      'entryScale': entryScale.clamp(
        MapMarkerCollisionConfig.entryStartScale,
        1.2,
      ),
      'entryOpacity': entryOpacity.clamp(0.0, 1.0),
    },
    'geometry': <String, dynamic>{
      'type': 'Point',
      'coordinates': <double>[center.longitude, center.latitude],
    },
  };
}
