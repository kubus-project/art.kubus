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
    Widget result = Listener(
      behavior: enabled ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      onPointerDown: enabled ? (_) {} : null,
      onPointerMove: enabled ? (_) {} : null,
      onPointerUp: enabled ? (_) {} : null,
      onPointerCancel: enabled ? (_) {} : null,
      onPointerSignal: enabled ? (_) {} : null,
      child: child,
    );

    result = MouseRegion(cursor: cursor, child: result);

    if (kIsWeb && enabled && interceptPlatformViews) {
      result = PointerInterceptor(child: result);
    }

    return result;
  }
}

