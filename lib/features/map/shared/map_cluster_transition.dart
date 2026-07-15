import 'dart:math' as math;

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

double kubusClusterRegroupProgress({
  required Iterable<double> entryOpacities,
  required double startOpacity,
}) {
  // Viewport entry state is intentionally sparse: off-screen features are
  // represented by opacity zero so they do not animate when panning. A regroup
  // transition must be driven only by its visible soft-regroup participants;
  // otherwise one off-screen marker pins the entire topology at its origin.
  final participants = entryOpacities
      .where((opacity) => opacity >= startOpacity)
      .toList(growable: false);
  if (participants.isEmpty) return 1.0;
  final opacity = participants.reduce(math.min).clamp(0.0, 1.0);
  if (startOpacity >= 1.0) return 1.0;
  return ((opacity - startOpacity) / (1.0 - startOpacity))
      .clamp(0.0, 1.0)
      .toDouble();
}
