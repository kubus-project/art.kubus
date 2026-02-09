import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../models/art_marker.dart';
import '../../features/map/shared/map_marker_collision_config.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/map_marker_icon_ids.dart';
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
  final iconId = MapMarkerIconIds.markerBase(
    typeName: typeName,
    tierName: tier.name,
    isDark: isDark,
  );
  final selectedIconId = MapMarkerIconIds.markerSelected(
    typeName: typeName,
    tierName: tier.name,
    isDark: isDark,
  );

  if (!registeredMapImages.contains(iconId)) {
    final baseColor = resolveMarkerBaseColor(marker);
    final bytes = await ArtMarkerCubeIconRenderer.renderMarkerPng(
      baseColor: baseColor,
      icon: resolveMarkerIcon(marker.type),
      tier: tier,
      scheme: scheme,
      roles: roles,
      isDark: isDark,
      forceGlow: false,
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

Future<Map<String, dynamic>> kubusClusterFeatureFor({
  required ml.MapLibreMapController controller,
  required Set<String> registeredMapImages,
  required KubusClusterBucket cluster,
  required bool isDark,
  required ColorScheme scheme,
  required KubusColorRoles roles,
  required double pixelRatio,
  required bool Function() shouldAbort,
}) async {
  if (shouldAbort()) return const <String, dynamic>{};

  final first = cluster.markers.first;
  final typeName = first.type.name;
  final label = cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
  final iconId = MapMarkerIconIds.cluster(
    typeName: typeName,
    label: label,
    isDark: isDark,
  );

  if (!registeredMapImages.contains(iconId)) {
    final baseColor = AppColorUtils.markerSubjectColor(
      markerType: typeName,
      metadata: first.metadata,
      scheme: scheme,
      roles: roles,
    );

    final bytes = await ArtMarkerCubeIconRenderer.renderClusterPng(
      count: cluster.markers.length,
      baseColor: baseColor,
      scheme: scheme,
      isDark: isDark,
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
      'lat': center.latitude,
      'lng': center.longitude,
      'renderMode': 'cluster',
      'sameCoordinateKey': cluster.sameCoordinateKey,
      'clusterCount': cluster.markers.length,
    },
    'geometry': <String, dynamic>{
      'type': 'Point',
      'coordinates': <double>[center.longitude, center.latitude],
    },
  };
}
