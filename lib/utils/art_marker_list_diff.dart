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
}

