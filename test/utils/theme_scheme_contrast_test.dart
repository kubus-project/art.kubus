import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/app_color_utils.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        Colors.white,
        Colors.black,
        Color(0xFFB85C38),
      ];
      for (final color in samples) {
        final fg = AppColorUtils.onColor(color);
        final white = _contrastRatio(Colors.white, color);
        final black = _contrastRatio(Colors.black, color);
        expect(fg, white >= black ? Colors.white : Colors.black);
      }
    });
  });

  group('ThemeProvider keeps family roles stable and bounds user accents', () {
    for (final accent in ThemeProvider.availableAccentColors) {
      final accentHex =
          accent.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();

      testWidgets('accent 0x$accentHex stays in the personal role',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final provider = await tester.runAsync(() async {
          final p = ThemeProvider();
          while (!p.isInitialized) {
            await Future<void>.delayed(Duration.zero);
          }
          await p.setAccentColor(accent);
          return p;
        });
        addTearDown(provider!.dispose);

        for (final theme in <ThemeData>[
          provider.darkTheme,
          provider.lightTheme,
        ]) {
          final scheme = theme.colorScheme;
          final roles = theme.extension<KubusColorRoles>()!;
          final label = scheme.brightness.name;

          expect(scheme.primary, roles.active,
              reason: '$label active is fixed');
          expect(roles.userAccent, accent, reason: '$label accent is personal');
          expect(scheme.surface, roles.surface, reason: '$label surface role');
          expect(
            _contrastRatio(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
            reason: '$label onPrimary contrast',
          );
          expect(
            _contrastRatio(scheme.onSurface, scheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$label onSurface contrast',
          );
          expect(
            _contrastRatio(roles.onUserAccent, roles.userAccent),
            greaterThanOrEqualTo(4.5),
            reason: '$label user accent contrast (0x$accentHex)',
          );
        }
      });
    }
  });
}
