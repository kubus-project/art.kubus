import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../utils/design_tokens.dart';

class MapMarkerOverlayCardLayoutConfig {
  const MapMarkerOverlayCardLayoutConfig({
    required this.width,
    required this.maxHeight,
    required this.markerOffset,
    required this.horizontalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.compact,
  });

  final double width;
  final double maxHeight;
  final double markerOffset;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final bool compact;
}

/// Shared sizing helpers for marker overlay cards on mobile + desktop maps.
class MapOverlaySizing {
  const MapOverlaySizing._();

  static const double minCardWidth = 272.0;
  static const double maxCardWidth = 336.0;
  static const double preferredCardWidth = 320.0;
  static const double minCardHeight = 280.0;
  static const double maxCardHeight = 500.0;
  static const double fixedCardHeight = 420.0;

  static const double defaultHorizontalPadding = KubusSpacing.md;
  static const double defaultVerticalPadding =
      KubusSpacing.md - KubusSpacing.xs;

  static double topSafeInset(MediaQueryData media) {
    return math.max(media.padding.top, media.viewPadding.top);
  }

  static double bottomSafeInset(MediaQueryData media) {
    return math.max(media.padding.bottom, media.viewPadding.bottom) +
        media.viewInsets.bottom;
  }

  static double resolveCardWidth(
    BoxConstraints constraints, {
    double preferred = maxCardWidth,
    double horizontalPadding = defaultHorizontalPadding,
  }) {
    final available =
        math.max(1.0, constraints.maxWidth - (horizontalPadding * 2.0));
    final clampedPreferred =
        preferred.clamp(minCardWidth, maxCardWidth).toDouble();
    return math.min(available, clampedPreferred).toDouble();
  }

  static double resolveMaxCardHeight({
    required BoxConstraints constraints,
    required MediaQueryData media,
    double extraVerticalPadding = 24.0,
  }) {
    final safeTop = topSafeInset(media);
    final safeBottom = bottomSafeInset(media);
    final available =
        constraints.maxHeight - safeTop - safeBottom - extraVerticalPadding;
    return math.max(minCardHeight, available).toDouble();
  }

  static double resolveCardHeight({
    required double estimatedHeight,
    required double maxCardHeight,
    required bool isCompactWidth,
  }) {
    final raw = math.max(estimatedHeight, minCardHeight);
    return raw.clamp(minCardHeight, maxCardHeight).toDouble();
  }

  static double resolveFixedCardHeight({
    required double maxCardHeight,
    double preferredHeight = fixedCardHeight,
  }) {
    final clampedPreferred =
        preferredHeight.clamp(minCardHeight, maxCardHeight).toDouble();
    return clampedPreferred;
  }

  static MapMarkerOverlayCardLayoutConfig resolveMarkerOverlayCardLayout({
    required BoxConstraints constraints,
    required MediaQueryData media,
    required bool isDesktop,
    bool rightSidebarOpen = false,
    bool leftPanelOpen = false,
    double? topChromePx,
  }) {
    final compact = constraints.maxWidth < 600;
    final horizontalPadding =
        isDesktop ? KubusSpacing.md : KubusSpacing.sm + KubusSpacing.xxs;
    final topPadding =
        topChromePx ?? (isDesktop ? KubusSpacing.md : defaultVerticalPadding);
    final bottomPadding = isDesktop ? KubusSpacing.md : defaultVerticalPadding;
    final availableWidth = constraints.maxWidth -
        (leftPanelOpen ? 400.0 : 0.0) -
        (rightSidebarOpen ? 360.0 : 0.0);
    final widthConstraints = BoxConstraints(
      maxWidth: math.max(minCardWidth, availableWidth),
      maxHeight: constraints.maxHeight,
    );
    final width = resolveCardWidth(
      widthConstraints,
      preferred: preferredCardWidth,
      horizontalPadding: horizontalPadding,
    );
    final maxHeight = resolveMaxCardHeight(
      constraints: constraints,
      media: media,
      extraVerticalPadding: topPadding + bottomPadding,
    );
    final markerOffset = (isDesktop ? 32.0 : 24.0).toDouble();

    return MapMarkerOverlayCardLayoutConfig(
      width: width,
      maxHeight: maxHeight,
      markerOffset: markerOffset,
      horizontalPadding: horizontalPadding,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      compact: compact,
    );
  }
}
