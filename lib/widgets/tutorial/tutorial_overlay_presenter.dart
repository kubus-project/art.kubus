import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'interactive_tutorial_overlay.dart';
import 'tutorial_overlay_controller.dart';

class TutorialOverlayPresenter extends StatelessWidget {
  const TutorialOverlayPresenter({
    super.key,
    required this.controller,
  });

  final TutorialOverlayController controller;

  static const Key rootKey =
      ValueKey<String>('kubus_tutorial_overlay_presenter');
  static const Key tooltipKey = ValueKey<String>('kubus_tutorial_tooltip');
  static const Key highlightTapRegionKey =
      ValueKey<String>('kubus_tutorial_highlight_tap_region');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final driver = controller.driver;
        if (driver == null || !driver.visible || driver.steps.isEmpty) {
          _debugLog(
            'hidden tutorialId=${controller.tutorialId} '
            'ownerRoute=${controller.ownerRoute} '
            'hasDriver=${driver != null} visible=${driver?.visible} '
            'index=${driver?.currentIndex} steps=${driver?.steps.length}',
          );
          return const SizedBox.shrink();
        }

        final steps = driver.steps;
        final int clampedIndex;
        if (driver.currentIndex < 0) {
          clampedIndex = 0;
        } else if (driver.currentIndex >= steps.length) {
          clampedIndex = steps.length - 1;
        } else {
          clampedIndex = driver.currentIndex;
        }

        final l10n = AppLocalizations.of(context)!;
        _debugLog(
          'visible tutorialId=${controller.tutorialId} '
          'ownerRoute=${controller.ownerRoute} '
          'index=${driver.currentIndex} clampedIndex=$clampedIndex '
          'steps=${steps.length}',
        );

        return KeyedSubtree(
          key: rootKey,
          child: InteractiveTutorialOverlay(
            steps: steps,
            currentIndex: clampedIndex,
            onNext: driver.next,
            onBack: driver.back,
            onSkip: () => unawaited(driver.dismiss()),
            skipLabel: l10n.commonSkip,
            backLabel: l10n.commonBack,
            nextLabel: l10n.commonNext,
            doneLabel: l10n.commonDone,
          ),
        );
      },
    );
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('TutorialOverlayPresenter: $message');
  }
}
