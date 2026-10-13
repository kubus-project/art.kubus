import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';
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

/// Spatial topology motion owns its clock; a loaded marker's entry opacity is
/// already one and cannot serve as the clock for a later split or merge.
class KubusClusterTopologyTransition {
  KubusClusterTopologyTransition(
      {required this.durationMs, int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
  final int durationMs;
  final int Function() _nowMs;
  List<Map<String, dynamic>> _last = [];
  List<Map<String, dynamic>> _origin = [];
  String _stableSignature = '';
  String? _targetSignature;
  int _startedAt = 0;

  void reset() {
    _last = [];
    _origin = [];
    _stableSignature = '';
    _targetSignature = null;
  }

  Map<String, dynamic> _copy(Map<String, dynamic> feature) => {
        ...feature,
        'properties': Map<String, dynamic>.from(feature['properties'] as Map),
        'geometry': Map<String, dynamic>.from(feature['geometry'] as Map),
      };

  KubusClusterTransitionNode _node(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map;
    final coordinates = (feature['geometry'] as Map)['coordinates'] as List;
    final rawMembers = properties['clusterMemberIds'];
    return KubusClusterTransitionNode(
      id: (properties['id'] ?? feature['id']).toString(),
      memberIds: rawMembers is List
          ? rawMembers.map((id) => id.toString()).toSet()
          : {
              (properties['markerId'] ?? properties['id'] ?? feature['id'])
                  .toString()
            },
      position: LatLng((coordinates[1] as num).toDouble(),
          (coordinates[0] as num).toDouble()),
    );
  }

  void _setPosition(Map<String, dynamic> feature, LatLng position) {
    (feature['geometry'] as Map)['coordinates'] = <double>[
      position.longitude,
      position.latitude
    ];
  }

  /// Mutates one canonical source frame. Returns whether another frame is due.
  bool apply(List<Map<String, dynamic>> features,
      {required bool reduceMotion}) {
    final targets = features.map(_node).toList();
    final signature = kubusClusterTopologySignature(targets);
    if (reduceMotion ||
        _last.isEmpty ||
        (_targetSignature == null && signature == _stableSignature)) {
      _last = features.map(_copy).toList();
      _stableSignature = signature;
      _targetSignature = null;
      _origin = [];
      return false;
    }
    if (_targetSignature != signature) {
      // Retarget from positions currently on screen, including children still
      // travelling into a parent. Never revive the previous target positions.
      _origin = _last.map(_copy).toList();
      _targetSignature = signature;
      _startedAt = _nowMs();
    }
    final previous = _origin.map(_node).toList();
    final raw = ((_nowMs() - _startedAt) / durationMs).clamp(0.0, 1.0);
    final progress = Curves.easeOutCubic.transform(raw.toDouble());
    final targetIds = targets.map((node) => node.id).toSet();
    var spatialContinuity = false;
    for (var index = 0; index < targets.length; index++) {
      final target = targets[index];
      final related = previous
          .where((node) =>
              node.memberIds.intersection(target.memberIds).isNotEmpty)
          .toList();
      if (related.isEmpty) continue;
      final origin = resolveKubusClusterTransitionOrigin(
          target: target, previous: related)!;
      _setPosition(features[index],
          interpolateKubusClusterPosition(origin, target.position, progress));
      if (related.any((node) =>
          node.id != target.id ||
          !setEquals(node.memberIds, target.memberIds))) {
        spatialContinuity = true;
      }
      // A new parent emerges while its existing children converge into it.
      if (related.length > 1 && !related.any((node) => node.id == target.id)) {
        final properties = features[index]['properties'] as Map;
        properties['entryOpacity'] =
            ((properties['entryOpacity'] as num?)?.toDouble() ?? 1) * progress;
      }
    }
    if (raw < 1 && spatialContinuity) {
      for (var index = 0; index < previous.length; index++) {
        final child = previous[index];
        if (targetIds.contains(child.id)) continue;
        KubusClusterTransitionNode? parent;
        var bestOverlap = 0;
        for (final target in targets) {
          final overlap = target.memberIds.intersection(child.memberIds).length;
          if (target.memberIds.length > child.memberIds.length &&
              overlap > bestOverlap) {
            parent = target;
            bestOverlap = overlap;
          }
        }
        if (parent == null) {
          continue; // A split emits children, not an old parent.
        }
        final retiring = _copy(_origin[index]);
        _setPosition(
            retiring,
            interpolateKubusClusterPosition(
                child.position, parent.position, progress));
        final properties = retiring['properties'] as Map;
        properties['transitionRetiring'] = true;
        properties['entryOpacity'] =
            ((properties['entryOpacity'] as num?)?.toDouble() ?? 1) *
                (1 - progress);
        features.add(retiring);
      }
      _last = features.map(_copy).toList();
      return true;
    }
    _last = features.map(_copy).toList();
    _stableSignature = signature;
    _targetSignature = null;
    _origin = [];
    return false;
  }
}
