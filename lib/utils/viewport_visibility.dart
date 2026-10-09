import 'package:flutter/widgets.dart';

/// Fraction (0..1) of the box behind [context] that is actually visible.
///
/// The box is intersected with the approximate paint clip of every ancestor
/// (scroll viewports, clipped cards) and with the view itself, so a widget that
/// has scrolled out of a list reads as 0 even though it is still built. Returns
/// 0 when the widget is not laid out or not attached.
double widgetVisibleFraction(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize) {
    return 0;
  }
  final size = renderObject.size;
  if (size.isEmpty) return 0;

  final boxRect = MatrixUtils.transformRect(
    renderObject.getTransformTo(null),
    Offset.zero & size,
  );
  final boxArea = boxRect.width * boxRect.height;
  if (boxArea <= 0) return 0;

  var visible = boxRect;
  final view = View.maybeOf(context);
  if (view != null) {
    final logical = view.physicalSize / view.devicePixelRatio;
    visible = visible.intersect(Offset.zero & logical);
    if (visible.isEmpty) return 0;
  }

  RenderObject child = renderObject;
  RenderObject? parent = renderObject.parent;
  while (parent != null) {
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      final globalClip = MatrixUtils.transformRect(
        parent.getTransformTo(null),
        clip,
      );
      visible = visible.intersect(globalClip);
      if (visible.isEmpty) return 0;
    }
    child = parent;
    parent = parent.parent;
  }

  return (visible.width * visible.height / boxArea).clamp(0.0, 1.0);
}
