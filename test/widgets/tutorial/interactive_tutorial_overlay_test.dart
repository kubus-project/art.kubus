import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/tutorial/interactive_tutorial_overlay.dart';

void main() {
  testWidgets(
      'InteractiveTutorialOverlay lets background gestures pass through',
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

    await tester.dragFrom(const Offset(120, 120), const Offset(80, 0));
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

    expect(tapCount, 1);
    expect(panCount, greaterThan(0));
  });

  testWidgets(
      'InteractiveTutorialOverlay defers target actions without auto-advancing',
      (tester) async {
    int targetTapCount = 0;
    int nextCount = 0;
    final firstTargetKey = GlobalKey();

    final steps = <TutorialStepDefinition>[
      TutorialStepDefinition(
        targetKey: firstTargetKey,
        title: 'Step 1',
        body: 'Body 1',
        onTargetTap: () => targetTapCount += 1,
      ),
      const TutorialStepDefinition(
        title: 'Step 2',
        body: 'Body 2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: SizedBox(
                  key: firstTargetKey,
                  width: 48,
                  height: 48,
                ),
              ),
              InteractiveTutorialOverlay(
                steps: steps,
                currentIndex: 0,
                onNext: () => nextCount += 1,
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

    final targetCenter = tester.getCenter(find.byKey(firstTargetKey));
    await tester.tapAt(targetCenter);

    // Deferred until the next frame.
    expect(targetTapCount, 0);
    expect(nextCount, 0);

    await tester.pump();
    await tester.pump();
    expect(targetTapCount, 1);
    expect(nextCount, 0);
  });

  testWidgets('descriptive highlight tap does not advance', (tester) async {
    int nextCount = 0;
    final targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: SizedBox(
                  key: targetKey,
                  width: 48,
                  height: 48,
                ),
              ),
              InteractiveTutorialOverlay(
                steps: <TutorialStepDefinition>[
                  TutorialStepDefinition(
                    targetKey: targetKey,
                    title: 'Step 1',
                    body: 'Body 1',
                  ),
                  const TutorialStepDefinition(
                    title: 'Step 2',
                    body: 'Body 2',
                  ),
                ],
                currentIndex: 0,
                onNext: () => nextCount += 1,
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
    await tester.tapAt(tester.getCenter(find.byKey(targetKey)));
    await tester.pump();
    await tester.pump();

    expect(nextCount, 0);
    expect(
      find.byKey(InteractiveTutorialOverlay.highlightTapRegionKey),
      findsNothing,
    );
  });

  testWidgets('explicit target advance calls onNext once', (tester) async {
    int nextCount = 0;
    final targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: SizedBox(
                  key: targetKey,
                  width: 48,
                  height: 48,
                ),
              ),
              InteractiveTutorialOverlay(
                steps: <TutorialStepDefinition>[
                  TutorialStepDefinition(
                    targetKey: targetKey,
                    title: 'Step 1',
                    body: 'Body 1',
                    advanceOnTargetTap: true,
                  ),
                  const TutorialStepDefinition(
                    title: 'Step 2',
                    body: 'Body 2',
                  ),
                ],
                currentIndex: 0,
                onNext: () => nextCount += 1,
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
    await tester.tapAt(tester.getCenter(find.byKey(targetKey)));
    await tester.pump();
    await tester.pump();

    expect(nextCount, 1);
  });

  testWidgets('last-step target tap does not dismiss by default',
      (tester) async {
    int nextCount = 0;
    int skipCount = 0;
    final targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: SizedBox(
                  key: targetKey,
                  width: 48,
                  height: 48,
                ),
              ),
              InteractiveTutorialOverlay(
                steps: <TutorialStepDefinition>[
                  TutorialStepDefinition(
                    targetKey: targetKey,
                    title: 'Only step',
                    body: 'Body',
                    advanceOnTargetTap: true,
                  ),
                ],
                currentIndex: 0,
                onNext: () => nextCount += 1,
                onBack: () {},
                onSkip: () => skipCount += 1,
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
    await tester.tapAt(tester.getCenter(find.byKey(targetKey)));
    await tester.pump();
    await tester.pump();

    expect(nextCount, 0);
    expect(skipCount, 0);
    expect(find.byKey(InteractiveTutorialOverlay.tooltipKey), findsOneWidget);
  });

  testWidgets('shows fallback tooltip when target geometry is unavailable',
      (tester) async {
    final detachedTargetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveTutorialOverlay(
            steps: <TutorialStepDefinition>[
              TutorialStepDefinition(
                targetKey: detachedTargetKey,
                title: 'Step',
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

    await tester.pump();

    expect(
        find.byKey(InteractiveTutorialOverlay.overlayRootKey), findsOneWidget);
    expect(find.byKey(InteractiveTutorialOverlay.tooltipKey), findsOneWidget);
    expect(find.byKey(InteractiveTutorialOverlay.highlightTapRegionKey),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps rendering when target disappears after valid geometry',
      (tester) async {
    final targetKey = GlobalKey();
    late StateSetter setHarnessState;
    var showTarget = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHarnessState = setState;
              return Stack(
                children: [
                  if (showTarget)
                    Center(
                      child: SizedBox(
                        key: targetKey,
                        width: 48,
                        height: 48,
                      ),
                    ),
                  InteractiveTutorialOverlay(
                    steps: <TutorialStepDefinition>[
                      TutorialStepDefinition(
                        targetKey: targetKey,
                        title: 'Step',
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
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(InteractiveTutorialOverlay.tooltipKey), findsOneWidget);

    setHarnessState(() => showTarget = false);
    await tester.pump();
    await tester.pump();

    expect(
        find.byKey(InteractiveTutorialOverlay.overlayRootKey), findsOneWidget);
    expect(find.byKey(InteractiveTutorialOverlay.tooltipKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses cached target rect when current target geometry is invalid',
      (tester) async {
    final targetKey = GlobalKey();
    late StateSetter setHarnessState;
    var showTarget = true;
    var targetTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHarnessState = setState;
              return Stack(
                children: [
                  if (showTarget)
                    Center(
                      child: SizedBox(
                        key: targetKey,
                        width: 48,
                        height: 48,
                      ),
                    ),
                  InteractiveTutorialOverlay(
                    steps: <TutorialStepDefinition>[
                      TutorialStepDefinition(
                        targetKey: targetKey,
                        title: 'Step',
                        body: 'Body',
                        onTargetTap: () => targetTapCount += 1,
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
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final oldCenter = tester.getCenter(find.byKey(targetKey));

    setHarnessState(() => showTarget = false);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(InteractiveTutorialOverlay.highlightTapRegionKey),
        findsOneWidget);
    await tester.tapAt(oldCenter);
    await tester.pump();
    await tester.pump();

    expect(targetTapCount, 1);
  });

  testWidgets(
      'InteractiveTutorialOverlay does not invoke target from outside highlight',
      (tester) async {
    int targetTapCount = 0;
    final targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: SizedBox(
                  key: targetKey,
                  width: 48,
                  height: 48,
                ),
              ),
              InteractiveTutorialOverlay(
                steps: <TutorialStepDefinition>[
                  TutorialStepDefinition(
                    targetKey: targetKey,
                    title: 'Step',
                    body: 'Body',
                    onTargetTap: () => targetTapCount += 1,
                    advanceOnTargetTap: false,
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
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();

    expect(targetTapCount, 0);
  });
}
