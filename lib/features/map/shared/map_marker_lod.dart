import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';

/// Marker level of detail. One identity, three costs:
///
/// * [far]  cheap GPU dots (data colour, cluster size); no marker artwork is
///   rendered or registered.
/// * [mid]  the canonical kubus marker (category shape, signal ring, promotion).
/// * [close] the canonical kubus marker with the artwork cover inside its
///   geometry, for a bounded set of markers.
enum KubusMarkerLodTier { far, mid, close }

abstract final class KubusMarkerLod {
  /// Dots become canonical markers across `[farMaxZoom - blendHalfWidth,
  /// farMaxZoom + blendHalfWidth]`: the dot stays, the marker fades in over it.
  static const double farMaxZoom = 6.0;
  static const double blendHalfWidth = 0.5;

  /// The selected marker is pinned out of clustering, so its cover may show
  /// from here: well before nearby covers, at city scale.
  static const double selectedCoverMinZoom = 10.0;

  /// Nearby covers start downloading/decoding (never rasterising) from here,
  /// one step before they are displayed, so the first covers are warm when the
  /// visitor arrives at street-approach scale.
  static const double coverPrefetchMinZoom = 11.5;

  /// Nearby covers may display from here (street approach). Clusters dissolve
  /// at `MapScreenConstants.clusterMaxZoom` (12), so covers only ever replace
  /// canonical individual markers.
  static const double coverDisplayMinZoom = 12.5;

  /// The cover budget grows with zoom instead of switching to a photo wall:
  /// a small early subset from [coverDisplayMinZoom], more from here, and the
  /// full viewport budget from [coverFullBudgetZoom].
  static const double coverMediumBudgetZoom = 13.5;
  static const double coverFullBudgetZoom = 14.5;

  /// Start of the close tier (covers allowed).
  static const double closeMinZoom = coverDisplayMinZoom;

  static double get blendStartZoom => farMaxZoom - blendHalfWidth;
  static double get blendEndZoom => farMaxZoom + blendHalfWidth;

  static KubusMarkerLodTier tierForZoom(double zoom) {
    if (!zoom.isFinite || zoom < farMaxZoom) return KubusMarkerLodTier.far;
    if (zoom < closeMinZoom) return KubusMarkerLodTier.mid;
    return KubusMarkerLodTier.close;
  }

  /// Whether marker artwork (icon images) must exist for non-selected markers.
  ///
  /// True from the start of the blend band, so the canonical markers are
  /// registered before the opacity ramp reveals them.
  static bool needsMarkerArtwork(double zoom) =>
      zoom.isFinite && zoom >= blendStartZoom;

  /// Whether nearby (non-selected) covers may be displayed.
  static bool allowsCovers(double zoom) =>
      zoom.isFinite && zoom >= coverDisplayMinZoom;

  /// Whether the selected marker may display its cover.
  static bool allowsSelectedCover(double zoom) =>
      zoom.isFinite && zoom >= selectedCoverMinZoom;

  /// Whether likely covers should be fetched and decoded ahead of display.
  static bool allowsCoverPrefetch(double zoom) =>
      zoom.isFinite && zoom >= coverPrefetchMinZoom;

  /// Whether a settled camera at [zoom] should re-plan covers (display or
  /// prefetch). Screens call this on camera idle.
  static bool plansCoversAt(double zoom) => allowsSelectedCover(zoom);

  /// Discrete cover stage for [zoom]. Crossing a stage changes what the marker
  /// source shows (or prefetches), so the regroup gate and the sync engine
  /// compare stages rather than one boolean.
  ///
  /// 0 none, 1 selected only, 2 prefetch, 3 early, 4 medium, 5 full.
  static int coverStageForZoom(double zoom) {
    if (!zoom.isFinite || zoom < selectedCoverMinZoom) return 0;
    if (zoom < coverPrefetchMinZoom) return 1;
    if (zoom < coverDisplayMinZoom) return 2;
    if (zoom < coverMediumBudgetZoom) return 3;
    if (zoom < coverFullBudgetZoom) return 4;
    return 5;
  }

  // ---------------------------------------------------------------------
  // Cover budget
  // ---------------------------------------------------------------------

  /// Hard ceiling on cover images registered per style epoch. MapLibre cannot
  /// remove an image (and the web plugin ignores a re-added name), so the pool
  /// is capped: at ~64 KB per image on a 2x phone this is ~10 MB worst case.
  /// When it is spent, markers keep their canonical badge until the next style
  /// reload clears the images.
  static const int maxRegisteredCoverImages = 160;

  static const int minCoverBudget = 8;
  static const int maxCoverBudget = 24;

  /// Logical pixels of map each cover is given (a cover marker is ~56x72 and
  /// needs air around it to stay a legible marker rather than a photo wall).
  static const double _areaPerCoverPx2 = 60000.0;

  /// Practical maximum of simultaneously active covers for [viewport].
  ///
  /// Scales with the visible area (a phone shows few, a 1440 desktop more) and
  /// is clamped so no device ever holds more than [maxCoverBudget] cover
  /// textures. The reference web value is 32; 24 keeps headroom for the
  /// canonical icons and the walking route.
  ///
  /// With [zoom], the budget is staged: below [coverDisplayMinZoom] there is no
  /// nearby budget, the early stage gets a quarter, the medium stage half, and
  /// only [coverFullBudgetZoom] and closer get the full value. The selected
  /// marker is outside this budget (see [selectCoverMarkerIds]).
  static int coverBudget(Size viewport, {double? zoom}) {
    final area = viewport.width * viewport.height;
    final full = (!area.isFinite || area <= 0)
        ? minCoverBudget
        : (area / _areaPerCoverPx2).round().clamp(
              minCoverBudget,
              maxCoverBudget,
            );
    if (zoom == null) return full;
    switch (coverStageForZoom(zoom)) {
      case 0:
      case 1:
      case 2:
        return 0;
      case 3:
        return math.max(earlyCoverBudgetFloor, (full / 4).ceil());
      case 4:
        return math.max(earlyCoverBudgetFloor + 2, (full / 2).ceil());
      default:
        return full;
    }
  }

  /// Fewest nearby covers the early stage shows (besides the selected one).
  static const int earlyCoverBudgetFloor = 3;

  /// Budget for warming covers ahead of display at [zoom]: the next stage's
  /// budget, so the covers about to be shown are already decoded. Zero below
  /// [coverPrefetchMinZoom].
  static int coverPrefetchBudget(Size viewport, {required double zoom}) {
    final stage = coverStageForZoom(zoom);
    if (stage < 2) return 0;
    final nextZoom = switch (stage) {
      2 => coverDisplayMinZoom,
      3 => coverMediumBudgetZoom,
      _ => coverFullBudgetZoom,
    };
    return coverBudget(viewport, zoom: math.max(zoom, nextZoom));
  }

  // ---------------------------------------------------------------------
  // Cover pixels
  // ---------------------------------------------------------------------

  /// Logical width of the cover face inside a marker (the badge face is 44
  /// logical px; the selected glow variant scales slightly).
  static const double coverFaceLogicalPx = 44.0;

  /// Oversample over the face so the cover stays crisp under the selected
  /// scale and the shape mask's anti-aliasing.
  static const double coverOversample = 1.5;

  /// Physical pixel width to request and decode for a marker cover at
  /// [pixelRatio], snapped to 32 px steps so a CDN/proxy cache sees few
  /// distinct sizes. Never archival: a 3x phone asks for ~208 px.
  static int coverFetchWidthPx(double pixelRatio) {
    final ratio = pixelRatio.isFinite && pixelRatio > 0 ? pixelRatio : 1.0;
    final raw = coverFaceLogicalPx * coverOversample * ratio;
    final snapped = ((raw / 32).ceil() * 32).clamp(96, 256);
    return snapped;
  }

  /// The covers to display at [zoom]: the selected marker from
  /// [selectedCoverMinZoom], nearby markers from [coverDisplayMinZoom] within
  /// the staged [coverBudget]. Empty below [selectedCoverMinZoom].
  static List<String> planCoverIds({
    required Iterable<ArtMarker> candidates,
    required String? selectedId,
    required LatLng center,
    required Size viewport,
    required double zoom,
    required bool Function(ArtMarker marker) hasCover,
    Set<String> failedIds = const <String>{},
  }) {
    if (!allowsSelectedCover(zoom)) return const <String>[];
    return selectCoverMarkerIds(
      candidates: allowsCovers(zoom)
          ? candidates
          : candidates.where((marker) => marker.id == selectedId),
      selectedId: selectedId,
      center: center,
      budget: coverBudget(viewport, zoom: zoom),
      hasCover: hasCover,
      failedIds: failedIds,
    );
  }

  /// Chooses which markers get a cover.
  ///
  /// Order: the selected marker (always, even over budget), then promoted
  /// markers, then nearest to [center]. Markers without a resolvable cover
  /// are never candidates, and a failed cover simply keeps its canonical
  /// marker, so a missing image can never remove a marker.
  static List<String> selectCoverMarkerIds({
    required Iterable<ArtMarker> candidates,
    required String? selectedId,
    required LatLng center,
    required int budget,
    required bool Function(ArtMarker marker) hasCover,
    Set<String> failedIds = const <String>{},
  }) {
    final distance = const Distance();
    final selected = <String>[];
    final ranked = <_RankedCover>[];
    for (final marker in candidates) {
      if (!marker.hasValidPosition) continue;
      if (marker.id == selectedId) {
        if (hasCover(marker) && !failedIds.contains(marker.id)) {
          selected.add(marker.id);
        }
        continue;
      }
      if (failedIds.contains(marker.id) || !hasCover(marker)) continue;
      ranked.add(
        _RankedCover(
          id: marker.id,
          promoted: marker.isPromoted,
          meters: distance.as(LengthUnit.Meter, center, marker.position),
        ),
      );
    }
    ranked.sort((a, b) {
      if (a.promoted != b.promoted) return a.promoted ? -1 : 1;
      final byDistance = a.meters.compareTo(b.meters);
      return byDistance != 0 ? byDistance : a.id.compareTo(b.id);
    });
    final room = math.max(0, budget - selected.length);
    return <String>[...selected, ...ranked.take(room).map((entry) => entry.id)];
  }

  // ---------------------------------------------------------------------
  // Style expressions (pure data, shared by install + restyle)
  // ---------------------------------------------------------------------

  /// Opacity of the canonical marker layer for the zoom/selection state.
  ///
  /// `['zoom']` must stay the input of the top-level `interpolate` (MapLibre GL
  /// JS), so the selection test lives inside the stop outputs. The selected
  /// marker is fully opaque at every zoom: it can never vanish with its level.
  static Object markerOpacityExpression({
    required Object entryOpacity,
    String? selectedId,
  }) {
    final Object revealed = entryOpacity;
    final Object hidden = selectedId == null || selectedId.isEmpty
        ? 0.0
        : <Object>[
            'case',
            <Object>[
              '==',
              <Object>['id'],
              selectedId,
            ],
            entryOpacity,
            0.0,
          ];
    return <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['zoom'],
      blendStartZoom,
      hidden,
      blendEndZoom,
      revealed,
    ];
  }

  /// Hitbox anchor: at far zoom the target is the dot itself, from the blend
  /// band on it covers the badge that floats above the dot.
  static Object hitboxAnchorExpression() => <Object>[
        'step',
        <Object>['zoom'],
        'center',
        blendStartZoom,
        'bottom',
      ];

  /// Radius of the data-coloured dot. Clusters scale with the square root of
  /// their member count so density stays legible without any artwork.
  static Object dotRadiusExpression({
    required double dotRadius,
    required double clusterDotRadius,
  }) {
    final Object farCluster = <Object>[
      'min',
      14.0,
      <Object>[
        '+',
        clusterDotRadius,
        <Object>[
          '*',
          1.1,
          <Object>[
            'sqrt',
            <Object>[
              'coalesce',
              <Object>['get', 'clusterCount'],
              1,
            ],
          ],
        ],
      ],
    ];
    Object radius(Object cluster) => <Object>[
          'case',
          <Object>[
            '==',
            <Object>['get', 'kind'],
            'cluster',
          ],
          cluster,
          dotRadius,
        ];
    return <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['zoom'],
      3,
      radius(farCluster),
      blendEndZoom,
      radius(clusterDotRadius),
    ];
  }
}

class _RankedCover {
  const _RankedCover({
    required this.id,
    required this.promoted,
    required this.meters,
  });

  final String id;
  final bool promoted;
  final double meters;
}
