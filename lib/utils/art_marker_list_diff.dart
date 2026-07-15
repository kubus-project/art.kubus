import '../models/art_marker.dart';

class ArtMarkerListDiff {
  static List<ArtMarker> mergeById({
    required List<ArtMarker> current,
    required List<ArtMarker> next,
  }) {
    if (current.isEmpty) return List<ArtMarker>.from(next);
    if (next.isEmpty) return <ArtMarker>[];

    final nextById = <String, ArtMarker>{
      for (final marker in next) marker.id: marker,
    };

    final merged = <ArtMarker>[];
    for (final marker in current) {
      final replacement = nextById.remove(marker.id);
      if (replacement != null) merged.add(replacement);
    }
    merged.addAll(nextById.values);
    return merged;
  }

  /// Applies a partial marker response without removing markers that were not
  /// part of that response.
  static List<ArtMarker> upsertById({
    required List<ArtMarker> current,
    required Iterable<ArtMarker> updates,
  }) {
    final byId = <String, ArtMarker>{
      for (final marker in current) marker.id: marker,
    };
    for (final marker in updates) {
      byId[marker.id] = marker;
    }
    return byId.values.toList(growable: false);
  }
}
