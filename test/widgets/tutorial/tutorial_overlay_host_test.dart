import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/tutorial/interactive_tutorial_overlay.dart';
import 'package:art_kubus/widgets/tutorial/tutorial_overlay_controller.dart';
import 'package:art_kubus/widgets/tutorial/tutorial_overlay_driver.dart';
import 'package:art_kubus/widgets/tutorial/tutorial_overlay_host.dart';
import 'package:art_kubus/widgets/tutorial/tutorial_overlay_presenter.dart';
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
      'TutorialOverlayHost does not block taps with no tutorial visible',
      (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _buildApp(
        Scaffold(
          body: TutorialOverlayHost(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tapCount += 1,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(40, 40));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets(
      'TutorialOverlayHost blocks background taps during tutorial and restores after skip',
      (tester) async {
    final targetKey = GlobalKey();
    var tapCount = 0;
    late TutorialOverlayController controller;

    await tester.pumpWidget(
      _buildApp(
        Scaffold(
          body: TutorialOverlayHost(
            child: Builder(
              builder: (context) {
                controller = TutorialOverlayScope.of(context);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => tapCount += 1,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Center(
                      child: SizedBox(
                        key: targetKey,
                        width: 48,
                        height: 48,
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
      tutorialId: 'modal-gate',
      ownerRoute: 'mobile-map',
      steps: <TutorialStepDefinition>[
        TutorialStepDefinition(
          targetKey: targetKey,
          title: 'Title',
          body: 'Body',
        ),
      ],
    );

    await tester.pump();
    await tester.pump();

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(find.byKey(TutorialOverlayPresenter.rootKey), findsOneWidget);
    expect(tapCount, 0);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(TutorialOverlayPresenter.rootKey), findsNothing);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets(
      'TutorialOverlayPresenter does not self-unbind for shell route mismatch',
      (tester) async {
    final controller = TutorialOverlayController();
    final targetKey = GlobalKey();
    final driver = _TestTutorialDriver(
      steps: <TutorialStepDefinition>[
        TutorialStepDefinition(
          targetKey: targetKey,
          title: 'Map controls',
          body: 'Use these controls to move around the map.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        initialRoute: '/shell',
        routes: <String, WidgetBuilder>{
          '/shell': (context) {
            return Scaffold(
              body: TutorialOverlayScope(
                controller: controller,
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        key: targetKey,
                        width: 48,
                        height: 48,
                      ),
                    ),
                    Positioned.fill(
                      child: TutorialOverlayPresenter(controller: controller),
                    ),
                  ],
                ),
              ),
            );
          },
        },
      ),
    );

    controller.bindDriver(
      tutorialId: 'map',
      ownerRoute: '/map',
      driver: driver,
    );

    await tester.pump();
    await tester.pump();

    expect(controller.driver, same(driver));
    expect(find.byKey(TutorialOverlayPresenter.rootKey), findsOneWidget);

    await tester.pump();

    expect(controller.driver, same(driver));
    expect(find.byKey(TutorialOverlayPresenter.rootKey), findsOneWidget);

    controller.dispose();
  });

  testWidgets('TutorialOverlayHost shows tutorial through root app host',
      (tester) async {
    final targetKey = GlobalKey();
    late TutorialOverlayController controller;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) {
          return TutorialOverlayHost(child: child ?? const SizedBox.shrink());
        },
        home: Scaffold(
          body: Builder(
            builder: (context) {
              controller = TutorialOverlayScope.of(context);
              return Center(
                child: SizedBox(
                  key: targetKey,
                  width: 48,
                  height: 48,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    controller.showTutorial(
      tutorialId: 'root-host',
      ownerRoute: '/map',
      steps: <TutorialStepDefinition>[
        TutorialStepDefinition(
          targetKey: targetKey,
          title: 'Root host title',
          body: 'Root host body',
        ),
      ],
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(TutorialOverlayPresenter.rootKey), findsOneWidget);
    expect(find.text('Root host title'), findsOneWidget);
  });

  testWidgets('TutorialOverlayHost keeps tutorial visible across frames',
      (tester) async {
    final targetKey = GlobalKey();
    late TutorialOverlayController controller;

    await tester.pumpWidget(
      _buildApp(
        Scaffold(
          body: TutorialOverlayHost(
            child: Builder(
              builder: (context) {
                controller = TutorialOverlayScope.of(context);
                return Center(
                  child: SizedBox(
                    key: targetKey,
                    width: 48,
                    height: 48,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    controller.showTutorial(
      tutorialId: 'persistent',
      ownerRoute: 'desktop-explore-map',
      steps: <TutorialStepDefinition>[
        TutorialStepDefinition(
          targetKey: targetKey,
          title: 'Persistent title',
          body: 'Persistent body',
        ),
      ],
    );

    for (var i = 0; i < 10; i += 1) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(TutorialOverlayPresenter.rootKey), findsOneWidget);
      expect(controller.driver, isNotNull);
    }

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(TutorialOverlayPresenter.rootKey), findsNothing);
  });

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
      ownerRoute: Navigator.defaultRouteName,
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

    await tester.pumpAndSettle();

    expect(find.byKey(InteractiveTutorialOverlay.tooltipKey), findsOneWidget);
    expect(
      find.byKey(InteractiveTutorialOverlay.highlightTapRegionKey),
      findsOneWidget,
    );

    final targetCenter = tester.getCenter(find.byKey(targetKey));
    await tester.tapAt(targetCenter);

    // Target callbacks are deferred by a frame.
    await tester.pump();
    await tester.pump();

    expect(targetTapCount, 1);
  });
}

class _TestTutorialDriver extends ChangeNotifier
    implements TutorialOverlayDriver {
  _TestTutorialDriver({
    required List<TutorialStepDefinition> steps,
  }) : _steps = steps;

  final List<TutorialStepDefinition> _steps;

  @override
  bool get visible => true;

  @override
  int get currentIndex => 0;

  @override
  List<TutorialStepDefinition> get steps => _steps;

  @override
  void back() {}

  @override
  Future<void> dismiss() async {}

  @override
  void next() {}
}
