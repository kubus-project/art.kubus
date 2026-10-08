import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// When each marker's entrance starts, relative to the first, in milliseconds.
///
/// Markers are revealed from the viewport centre outwards, so a dense field
/// (a city's individual markers replacing its clusters at the street threshold,
/// or the first markers of a cold load) arrives as one coherent wave from where
/// the visitor is looking, not all at once and not in arbitrary id order.
///
/// The per-marker step is [maxStepMs] for small sets and shrinks so that the
/// whole wave never spans more than [maxSpreadMs]: the reveal stays brief and
/// deliberate however many markers arrive, and the number of animation frames
/// (each a marker source write) is bounded by the spread, not by the count.
///
/// Markers without a known position are revealed last, in id order. Ties are
/// broken by id, so the schedule is deterministic.
Map<String, int> kubusEntryRevealOffsets({
  required Iterable<String> ids,
  required LatLng? Function(String id) positionOf,
  required LatLng? center,
  required int maxStepMs,
  required int maxSpreadMs,
}) {
  final unique = ids.toSet().toList(growable: false);
  if (unique.isEmpty) return const <String, int>{};

  final cosLat = center == null
      ? 1.0
      : math.cos(center.latitude * math.pi / 180.0).abs().clamp(0.05, 1.0);
  double distanceOf(String id) {
    final position = positionOf(id);
    if (position == null || center == null) return double.infinity;
    final dLat = position.latitude - center.latitude;
    var dLng = (position.longitude - center.longitude).abs();
    if (dLng > 180) dLng = 360 - dLng;
    dLng *= cosLat;
    return dLat * dLat + dLng * dLng;
  }

  final distances = <String, double>{
    for (final id in unique) id: distanceOf(id),
  };
  unique.sort((a, b) {
    final byDistance = distances[a]!.compareTo(distances[b]!);
    return byDistance != 0 ? byDistance : a.compareTo(b);
  });

  final count = unique.length;
  final step = count <= 1
      ? 0.0
      : math.min(maxStepMs.toDouble(), maxSpreadMs / (count - 1));
  return <String, int>{
    for (var i = 0; i < count; i++) unique[i]: (i * step).round(),
  };
}
