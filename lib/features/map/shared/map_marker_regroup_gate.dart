import 'map_marker_lod.dart';

/// What a zoom change did to the marker source.
enum KubusMarkerRegroup {
  /// Nothing the marker source depends on changed.
  none,

  /// Same topology, different artwork (a level-of-detail boundary was crossed):
  /// the source is rewritten, no regroup animation.
  visual,

  /// Clustering switched on/off or crossed a grid level: markers regroup, so
  /// the new arrangement eases in.
  topology,
}

/// Decides, per zoom change, whether the marker source must be rebuilt.
///
/// Mobile and desktop share this so the rule exists once. It remembers the
/// last cluster mode, grid level and level-of-detail flags, and reports the
/// strongest change since the previous call.
class KubusMarkerRegroupGate {
  bool? _clustering;
  int? _gridLevel;
  bool? _artwork;
  int? _coverStage;

  KubusMarkerRegroup update({
    required double zoom,
    required double clusterMaxZoom,
    required int Function(double zoom) gridLevelForZoom,
  }) {
    final clustering = zoom < clusterMaxZoom;
    final gridLevel = clustering ? gridLevelForZoom(zoom) : -1;
    final artwork = KubusMarkerLod.needsMarkerArtwork(zoom);
    final coverStage = KubusMarkerLod.coverStageForZoom(zoom);

    final topology = clustering != _clustering || gridLevel != _gridLevel;
    final visual = artwork != _artwork || coverStage != _coverStage;
    _clustering = clustering;
    _gridLevel = gridLevel;
    _artwork = artwork;
    _coverStage = coverStage;

    if (topology) return KubusMarkerRegroup.topology;
    if (visual) return KubusMarkerRegroup.visual;
    return KubusMarkerRegroup.none;
  }
}
