import '../../features/map/shared/map_marker_collision_utils.dart';
import '../../models/art_marker.dart';
import '../../utils/grid_utils.dart';
import 'kubus_map_marker_rendering.dart';

/// Shared helper to build GeoJSON feature lists for map markers.
///
/// Both mobile and desktop map screens share this loop structure:
/// - (optional) pseudo-cluster markers by grid level
/// - emit either marker features or cluster features
///
/// This function keeps the screens in control of how individual features are
/// built (properties, icon IDs, selection state, etc.), while unifying the
/// higher-level iteration and clustering behavior.
///
/// Even when zoom-based clustering is disabled, markers at the exact same
/// position are always collapsed into a single cluster feature with a count
/// badge so that only one icon is shown per location.
Future<List<Map<String, dynamic>>> kubusBuildMarkerFeatureList({
  required List<ArtMarker> markers,
  required bool useClustering,
  required double zoom,
  required int Function(double zoom) clusterGridLevelForZoom,
  required bool sortClustersBySizeDesc,
  required bool Function() shouldAbort,
  required Future<Map<String, dynamic>> Function(ArtMarker marker)
      buildMarkerFeature,
  required Future<Map<String, dynamic>> Function(KubusClusterBucket cluster)
      buildClusterFeature,
}) async {
  if (markers.isEmpty) return const <Map<String, dynamic>>[];

  final features = <Map<String, dynamic>>[];

  if (useClustering) {
    final level = clusterGridLevelForZoom(zoom);
    final clusters = kubusClusterMarkersByGridLevel(
      markers,
      level,
      sortBySizeDesc: sortClustersBySizeDesc,
    );

    for (final cluster in clusters) {
      if (shouldAbort()) return const <Map<String, dynamic>>[];

      if (cluster.markers.length == 1) {
        final feature = await buildMarkerFeature(cluster.markers.first);
        if (shouldAbort()) return const <Map<String, dynamic>>[];
        if (feature.isNotEmpty) features.add(feature);
      } else {
        final feature = await buildClusterFeature(cluster);
        if (shouldAbort()) return const <Map<String, dynamic>>[];
        if (feature.isNotEmpty) features.add(feature);
      }
    }
  } else {
    // Even without zoom-based clustering, group markers that occupy the
    // exact same coordinates so the map shows one icon with a count badge
    // instead of overlapping icons.
    final groups = _groupByExactPosition(markers);

    for (final group in groups) {
      if (shouldAbort()) return const <Map<String, dynamic>>[];

      if (group.length == 1) {
        final feature = await buildMarkerFeature(group.first);
        if (shouldAbort()) return const <Map<String, dynamic>>[];
        if (feature.isNotEmpty) features.add(feature);
      } else {
        final centroid = group.first.position;
        final bucket = KubusClusterBucket(
          cell: GridUtils.gridCellForLevel(centroid, 20),
          markers: List<ArtMarker>.unmodifiable(group),
          centroid: centroid,
          sameCoordinateKey: mapMarkerCoordinateKey(centroid),
        );
        final feature = await buildClusterFeature(bucket);
        if (shouldAbort()) return const <Map<String, dynamic>>[];
        if (feature.isNotEmpty) features.add(feature);
      }
    }
  }

  // Defensive: ensure the list is not modified from the outside.
  return List<Map<String, dynamic>>.unmodifiable(features);
}

/// Groups markers that share the exact same latitude and longitude.
///
/// Returns a list of groups; each group contains one or more markers.
List<List<ArtMarker>> _groupByExactPosition(List<ArtMarker> markers) {
  return groupMarkersByCoordinateKey(markers).values.toList();
}
