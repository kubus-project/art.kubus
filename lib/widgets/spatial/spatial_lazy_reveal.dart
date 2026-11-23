import 'package:flutter/material.dart';

/// Builds [child] only once this widget has scrolled into the viewport.
///
/// A splat is tens of megabytes. A visitor who never scrolls to it should not
/// pay for it, so the inline viewer is created on first sight rather than on
/// page load. Until then [placeholder] holds the same space (the box is sized
/// by [height], so the page does not jump when the viewer appears). Once
/// revealed it stays revealed.
class SpatialLazyReveal extends StatefulWidget {
  const SpatialLazyReveal({
    required this.height,
    required this.placeholder,
    required this.child,
    super.key,
  });

  final double height;
  final Widget placeholder;
  final Widget child;

  @override
  State<SpatialLazyReveal> createState() => _SpatialLazyRevealState();
}

class _SpatialLazyRevealState extends State<SpatialLazyReveal> {
  bool _revealed = false;
  final List<ScrollPosition> _positions = <ScrollPosition>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Registers a dependency on the nearest scrollable's scope, so this runs
    // again when that scrollable replaces its ScrollPosition (a new controller
    // or physics): the position listened to below is disposed then and would
    // never notify again.
    Scrollable.maybeOf(context);
    _syncPositions();
    _scheduleCheck();
  }

  /// Listens to the position of every scrollable above this widget, on either
  /// axis: a viewer inside a horizontally paged parent must be revealed by the
  /// page turning, not only by the vertical scroll around it. Cheap, and run
  /// again before every check, so a replaced position (including one of an
  /// outer scrollable, which registers no dependency) is picked up.
  void _syncPositions() {
    final next = <ScrollPosition>[];
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        next.add((element.state as ScrollableState).position);
      }
      return true;
    });
    var unchanged = next.length == _positions.length;
    for (var i = 0; unchanged && i < next.length; i++) {
      unchanged = identical(next[i], _positions[i]);
    }
    if (unchanged) return;
    for (final position in _positions) {
      position.removeListener(_scheduleCheck);
    }
    _positions
      ..clear()
      ..addAll(next);
    for (final position in _positions) {
      position.addListener(_scheduleCheck);
    }
  }

  @override
  void dispose() {
    for (final position in _positions) {
      position.removeListener(_scheduleCheck);
    }
    super.dispose();
  }

  bool _checkQueued = false;

  /// Checks after the next layout. A scroll listener fires before the new
  /// scroll offset has been laid out (a page jump moves the child only at
  /// layout), so it must never measure at once.
  void _scheduleCheck() {
    if (_revealed || _checkQueued) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      _check();
    });
  }

  /// The part of the screen this widget may currently be seen through: the
  /// window, narrowed by the on-screen box of every scrollable above it (a pane
  /// shorter than the window, a horizontally paged parent). Null when a
  /// scrollable above it has no layout yet.
  Rect? _visibleBounds() {
    var bounds = Offset.zero & MediaQuery.sizeOf(context);
    final boxes = <RenderBox>[];
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final box = element.renderObject;
        if (box is RenderBox) boxes.add(box);
      }
      return true;
    });
    for (final box in boxes) {
      if (!box.attached || !box.hasSize) return null;
      bounds = bounds.intersect(box.localToGlobal(Offset.zero) & box.size);
    }
    return bounds;
  }

  void _check() {
    if (!mounted || _revealed) return;
    _syncPositions();
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      _scheduleCheck();
      return;
    }
    final visible = _visibleBounds();
    if (visible == null) {
      _scheduleCheck();
      return;
    }
    final own = box.localToGlobal(Offset.zero) & box.size;
    // A positive-area overlap: a box that only touches the edge is not seen.
    final overlap = own.intersect(visible);
    if (overlap.width > 0 && overlap.height > 0) {
      setState(() => _revealed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-check after every layout so a page that grows above this widget
    // (late images, expanding sections) still reveals it.
    if (!_revealed) _scheduleCheck();
    return SizedBox(
      height: widget.height,
      child: _revealed ? widget.child : widget.placeholder,
    );
  }
}
