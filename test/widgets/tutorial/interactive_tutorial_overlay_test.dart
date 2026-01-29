import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/tutorial/interactive_tutorial_overlay.dart';

void main() {
  testWidgets('InteractiveTutorialOverlay absorbs background gestures',
      (tester) async {
    int tapCount = 0;
    int panCount = 0;
    final targetKey = GlobalKey();

    final steps = <TutorialStepDefinition>[
      TutorialStepDefinition(
        targetKey: targetKey,
        title: 'Step title',
        body: 'Step body',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapCount += 1,
                  onPanUpdate: (_) => panCount += 1,
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
              InteractiveTutorialOverlay(
                steps: steps,
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

    await tester.drag(
      find.byType(InteractiveTutorialOverlay),
      const Offset(80, 0),
    );
    await tester.pump();

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(tapCount, 0);
    expect(panCount, 0);
  });
}
