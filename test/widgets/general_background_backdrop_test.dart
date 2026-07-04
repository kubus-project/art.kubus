import 'package:art_kubus/widgets/general_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GeneralBackground paints a non-white fallback first',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: GeneralBackground(
            animate: false,
            showMapLayer: false,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final fallback = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('general-background-fallback')),
    );

    expect(fallback.color, isNot(Colors.white));
    expect(fallback.color.toARGB32() >> 24, 0xFF);
  });

  testWidgets('GeneralBackground animates while visible and resumed',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: GeneralBackground(
            animate: true,
            showMapLayer: false,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('GeneralBackground stops its ticker when reduce-motion is set',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox.expand(
            child: GeneralBackground(
              animate: true,
              showMapLayer: false,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 950));

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('GeneralBackground pauses its ticker when app is backgrounded',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: GeneralBackground(
            animate: true,
            showMapLayer: false,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isTrue);

    // Let the one-shot palette transition (900ms) finish so only the
    // repeating motion ticker remains.
    await tester.pump(const Duration(milliseconds: 950));

    final observer = tester.state(find.byType(GeneralBackground))
        as WidgetsBindingObserver;

    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
  });
}
