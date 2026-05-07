import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../widgets/map_overlay_blocker.dart';
import '../../widgets/map/overlays/kubus_marker_overlay_card_wrapper.dart';

/// Shared overlay layer shell for marker selection overlays.
///
/// The content itself (mobile anchored card vs desktop positioned card) is
/// provided by the caller, but the following behavior is centralized:
/// - web pointer interception (no click-through to the MapLibre DOM element)
/// - backdrop that dismisses the overlay
/// - consistent AnimatedSwitcher transition used by mobile+desktop
class KubusMapMarkerOverlayLayer extends StatelessWidget {
  const KubusMapMarkerOverlayLayer({
    required this.content,
    required this.contentKey,
    required this.onDismiss,
    this.underlay,
    this.cursor,
    this.blockMapGestures = true,
    this.dismissOnBackdropTap = true,
    this.interceptPlatformViews = true,
    super.key,
  });

  /// When null, the overlay is considered hidden.
  final Widget? content;

  /// Key for the visible overlay content.
  final Key contentKey;

  final VoidCallback onDismiss;

  /// Optional layer painted behind the animated overlay content.
  ///
  /// Used for effects like the mobile marker tap ripple.
  final Widget? underlay;

  /// Desktop uses a basic cursor over the overlay layer.
  final MouseCursor? cursor;

  /// When true, a full-screen backdrop is inserted above the map.
  ///
  /// This was the legacy behavior, but it can feel like the map "freezes" on
  /// marker tap because all map gestures are blocked.
  ///
  /// Most screens now prefer leaving map gestures enabled and only blocking
  /// interaction within the actual overlay card (via [MapOverlayBlocker]).
  final bool blockMapGestures;

  /// Whether tapping the backdrop dismisses the overlay.
  ///
  /// Only applies when [blockMapGestures] is true.
  final bool dismissOnBackdropTap;

  /// Whether to intercept events over platform views (web MapLibre DOM).
  ///
  /// Only applies when [blockMapGestures] is true.
  final bool interceptPlatformViews;

  @override
  Widget build(BuildContext context) {
    final isVisible = content != null;

    Widget layer = Stack(
      fit: StackFit.expand,
      children: [
        if (isVisible && blockMapGestures)
          Positioned.fill(
            child: MapOverlayBlocker(
              enabled: true,
              cursor: cursor ?? SystemMouseCursors.basic,
              interceptPlatformViews: interceptPlatformViews,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: dismissOnBackdropTap ? onDismiss : null,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        if (underlay != null) underlay!,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved);
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: slide,
                  child: ScaleTransition(
                    scale:
                        Tween<double>(begin: 0.985, end: 1.0).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
            child: !isVisible
                ? const SizedBox.shrink(key: ValueKey('marker_overlay_hidden'))
                // Use StackFit.expand to ensure bounded constraints for
                // Positioned.fill children during AnimatedSwitcher transitions.
                // Without this, web can throw "RenderBox was not laid out".
                : Stack(
                    key: contentKey,
                    fit: StackFit.expand,
                    children: [content!],
                  ),
          ),
        ),
      ],
    );

    if (cursor != null) {
      layer = MouseRegion(cursor: cursor!, child: layer);
    }

    return Positioned.fill(child: layer);
  }
}

/// Shared marker overlay shell that combines the backdrop layer and the
/// anchored/centered card wrapper.
///
/// Screens supply only the marker-card builder and per-screen sizing config.
class KubusMapMarkerOverlayShell {
  const KubusMapMarkerOverlayShell._();

  static Widget build({
    required bool isVisible,
    required ValueListenable<Offset?> anchorListenable,
    required Key contentKey,
    required VoidCallback onDismiss,
    required Widget Function(
      BuildContext context,
      KubusMarkerOverlayLayoutState layout,
    ) cardBuilder,
    required KubusMarkerOverlayPlacementStrategy placementStrategy,
    required KubusMarkerOverlayWidthResolver widthResolver,
    required KubusMarkerOverlayMaxHeightResolver maxHeightResolver,
    required KubusMarkerOverlayHeightResolver heightResolver,
    KubusMarkerOverlayFallbackAnchorResolver? fallbackAnchorResolver,
    double horizontalPadding = 16,
    double topPadding = 12,
    double bottomPadding = 12,
    double markerOffset = 32,
    KubusMarkerOverlayAnimationConfig animation =
        const KubusMarkerOverlayAnimationConfig(),
    MouseCursor? cursor,
    Widget? underlay,
    bool blockMapGestures = false,
    bool dismissOnBackdropTap = false,
    bool interceptPlatformViews = true,
    bool enabled = true,
    bool centerWhenAnchorMissing = true,
    KubusMarkerOverlayLayoutCallback? onLayoutResolved,
  }) {
    return KubusMapMarkerOverlayLayer(
      content: isVisible
          ? KubusMarkerOverlayCardWrapper(
              anchorListenable: anchorListenable,
              placementStrategy: placementStrategy,
              widthResolver: widthResolver,
              maxHeightResolver: maxHeightResolver,
              heightResolver: heightResolver,
              fallbackAnchorResolver: fallbackAnchorResolver,
              horizontalPadding: horizontalPadding,
              topPadding: topPadding,
              bottomPadding: bottomPadding,
              markerOffset: markerOffset,
              animation: animation,
              cursor: cursor ?? SystemMouseCursors.basic,
              interceptPlatformViews: interceptPlatformViews,
              enabled: enabled,
              centerWhenAnchorMissing: centerWhenAnchorMissing,
              onLayoutResolved: onLayoutResolved,
              cardBuilder: cardBuilder,
            )
          : null,
      contentKey: contentKey,
      onDismiss: onDismiss,
      underlay: underlay,
      cursor: cursor,
      blockMapGestures: blockMapGestures,
      dismissOnBackdropTap: dismissOnBackdropTap,
      interceptPlatformViews: interceptPlatformViews,
    );
  }
}
