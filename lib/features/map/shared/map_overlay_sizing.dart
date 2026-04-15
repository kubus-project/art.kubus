import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../utils/design_tokens.dart';

/// Shared sizing helpers for marker overlay cards on mobile + desktop maps.
class MapOverlaySizing {
  const MapOverlaySizing._();

  static const double minCardWidth = 272.0;
  static const double maxCardWidth = 336.0;
  static const double preferredCardWidth = 320.0;
  static const double minCardHeight = 320.0;
  static const double maxCardHeight = 500.0;
  static const double fixedCardHeight = 450.0;

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
    final minExpandedHeight = isCompactWidth ? 360.0 : 320.0;
    final raw = math.max(estimatedHeight, minExpandedHeight);
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
}
