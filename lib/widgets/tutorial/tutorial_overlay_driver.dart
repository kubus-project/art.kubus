import 'package:flutter/foundation.dart';

import 'interactive_tutorial_overlay.dart';

/// Minimal interface that lets the root tutorial presenter render and control
/// a tutorial flow without caring who owns the state machine.
///
/// Map tutorial uses [MapTutorialCoordinator] as a driver.
/// Other screens can use [TutorialOverlayController.showTutorial] which creates
/// an internal driver.
abstract class TutorialOverlayDriver extends Listenable {
  /// Whether the tutorial should be visible.
  bool get visible;

  /// Current step index.
  int get currentIndex;

  /// Steps to render.
  List<TutorialStepDefinition> get steps;

  void next();
  void back();

  Future<void> dismiss();
}
