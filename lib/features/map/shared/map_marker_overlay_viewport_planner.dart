import 'dart:math' as math;

import 'package:flutter/widgets.dart';

@immutable
class MapMarkerOverlayViewportPlan {
  const MapMarkerOverlayViewportPlan({
    required this.needsNudge,
    required this.compositionYOffsetPx,
    required this.rawNudgePx,
    required this.pairTop,
    required this.pairBottom,
    required this.safeTop,
    required this.safeBottom,
    required this.diagnostics,
  });

  final bool needsNudge;
  final double compositionYOffsetPx;
  final double rawNudgePx;
  final double pairTop;
  final double pairBottom;
  final double safeTop;
  final double safeBottom;
  final String diagnostics;
}

/// Plans a small camera composition nudge for a selected marker overlay.
///
/// Positive [compositionYOffsetPx] moves the selected marker/card pair lower in
/// the viewport through the existing MapLibre camera composition path.
MapMarkerOverlayViewportPlan planSelectedMarkerOverlayViewport({
  required Size viewportSize,
  required Offset markerAnchor,
  required Size cardSize,
  required EdgeInsets safeInsets,
  required double markerOffset,
  double topChromePx = 0,
  double bottomChromePx = 0,
  double maxNudgePx = 120,
  double epsilonPx = 8,
  double markerTailPx = 18,
}) {
  final viewportHeight = viewportSize.height;
  final safeTop = math
      .max(safeInsets.top, topChromePx)
      .clamp(0.0, viewportHeight)
      .toDouble();
  final safeBottom =
      (viewportHeight - math.max(safeInsets.bottom, bottomChromePx))
          .clamp(safeTop, viewportHeight)
          .toDouble();
  final pairTop = markerAnchor.dy - cardSize.height - markerOffset;
  final pairBottom = markerAnchor.dy + markerTailPx;

  double rawNudge = 0;
  if (pairTop < safeTop) {
    rawNudge = safeTop - pairTop;
  } else if (pairBottom > safeBottom) {
    rawNudge = safeBottom - pairBottom;
  }

  final clampedNudge = rawNudge.clamp(-maxNudgePx, maxNudgePx).toDouble();
  final needsNudge = clampedNudge.abs() >= epsilonPx;
  final compositionYOffsetPx = needsNudge ? clampedNudge : 0.0;

  return MapMarkerOverlayViewportPlan(
    needsNudge: needsNudge,
    compositionYOffsetPx: compositionYOffsetPx,
    rawNudgePx: rawNudge,
    pairTop: pairTop,
    pairBottom: pairBottom,
    safeTop: safeTop,
    safeBottom: safeBottom,
    diagnostics: 'pairTop=${pairTop.toStringAsFixed(1)}, '
        'pairBottom=${pairBottom.toStringAsFixed(1)}, '
        'safeTop=${safeTop.toStringAsFixed(1)}, '
        'safeBottom=${safeBottom.toStringAsFixed(1)}, '
        'raw=${rawNudge.toStringAsFixed(1)}, '
        'clamped=${compositionYOffsetPx.toStringAsFixed(1)}',
  );
}
