import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/tutorial/interactive_tutorial_overlay.dart';

void main() {
  testWidgets('InteractiveTutorialOverlay absorbs background gestures',
      (tester) async {
    int tapCount = 0;
    int panCount = 0;
    int scaleCount = 0;
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
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerMove: (_) => panCount += 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => tapCount += 1,
                    onScaleUpdate: (_) => scaleCount += 1,
                    child: const SizedBox.expand(),
                  ),
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

    final gesture1 = await tester.startGesture(
      const Offset(120, 120),
      pointer: 1,
    );
    final gesture2 = await tester.startGesture(
      const Offset(200, 120),
      pointer: 2,
    );
    await tester.pump();
    await gesture1.moveTo(const Offset(100, 120));
    await gesture2.moveTo(const Offset(220, 120));
    await tester.pump();
    await gesture1.up();
    await gesture2.up();

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(tapCount, 0);
    expect(panCount, 0);
    expect(scaleCount, 0);
  });
}
