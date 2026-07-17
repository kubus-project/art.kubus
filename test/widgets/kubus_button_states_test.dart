import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('loading state shows a spinner and blocks taps', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(
        KubusButton(
          onPressed: () => pressed++,
          label: 'Continue',
          isLoading: true,
        ),
      ),
    );

    expect(find.byType(InlineLoading), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    await tester.tap(find.byType(KubusButton), warnIfMissed: false);
    expect(pressed, 0);
  });

  testWidgets('disabled state keeps the label and blocks taps', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KubusButton(
          onPressed: null,
          label: 'Continue',
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    final elevated = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(elevated.onPressed, isNull);
  });

  testWidgets('accent variant computes a readable foreground for dark accents',
      (tester) async {
    // Oxblood — one of the selectable dark accents that used to yield
    // dark-on-dark CTAs when combined with a black default onPrimary.
    const oxblood = Color(0xFF7A2E2E);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(primary: oxblood),
        ),
        home: Scaffold(
          body: Center(
            child: KubusButton(
              onPressed: () {},
              label: 'Navigate',
              variant: KubusButtonVariant.accent,
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Navigate'));
    expect(text.style?.color, Colors.white);
  });

  testWidgets('accent variant computes a readable foreground for light accents',
      (tester) async {
    const amberGold = Color(0xFFB8860B);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(primary: amberGold),
        ),
        home: Scaffold(
          body: Center(
            child: KubusButton(
              onPressed: () {},
              label: 'Navigate',
              variant: KubusButtonVariant.accent,
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Navigate'));
    expect(text.style?.color, Colors.black);
  });

  testWidgets('destructive variant fills with the theme error color',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        KubusButton(
          onPressed: () {},
          label: 'Delete',
          variant: KubusButtonVariant.destructive,
        ),
      ),
    );

    final context = tester.element(find.text('Delete'));
    final scheme = Theme.of(context).colorScheme;
    final text = tester.widget<Text>(find.text('Delete'));
    expect(text.style?.color, AppColorUtils.onColor(scheme.error));
  });

  testWidgets('success state swaps the icon to a restrained check',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        KubusButton(
          onPressed: () {},
          label: 'Wallet linked',
          icon: Icons.add_rounded,
          isSuccess: true,
        ),
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('hover lifts the button with a soft glow', (tester) async {
    await tester.pumpWidget(
      _wrap(
        KubusButton(
          onPressed: () {},
          label: 'Hover me',
        ),
      ),
    );

    AnimatedContainer interactionContainer() => tester.widget(
          find
              .descendant(
                of: find.byType(KubusButton),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );

    BoxDecoration decorationOf(AnimatedContainer container) =>
        container.decoration! as BoxDecoration;

    expect(decorationOf(interactionContainer()).boxShadow, isEmpty);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(KubusButton)));
    await tester.pumpAndSettle();

    expect(decorationOf(interactionContainer()).boxShadow, isNotEmpty);

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(decorationOf(interactionContainer()).boxShadow, isEmpty);
  });

  testWidgets('reduced motion collapses interaction animations to zero',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        KubusButton(
          onPressed: () {},
          label: 'Calm',
        ),
        disableAnimations: true,
      ),
    );

    final scale = tester.widget<AnimatedScale>(
      find
          .descendant(
            of: find.byType(KubusButton),
            matching: find.byType(AnimatedScale),
          )
          .first,
    );
    expect(scale.duration, Duration.zero);
  });
}
