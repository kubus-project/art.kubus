import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../map_overlay_blocker.dart';

enum KubusMarkerOverlayPlacementStrategy {
  anchored,
  centered,
}

@immutable
class KubusMarkerOverlayAnimationConfig {
  const KubusMarkerOverlayAnimationConfig({
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
  });

  final Duration duration;
  final Curve curve;
}

@immutable
class KubusMarkerOverlayLayoutState {
  const KubusMarkerOverlayLayoutState({
    required this.cardWidth,
    required this.cardHeight,
    required this.maxCardHeight,
    this.anchor,
  });

  final double cardWidth;
  final double cardHeight;
  final double maxCardHeight;
  final Offset? anchor;
}

typedef KubusMarkerOverlayWidthResolver = double Function(
  BoxConstraints constraints,
  MediaQueryData mediaQuery,
);

typedef KubusMarkerOverlayMaxHeightResolver = double Function(
  BoxConstraints constraints,
  MediaQueryData mediaQuery,
);

typedef KubusMarkerOverlayHeightResolver = double Function(
  BoxConstraints constraints,
  MediaQueryData mediaQuery,
  double maxCardHeight,
);

typedef KubusMarkerOverlayFallbackAnchorResolver = Offset Function(
  BoxConstraints constraints,
);

typedef KubusMarkerOverlayCardBuilder = Widget Function(
  BuildContext context,
  KubusMarkerOverlayLayoutState layout,
);

/// Shared anchored/centered marker overlay placement wrapper.
///
/// This centralizes width/height clamping, safe-area handling, pointer
/// interception, and desktop/mobile animation defaults.
class KubusMarkerOverlayCardWrapper extends StatelessWidget {
  const KubusMarkerOverlayCardWrapper({
    super.key,
    required this.anchorListenable,
    required this.cardBuilder,
    this.placementStrategy = KubusMarkerOverlayPlacementStrategy.anchored,
    this.widthResolver = _defaultWidthResolver,
    this.maxHeightResolver = _defaultMaxHeightResolver,
    this.heightResolver = _defaultHeightResolver,
    this.fallbackAnchorResolver,
    this.horizontalPadding = 16,
    this.topPadding = 12,
    this.bottomPadding = 12,
    this.markerOffset = 32,
    this.animation = const KubusMarkerOverlayAnimationConfig(),
    this.cursor = SystemMouseCursors.basic,
    this.interceptPlatformViews = true,
    this.enabled = true,
    this.centerWhenAnchorMissing = true,
  });

  final ValueListenable<Offset?> anchorListenable;
  final KubusMarkerOverlayCardBuilder cardBuilder;

  final KubusMarkerOverlayPlacementStrategy placementStrategy;
  final KubusMarkerOverlayWidthResolver widthResolver;
  final KubusMarkerOverlayMaxHeightResolver maxHeightResolver;
  final KubusMarkerOverlayHeightResolver heightResolver;
  final KubusMarkerOverlayFallbackAnchorResolver? fallbackAnchorResolver;

  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double markerOffset;

  final KubusMarkerOverlayAnimationConfig animation;
  final MouseCursor cursor;
  final bool interceptPlatformViews;
  final bool enabled;
  final bool centerWhenAnchorMissing;

  static double _defaultWidthResolver(
    BoxConstraints constraints,
    MediaQueryData mediaQuery,
  ) {
    return math.min(280.0, constraints.maxWidth - 32.0);
  }

  static double _defaultMaxHeightResolver(
    BoxConstraints constraints,
    MediaQueryData mediaQuery,
  ) {
    return math
        .max(240.0, constraints.maxHeight - mediaQuery.padding.vertical - 24)
        .toDouble();
  }

  static double _defaultHeightResolver(
    BoxConstraints constraints,
    MediaQueryData mediaQuery,
    double maxCardHeight,
  ) {
    return math.min(360.0, maxCardHeight);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return ValueListenableBuilder<Offset?>(
      valueListenable: anchorListenable,
      builder: (context, liveAnchor, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.of(context);
            final rawWidth = widthResolver(constraints, media);
            final cardWidth = rawWidth.isFinite
                ? rawWidth.clamp(1.0, constraints.maxWidth).toDouble()
                : math.min(280.0, constraints.maxWidth);

            final rawMaxHeight = maxHeightResolver(constraints, media);
            final maxCardHeight = rawMaxHeight.isFinite
                ? rawMaxHeight.clamp(1.0, constraints.maxHeight).toDouble()
                : constraints.maxHeight;

            final rawCardHeight = heightResolver(
              constraints,
              media,
              maxCardHeight,
            );
            final cardHeight = rawCardHeight
                .clamp(1.0, maxCardHeight)
                .toDouble();

            final fallbackAnchor = fallbackAnchorResolver?.call(constraints);
            final anchor = _resolveAnchor(
              constraints: constraints,
              candidate: liveAnchor,
              fallback: fallbackAnchor,
            );

            final layout = KubusMarkerOverlayLayoutState(
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              maxCardHeight: maxCardHeight,
              anchor: anchor,
            );
            final card = _buildWrappedCard(context, layout);

            final shouldCenter = placementStrategy ==
                    KubusMarkerOverlayPlacementStrategy.centered ||
                (anchor == null && centerWhenAnchorMissing);

            if (shouldCenter) {
              return KeyedSubtree(
                key: const ValueKey<String>('kubus_marker_overlay_centered'),
                child: Center(
                  child: UnconstrainedBox(
                    child: SizedBox(
                      width: cardWidth,
                      child: card,
                    ),
                  ),
                ),
              );
            }

            final anchored = anchor ?? fallbackAnchor;
            if (anchored == null) {
              return const SizedBox.shrink();
            }

            final topSafe = media.padding.top + topPadding;
            final maxLeft =
                math.max(horizontalPadding, constraints.maxWidth - cardWidth - horizontalPadding);
            final left = (anchored.dx - (cardWidth / 2)).clamp(
              horizontalPadding,
              maxLeft,
            ).toDouble();

            double top = anchored.dy - cardHeight - markerOffset;
            if (top < topSafe) {
              top = topSafe;
            }
            top = top.clamp(
              topSafe,
              math.max(
                topSafe,
                constraints.maxHeight - cardHeight - bottomPadding,
              ),
            ).toDouble();

            return KeyedSubtree(
              key: const ValueKey<String>('kubus_marker_overlay_anchored'),
              child: Stack(
                children: [
                  Positioned(
                    left: left,
                    top: top,
                    child: UnconstrainedBox(
                      alignment: Alignment.topLeft,
                      constrainedAxis: Axis.horizontal,
                      child: SizedBox(
                        width: cardWidth,
                        child: card,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWrappedCard(
    BuildContext context,
    KubusMarkerOverlayLayoutState layout,
  ) {
    return MapOverlayBlocker(
      enabled: true,
      cursor: cursor,
      interceptPlatformViews: interceptPlatformViews,
      child: AnimatedSize(
        duration: animation.duration,
        curve: animation.curve,
        alignment: Alignment.topCenter,
        child: cardBuilder(context, layout),
      ),
    );
  }

  Offset? _resolveAnchor({
    required BoxConstraints constraints,
    required Offset? candidate,
    required Offset? fallback,
  }) {
    final anchor = candidate;
    if (anchor == null) return fallback;
    if (!anchor.dx.isFinite || !anchor.dy.isFinite) return fallback;

    final looksUsable = anchor.dx >= -constraints.maxWidth * 0.5 &&
        anchor.dx <= constraints.maxWidth * 1.5 &&
        anchor.dy >= -constraints.maxHeight * 0.5 &&
        anchor.dy <= constraints.maxHeight * 1.5;

    return looksUsable ? anchor : fallback;
  }
}
