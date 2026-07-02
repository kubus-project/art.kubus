import 'package:art_kubus/widgets/detail/shared_section_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHarness(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  testWidgets('tappable showcase cards expose button semantics and tap',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;

    await tester.pumpWidget(
      _buildHarness(
        SharedShowcaseCard(
          title: 'Sun Garden',
          subtitle: 'AR mural',
          footer: '12 likes',
          onTap: () => taps += 1,
        ),
      ),
    );

    final cardFinder = find.bySemanticsLabel('Sun Garden, AR mural, 12 likes');
    expect(cardFinder, findsOneWidget);
    expect(tester.getSemantics(cardFinder).flagsCollection.isButton, isTrue);

    await tester.tap(cardFinder);
    await tester.pump();

    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('tappable showcase cards activate from keyboard focus',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      _buildHarness(
        SharedShowcaseCard(
          title: 'Sun Garden',
          subtitle: 'AR mural',
          semanticLabel: 'Open Sun Garden',
          onTap: () => taps += 1,
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final animatedContainer =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    final decoration = animatedContainer.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.width, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(taps, 2);
  });
}
