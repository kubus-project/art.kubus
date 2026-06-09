import 'dart:math' as math;

import 'package:flutter/widgets.dart';

@immutable
class MapMarkerOverlayViewportPlan {
  const MapMarkerOverlayViewportPlan({
    required this.needsNudge,
    required this.compositionYOffsetPx,
    required this.rawNudgePx,
    required this.overlayShiftXPx,
    required this.rawOverlayShiftXPx,
    required this.needsOverlayShift,
    required this.pairLeft,
    required this.pairRight,
    required this.pairTop,
    required this.pairBottom,
    required this.safeLeft,
    required this.safeRight,
    required this.safeTop,
    required this.safeBottom,
    required this.diagnostics,
  });

  final bool needsNudge;
  final double compositionYOffsetPx;
  final double rawNudgePx;
  final double overlayShiftXPx;
  final double rawOverlayShiftXPx;
  final bool needsOverlayShift;
  final double pairLeft;
  final double pairRight;
  final double pairTop;
  final double pairBottom;
  final double safeLeft;
  final double safeRight;
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
  double maxOverlayShiftPx = 160,
  double epsilonPx = 8,
  double markerTailPx = 18,
}) {
  final viewportWidth = viewportSize.width;
  final viewportHeight = viewportSize.height;
  final safeLeft = safeInsets.left.clamp(0.0, viewportWidth).toDouble();
  final safeRight = (viewportWidth - safeInsets.right)
      .clamp(safeLeft, viewportWidth)
      .toDouble();
  final safeTop = math
      .max(safeInsets.top, topChromePx)
      .clamp(0.0, viewportHeight)
      .toDouble();
  final safeBottom =
      (viewportHeight - math.max(safeInsets.bottom, bottomChromePx))
          .clamp(safeTop, viewportHeight)
          .toDouble();
  final pairLeft = markerAnchor.dx - (cardSize.width / 2);
  final pairRight = markerAnchor.dx + (cardSize.width / 2);
  final pairTop = markerAnchor.dy - cardSize.height - markerOffset;
  final pairBottom = markerAnchor.dy + markerTailPx;

  double rawOverlayShift = 0;
  if (pairLeft < safeLeft) {
    rawOverlayShift = safeLeft - pairLeft;
  } else if (pairRight > safeRight) {
    rawOverlayShift = safeRight - pairRight;
  }

  final clampedOverlayShift =
      rawOverlayShift.clamp(-maxOverlayShiftPx, maxOverlayShiftPx).toDouble();
  final needsOverlayShift = clampedOverlayShift.abs() >= epsilonPx;
  final overlayShiftXPx = needsOverlayShift ? clampedOverlayShift : 0.0;

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
    overlayShiftXPx: overlayShiftXPx,
    rawOverlayShiftXPx: rawOverlayShift,
    needsOverlayShift: needsOverlayShift,
    pairLeft: pairLeft,
    pairRight: pairRight,
    pairTop: pairTop,
    pairBottom: pairBottom,
    safeLeft: safeLeft,
    safeRight: safeRight,
    safeTop: safeTop,
    safeBottom: safeBottom,
    diagnostics: 'pairLeft=${pairLeft.toStringAsFixed(1)}, '
        'pairRight=${pairRight.toStringAsFixed(1)}, '
        'pairTop=${pairTop.toStringAsFixed(1)}, '
        'pairBottom=${pairBottom.toStringAsFixed(1)}, '
        'safeLeft=${safeLeft.toStringAsFixed(1)}, '
        'safeRight=${safeRight.toStringAsFixed(1)}, '
        'safeTop=${safeTop.toStringAsFixed(1)}, '
        'safeBottom=${safeBottom.toStringAsFixed(1)}, '
        'raw=${rawNudge.toStringAsFixed(1)}, '
        'rawX=${rawOverlayShift.toStringAsFixed(1)}, '
        'shiftX=${overlayShiftXPx.toStringAsFixed(1)}, '
        'clamped=${compositionYOffsetPx.toStringAsFixed(1)}',
  );
}
