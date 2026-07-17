import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG relative-luminance contrast ratio between two opaque colors.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppColorUtils.onColor', () {
    test('always picks the higher-contrast foreground', () {
      const samples = <Color>[
        Color(0xFF00838F),
        Color(0xFFB8860B),
        Color(0xFFFFFFFF),
        Color(0xFF000000),
        Color(0xFFB85C38),
      ];
      for (final color in samples) {
        final fg = AppColorUtils.onColor(color);
        final white = _contrastRatio(Colors.white, color);
        final black = _contrastRatio(Colors.black, color);
        final expected = white >= black ? Colors.white : Colors.black;
        expect(fg, expected, reason: 'onColor(${color.toARGB32()})');
      }
    });
  });

  group('ThemeProvider color schemes resolve accessible pairs', () {
    for (final accent in ThemeProvider.availableAccentColors) {
      final accentHex =
          accent.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();

      // testWidgets (not test): building ThemeData triggers GoogleFonts
      // lookups whose fetch futures must stay un-run (fake async), matching
      // how every other widget test in this repo tolerates them offline.
      testWidgets('accent 0x$accentHex — dark and light schemes meet AA',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final provider = await tester.runAsync(() async {
          final p = ThemeProvider();
          // The constructor loads persisted preferences asynchronously; wait
          // for it so the load cannot overwrite the accent set below.
          while (!p.isInitialized) {
            await Future<void>.delayed(Duration.zero);
          }
          await p.setAccentColor(accent);
          return p;
        });

        for (final scheme in <ColorScheme>[
          provider!.darkTheme.colorScheme,
          provider.lightTheme.colorScheme,
        ]) {
          final label = scheme.brightness.name;
          expect(
            _contrastRatio(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
            reason: '$label onPrimary vs primary (accent 0x$accentHex)',
          );
          expect(
            _contrastRatio(
              scheme.onPrimaryContainer,
              scheme.primaryContainer,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '$label onPrimaryContainer vs primaryContainer '
                '(accent 0x$accentHex)',
          );
          expect(
            _contrastRatio(
              scheme.onSecondaryContainer,
              scheme.secondaryContainer,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '$label onSecondaryContainer vs secondaryContainer '
                '(accent 0x$accentHex)',
          );
          expect(
            _contrastRatio(
              scheme.onTertiaryContainer,
              scheme.tertiaryContainer,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '$label onTertiaryContainer vs tertiaryContainer '
                '(accent 0x$accentHex)',
          );
          expect(
            _contrastRatio(scheme.onSurface, scheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$label onSurface vs surface (accent 0x$accentHex)',
          );
        }
      });
    }
  });
}
