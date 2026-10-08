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
///
/// Grouping follows a hysteretic [topologyZoom], not the camera zoom itself:
/// it tracks the camera immediately when zooming in, but on the way out it
/// keeps up to [topologyPlay] of slack before it follows. Entering a finer
/// grouping (or individual markers at the cluster threshold A) therefore
/// happens exactly where it always did, while returning to the coarser one
/// waits until the camera is below `A - topologyPlay`. A camera settling or a
/// trackpad jittering around a boundary no longer swaps the whole marker
/// population back and forth. Level of detail (artwork, cover stage) keeps
/// following the real zoom: it only changes artwork, never the grouping.
class KubusMarkerRegroupGate {
  KubusMarkerRegroupGate({this.topologyPlay = defaultTopologyPlay});

  /// Zoom slack before the grouping follows a zoom-out.
  ///
  /// Derived from the measured behaviour at the street threshold (z12): one
  /// MapLibre mouse-wheel notch moves the camera about 0.15 zoom and a settling
  /// camera or trackpad oscillates by about ±0.06, and each of those used to
  /// swap 6 clusters for 55 individual markers and back. 0.25 absorbs a full
  /// notch plus settle jitter; two notches out (or any deliberate zoom-out)
  /// still regroup. At the threshold the grid cell is ~60 px, so 0.25 zoom of
  /// slack means clusters at most 2^0.25 ≈ 1.19× tighter than their nominal
  /// spacing while it applies.
  static const double defaultTopologyPlay = 0.25;

  final double topologyPlay;

  double? _topologyZoom;
  bool? _clustering;
  int? _gridLevel;
  bool? _artwork;
  int? _coverStage;

  /// The zoom marker grouping is evaluated at for camera [zoom].
  ///
  /// Pure with respect to the latched state: callers that build the marker
  /// source between gate updates get the same answer [update] would store.
  double topologyZoomFor(double zoom) {
    final latched = _topologyZoom;
    if (latched == null || !zoom.isFinite || !latched.isFinite) return zoom;
    if (latched < zoom) return zoom;
    final ceiling = zoom + topologyPlay;
    if (latched > ceiling) return ceiling;
    return latched;
  }

  /// Whether markers are grouped into grid clusters at camera [zoom].
  bool clusteringAt(double zoom, {required double clusterMaxZoom}) =>
      topologyZoomFor(zoom) < clusterMaxZoom;

  KubusMarkerRegroup update({
    required double zoom,
    required double clusterMaxZoom,
    required int Function(double zoom) gridLevelForZoom,
  }) {
    final topologyZoom = topologyZoomFor(zoom);
    _topologyZoom = topologyZoom;
    final clustering = topologyZoom < clusterMaxZoom;
    final gridLevel = clustering ? gridLevelForZoom(topologyZoom) : -1;
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
