import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../models/art_marker.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/grid_utils.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/map_marker_icon_ids.dart';
import '../art_marker_cube.dart';

/// A grouped set of markers for pseudo-clustering.
///
/// Both mobile and desktop map screens use this to create stable marker clusters
/// without relying on MapLibre's runtime clustering.
@immutable
class KubusClusterBucket {
  const KubusClusterBucket({
    required this.cell,
    required this.markers,
    required this.centroid,
  });

  final GridCell cell;
  final List<ArtMarker> markers;
  final LatLng centroid;
}

/// Helper for batched icon pre-registration.
@immutable
class KubusIconRenderTask {
  const KubusIconRenderTask({
    required this.iconId,
    required this.marker,
    required this.cluster,
    required this.isCluster,
    required this.selected,
  });

  final String iconId;
  final ArtMarker? marker;
  final KubusClusterBucket? cluster;
  final bool isCluster;
  final bool selected;
}

/// Clusters markers by [GridCell] at [level].
///
/// If [sortBySizeDesc] is true, clusters are returned largest-first. Mobile uses
/// this ordering to improve hitbox reliability when multiple clusters overlap.
List<KubusClusterBucket> kubusClusterMarkersByGridLevel(
  List<ArtMarker> markers,
  int level, {
  bool sortBySizeDesc = false,
}) {
  if (markers.isEmpty) return const <KubusClusterBucket>[];

  final Map<String, GridCell> cellsByKey = <String, GridCell>{};
  final Map<String, List<ArtMarker>> markersByKey = <String, List<ArtMarker>>{};

  for (final marker in markers) {
    final cell = GridUtils.gridCellForLevel(marker.position, level);
    final key = cell.anchorKey;
    cellsByKey.putIfAbsent(key, () => cell);
    (markersByKey[key] ??= <ArtMarker>[]).add(marker);
  }

  final result = <KubusClusterBucket>[];
  for (final entry in markersByKey.entries) {
    final key = entry.key;
    final bucketMarkers = entry.value;
    double sumLat = 0.0;
    double sumLng = 0.0;
    for (final marker in bucketMarkers) {
      sumLat += marker.position.latitude;
      sumLng += marker.position.longitude;
    }
    final count = bucketMarkers.length;
    final centroid = LatLng(sumLat / count, sumLng / count);
    result.add(
      KubusClusterBucket(
        cell: cellsByKey[key]!,
        markers: List<ArtMarker>.unmodifiable(bucketMarkers),
        centroid: centroid,
      ),
    );
  }
  if (sortBySizeDesc) {
    result.sort((a, b) => b.markers.length.compareTo(a.markers.length));
  }
  return result;
}

/// Pre-registers marker icons in parallel batches to avoid waterfall.
///
/// This is shared by both `MapScreen` and `DesktopMapScreen`.
Future<void> kubusPreregisterMarkerIcons({
  required ml.MapLibreMapController controller,
  required Set<String> registeredMapImages,
  required List<ArtMarker> markers,
  required bool isDark,
  required bool useClustering,
  required double zoom,
  required int Function(double zoom) clusterGridLevelForZoom,
  required bool sortClustersBySizeDesc,
  required ColorScheme scheme,
  required KubusColorRoles roles,
  required double pixelRatio,
  required IconData Function(ArtMarkerType type) resolveMarkerIcon,
  required Color Function(ArtMarker marker) resolveMarkerBaseColor,
}) async {
  final toRender = <KubusIconRenderTask>[];

  if (useClustering) {
    final level = clusterGridLevelForZoom(zoom);
    final clusters = kubusClusterMarkersByGridLevel(
      markers,
      level,
      sortBySizeDesc: sortClustersBySizeDesc,
    );

    for (final cluster in clusters) {
      if (cluster.markers.length == 1) {
        final marker = cluster.markers.first;
        final typeName = marker.type.name;
        final tier = marker.signalTier;
        final baseIconId = MapMarkerIconIds.markerBase(
          typeName: typeName,
          tierName: tier.name,
          isDark: isDark,
        );
        final selectedIconId = MapMarkerIconIds.markerSelected(
          typeName: typeName,
          tierName: tier.name,
          isDark: isDark,
        );

        if (!registeredMapImages.contains(baseIconId)) {
          toRender.add(
            KubusIconRenderTask(
              iconId: baseIconId,
              marker: marker,
              cluster: null,
              isCluster: false,
              selected: false,
            ),
          );
        }
        if (!registeredMapImages.contains(selectedIconId)) {
          toRender.add(
            KubusIconRenderTask(
              iconId: selectedIconId,
              marker: marker,
              cluster: null,
              isCluster: false,
              selected: true,
            ),
          );
        }
      } else {
        final first = cluster.markers.first;
        final typeName = first.type.name;
        final label = cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
        final iconId = MapMarkerIconIds.cluster(
          typeName: typeName,
          label: label,
          isDark: isDark,
        );

        if (!registeredMapImages.contains(iconId)) {
          toRender.add(
            KubusIconRenderTask(
              iconId: iconId,
              marker: null,
              cluster: cluster,
              isCluster: true,
              selected: false,
            ),
          );
        }
      }
    }
  } else {
    // Even without zoom-based clustering, group markers at the exact same
    // position so cluster icons are pre-registered for them.
    final groups = _groupByExactPosition(markers);

    for (final group in groups) {
      if (group.length == 1) {
        final marker = group.first;
        final typeName = marker.type.name;
        final tier = marker.signalTier;
        final baseIconId = MapMarkerIconIds.markerBase(
          typeName: typeName,
          tierName: tier.name,
          isDark: isDark,
        );
        final selectedIconId = MapMarkerIconIds.markerSelected(
          typeName: typeName,
          tierName: tier.name,
          isDark: isDark,
        );

        if (!registeredMapImages.contains(baseIconId)) {
          toRender.add(
            KubusIconRenderTask(
              iconId: baseIconId,
              marker: marker,
              cluster: null,
              isCluster: false,
              selected: false,
            ),
          );
        }
        if (!registeredMapImages.contains(selectedIconId)) {
          toRender.add(
            KubusIconRenderTask(
              iconId: selectedIconId,
              marker: marker,
              cluster: null,
              isCluster: false,
              selected: true,
            ),
          );
        }
      } else {
        final first = group.first;
        final typeName = first.type.name;
        final label = group.length > 99 ? '99+' : '${group.length}';
        final iconId = MapMarkerIconIds.cluster(
          typeName: typeName,
          label: label,
          isDark: isDark,
        );

        if (!registeredMapImages.contains(iconId)) {
          final centroid = first.position;
          final bucket = KubusClusterBucket(
            cell: GridUtils.gridCellForLevel(centroid, 20),
            markers: List<ArtMarker>.unmodifiable(group),
            centroid: centroid,
          );
          toRender.add(
            KubusIconRenderTask(
              iconId: iconId,
              marker: null,
              cluster: bucket,
              isCluster: true,
              selected: false,
            ),
          );
        }
      }
    }
  }

  if (toRender.isEmpty) return;

  // De-dupe by iconId.
  final uniqueTasks = <String, KubusIconRenderTask>{};
  for (final task in toRender) {
    uniqueTasks.putIfAbsent(task.iconId, () => task);
  }

  const batchSize = 8;
  final tasks = uniqueTasks.values.toList(growable: false);
  for (var i = 0; i < tasks.length; i += batchSize) {
    final batch = tasks.skip(i).take(batchSize).toList(growable: false);

    await Future.wait(batch.map((task) async {
      if (registeredMapImages.contains(task.iconId)) return;

      try {
        Uint8List bytes;
        if (task.isCluster && task.cluster != null) {
          final first = task.cluster!.markers.first;
          final baseColor = AppColorUtils.markerSubjectColor(
            markerType: first.type.name,
            metadata: first.metadata,
            scheme: scheme,
            roles: roles,
          );
          bytes = await ArtMarkerCubeIconRenderer.renderClusterPng(
            count: task.cluster!.markers.length,
            baseColor: baseColor,
            scheme: scheme,
            isDark: isDark,
            pixelRatio: pixelRatio,
          );
        } else if (task.marker != null) {
          final marker = task.marker!;
          final baseColor = resolveMarkerBaseColor(marker);
          bytes = await ArtMarkerCubeIconRenderer.renderMarkerPng(
            baseColor: baseColor,
            icon: resolveMarkerIcon(marker.type),
            tier: marker.signalTier,
            scheme: scheme,
            roles: roles,
            isDark: isDark,
            forceGlow: task.selected,
            pixelRatio: pixelRatio,
          );
        } else {
          return;
        }

        await controller.addImage(task.iconId, bytes);
        registeredMapImages.add(task.iconId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('kubusPreregisterMarkerIcons: addImage failed (${task.iconId}): $e');
        }
      }
    }));
  }
}

/// Groups markers that share the exact same latitude and longitude.
///
/// Used by icon pre-registration to render cluster icons for same-position
/// markers even when zoom-based clustering is disabled.
List<List<ArtMarker>> _groupByExactPosition(List<ArtMarker> markers) {
  final Map<String, List<ArtMarker>> grouped = <String, List<ArtMarker>>{};
  for (final marker in markers) {
    final key =
        '${marker.position.latitude.toStringAsFixed(7)},${marker.position.longitude.toStringAsFixed(7)}';
    (grouped[key] ??= <ArtMarker>[]).add(marker);
  }
  return grouped.values.toList();
}
