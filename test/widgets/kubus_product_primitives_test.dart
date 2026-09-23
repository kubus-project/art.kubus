import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/kubus_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  final roles = brightness == Brightness.dark
      ? KubusColorRoles.dark
      : KubusColorRoles.light;
  final colorScheme = brightness == Brightness.dark
      ? const ColorScheme.dark(
          primary: KubusProductPalette.activeDark,
          onPrimary: KubusProductPalette.foregroundLight,
          surface: KubusProductPalette.surfaceDark,
          onSurface: KubusProductPalette.foregroundDark,
        )
      : const ColorScheme.light(
          primary: KubusProductPalette.activeLight,
          onPrimary: Colors.white,
          surface: KubusProductPalette.surfaceLight,
          onSurface: KubusProductPalette.foregroundLight,
        );

  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: roles.ground,
      extensions: <ThemeExtension<dynamic>>[roles],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  test('light and dark semantic roles form family counterparts', () {
    expect(KubusColorRoles.light.ground, KubusProductPalette.groundLight);
    expect(KubusColorRoles.dark.ground, KubusProductPalette.groundDark);
    expect(KubusColorRoles.light.active, KubusProductPalette.activeLight);
    expect(KubusColorRoles.dark.active, KubusProductPalette.activeDark);
    expect(KubusColorRoles.light.rule, KubusProductPalette.ruleLight);
    expect(KubusColorRoles.dark.rule, KubusProductPalette.ruleDark);
  });

  test('family fonts are bundled for offline Flutter builds', () async {
    await rootBundle.load(
      'assets/fonts/product-v5/sofia-sans/SofiaSans-Variable.ttf',
    );
    await rootBundle.load(
      'assets/fonts/product-v5/space-mono/SpaceMono-Regular.ttf',
    );
    await rootBundle.load(
      'assets/fonts/product-v5/space-mono/SpaceMono-Bold.ttf',
    );
  });

  test('content and structural text use distinct local font families', () {
    expect(KubusTypography.textTheme.bodyLarge!.fontFamily, 'Sofia Sans');
    expect(KubusTypography.content(fontSize: 16).fontFamily, 'Sofia Sans');
    expect(KubusTypography.structural(fontSize: 12).fontFamily, 'Space Mono');
    expect(KubusTypography.machine(fontSize: 12).fontFamily, 'Space Mono');
    expect(KubusTextStyles.structuralLabel.fontFamily, 'Space Mono');
    expect(KubusTextStyles.body.fontFamily, 'Sofia Sans');
  });

  testWidgets('ordinary card is flat; glass remains an explicit option',
      (tester) async {
    await tester.pumpWidget(
      _app(const KubusCard(child: Text('Flat content'))),
    );
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(LiquidGlassPanel), findsNothing);

    await tester.pumpWidget(
      _app(const KubusCard(isGlass: true, child: Text('Spatial overlay'))),
    );
    expect(find.byType(LiquidGlassPanel), findsOneWidget);
  });

  testWidgets('default chip uses neutral surface and rule', (tester) async {
    await tester.pumpWidget(
      _app(const KubusChip(label: 'Neutral tag')),
    );
    final chip = tester.widget<Chip>(find.byType(Chip));
    expect(chip.backgroundColor, KubusColorRoles.light.surface);
    expect(chip.side!.color, KubusColorRoles.light.rule);
    expect(
      tester.widget<Text>(find.text('Neutral tag')).style?.color,
      KubusColorRoles.light.foreground,
    );
  });

  testWidgets('button variants resolve through semantic roles', (tester) async {
    await tester.pumpWidget(
      _app(
        Wrap(
          children: [
            KubusButton(onPressed: () {}, label: 'Primary'),
            KubusButton(
              onPressed: () {},
              label: 'Secondary',
              variant: KubusButtonVariant.secondary,
            ),
            KubusButton(
              onPressed: () {},
              label: 'Quiet',
              variant: KubusButtonVariant.quiet,
            ),
            KubusButton(
              onPressed: () {},
              label: 'Destructive',
              variant: KubusButtonVariant.destructive,
            ),
            KubusButton(
              onPressed: () {},
              label: 'Contextual',
              variant: KubusButtonVariant.contextual,
              backgroundColor: KubusProductPalette.successLight,
            ),
          ],
        ),
      ),
    );

    final labels = <String>[
      'Primary',
      'Secondary',
      'Quiet',
      'Destructive',
      'Contextual',
    ];
    expect(find.byType(ElevatedButton), findsNWidgets(labels.length));
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester.widget<Text>(find.text('Contextual')).style!.color,
      isNotNull,
    );
  });
}
