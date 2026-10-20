import 'dart:math' as math;

import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showKubusDialog<void>(
            context: context,
            builder: (ctx) => KubusAlertDialog(
              title: const Text('Title'),
              content: const Text('Body'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

double _panelTintAlpha(WidgetTester tester) {
  final panel = tester.widget<LiquidGlassPanel>(find.descendant(
    of: find.byType(KubusAlertDialog),
    matching: find.byType(LiquidGlassPanel),
  ));
  return panel.backgroundColor!.a;
}

void main() {
  testWidgets('light-mode dialog panel uses the contrast tint token',
      (tester) async {
    await _open(tester, ThemeData.light());
    expect(
      _panelTintAlpha(tester),
      closeTo(KubusGlassEffects.dialogTintAlphaLight, 0.005),
    );
  });

  testWidgets('dark-mode dialog panel keeps its original tint alpha',
      (tester) async {
    await _open(tester, ThemeData.dark());
    expect(_panelTintAlpha(tester), closeTo(0.22, 0.005));
  });

  test('light dialog tint token clears WCAG AA for the teal action colour', () {
    // Relative luminance of the light primary (0,118,106) used for actions.
    double channel(int v) {
      final c = v / 255.0;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final lPrimary =
        0.2126 * channel(0) + 0.7152 * channel(118) + 0.0722 * channel(106);
    // Opaque tint lerp(surface F4F5F2, primary, 0.06) composited over an
    // assumed dimmed page (138,140,138) at the token alpha.
    const a = KubusGlassEffects.dialogTintAlphaLight;
    int mix(double fg, double bg) => (a * fg + (1 - a) * bg).round();
    final r = mix(229.4, 138);
    final g = mix(237.4, 140);
    final b = mix(233.8, 138);
    final lPanel =
        0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
    final ratio = (lPanel + 0.05) / (lPrimary + 0.05);
    expect(ratio, greaterThanOrEqualTo(4.5));
  });

  Color actionPrimary(WidgetTester tester) => Theme.of(
        tester.element(find.text('Confirm')),
      ).colorScheme.primary;

  testWidgets('light-mode dialog actions use the deepened primary',
      (tester) async {
    final theme = ThemeData.light();
    await _open(tester, theme);
    final expected = Color.lerp(
      theme.colorScheme.primary,
      Colors.black,
      KubusGlassEffects.dialogActionDarkenLight,
    )!;
    expect(actionPrimary(tester), expected);
  });

  testWidgets('dark-mode dialog actions keep the theme primary',
      (tester) async {
    final theme = ThemeData.dark();
    await _open(tester, theme);
    expect(actionPrimary(tester), theme.colorScheme.primary);
  });
}
