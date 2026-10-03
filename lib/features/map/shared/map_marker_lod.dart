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

  /// Covers may appear from here (street scale). Same boundary as the existing
  /// spiderfy / nearby close-up constants.
  static const double closeMinZoom = 15.0;

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

  static bool allowsCovers(double zoom) =>
      zoom.isFinite && zoom >= closeMinZoom;

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
  static int coverBudget(Size viewport) {
    final area = viewport.width * viewport.height;
    if (!area.isFinite || area <= 0) return minCoverBudget;
    return (area / _areaPerCoverPx2)
        .round()
        .clamp(minCoverBudget, maxCoverBudget);
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
    return <String>[
      ...selected,
      ...ranked.take(room).map((entry) => entry.id),
    ];
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
              selectedId
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
            'cluster'
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
