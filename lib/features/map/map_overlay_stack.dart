import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Prevents pointer events from leaking through Flutter overlays to the
/// underlying MapLibre platform view on web.
///
/// This is a common footgun when building map overlays: without interception,
/// taps/scrolls can "touch through" to the map canvas.
class KubusMapPointerInterceptor extends StatelessWidget {
  const KubusMapPointerInterceptor({
    required this.child,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !enabled) return child;
    return PointerInterceptor(child: child);
  }
}

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

  @override
  Widget build(BuildContext context) {
    final isVisible = content != null;

    Widget layer = Stack(
      fit: StackFit.expand,
      children: [
        if (isVisible)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {},
              onPointerMove: (_) {},
              onPointerUp: (_) {},
              onPointerSignal: (_) {},
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
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
                    scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
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

    return Positioned.fill(
      child: KubusMapPointerInterceptor(
        enabled: isVisible,
        child: layer,
      ),
    );
  }
}
