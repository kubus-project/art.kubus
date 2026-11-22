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
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(next, _position)) {
      _position?.removeListener(_check);
      _position = next;
      _position?.addListener(_check);
    }
    _scheduleCheck();
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _scheduleCheck() {
    if (_revealed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted || _revealed) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      _scheduleCheck();
      return;
    }
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < viewportHeight && top + box.size.height > 0) {
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
