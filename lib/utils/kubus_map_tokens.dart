import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_animations.dart';
import 'design_tokens.dart';

/// Responsive composition tiers for the map.
///
/// These tiers describe available map canvas rather than device platforms. A
/// resized desktop window can therefore use the same intermediate composition
/// as a tablet without branching on the current target platform.
enum KubusMapLayoutTier {
  compact,
  intermediate,
  wide;

  static KubusMapLayoutTier fromWidth(double width) {
    if (width < KubusMapMetrics.intermediateMinWidth) {
      return KubusMapLayoutTier.compact;
    }
    if (width < KubusMapMetrics.wideMinWidth) {
      return KubusMapLayoutTier.intermediate;
    }
    return KubusMapLayoutTier.wide;
  }
}

/// Semantic map layout metrics.
///
/// This inventory intentionally covers values that recur across the mobile and
/// desktop map compositions: chrome insets, search width, primary touch
/// controls, dominant context panels, marker previews, and the relationship
/// between the mobile marker dock and Nearby peek. General-purpose spacing and
/// navigation dimensions continue to come from [KubusSpacing],
/// [KubusHeaderMetrics], and [KubusLayout].
abstract final class KubusMapMetrics {
  /// Compact layouts end immediately before a 768 px canvas.
  static const double intermediateMinWidth = 768.0;

  /// Wide layouts have enough map canvas for a stable side context surface.
  static const double wideMinWidth = 1200.0;

  /// Safe inset for persistent map chrome from the viewport edge.
  static const double chromeInset = KubusSpacing.md;

  /// Tighter edge inset for constrained compact layouts.
  static const double compactChromeInset = KubusSpacing.sm + KubusSpacing.xs;

  /// Maximum readable width for map search and its result surface.
  static const double searchMaxWidth = 560.0;

  /// Minimum interactive dimension for every map control.
  static const double minimumTouchTarget = KubusHeaderMetrics.actionHitArea;

  /// Visible mobile primary control size, including its tap target.
  static const double mobileControlSize = 48.0;

  /// Context panels target this range on intermediate and wide canvases.
  static const double desktopContextPanelMinWidth = 300.0;
  static const double desktopContextPanelPreferredWidth = 360.0;
  static const double desktopContextPanelMaxWidth = 420.0;

  /// Maximum share of a non-compact viewport occupied by a context panel.
  static const double desktopContextPanelMaxViewportFraction = 0.38;

  /// Marker previews share the established overlay card sizing range.
  static const double markerPreviewMinWidth = 272.0;
  static const double markerPreviewPreferredWidth = 320.0;
  static const double markerPreviewMaxWidth = 336.0;

  /// Stable visual separation between a marker and its desktop preview.
  static const double markerPreviewGap = KubusSpacing.md;

  /// Horizontal inset for the bottom-docked compact marker preview.
  static const double mobileMarkerPreviewInset =
      KubusSpacing.sm + KubusSpacing.xs;

  /// Maximum height of the map-first mobile marker preview.
  static const double mobileMarkerPreviewMaxHeight = 208.0;

  /// Accessibility allowance for large text without clipping the marker card.
  static const double mobileMarkerPreviewLargeTextMaxHeight = 288.0;

  /// Square cover size used by the compact mobile marker preview.
  static const double mobileMarkerPreviewMediaSize = 72.0;
  static const double mobileMarkerPreviewLargeTextMediaSize = 56.0;

  /// Vertical separation between the marker dock and Nearby peek.
  static const double mobileMarkerDockGap = KubusSpacing.sm;

  /// Nearby stays discoverable without permanently consuming the map canvas.
  static const double mobileNearbyPeekMinHeight = 72.0;
  static const double mobileNearbyPeekMaxHeight = 96.0;
  static const double mobileNearbyPeekViewportFraction = 0.10;

  /// Separation between a dominant panel and adjacent map chrome.
  static const double contextPanelSafeGap = KubusSpacing.md;

  /// Desktop chrome stays aligned with contextual panel geometry.
  static const double desktopChromeInset = KubusSpacing.lg;
  static const double desktopContextPanelTopInset = 80.0;
  static const double desktopContextPanelBottomInset = KubusSpacing.lg;

  static double chromeInsetFor(KubusMapLayoutTier tier) {
    return tier == KubusMapLayoutTier.compact
        ? compactChromeInset
        : chromeInset;
  }

  /// Resolves the search width while retaining symmetric viewport insets.
  static double resolveSearchWidth(double viewportWidth) {
    final tier = KubusMapLayoutTier.fromWidth(viewportWidth);
    final available = math.max(
      0.0,
      viewportWidth - (chromeInsetFor(tier) * 2.0),
    );
    return math.min(searchMaxWidth, available).toDouble();
  }

  /// Resolves a desktop context panel without allowing it to dominate the map.
  ///
  /// Compact layouts should use a sheet instead, so this resolver returns zero
  /// for them. At intermediate widths the preferred width yields to the
  /// viewport-share limit. Wide canvases settle at the preferred width rather
  /// than growing merely because more space exists.
  static double resolveDesktopContextPanelWidth(double viewportWidth) {
    if (KubusMapLayoutTier.fromWidth(viewportWidth) ==
        KubusMapLayoutTier.compact) {
      return 0.0;
    }
    final available = math.max(
      0.0,
      viewportWidth - (chromeInset * 2.0) - contextPanelSafeGap,
    );
    final maximumForViewport = math.min(
      desktopContextPanelMaxWidth,
      available * desktopContextPanelMaxViewportFraction,
    );
    final effectiveMinimum = math.min(
      desktopContextPanelMinWidth,
      maximumForViewport,
    );
    return desktopContextPanelPreferredWidth
        .clamp(effectiveMinimum, maximumForViewport)
        .toDouble();
  }

  /// Resolves a marker preview width within the available horizontal canvas.
  static double resolveMarkerPreviewWidth(double availableWidth) {
    final insetAvailable = math.max(
      0.0,
      availableWidth - (mobileMarkerPreviewInset * 2.0),
    );
    if (insetAvailable < markerPreviewMinWidth) {
      return insetAvailable;
    }
    return markerPreviewPreferredWidth
        .clamp(markerPreviewMinWidth,
            math.min(markerPreviewMaxWidth, insetAvailable))
        .toDouble();
  }

  /// Allows the compact preview to grow for accessibility text scaling while
  /// retaining the calmer fixed-height presentation at normal text sizes.
  static double resolveMobileMarkerPreviewMaxHeight(MediaQueryData media) {
    final textScale = media.textScaler.scale(1.0);
    return textScale > 1.3
        ? mobileMarkerPreviewLargeTextMaxHeight
        : mobileMarkerPreviewMaxHeight;
  }

  /// Resolves the collapsed Nearby affordance from viewport height.
  static double resolveMobileNearbyPeekHeight(double viewportHeight) {
    return (viewportHeight * mobileNearbyPeekViewportFraction)
        .clamp(mobileNearbyPeekMinHeight, mobileNearbyPeekMaxHeight)
        .toDouble();
  }

  /// Bottom inset for a mobile marker dock, including safe area and navigation.
  ///
  /// When Nearby is visible the dock yields to its compact peek. When marker
  /// context becomes dominant callers can hide Nearby and pass `false`.
  static double resolveMobileMarkerDockBottomInset({
    required double viewportHeight,
    required double safeBottom,
    required bool nearbyPeekVisible,
  }) {
    final nearbyHeight = nearbyPeekVisible
        ? resolveMobileNearbyPeekHeight(viewportHeight) + mobileMarkerDockGap
        : 0.0;
    return math.max(0.0, safeBottom) +
        KubusLayout.mainBottomNavBarHeight +
        mobileMarkerDockGap +
        nearbyHeight;
  }
}

/// A semantic motion role resolved to app-wide duration and curve tokens.
@immutable
class KubusMapMotionSpec {
  const KubusMapMotionSpec({
    required this.duration,
    required this.curve,
    required this.allowsSpatialTransform,
  });

  final Duration duration;
  final Curve curve;

  /// Whether translation, scale, or camera interpolation is appropriate.
  ///
  /// Opacity and selected-state feedback can remain when this is false.
  final bool allowsSpatialTransform;
}

/// Resolved semantic motion tokens for map interactions.
///
/// Normal motion is derived exclusively from [AppAnimationTheme]. Reduced
/// motion removes regrouping, camera, spiderfy, repositioning, and panel travel
/// while retaining short non-spatial feedback for entrances and selection.
@immutable
class KubusMapMotion {
  const KubusMapMotion._({
    required this.markerEnter,
    required this.markerSelect,
    required this.clusterRegroup,
    required this.clusterExpand,
    required this.spiderfy,
    required this.overlayEnter,
    required this.overlayReposition,
    required this.panelEnter,
    required this.reduced,
  });

  final KubusMapMotionSpec markerEnter;
  final KubusMapMotionSpec markerSelect;
  final KubusMapMotionSpec clusterRegroup;
  final KubusMapMotionSpec clusterExpand;
  final KubusMapMotionSpec spiderfy;
  final KubusMapMotionSpec overlayEnter;
  final KubusMapMotionSpec overlayReposition;
  final KubusMapMotionSpec panelEnter;
  final bool reduced;

  factory KubusMapMotion.resolve({
    required AppAnimationTheme animationTheme,
    required bool reduceMotion,
  }) {
    KubusMapMotionSpec role(
      Duration duration,
      Curve curve, {
      required bool spatial,
      required bool essentialFeedback,
    }) {
      if (!reduceMotion) {
        return KubusMapMotionSpec(
          duration: duration,
          curve: curve,
          allowsSpatialTransform: spatial,
        );
      }
      return KubusMapMotionSpec(
        duration: essentialFeedback ? animationTheme.short : Duration.zero,
        curve: animationTheme.fadeCurve,
        allowsSpatialTransform: false,
      );
    }

    return KubusMapMotion._(
      markerEnter: role(
        animationTheme.short,
        animationTheme.defaultCurve,
        spatial: true,
        essentialFeedback: true,
      ),
      markerSelect: role(
        animationTheme.short,
        animationTheme.emphasisCurve,
        spatial: true,
        essentialFeedback: true,
      ),
      clusterRegroup: role(
        animationTheme.medium,
        animationTheme.defaultCurve,
        spatial: true,
        essentialFeedback: false,
      ),
      clusterExpand: role(
        animationTheme.long,
        animationTheme.emphasisCurve,
        spatial: true,
        essentialFeedback: false,
      ),
      spiderfy: role(
        animationTheme.medium,
        animationTheme.emphasisCurve,
        spatial: true,
        essentialFeedback: false,
      ),
      overlayEnter: role(
        animationTheme.short,
        animationTheme.defaultCurve,
        spatial: true,
        essentialFeedback: true,
      ),
      overlayReposition: role(
        animationTheme.medium,
        animationTheme.defaultCurve,
        spatial: true,
        essentialFeedback: false,
      ),
      panelEnter: role(
        animationTheme.medium,
        animationTheme.emphasisCurve,
        spatial: true,
        essentialFeedback: false,
      ),
      reduced: reduceMotion,
    );
  }

  factory KubusMapMotion.fromMediaQuery({
    required AppAnimationTheme animationTheme,
    required MediaQueryData mediaQuery,
  }) {
    return KubusMapMotion.resolve(
      animationTheme: animationTheme,
      reduceMotion:
          mediaQuery.disableAnimations || mediaQuery.accessibleNavigation,
    );
  }

  factory KubusMapMotion.defaults({bool reduceMotion = false}) {
    return KubusMapMotion.resolve(
      animationTheme: AppAnimationTheme.defaults,
      reduceMotion: reduceMotion,
    );
  }
}
