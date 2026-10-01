import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
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
          extensions: <ThemeExtension<dynamic>>[
            KubusColorRoles.dark.copyWith(
              userAccent: oxblood,
              onUserAccent: Colors.white,
            ),
          ],
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
          extensions: <ThemeExtension<dynamic>>[
            KubusColorRoles.light.copyWith(
              userAccent: amberGold,
              onUserAccent: Colors.black,
            ),
          ],
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

  testWidgets('state overlays are restrained and do not add a glow',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        KubusButton(
          onPressed: () {},
          label: 'Hover me',
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final overlay = button.style!.overlayColor!;
    expect(
      overlay.resolve(<WidgetState>{WidgetState.hovered})!.a,
      lessThan(0.1),
    );
    expect(
      overlay.resolve(<WidgetState>{WidgetState.focused})!.a,
      greaterThan(0.2),
    );
    expect(find.byType(AnimatedContainer), findsNothing);
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
