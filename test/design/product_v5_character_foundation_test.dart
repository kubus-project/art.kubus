import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/desktop/components/desktop_widgets.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_context_icon.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/qa_font_loader.dart';

/// Wave 5A foundation: kubus teal is the family primary, blue the secondary,
/// and metric tiles carry a visible contextual icon without clipping.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Real Sofia Sans metrics: overflow checks against the placeholder test
  // font would measure glyphs the product never draws.
  setUpAll(QaFontLoader.ensureLoaded);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  bool isTealHue(Color c) {
    final hue = HSVColor.fromColor(c).hue;
    return hue >= 165 && hue <= 185;
  }

  bool isBlueHue(Color c) {
    final hue = HSVColor.fromColor(c).hue;
    return hue >= 205 && hue <= 230;
  }

  Future<void> pumpThemed(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final provider = ThemeProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: provider.lightTheme,
          darkTheme: provider.darkTheme,
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('palette and roles', () {
    test('global active is kubus teal; secondary stays blue', () {
      expect(KubusProductPalette.activeLight, const Color(0xFF00766A));
      expect(KubusProductPalette.activeDark, const Color(0xFF4ECDC4));
      expect(KubusProductPalette.secondaryLight, const Color(0xFF1F5FD0));
      expect(KubusProductPalette.secondaryDark, const Color(0xFF3F83FF));
      for (final roles in [KubusColorRoles.light, KubusColorRoles.dark]) {
        expect(isTealHue(roles.active), isTrue);
        expect(isBlueHue(roles.secondary), isTrue);
        expect(roles.focus, roles.active,
            reason: 'focus follows the structural teal');
      }
    });

    test('screen accents: structural screens are teal, never the user accent',
        () {
      final roles =
          KubusColorRoles.dark.copyWith(userAccent: const Color(0xFF7A2E2E));
      for (final key in ['home', 'settings', 'profile', 'wallet', 'map']) {
        expect(roles.screenAccentForKey(key), roles.active, reason: key);
      }
      expect(roles.screenAccentForKey('analytics'), roles.secondary);
      expect(roles.screenAccentForKey('studio'), roles.web3ArtistStudioAccent);
    });

    for (final brightness in Brightness.values) {
      testWidgets(
          'ColorScheme wires teal primary and blue secondary '
          '(${brightness.name})', (tester) async {
        await pumpThemed(tester, const SizedBox(), brightness: brightness);
        final context = tester.element(find.byType(Scaffold));
        final scheme = Theme.of(context).colorScheme;
        final roles = KubusColorRoles.of(context);
        expect(scheme.primary, roles.active);
        expect(isTealHue(scheme.primary), isTrue);
        expect(scheme.secondary, roles.secondary);
        expect(isBlueHue(scheme.secondary), isTrue);
        expect(scheme.tertiary, roles.active);
      });
    }
  });

  group('KubusContextIcon', () {
    testWidgets('sizes follow the compact/regular/hero steps', (tester) async {
      await pumpThemed(
        tester,
        const Column(
          children: [
            KubusContextIcon(
              key: ValueKey('compact'),
              icon: Icons.people_outline,
              accent: Colors.teal,
              size: KubusContextIconSize.compact,
            ),
            KubusContextIcon(
              key: ValueKey('regular'),
              icon: Icons.people_outline,
              accent: Colors.teal,
            ),
            KubusContextIcon(
              key: ValueKey('hero'),
              icon: Icons.people_outline,
              accent: Colors.teal,
              size: KubusContextIconSize.hero,
            ),
          ],
        ),
      );
      const expected = {'compact': (30.0, 16.0), 'regular': (38.0, 20.0)};
      for (final entry in {...expected, 'hero': (52.0, 26.0)}.entries) {
        final tile = find.byKey(ValueKey(entry.key));
        expect(tester.getSize(tile), Size.square(entry.value.$1));
        final glyph = find.descendant(of: tile, matching: find.byType(Icon));
        expect(tester.getSize(glyph), Size.square(entry.value.$2));
      }
    });

    testWidgets('flat accent tile: tinted fill, hairline, no shadow',
        (tester) async {
      const accent = Color(0xFFE07A5F);
      await pumpThemed(
        tester,
        const Center(
          child: KubusContextIcon(icon: Icons.bolt, accent: accent),
        ),
      );
      final box = tester.widget<Container>(find.descendant(
        of: find.byType(KubusContextIcon),
        matching: find.byType(Container),
      ));
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color,
          accent.withValues(alpha: KubusContextIcon.fillAlpha));
      expect(decoration.boxShadow, isNull);
      expect((decoration.border! as Border).top.width, KubusSizes.hairline);
      expect(tester.widget<Icon>(find.byIcon(Icons.bolt)).color, accent);
    });
  });

  group('stat tiles', () {
    testWidgets('centered tile renders the icon in its contextual accent',
        (tester) async {
      const accent = Color(0xFFE07A5F);
      await pumpThemed(
        tester,
        const Center(
          child: SizedBox(
            width: 200,
            child: KubusStatCard(
              title: 'Followers',
              value: '1,284',
              icon: Icons.people_outline,
              accent: accent,
              layout: KubusStatCardLayout.centered,
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.people_outline));
      expect(icon.color, accent);
      // The accent stays in the icon tile; the card surface is neutral.
      final context = tester.element(find.byType(KubusStatCard));
      final material = tester.widget<Material>(find.descendant(
        of: find.byType(KubusStatCard),
        matching: find.byType(Material),
      ));
      expect(material.color, KubusColorRoles.of(context).surface);
    });

    testWidgets('standard tile still shows icon, value and label',
        (tester) async {
      await pumpThemed(
        tester,
        const Center(
          child: SizedBox(
            width: 260,
            child: KubusStatCard(
              title: 'Views',
              value: '42',
              icon: Icons.visibility_outlined,
            ),
          ),
        ),
      );
      expect(find.byType(KubusContextIcon), findsOneWidget);
      final iconRect = tester.getRect(find.byType(KubusContextIcon));
      final valueRect = tester.getRect(find.text('42'));
      expect(iconRect.right, lessThan(valueRect.left),
          reason: 'standard layout leads with the icon');
      expect(find.text('Views'), findsOneWidget);
    });

    testWidgets('a narrow standard tile scales its value, never ellipsises',
        (tester) async {
      // The mobile governance header puts three standard tiles in a row;
      // at 320 dp each leaves ~59 px for the number.
      await pumpThemed(
        tester,
        const Center(
          child: SizedBox(
            width: 120,
            child: KubusStatCard(
              title: 'Voting power',
              value: '0.00 KUB8',
              icon: Icons.how_to_vote_outlined,
            ),
          ),
        ),
        size: const Size(320, 640),
      );
      final value =
          tester.renderObject<RenderParagraph>(find.text('0.00 KUB8'));
      expect(value.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DesktopStatCard passes its colour to the icon tile',
        (tester) async {
      const accent = Color(0xFF70C58B);
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Center(
            child: SizedBox(
              width: 220,
              height: DesktopStatCard.extentOf(context),
              child: const DesktopStatCard(
                label: 'Created',
                value: '7',
                icon: Icons.create_outlined,
                color: accent,
              ),
            ),
          ),
        ),
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.create_outlined)).color,
          accent);
    });

    testWidgets('tappable tile keeps button semantics and a 44 px target',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpThemed(
        tester,
        Center(
          child: SizedBox(
            width: 220,
            child: DesktopStatCard(
              label: 'Followers',
              value: '12',
              icon: Icons.people_outline,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(KubusStatCard)),
        isSemantics(label: '12 Followers', isButton: true),
      );
      expect(tester.getSize(find.byType(KubusStatCard)).height,
          greaterThanOrEqualTo(44));
      await tester.tap(find.byType(KubusStatCard));
      expect(taps, 1);
      handle.dispose();
    });

    // The profile side column is ~360 px: two columns of ~174 px tiles.
    // At 2x the card adds a third label line and the extent reserves it.
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
          'two-line labels fit the measured grid extent at ${scale}x text',
          (tester) async {
        await pumpThemed(
          tester,
          Builder(
            builder: (context) => SizedBox(
              width: 360,
              child: DesktopGrid(
                minCrossAxisCount: 2,
                maxCrossAxisCount: 2,
                spacing: 12,
                mainAxisExtent: DesktopStatCard.extentOf(context),
                children: const [
                  DesktopStatCard(
                    label: 'Digital editions held',
                    value: '1,284',
                    icon: Icons.token_outlined,
                  ),
                  DesktopStatCard(
                    label: 'Added Public Art',
                    value: '12.4K',
                    icon: Icons.brush_outlined,
                  ),
                  DesktopStatCard(
                    label: 'Artworks viewed',
                    value: '905',
                    icon: Icons.visibility_outlined,
                  ),
                  DesktopStatCard(
                    label: 'Discoveries',
                    value: '31',
                    icon: Icons.explore_outlined,
                  ),
                ],
              ),
            ),
          ),
          textScale: scale,
        );
        expect(tester.takeException(), isNull,
            reason: 'no RenderFlex overflow at ${scale}x');
        for (final label in [
          'Digital editions held',
          'Added Public Art',
          'Artworks viewed',
          'Discoveries',
        ]) {
          final text = tester.renderObject<RenderParagraph>(find.text(label));
          expect(text.didExceedMaxLines, isFalse, reason: label);
          final tile = find.ancestor(
            of: find.text(label),
            matching: find.byType(KubusStatCard),
          );
          final tileRect = tester.getRect(tile);
          final labelRect = tester.getRect(find.text(label));
          expect(labelRect.bottom, lessThanOrEqualTo(tileRect.bottom),
              reason: '$label is inside its tile at ${scale}x');
        }
        // The number is never ellipsised.
        final value = tester.renderObject<RenderParagraph>(find.text('12.4K'));
        expect(value.didExceedMaxLines, isFalse);
      });
    }

    testWidgets('grid extent grows with the text scale', (tester) async {
      late double base;
      late double large;
      await pumpThemed(tester, Builder(builder: (context) {
        base = DesktopStatCard.extentOf(context);
        return const SizedBox();
      }));
      await pumpThemed(
        tester,
        Builder(builder: (context) {
          large = DesktopStatCard.extentOf(context);
          return const SizedBox();
        }),
        textScale: 2.0,
      );
      expect(large, greaterThan(base));
    });
  });

  testWidgets('DesktopGrid honours mainAxisExtent over the aspect ratio',
      (tester) async {
    await pumpThemed(
      tester,
      const SizedBox(
        width: 600,
        child: DesktopGrid(
          minCrossAxisCount: 2,
          maxCrossAxisCount: 2,
          childAspectRatio: 4,
          mainAxisExtent: 131,
          children: [
            ColoredBox(key: ValueKey('a'), color: Colors.red),
            ColoredBox(key: ValueKey('b'), color: Colors.blue),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('a'))).height, 131);
    expect(tester.getSize(find.byKey(const ValueKey('b'))).height, 131);
  });
}
