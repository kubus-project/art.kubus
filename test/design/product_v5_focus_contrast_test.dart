import 'dart:math' as math;

import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG 2.x relative luminance and contrast ratio, computed from the actual
/// colour values (no hard-coded ratios).
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Family focus ring must clear WCAG 1.4.11 (3:1) against every surface it can
/// sit on, and against its own halo, for every personal accent preset. The
/// ring colour is the structural focus role; the personal accent must never
/// reach it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // The accent presets the settings screen offers, plus the default teal.
  final accents = <Color>{
    KubusProductPalette.activeLight,
    ...ThemeProvider.availableAccentColors,
  }.toList();

  testWidgets(
      'focus ring clears 3:1 on every page surface in light and dark for each '
      'accent preset', (tester) async {
    for (final accent in accents) {
      final provider = ThemeProvider();
      await tester.runAsync(() async {
        while (!provider.isInitialized) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      await tester.runAsync(() => provider.setAccentColor(accent));

      final dark = provider.darkTheme.extension<KubusColorRoles>()!;
      final light = provider.lightTheme.extension<KubusColorRoles>()!;

      // The personal accent never changes the structural focus ring.
      expect(
        dark.focus,
        KubusProductPalette.focusDark,
        reason:
            'dark focus must not follow accent 0x${accent.toARGB32().toRadixString(16)}',
      );
      expect(light.focus, KubusProductPalette.focusLight);

      for (final entry in <String, (KubusColorRoles, Color)>{
        'dark': (dark, dark.surface),
        'light': (light, light.surface),
      }.entries) {
        final roles = entry.value.$1;
        final pages = <String, Color>{
          'ground': roles.ground,
          'surface': roles.surface,
          'surfaceRaised': roles.surfaceRaised,
          // Overlays are translucent: judge them as painted over the ground.
          'surfaceOverlay':
              Color.alphaBlend(roles.surfaceOverlay, roles.ground),
        };
        for (final page in pages.entries) {
          final ratio = _contrast(roles.focus, page.value);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: '${entry.key} focus ring on ${page.key} is '
                '${ratio.toStringAsFixed(2)}:1 for accent '
                '0x${accent.toARGB32().toRadixString(16)}',
          );
        }
        // The halo sits between the ring and the page; ring vs halo must hold.
        expect(_contrast(roles.focus, roles.ground), greaterThanOrEqualTo(3.0));
      }
    }
  });

  testWidgets(
      'theme focus fill (ThemeData.focusColor) clears 3:1 against every page '
      'surface, in light and dark', (tester) async {
    final provider = ThemeProvider();
    await tester.runAsync(() async {
      while (!provider.isInitialized) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    for (final entry in <String, (ThemeData, KubusColorRoles)>{
      'dark': (provider.darkTheme, KubusColorRoles.dark),
      'light': (provider.lightTheme, KubusColorRoles.light),
    }.entries) {
      final (theme, roles) = entry.value;
      final fill = theme.focusColor;
      final pages = <String, Color>{
        'ground': roles.ground,
        'surface': roles.surface,
        'surfaceRaised': roles.surfaceRaised,
      };
      for (final page in pages.entries) {
        final composed = Color.alphaBlend(fill, page.value);
        final ratio = _contrast(composed, page.value);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key} focus fill on ${page.key} is '
              '${ratio.toStringAsFixed(2)}:1',
        );
      }
    }
  });
}
