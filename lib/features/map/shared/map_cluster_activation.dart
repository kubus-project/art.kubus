import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import '../../../utils/grid_utils.dart';

/// A deterministic camera target for opening one pseudo-cluster.
@immutable
class KubusClusterActivationPlan {
  const KubusClusterActivationPlan({
    required this.center,
    required this.southwest,
    required this.northeast,
    required this.targetZoom,
    required this.memberIds,
  });

  final LatLng center;
  final LatLng southwest;
  final LatLng northeast;
  final double targetZoom;
  final Set<String> memberIds;
}

/// Resolves the cluster members from the same grid function used by rendering,
/// then finds the first zoom at which those members occupy multiple cells.
///
/// This makes cluster activation describe the data topology instead of applying
/// one arbitrary zoom increment to every cluster. Camera travel is capped so a
/// single activation remains calm even when a cluster spans many grid levels.
KubusClusterActivationPlan? resolveKubusClusterActivationPlan({
  required List<ArtMarker> markers,
  required String clusterFeatureId,
  required String clusterIdPrefix,
  required double currentZoom,
  required double maxZoom,
  required int Function(double zoom) gridLevelForZoom,
  double searchStep = 0.25,
  double maxZoomTravel = 3.0,
  double settlePastSplit = 0.25,
}) {
  if (!clusterFeatureId.startsWith(clusterIdPrefix)) return null;
  if (!currentZoom.isFinite || !maxZoom.isFinite || searchStep <= 0) {
    return null;
  }

  final anchorKey = clusterFeatureId.substring(clusterIdPrefix.length);
  if (anchorKey.isEmpty) return null;
  final currentLevel = gridLevelForZoom(currentZoom);
  final members = markers
      .where((marker) =>
          marker.hasValidPosition &&
          GridUtils.gridCellForLevel(marker.position, currentLevel).anchorKey ==
              anchorKey)
      .toList(growable: false);
  if (members.length < 2) return null;

  var minLat = members.first.position.latitude;
  var maxLat = minLat;
  var minLng = members.first.position.longitude;
  var maxLng = minLng;
  var sumLat = 0.0;
  var sumLng = 0.0;
  for (final marker in members) {
    final position = marker.position;
    minLat = math.min(minLat, position.latitude);
    maxLat = math.max(maxLat, position.latitude);
    minLng = math.min(minLng, position.longitude);
    maxLng = math.max(maxLng, position.longitude);
    sumLat += position.latitude;
    sumLng += position.longitude;
  }

  final searchLimit = math.min(maxZoom, currentZoom + maxZoomTravel);
  double? splitZoom;
  for (var zoom = currentZoom + searchStep;
      zoom <= searchLimit + 0.000001;
      zoom += searchStep) {
    final level = gridLevelForZoom(zoom);
    final childCells = <String>{
      for (final marker in members)
        GridUtils.gridCellForLevel(marker.position, level).anchorKey,
    };
    if (childCells.length > 1) {
      splitZoom = zoom;
      break;
    }
  }

  final fallbackZoom = math.min(currentZoom + 1.0, maxZoom);
  final targetZoom = math
      .min(
          (splitZoom ?? fallbackZoom) +
              (splitZoom == null ? 0 : settlePastSplit),
          maxZoom)
      .toDouble();
  return KubusClusterActivationPlan(
    center: LatLng(sumLat / members.length, sumLng / members.length),
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
    targetZoom: targetZoom,
    memberIds: Set<String>.unmodifiable(
      members.map((marker) => marker.id),
    ),
  );
}
