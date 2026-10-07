import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

@immutable
class KubusClusterTransitionNode {
  const KubusClusterTransitionNode({
    required this.id,
    required this.memberIds,
    required this.position,
  });

  final String id;
  final Set<String> memberIds;
  final LatLng position;
}

/// Finds the visual origin of [target] in the previously rendered topology.
///
/// Splits originate at their parent centroid. Merges originate at the weighted
/// centroid of their prior children, so both directions communicate continuity.
LatLng? resolveKubusClusterTransitionOrigin({
  required KubusClusterTransitionNode target,
  required List<KubusClusterTransitionNode> previous,
}) {
  var latitude = 0.0;
  var longitude = 0.0;
  var weight = 0;
  for (final node in previous) {
    final overlap = node.memberIds.intersection(target.memberIds).length;
    if (overlap == 0) continue;
    latitude += node.position.latitude * overlap;
    longitude += node.position.longitude * overlap;
    weight += overlap;
  }
  if (weight == 0) return null;
  return LatLng(latitude / weight, longitude / weight);
}

LatLng interpolateKubusClusterPosition(
  LatLng from,
  LatLng to,
  double progress,
) {
  final t = progress.clamp(0.0, 1.0).toDouble();
  return LatLng(
    from.latitude + ((to.latitude - from.latitude) * t),
    from.longitude + ((to.longitude - from.longitude) * t),
  );
}

String kubusClusterTopologySignature(
  List<KubusClusterTransitionNode> nodes,
) {
  final parts = <String>[
    for (final node in nodes)
      '${node.id}:${(node.memberIds.toList()..sort()).join(',')}',
  ]..sort();
  return parts.join('|');
}

/// Regroup progress (0..1) of one feature from its own entry opacity.
///
/// A soft regroup entrance runs from [startOpacity] to 1. Viewport entry state
/// is intentionally sparse: off-screen features are kept at opacity zero so
/// they do not animate when panning, and a first-time entrance starts from
/// zero. A feature below [startOpacity] is therefore not part of the regroup
/// and is drawn at its target, so it can never pin itself, or anything else,
/// to an old origin. Each feature progresses on its own, which lets a
/// dissolving cluster fan out in a staggered wave.
double kubusClusterRegroupFeatureProgress({
  required double entryOpacity,
  required double startOpacity,
}) {
  if (startOpacity >= 1.0) return 1.0;
  if (entryOpacity < startOpacity) return 1.0;
  return ((entryOpacity - startOpacity) / (1.0 - startOpacity))
      .clamp(0.0, 1.0)
      .toDouble();
}
