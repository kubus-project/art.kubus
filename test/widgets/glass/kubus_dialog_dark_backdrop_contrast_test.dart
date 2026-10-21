import 'dart:math' as math;

import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/glass/glass_surface.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _wcagAa = 4.5;

ThemeData _lightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    extensions: const <ThemeExtension<dynamic>>[KubusColorRoles.light],
    colorScheme: base.colorScheme.copyWith(
      primary: KubusColorRoles.light.active,
      surface: KubusColorRoles.light.surface,
    ),
  );
}

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Composites a translucent gradient stop over an opaque backdrop.
Color _over(Color stop, Color backdrop) => Color.alphaBlend(stop, backdrop);

Future<void> _openDialog(WidgetTester tester, ThemeData theme) async {
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
              title: const Text('Scan'),
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

/// Gradient stops of the glass panel that paints the dialog background.
List<Color> _panelStops(WidgetTester tester) {
  final boxes = tester.widgetList<DecoratedBox>(find.descendant(
    of: find.byType(LiquidGlassPanel),
    matching: find.byType(DecoratedBox),
  ));
  for (final box in boxes) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration && decoration.gradient is LinearGradient) {
      return (decoration.gradient! as LinearGradient).colors;
    }
  }
  fail('dialog panel has no gradient');
}

void _expectStopsClearAa(List<Color> stops, Color actionPrimary) {
  expect(stops, hasLength(2));
  for (final stop in stops) {
    final overBlack = _over(stop, Colors.black);
    final overWhite = _over(stop, Colors.white);
    expect(
      _contrast(overBlack, actionPrimary),
      greaterThanOrEqualTo(_wcagAa),
      reason: 'worst case (black backdrop) stop $stop',
    );
    expect(
      _contrast(overWhite, actionPrimary),
      greaterThanOrEqualTo(_wcagAa),
      reason: 'white backdrop stop $stop',
    );
  }
}

void main() {
  testWidgets(
      'light dialog gradient stops clear 4.5:1 against the action primary '
      'over a black backdrop', (tester) async {
    final theme = _lightTheme();
    await _openDialog(tester, theme);

    final actionPrimary = Color.lerp(
      theme.colorScheme.primary,
      Colors.black,
      KubusGlassEffects.dialogActionDarkenLight,
    )!;
    _expectStopsClearAa(_panelStops(tester), actionPrimary);
  });

  testWidgets(
      'blur-disabled light dialog surface also clears 4.5:1 over black',
      (tester) async {
    // Mirrors the light dialog panel tint on the opaque fallback path, which
    // low-end and reduced-effects devices take instead of BackdropFilter.
    final theme = _lightTheme();
    final surface = theme.colorScheme.surface;
    final tint = (Color.lerp(surface, theme.colorScheme.primary, 0.06) ??
            surface)
        .withValues(alpha: KubusGlassEffects.dialogTintAlphaLight);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: GlassSurface(
          enableBlur: false,
          tintColor: tint,
          minimumStopOpacity: KubusAlertDialog.lightStopOpacityFloor,
          child: const SizedBox(width: 120, height: 60),
        ),
      ),
    ));

    final box = tester.widget<DecoratedBox>(find
        .descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(DecoratedBox),
        )
        .first);
    final gradient = (box.decoration as BoxDecoration).gradient!
        as LinearGradient;
    final actionPrimary = Color.lerp(
      theme.colorScheme.primary,
      Colors.black,
      KubusGlassEffects.dialogActionDarkenLight,
    )!;
    _expectStopsClearAa(gradient.colors, actionPrimary);
  });

  testWidgets('dark-mode dialog panel keeps its original stop opacities',
      (tester) async {
    await _openDialog(tester, ThemeData.dark());
    final stops = _panelStops(tester);
    expect(stops.first.a, closeTo(0.22, 0.005));
  });
}
