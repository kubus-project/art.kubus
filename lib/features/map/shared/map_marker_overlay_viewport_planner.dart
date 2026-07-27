import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum MapMarkerOverlayVerticalComposition {
  /// Retains the current anchor unless the marker/card pair crosses a safe edge.
  ensureVisible,

  /// Places the marker on the usable viewport's lower-third guide.
  lowerThird,
}

@immutable
class MapMarkerOverlayViewportPlan {
  const MapMarkerOverlayViewportPlan({
    required this.needsNudge,
    required this.isMaterialCorrection,
    required this.compositionYOffsetPx,
    required this.rawNudgePx,
    required this.targetAnchorY,
    required this.overlayShiftXPx,
    required this.rawOverlayShiftXPx,
    required this.needsOverlayShift,
    required this.oversizedCard,
    required this.layoutRevision,
    required this.isStale,
    required this.correctionAlreadyApplied,
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
  final bool isMaterialCorrection;
  final double compositionYOffsetPx;
  final double rawNudgePx;
  final double targetAnchorY;
  final double overlayShiftXPx;
  final double rawOverlayShiftXPx;
  final bool needsOverlayShift;
  final bool oversizedCard;
  final int layoutRevision;
  final bool isStale;
  final bool correctionAlreadyApplied;
  final double pairLeft;
  final double pairRight;
  final double pairTop;
  final double pairBottom;
  final double safeLeft;
  final double safeRight;
  final double safeTop;
  final double safeBottom;
  final String diagnostics;

  /// Whether this plan may perform its one automatic camera correction.
  bool get canApplyCorrection =>
      needsNudge && !isStale && !correctionAlreadyApplied;
}

/// Plans selected-marker composition within the usable map viewport.
///
/// Positive [compositionYOffsetPx] moves the selected marker/card pair lower in
/// the viewport through the existing MapLibre camera composition path.
///
/// With [MapMarkerOverlayVerticalComposition.lowerThird], the marker target is
/// the lower-third guide of the usable viewport. When the anchored card fits,
/// the guide is constrained so the card and marker tail remain inside the safe
/// region. Oversized cards retain the lower-third marker guide and rely on the
/// overlay's bounded, internally scrollable layout.
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
  MapMarkerOverlayVerticalComposition verticalComposition =
      MapMarkerOverlayVerticalComposition.ensureVisible,
  int layoutRevision = 0,
  int? expectedLayoutRevision,
  int? lastCorrectedLayoutRevision,
}) {
  final viewportWidth =
      viewportSize.width.isFinite ? math.max(0.0, viewportSize.width) : 0.0;
  final viewportHeight =
      viewportSize.height.isFinite ? math.max(0.0, viewportSize.height) : 0.0;
  final effectiveEpsilon = epsilonPx.isFinite ? math.max(0.0, epsilonPx) : 0.0;
  final effectiveMarkerOffset =
      markerOffset.isFinite ? math.max(0.0, markerOffset) : 0.0;
  final effectiveMarkerTail =
      markerTailPx.isFinite ? math.max(0.0, markerTailPx) : 0.0;
  final effectiveCardWidth =
      cardSize.width.isFinite ? math.max(0.0, cardSize.width) : 0.0;
  final effectiveCardHeight =
      cardSize.height.isFinite ? math.max(0.0, cardSize.height) : 0.0;
  final safeLeft = safeInsets.left.clamp(0.0, viewportWidth).toDouble();
  final safeRight = (viewportWidth - safeInsets.right)
      .clamp(safeLeft, viewportWidth)
      .toDouble();
  // The overlay wrapper reserves both the device safe area and its own chrome
  // padding. Keep the camera planner on that exact same coordinate system.
  final safeTop =
      (safeInsets.top + topChromePx).clamp(0.0, viewportHeight).toDouble();
  final safeBottom =
      (viewportHeight - math.max(safeInsets.bottom, bottomChromePx))
          .clamp(safeTop, viewportHeight)
          .toDouble();
  final usableWidth = math.max(0.0, safeRight - safeLeft);
  final usableHeight = math.max(0.0, safeBottom - safeTop);
  final lowerThirdTarget = safeTop + (usableHeight * 2 / 3);
  final minimumFittingAnchor =
      safeTop + effectiveCardHeight + effectiveMarkerOffset;
  final maximumFittingAnchor = safeBottom - effectiveMarkerTail;
  final oversizedCard = minimumFittingAnchor > maximumFittingAnchor;
  final markerX = markerAnchor.dx.isFinite ? markerAnchor.dx : safeLeft;
  final markerY = markerAnchor.dy.isFinite ? markerAnchor.dy : safeTop;
  final pairLeft = markerX - (effectiveCardWidth / 2);
  final pairRight = markerX + (effectiveCardWidth / 2);
  final pairTop = markerY - effectiveCardHeight - effectiveMarkerOffset;
  final pairBottom = markerY + effectiveMarkerTail;
  final targetAnchorY = switch (verticalComposition) {
    MapMarkerOverlayVerticalComposition.lowerThird => oversizedCard
        ? lowerThirdTarget.clamp(safeTop, safeBottom).toDouble()
        : lowerThirdTarget
            .clamp(minimumFittingAnchor, maximumFittingAnchor)
            .toDouble(),
    MapMarkerOverlayVerticalComposition.ensureVisible => pairTop < safeTop
        ? markerY + (safeTop - pairTop)
        : pairBottom > safeBottom
            ? markerY + (safeBottom - pairBottom)
            : markerY,
  };

  double rawOverlayShift = 0;
  if (effectiveCardWidth > usableWidth) {
    rawOverlayShift = ((safeLeft + safeRight) / 2) - markerX;
  } else if (pairLeft < safeLeft) {
    rawOverlayShift = safeLeft - pairLeft;
  } else if (pairRight > safeRight) {
    rawOverlayShift = safeRight - pairRight;
  }

  final effectiveMaxOverlayShift =
      maxOverlayShiftPx.isFinite ? math.max(0.0, maxOverlayShiftPx) : 0.0;
  final clampedOverlayShift = rawOverlayShift
      .clamp(-effectiveMaxOverlayShift, effectiveMaxOverlayShift)
      .toDouble();
  final needsOverlayShift = clampedOverlayShift.abs() >= effectiveEpsilon;
  final overlayShiftXPx = needsOverlayShift ? clampedOverlayShift : 0.0;

  final rawNudge = targetAnchorY - markerY;
  final effectiveMaxNudge =
      maxNudgePx.isFinite ? math.max(0.0, maxNudgePx) : 0.0;
  final clampedNudge =
      rawNudge.clamp(-effectiveMaxNudge, effectiveMaxNudge).toDouble();
  final isMaterialCorrection = clampedNudge.abs() >= effectiveEpsilon;
  final isStale = expectedLayoutRevision != null &&
      layoutRevision != expectedLayoutRevision;
  final correctionAlreadyApplied =
      lastCorrectedLayoutRevision == layoutRevision;
  final needsNudge =
      isMaterialCorrection && !isStale && !correctionAlreadyApplied;
  final compositionYOffsetPx = needsNudge ? clampedNudge : 0.0;

  return MapMarkerOverlayViewportPlan(
    needsNudge: needsNudge,
    isMaterialCorrection: isMaterialCorrection,
    compositionYOffsetPx: compositionYOffsetPx,
    rawNudgePx: rawNudge,
    targetAnchorY: targetAnchorY,
    overlayShiftXPx: overlayShiftXPx,
    rawOverlayShiftXPx: rawOverlayShift,
    needsOverlayShift: needsOverlayShift,
    oversizedCard: oversizedCard,
    layoutRevision: layoutRevision,
    isStale: isStale,
    correctionAlreadyApplied: correctionAlreadyApplied,
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
        'targetY=${targetAnchorY.toStringAsFixed(1)}, '
        'composition=${verticalComposition.name}, '
        'oversized=$oversizedCard, '
        'revision=$layoutRevision, '
        'stale=$isStale, '
        'applied=$correctionAlreadyApplied, '
        'raw=${rawNudge.toStringAsFixed(1)}, '
        'rawX=${rawOverlayShift.toStringAsFixed(1)}, '
        'shiftX=${overlayShiftXPx.toStringAsFixed(1)}, '
        'clamped=${compositionYOffsetPx.toStringAsFixed(1)}',
  );
}
