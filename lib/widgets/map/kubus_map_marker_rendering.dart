import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../models/art_marker.dart';
import '../../features/map/shared/map_marker_collision_utils.dart';
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
    this.sameCoordinateKey,
  });

  final GridCell cell;
  final List<ArtMarker> markers;
  final LatLng centroid;

  /// Non-null when all markers in this bucket share the same rounded
  /// coordinate key (same-location collision group).
  final String? sameCoordinateKey;
}

/// A single marker category present inside a cluster, with how many markers of
/// that category the cluster contains.
@immutable
class KubusClusterCategory {
  const KubusClusterCategory({required this.type, required this.count});

  final ArtMarkerType type;
  final int count;
}

/// Maximum number of distinct categories rendered into a combined cluster badge.
///
/// Keeps the badge legible: beyond this the remaining (least common) categories
/// are folded into the dominant ones visually.
const int kKubusClusterMaxBadgeCategories = 5;

/// Computes the marker-category composition of [markers], dominant categories
/// first (ties broken by enum order for stable icon ids).
List<KubusClusterCategory> kubusClusterCategoryBreakdown(
  List<ArtMarker> markers,
) {
  final counts = <ArtMarkerType, int>{};
  for (final marker in markers) {
    counts.update(marker.type, (value) => value + 1, ifAbsent: () => 1);
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.index.compareTo(b.key.index);
    });
  return <KubusClusterCategory>[
    for (final entry in entries)
      KubusClusterCategory(type: entry.key, count: entry.value),
  ];
}

/// Stable signature for a cluster's category composition, used to key the
/// combined cluster icon image. Only the dominant categories (capped at
/// [kKubusClusterMaxBadgeCategories]) participate, matching what is rendered.
String kubusClusterCategorySignature(
  List<KubusClusterCategory> breakdown, {
  int max = kKubusClusterMaxBadgeCategories,
}) {
  return breakdown.take(max).map((category) => category.type.name).join('-');
}

/// Bundles everything the renderer needs to draw a combined cluster badge that
/// communicates the categories contained in [markers].
///
/// [signature] keys the cached icon, [badges] are the per-category shape+colour
/// pips (dominant first, capped at [kKubusClusterMaxBadgeCategories]) and
/// [baseColor] is the dominant category colour used for the central body.
({
  String signature,
  Color baseColor,
  List<ClusterCategoryBadge> badges,
}) kubusClusterBadgeRenderData(
  List<ArtMarker> markers, {
  required ColorScheme scheme,
  required KubusColorRoles roles,
}) {
  final breakdown = kubusClusterCategoryBreakdown(markers);
  final signature = kubusClusterCategorySignature(breakdown);
  final shown = breakdown.take(kKubusClusterMaxBadgeCategories);
  final badges = <ClusterCategoryBadge>[
    for (final category in shown)
      ClusterCategoryBadge(
        shape: ArtMapMarkerShape.forType(category.type),
        color: AppColorUtils.markerSubjectColor(
          markerType: category.type.name,
          metadata: null,
          scheme: scheme,
          roles: roles,
        ),
        count: category.count,
      ),
  ];
  final baseColor = badges.isNotEmpty
      ? badges.first.color
      : AppColorUtils.markerSubjectColor(
          markerType: markers.first.type.name,
          metadata: markers.first.metadata,
          scheme: scheme,
          roles: roles,
        );
  return (signature: signature, baseColor: baseColor, badges: badges);
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
        sameCoordinateKey: sharedCoordinateKeyIfSameLocation(bucketMarkers),
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
          promoted: marker.isPromoted,
        );
        final selectedIconId = MapMarkerIconIds.markerSelected(
          typeName: typeName,
          tierName: tier.name,
          isDark: isDark,
          promoted: marker.isPromoted,
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
        final signature = kubusClusterCategorySignature(
          kubusClusterCategoryBreakdown(cluster.markers),
        );
        final label = cluster.markers.length > 99 ? '99+' : '${cluster.markers.length}';
        final iconId = MapMarkerIconIds.cluster(
          categorySignature: signature,
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
          promoted: marker.isPromoted,
        );
        final selectedIconId = MapMarkerIconIds.markerSelected(
          typeName: typeName,
          tierName: tier.name,
          isDark: isDark,
          promoted: marker.isPromoted,
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
        final signature = kubusClusterCategorySignature(
          kubusClusterCategoryBreakdown(group),
        );
        final label = group.length > 99 ? '99+' : '${group.length}';
        final iconId = MapMarkerIconIds.cluster(
          categorySignature: signature,
          label: label,
          isDark: isDark,
        );

        if (!registeredMapImages.contains(iconId)) {
          final centroid = first.position;
          final bucket = KubusClusterBucket(
            cell: GridUtils.gridCellForLevel(centroid, 20),
            markers: List<ArtMarker>.unmodifiable(group),
            centroid: centroid,
            sameCoordinateKey: mapMarkerCoordinateKey(centroid),
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

  final batchSize = kIsWeb ? 3 : 8;
  final tasks = uniqueTasks.values.toList(growable: false);
  for (var i = 0; i < tasks.length; i += batchSize) {
    final batch = tasks.skip(i).take(batchSize).toList(growable: false);

    await Future.wait(batch.map((task) async {
      if (registeredMapImages.contains(task.iconId)) return;

      try {
        Uint8List bytes;
        if (task.isCluster && task.cluster != null) {
          final renderData = kubusClusterBadgeRenderData(
            task.cluster!.markers,
            scheme: scheme,
            roles: roles,
          );
          bytes = await ArtMarkerCubeIconRenderer.renderClusterPng(
            count: task.cluster!.markers.length,
            baseColor: renderData.baseColor,
            scheme: scheme,
            isDark: isDark,
            categories: renderData.badges,
            pixelRatio: pixelRatio,
          );
        } else if (task.marker != null) {
          final marker = task.marker!;
          final baseColor = resolveMarkerBaseColor(marker);
          bytes = await ArtMarkerCubeIconRenderer.renderMarkerPng(
            baseColor: baseColor,
            icon: resolveMarkerIcon(marker.type),
            tier: marker.signalTier,
            shape: ArtMapMarkerShape.forType(marker.type),
            scheme: scheme,
            roles: roles,
            isDark: isDark,
            forceGlow: task.selected,
            showPromotionStar: marker.isPromoted,
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
  return groupMarkersByCoordinateKey(markers).values.toList();
}
