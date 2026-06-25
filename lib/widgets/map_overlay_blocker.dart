import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// A small helper for map overlays layered above the MapLibre platform view.
///
/// Goals:
/// - Make the overlay area hit-test opaque so pointer/scroll events don't leak
///   through to the map underneath.
/// - On web, add a [PointerInterceptor] so events don't reach the map DOM node.
/// - Optionally override the mouse cursor for the overlay surface.
class MapOverlayBlocker extends StatelessWidget {
  const MapOverlayBlocker({
    super.key,
    required this.child,
    this.enabled = true,
    this.cursor = SystemMouseCursors.basic,
    this.interceptPlatformViews = true,
  });

  final Widget child;

  /// When false, this widget becomes a no-op wrapper.
  final bool enabled;

  /// Cursor for the overlay surface. Interactive children should override this
  /// with their own [MouseRegion] or `mouseCursor` properties.
  final MouseCursor cursor;

  /// Whether to insert a [PointerInterceptor] on web.
  final bool interceptPlatformViews;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    // Important: avoid GestureDetector(onTap: ...) here.
    // On web this can steal taps from interactive children by competing in the
    // gesture arena, which breaks hit-testing for visible UI layered above the
    // MapLibre DOM node.
    Widget result = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      onPointerMove: (_) {},
      onPointerUp: (_) {},
      onPointerCancel: (_) {},
      onPointerSignal: (_) {},
      child: child,
    );

    result = MouseRegion(cursor: cursor, child: result);

    // Insert a PointerInterceptor over the overlay so touches/clicks don't get
    // captured by the map platform view underneath. This is required not only on
    // web (DOM map node) but also on iOS/Android, where MapLibre renders as a
    // native platform view that otherwise steals taps from Flutter overlay
    // buttons (claim/save/like/share) layered above it. `pointer_interceptor`
    // (^0.10) ships web/iOS/Android implementations but NOT desktop, where the
    // map composites with Flutter and no interceptor is needed (and calling it
    // would throw), so desktop is intentionally excluded.
    final needsPlatformViewInterceptor = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    if (interceptPlatformViews && needsPlatformViewInterceptor) {
      result = PointerInterceptor(child: result);
    }

    return result;
  }
}
