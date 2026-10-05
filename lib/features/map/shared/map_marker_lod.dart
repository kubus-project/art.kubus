import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../models/art_marker.dart';

/// Marker level of detail. One identity, three costs:
///
/// * [far]  cheap GPU dots (data colour, cluster size); no marker artwork is
///   rendered or registered.
/// * [mid]  the canonical kubus marker (category shape, signal ring, promotion).
/// * [close] the canonical kubus marker with the artwork cover inside its
///   geometry, for every eligible individual marker in view.
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
  ///
  /// In the selected-only band below [coverPrefetchMinZoom] only a selection
  /// can show a cover, so without one there is nothing to plan. With one the
  /// idle re-plan is required: selecting a marker usually animates the
  /// camera, and a cover is never rasterised mid-move, so the resync that the
  /// selection triggered skipped it.
  static bool plansCoversAt(double zoom, {bool hasSelection = false}) =>
      allowsCoverPrefetch(zoom) || (hasSelection && allowsSelectedCover(zoom));

  /// Discrete cover stage for [zoom]. Crossing a stage changes what the marker
  /// source shows (or prefetches), so the regroup gate and the sync engine
  /// compare stages rather than one boolean.
  ///
  /// 0 none, 1 selected only, 2 prefetch, 3 display (every eligible marker in
  /// view).
  static int coverStageForZoom(double zoom) {
    if (!zoom.isFinite || zoom < selectedCoverMinZoom) return 0;
    if (zoom < coverPrefetchMinZoom) return 1;
    if (zoom < coverDisplayMinZoom) return 2;
    return 3;
  }

  // ---------------------------------------------------------------------
  // Cover working set
  // ---------------------------------------------------------------------

  /// There is deliberately no cap on how many in-view markers show a cover:
  /// at [coverDisplayMinZoom] every eligible individual marker in the viewport
  /// is planned, and what stays bounded is the work (download and decode
  /// concurrency, decoded pixels per image, the decoded-image cache) and the
  /// memory (see below), not the visible count.
  ///
  /// Ceiling on cover images registered per style epoch. MapLibre cannot
  /// remove an image (and the web plugin ignores a re-added name), so the pool
  /// is append-only: at ~64 KB per image on a 2x phone this is ~20 MB worst
  /// case, enough for several dense viewports of panning. When it is spent,
  /// markers keep their canonical badge until the next style reload clears the
  /// images.
  static const int maxRegisteredCoverImages = 320;

  /// Most covers warmed ahead of display (prefetch only decodes, never
  /// rasterises), so the decoded cache is not churned before the covers it is
  /// warming are shown.
  static const int coverPrefetchLimit = 32;

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
  /// distinct sizes, clamped to 96-256. Never archival: 1x asks for 96 px,
  /// 2x for 160 px and 3x for 224 px.
  static int coverFetchWidthPx(double pixelRatio) {
    final ratio = pixelRatio.isFinite && pixelRatio > 0 ? pixelRatio : 1.0;
    final raw = coverFaceLogicalPx * coverOversample * ratio;
    final snapped = ((raw / 32).ceil() * 32).clamp(96, 256);
    return snapped;
  }

  /// Widest source aspect (long edge over short edge) a cover download is sized
  /// for. The face is square and the decode targets the short side, so a
  /// landscape source needs this much long-edge headroom to reach it.
  static const double coverSourceAspectHeadroom = 16 / 9;

  /// Physical long-edge width a cover is *downloaded* at: enough that a 16:9
  /// source still has [coverFetchWidthPx] on its short edge. The decode stays
  /// short-side bound, so this only widens the (small) transfer.
  static int coverDownloadWidthPx(double pixelRatio) {
    final raw = coverFetchWidthPx(pixelRatio) * coverSourceAspectHeadroom;
    return ((raw / 32).ceil() * 32).clamp(160, 512);
  }

  /// The covers to display at [zoom], in loading priority order: the selected
  /// marker from [selectedCoverMinZoom], and from [coverDisplayMinZoom] every
  /// eligible candidate (see [selectCoverMarkerIds]). Empty below
  /// [selectedCoverMinZoom].
  static List<String> planCoverIds({
    required Iterable<ArtMarker> candidates,
    required String? selectedId,
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
      hasCover: hasCover,
      failedIds: failedIds,
    );
  }

  /// Orders the markers that get a cover, which is every candidate that has a
  /// resolvable cover that has not failed (the caller passes only individual
  /// markers that are in view).
  ///
  /// The order is the loading priority: the selected marker, then promoted
  /// markers, then everyone else interleaved across the candidates' own extent
  /// so the viewport fills across its whole area instead of centre-out (no
  /// ranking by distance from the map centre, which would draw a photo circle
  /// while loading). A failed or missing cover keeps its canonical marker, so a
  /// missing image can never remove a marker. [limit] truncates the *rest*
  /// (used for prefetch); the selected marker is never counted against it.
  static List<String> selectCoverMarkerIds({
    required Iterable<ArtMarker> candidates,
    required String? selectedId,
    required bool Function(ArtMarker marker) hasCover,
    Set<String> failedIds = const <String>{},
    int? limit,
  }) {
    final selected = <String>[];
    final promoted = <ArtMarker>[];
    final rest = <ArtMarker>[];
    for (final marker in candidates) {
      if (!marker.hasValidPosition) continue;
      if (marker.id == selectedId) {
        if (hasCover(marker) && !failedIds.contains(marker.id)) {
          selected.add(marker.id);
        }
        continue;
      }
      if (failedIds.contains(marker.id) || !hasCover(marker)) continue;
      (marker.isPromoted ? promoted : rest).add(marker);
    }
    final ordered = <String>[
      ...spatiallyFairOrder(promoted).map((m) => m.id),
      ...spatiallyFairOrder(rest).map((m) => m.id),
    ];
    return <String>[
      ...selected,
      ...(limit == null ? ordered : ordered.take(math.max(0, limit))),
    ];
  }

  /// Scattered visiting order of the 4 x 4 cells a set of markers is binned
  /// into (neighbouring ranks are far apart on the map).
  static const List<int> _cellVisitOrder = <int>[
    0, 10, 5, 15, 3, 9, 6, 12, 1, 11, 4, 14, 2, 8, 7, 13, //
  ];

  /// Interleaves [markers] across their own bounding box: bin them into a 4 x 4
  /// grid, then take one from each cell in a scattered cell order, round after
  /// round. Deterministic (ties by id) and independent of the camera centre.
  @visibleForTesting
  static List<ArtMarker> spatiallyFairOrder(List<ArtMarker> markers) {
    if (markers.length < 3) {
      return List<ArtMarker>.of(markers)..sort((a, b) => a.id.compareTo(b.id));
    }
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final m in markers) {
      minLat = math.min(minLat, m.position.latitude);
      maxLat = math.max(maxLat, m.position.latitude);
      minLng = math.min(minLng, m.position.longitude);
      maxLng = math.max(maxLng, m.position.longitude);
    }
    final latSpan = math.max(maxLat - minLat, 1e-9);
    final lngSpan = math.max(maxLng - minLng, 1e-9);
    final cells = List<List<ArtMarker>>.generate(16, (_) => <ArtMarker>[]);
    for (final m in markers) {
      final row =
          (((m.position.latitude - minLat) / latSpan) * 4).floor().clamp(0, 3);
      final col =
          (((m.position.longitude - minLng) / lngSpan) * 4).floor().clamp(0, 3);
      cells[row * 4 + col].add(m);
    }
    for (final cell in cells) {
      cell.sort((a, b) => a.id.compareTo(b.id));
    }
    final out = <ArtMarker>[];
    for (var round = 0; out.length < markers.length; round++) {
      for (final index in _cellVisitOrder) {
        if (round < cells[index].length) out.add(cells[index][round]);
      }
    }
    return out;
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
