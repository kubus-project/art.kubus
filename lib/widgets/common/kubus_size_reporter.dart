import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Reports the laid-out size of [child] to [onSize] after layout, whenever it
/// changes. Lets a sibling take exactly the width of this widget (for example
/// a card that must match the control cluster beneath it) without intrinsic
/// sizing, which the cards' flexible content cannot answer.
class KubusSizeReporter extends SingleChildRenderObjectWidget {
  const KubusSizeReporter({
    super.key,
    required this.onSize,
    required super.child,
  });

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderObject renderObject,
  ) {
    (renderObject as _RenderSizeReporter).onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final next = size;
    if (_last == next) return;
    _last = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(next);
    });
  }
}
