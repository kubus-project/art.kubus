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
/// controls, dominant context panels, and marker overlay cards.
/// General-purpose spacing and navigation dimensions continue to come from [KubusSpacing],
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

  /// Corner radius shared by the stacked mobile map header surfaces (search
  /// field and discovery path bar).
  ///
  /// These two sit directly on top of each other, so they must resolve to the
  /// same token or the header reads as two unrelated shapes. [KubusRadius.sm]
  /// is the documented "Buttons, Inputs" radius: it keeps the header
  /// rectangular instead of the pill/capsule silhouette produced by the larger
  /// container tokens.
  static const double headerSurfaceRadius = KubusRadius.sm;

  /// Visible mobile primary control size, including its tap target.
  static const double mobileControlSize = 48.0;

  /// Context panels target this range on intermediate and wide canvases.
  static const double desktopContextPanelMinWidth = 300.0;
  static const double desktopContextPanelPreferredWidth = 360.0;
  static const double desktopContextPanelMaxWidth = 420.0;

  /// Maximum share of a non-compact viewport occupied by a context panel.
  static const double desktopContextPanelMaxViewportFraction = 0.38;

  /// Marker overlay cards share this readable width range.
  static const double markerOverlayCardMinWidth = 272.0;
  static const double markerOverlayCardPreferredWidth = 320.0;
  static const double markerOverlayCardMaxWidth = 336.0;

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
