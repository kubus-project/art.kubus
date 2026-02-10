import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import 'map_marker_collision_config.dart';

/// Builds a stable same-location key using rounded coordinates.
String mapMarkerCoordinateKey(
  LatLng position, {
  int decimals = MapMarkerCollisionConfig.coordinateKeyDecimals,
}) {
  return '${position.latitude.toStringAsFixed(decimals)},${position.longitude.toStringAsFixed(decimals)}';
}

/// Groups markers by rounded same-location key.
Map<String, List<ArtMarker>> groupMarkersByCoordinateKey(
  Iterable<ArtMarker> markers, {
  int decimals = MapMarkerCollisionConfig.coordinateKeyDecimals,
}) {
  final grouped = <String, List<ArtMarker>>{};
  for (final marker in markers) {
    final key = mapMarkerCoordinateKey(marker.position, decimals: decimals);
    (grouped[key] ??= <ArtMarker>[]).add(marker);
  }
  return grouped;
}

/// Returns a coordinate key when every marker belongs to the same rounded
/// location; otherwise returns null.
String? sharedCoordinateKeyIfSameLocation(
  Iterable<ArtMarker> markers, {
  int decimals = MapMarkerCollisionConfig.coordinateKeyDecimals,
}) {
  String? key;
  for (final marker in markers) {
    final next = mapMarkerCoordinateKey(marker.position, decimals: decimals);
    if (key == null) {
      key = next;
      continue;
    }
    if (key != next) return null;
  }
  return key;
}

@immutable
class SpiderfyLayoutConfig {
  const SpiderfyLayoutConfig({
    this.baseRadiusPx = MapMarkerCollisionConfig.spiderfyBaseRadiusPx,
    this.radiusStepPx = MapMarkerCollisionConfig.spiderfyRadiusStepPx,
    this.minSeparationPx = MapMarkerCollisionConfig.spiderfyMinSeparationPx,
    this.minFirstRingCount = MapMarkerCollisionConfig.spiderfyMinFirstRingCount,
  });

  final double baseRadiusPx;
  final double radiusStepPx;
  final double minSeparationPx;
  final int minFirstRingCount;
}

/// Builds deterministic spiderfy offsets around [Offset.zero].
///
/// Offsets are generated ring-by-ring (clockwise from top), with each ring
/// capacity derived from circumference/min-separation.
List<Offset> buildSpiderfyOffsets(
  int count, {
  SpiderfyLayoutConfig config = const SpiderfyLayoutConfig(),
}) {
  if (count <= 0) return const <Offset>[];
  if (count == 1) return const <Offset>[Offset.zero];

  final adaptiveConfig = _adaptiveSpiderfyLayoutConfig(
    count: count,
    base: config,
  );

  final offsets = <Offset>[];
  var remaining = count;
  var ring = 0;

  while (remaining > 0) {
    final radius =
        adaptiveConfig.baseRadiusPx + (ring * adaptiveConfig.radiusStepPx);
    final circumference = 2 * math.pi * radius;
    final ringCapacity = math.max(
      ring == 0 ? adaptiveConfig.minFirstRingCount : 1,
      (circumference / adaptiveConfig.minSeparationPx).floor(),
    );

    final take = math.min(remaining, ringCapacity);
    final angleStep = (2 * math.pi) / take;

    for (var i = 0; i < take; i++) {
      final angle = (-math.pi / 2.0) + (i * angleStep);
      offsets.add(Offset(math.cos(angle) * radius, math.sin(angle) * radius));
    }

    remaining -= take;
    ring += 1;
  }

  return List<Offset>.unmodifiable(offsets);
}

SpiderfyLayoutConfig _adaptiveSpiderfyLayoutConfig({
  required int count,
  required SpiderfyLayoutConfig base,
}) {
  final threshold = MapMarkerCollisionConfig.spiderfyAdaptiveSpacingStartCount;
  if (count <= threshold) return base;

  final overflow = count - threshold;
  final radiusBoost = (overflow *
          MapMarkerCollisionConfig.spiderfyRadiusScalePerExtraMarker)
      .clamp(0.0, MapMarkerCollisionConfig.spiderfyRadiusScaleMaxBoost)
      .toDouble();
  final separationBoost = (overflow *
          MapMarkerCollisionConfig.spiderfySeparationScalePerExtraMarker)
      .clamp(0.0, MapMarkerCollisionConfig.spiderfySeparationScaleMaxBoost)
      .toDouble();

  final radiusScale = 1.0 + radiusBoost;
  final separationScale = 1.0 + separationBoost;
  return SpiderfyLayoutConfig(
    baseRadiusPx: base.baseRadiusPx * radiusScale,
    radiusStepPx: base.radiusStepPx * radiusScale,
    minSeparationPx: base.minSeparationPx * separationScale,
    minFirstRingCount: base.minFirstRingCount,
  );
}
