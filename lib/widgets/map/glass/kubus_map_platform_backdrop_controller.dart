import 'package:flutter/material.dart';

@immutable
class KubusMapBackdropRegion {
  const KubusMapBackdropRegion({
    required this.id,
    required this.rect,
    required this.borderRadius,
    required this.blurSigma,
    this.visible = true,
    this.clipPath,
  });

  final String id;
  final Rect rect;
  final BorderRadius borderRadius;
  final double blurSigma;
  final bool visible;
  final String? clipPath;
}

enum KubusMapBackdropRegionDisposition {
  accepted,
  clamped,
  rejected,
}

@immutable
class KubusMapBackdropRegionValidation {
  const KubusMapBackdropRegionValidation({
    required this.disposition,
    required this.reason,
    required this.mapRect,
    required this.originalRect,
    this.resolvedRegion,
  });

  final KubusMapBackdropRegionDisposition disposition;
  final String reason;
  final Rect mapRect;
  final Rect originalRect;
  final KubusMapBackdropRegion? resolvedRegion;

  bool get accepted =>
      disposition == KubusMapBackdropRegionDisposition.accepted ||
      disposition == KubusMapBackdropRegionDisposition.clamped;
}

// Map-glass overlays (search panel, nearby panel, filter panel, dropdown) are
// legitimately large, so the backdrop host must blur sizeable regions — not just
// tiny controls. Only reject regions that cover almost the ENTIRE map (blurring
// everything is pointless and costly).
const double kubusMapBackdropMaxAreaRatio = 0.90;
const double kubusMapBackdropAlmostFullWidthRatio = 0.985;
const double kubusMapBackdropVeryTallHeightRatio = 0.92;

KubusMapBackdropRegionValidation validateKubusMapBackdropRegionForMap({
  required KubusMapBackdropRegion region,
  required Rect mapRect,
}) {
  if (!region.visible) {
    return KubusMapBackdropRegionValidation(
      disposition: KubusMapBackdropRegionDisposition.rejected,
      reason: 'region-hidden',
      mapRect: mapRect,
      originalRect: region.rect,
    );
  }

  if (!region.rect.isFinite ||
      region.rect.width <= 0 ||
      region.rect.height <= 0 ||
      !region.blurSigma.isFinite ||
      region.blurSigma < 0) {
    return KubusMapBackdropRegionValidation(
      disposition: KubusMapBackdropRegionDisposition.rejected,
      reason: 'invalid-region-geometry',
      mapRect: mapRect,
      originalRect: region.rect,
    );
  }

  if (!mapRect.isFinite || mapRect.width <= 0 || mapRect.height <= 0) {
    return KubusMapBackdropRegionValidation(
      disposition: KubusMapBackdropRegionDisposition.rejected,
      reason: 'invalid-map-geometry',
      mapRect: mapRect,
      originalRect: region.rect,
    );
  }

  final overlap = region.rect.intersect(mapRect);
  if (!overlap.isFinite || overlap.width <= 0 || overlap.height <= 0) {
    return KubusMapBackdropRegionValidation(
      disposition: KubusMapBackdropRegionDisposition.rejected,
      reason: 'outside-map-bounds',
      mapRect: mapRect,
      originalRect: region.rect,
    );
  }

  final mapArea = mapRect.width * mapRect.height;
  final overlapArea = overlap.width * overlap.height;
  final areaRatio = overlapArea / mapArea;
  final widthRatio = overlap.width / mapRect.width;
  final heightRatio = overlap.height / mapRect.height;

  if (areaRatio > kubusMapBackdropMaxAreaRatio) {
    return KubusMapBackdropRegionValidation(
      disposition: KubusMapBackdropRegionDisposition.rejected,
      reason: 'region-area-too-large',
      mapRect: mapRect,
      originalRect: region.rect,
    );
  }

  if (widthRatio >= kubusMapBackdropAlmostFullWidthRatio &&
      heightRatio >= kubusMapBackdropVeryTallHeightRatio) {
    return KubusMapBackdropRegionValidation(
      disposition: KubusMapBackdropRegionDisposition.rejected,
      reason: 'region-near-fullscreen',
      mapRect: mapRect,
      originalRect: region.rect,
    );
  }

  final clamped = overlap != region.rect;
  return KubusMapBackdropRegionValidation(
    disposition: clamped
        ? KubusMapBackdropRegionDisposition.clamped
        : KubusMapBackdropRegionDisposition.accepted,
    reason: clamped ? 'clamped-to-map-bounds' : 'accepted',
    mapRect: mapRect,
    originalRect: region.rect,
    resolvedRegion: clamped
        ? KubusMapBackdropRegion(
            id: region.id,
            rect: overlap,
            borderRadius: region.borderRadius,
            blurSigma: region.blurSigma,
            visible: region.visible,
            clipPath: region.clipPath,
          )
        : region,
  );
}

class KubusMapBackdropHostController extends ChangeNotifier {
  final Map<String, KubusMapBackdropRegion> _regions =
      <String, KubusMapBackdropRegion>{};

  List<KubusMapBackdropRegion> get regions =>
      List<KubusMapBackdropRegion>.unmodifiable(_regions.values);

  int get regionCount => _regions.length;

  void upsertRegion(KubusMapBackdropRegion region) {
    final previous = _regions[region.id];
    if (previous != null &&
        previous.rect == region.rect &&
        previous.borderRadius == region.borderRadius &&
        previous.blurSigma == region.blurSigma &&
        previous.visible == region.visible &&
        previous.clipPath == region.clipPath) {
      return;
    }
    _regions[region.id] = region;
    notifyListeners();
  }

  void removeRegion(String id) {
    if (_regions.remove(id) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_regions.isEmpty) return;
    _regions.clear();
    notifyListeners();
  }
}

class KubusMapBackdropScope
    extends InheritedNotifier<KubusMapBackdropHostController> {
  const KubusMapBackdropScope({
    super.key,
    required KubusMapBackdropHostController controller,
    required super.child,
  }) : super(notifier: controller);

  static KubusMapBackdropHostController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<KubusMapBackdropScope>()
        ?.notifier;
  }
}
