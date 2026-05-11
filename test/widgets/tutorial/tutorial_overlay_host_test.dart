import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/tutorial/interactive_tutorial_overlay.dart';
import 'package:art_kubus/widgets/tutorial/tutorial_overlay_controller.dart';
import 'package:art_kubus/widgets/tutorial/tutorial_overlay_host.dart';
import 'package:art_kubus/widgets/tutorial/tutorial_overlay_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'TutorialOverlayHost renders in full-window coordinates (sidebar layout)',
      (tester) async {
    final targetKey = GlobalKey();
    var targetTapCount = 0;

    late TutorialOverlayController controller;

    await tester.pumpWidget(
      _buildApp(
        Scaffold(
          body: TutorialOverlayHost(
            child: Builder(
              builder: (context) {
                controller = TutorialOverlayScope.of(context);
                return Row(
                  children: [
                    const SizedBox(
                      width: 240,
                      child: ColoredBox(color: Colors.black12),
                    ),
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          key: targetKey,
                          width: 48,
                          height: 48,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    controller.showTutorial(
      tutorialId: 'test',
      ownerRoute: 'test',
      steps: <TutorialStepDefinition>[
        TutorialStepDefinition(
          targetKey: targetKey,
          title: 'Title',
          body: 'Body',
          onTargetTap: () => targetTapCount += 1,
          advanceOnTargetTap: false,
        ),
      ],
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(InteractiveTutorialOverlay.tooltipKey), findsOneWidget);

    final targetCenter = tester.getCenter(find.byKey(targetKey));
    await tester.tapAt(targetCenter);

    // Target callbacks are deferred by a frame.
    await tester.pump();
    await tester.pump();

    expect(targetTapCount, 1);
  });
}
