import 'package:art_kubus/widgets/map/tutorial/kubus_map_tutorial_overlay.dart';
import 'package:art_kubus/widgets/tutorial/interactive_tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KubusMapTutorialOverlay routes next/skip callbacks',
      (tester) async {
    final targetKey = GlobalKey();
    var nextTapped = 0;
    var skipTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox(
                key: targetKey,
                width: 40,
                height: 40,
              ),
              KubusMapTutorialOverlay(
                visible: true,
                steps: <TutorialStepDefinition>[
                  TutorialStepDefinition(
                    targetKey: targetKey,
                    title: 'Title',
                    body: 'Body',
                  ),
                ],
                currentIndex: 0,
                onNext: () => nextTapped += 1,
                onBack: () {},
                onSkip: () => skipTapped += 1,
                skipLabel: 'Skip',
                backLabel: 'Back',
                nextLabel: 'Next',
                doneLabel: 'Done',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(nextTapped, 1);
    expect(skipTapped, 1);
  });

  testWidgets('KubusMapTutorialOverlay tolerates missing target render context',
      (tester) async {
    final detachedTargetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KubusMapTutorialOverlay(
            visible: true,
            steps: <TutorialStepDefinition>[
              TutorialStepDefinition(
                targetKey: detachedTargetKey,
                title: 'Title',
                body: 'Body',
              ),
            ],
            currentIndex: 0,
            onNext: () {},
            onBack: () {},
            onSkip: () {},
            skipLabel: 'Skip',
            backLabel: 'Back',
            nextLabel: 'Next',
            doneLabel: 'Done',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'KubusMapTutorialOverlay blocks taps from reaching underlying map layer',
      (tester) async {
    final targetKey = GlobalKey();
    var backgroundTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => backgroundTapCount += 1,
                  child: const SizedBox.expand(),
                ),
              ),
              Center(
                child: SizedBox(
                  key: targetKey,
                  width: 40,
                  height: 40,
                ),
              ),
              KubusMapTutorialOverlay(
                visible: true,
                steps: <TutorialStepDefinition>[
                  TutorialStepDefinition(
                    targetKey: targetKey,
                    title: 'Title',
                    body: 'Body',
                  ),
                ],
                currentIndex: 0,
                onNext: () {},
                onBack: () {},
                onSkip: () {},
                skipLabel: 'Skip',
                backLabel: 'Back',
                nextLabel: 'Next',
                doneLabel: 'Done',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(backgroundTapCount, 0);
  });
}
