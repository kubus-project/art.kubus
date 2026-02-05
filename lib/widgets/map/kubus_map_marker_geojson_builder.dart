import '../../models/art_marker.dart';
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
    for (final marker in markers) {
      if (shouldAbort()) return const <Map<String, dynamic>>[];
      final feature = await buildMarkerFeature(marker);
      if (shouldAbort()) return const <Map<String, dynamic>>[];
      if (feature.isNotEmpty) features.add(feature);
    }
  }

  // Defensive: ensure the list is not modified from the outside.
  return List<Map<String, dynamic>>.unmodifiable(features);
}
