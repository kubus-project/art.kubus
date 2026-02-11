import 'package:flutter/material.dart';

import '../../../features/map/shared/map_screen_shared_helpers.dart';
import '../../tutorial/interactive_tutorial_overlay.dart';

/// Shared map tutorial overlay shell used by mobile + desktop map screens.
class KubusMapTutorialOverlay extends StatelessWidget {
  const KubusMapTutorialOverlay({
    super.key,
    required this.visible,
    required this.steps,
    required this.currentIndex,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.skipLabel,
    required this.backLabel,
    required this.nextLabel,
    required this.doneLabel,
  });

  final bool visible;
  final List<TutorialStepDefinition> steps;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final String skipLabel;
  final String backLabel;
  final String nextLabel;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    if (!visible || steps.isEmpty) return const SizedBox.shrink();

    final int clampedIndex;
    if (currentIndex < 0) {
      clampedIndex = 0;
    } else if (currentIndex >= steps.length) {
      clampedIndex = steps.length - 1;
    } else {
      clampedIndex = currentIndex;
    }
    return Stack(
      children: [
        Positioned.fill(
          child: KubusMapWebPointerInterceptor.wrap(
            child: const ModalBarrier(
              dismissible: false,
              color: Colors.transparent,
            ),
          ),
        ),
        Positioned.fill(
          child: KubusMapWebPointerInterceptor.wrap(
            child: InteractiveTutorialOverlay(
              steps: steps,
              currentIndex: clampedIndex,
              onNext: onNext,
              onBack: onBack,
              onSkip: onSkip,
              skipLabel: skipLabel,
              backLabel: backLabel,
              nextLabel: nextLabel,
              doneLabel: doneLabel,
            ),
          ),
        ),
      ],
    );
  }
}
