import 'package:flutter/widgets.dart';

import 'tutorial_overlay_controller.dart';

class TutorialOverlayScope
    extends InheritedNotifier<TutorialOverlayController> {
  const TutorialOverlayScope({
    super.key,
    required TutorialOverlayController controller,
    required super.child,
  }) : super(notifier: controller);

  static TutorialOverlayController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TutorialOverlayScope>();
    final controller = scope?.notifier;
    assert(controller != null, 'TutorialOverlayScope not found in widget tree');
    return controller!;
  }

  static TutorialOverlayController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TutorialOverlayScope>();
    return scope?.notifier;
  }
}
