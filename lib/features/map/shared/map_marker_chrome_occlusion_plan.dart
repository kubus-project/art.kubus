import 'package:flutter/widgets.dart';

/// Immutable geometric visibility decision for passive mobile map chrome.
///
/// Dominant contextual state remains outside this model. This plan only hides
/// independently measured chrome whose rectangle intersects the marker card.
@immutable
class MapMarkerChromeOcclusionPlan {
  const MapMarkerChromeOcclusionPlan._({
    required this.revision,
    required this.searchOccluded,
    required this.discoveryOccluded,
    required this.controlsOccluded,
    required this.nearbyOccluded,
  });

  factory MapMarkerChromeOcclusionPlan.visible({required int revision}) {
    return MapMarkerChromeOcclusionPlan._(
      revision: revision,
      searchOccluded: false,
      discoveryOccluded: false,
      controlsOccluded: false,
      nearbyOccluded: false,
    );
  }

  factory MapMarkerChromeOcclusionPlan.resolve({
    required int revision,
    required Rect cardRect,
    Rect? searchRect,
    Rect? discoveryRect,
    Rect? controlsRect,
    Rect? nearbyRect,
    double collisionMargin = 0,
  }) {
    if (!_isMeasurable(cardRect)) {
      return MapMarkerChromeOcclusionPlan.visible(revision: revision);
    }

    final margin = collisionMargin.isFinite
        ? collisionMargin.clamp(0.0, double.infinity).toDouble()
        : 0.0;
    final collisionRect = cardRect.inflate(margin);

    bool occludes(Rect? chromeRect) {
      return chromeRect != null &&
          _isMeasurable(chromeRect) &&
          collisionRect.overlaps(chromeRect);
    }

    return MapMarkerChromeOcclusionPlan._(
      revision: revision,
      searchOccluded: occludes(searchRect),
      discoveryOccluded: occludes(discoveryRect),
      controlsOccluded: occludes(controlsRect),
      nearbyOccluded: occludes(nearbyRect),
    );
  }

  final int revision;
  final bool searchOccluded;
  final bool discoveryOccluded;
  final bool controlsOccluded;
  final bool nearbyOccluded;

  bool get hasOcclusion =>
      searchOccluded || discoveryOccluded || controlsOccluded || nearbyOccluded;

  bool isCurrentRevision(int currentRevision) => revision == currentRevision;

  static bool _isMeasurable(Rect rect) {
    return rect.left.isFinite &&
        rect.top.isFinite &&
        rect.right.isFinite &&
        rect.bottom.isFinite &&
        rect.width > 0 &&
        rect.height > 0;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapMarkerChromeOcclusionPlan &&
            revision == other.revision &&
            searchOccluded == other.searchOccluded &&
            discoveryOccluded == other.discoveryOccluded &&
            controlsOccluded == other.controlsOccluded &&
            nearbyOccluded == other.nearbyOccluded;
  }

  @override
  int get hashCode => Object.hash(
        revision,
        searchOccluded,
        discoveryOccluded,
        controlsOccluded,
        nearbyOccluded,
      );
}
