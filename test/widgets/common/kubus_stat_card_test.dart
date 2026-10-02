import 'package:flutter/gestures.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:art_kubus/widgets/common/kubus_context_icon.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Center(child: SizedBox(width: 200, child: child)),
      ),
    );

void main() {
  testWidgets('tappable tile keeps the requested height, never below 44',
      (tester) async {
    double heightOf(String title) => tester
        .getSize(find.ancestor(
          of: find.text(title),
          matching: find.byType(KubusStatCard),
        ))
        .height;

    await tester.pumpWidget(_wrap(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const KubusStatCard(title: 'Static', value: '3', minHeight: 96),
        KubusStatCard(
          title: 'Tappable',
          value: '3',
          minHeight: 96,
          onTap: () {},
        ),
        KubusStatCard(
          title: 'Small',
          value: '3',
          minHeight: 0,
          padding: EdgeInsets.zero,
          onTap: () {},
        ),
      ],
    )));

    // Adding an action must not change the tile geometry.
    expect(heightOf('Tappable'), heightOf('Static'));
    expect(heightOf('Tappable'), greaterThanOrEqualTo(96));
    expect(heightOf('Small'), greaterThanOrEqualTo(44));
  });

  testWidgets(
      'expressive tiles: neutral surface and rule under the text, one '
      'identity layer (the cropped decorative ghost glyph), no foreground '
      'icon', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(_wrap(
        const KubusStatCard(
          title: 'Followers',
          value: '1,284',
          icon: Icons.people_outline,
          layout: KubusStatCardLayout.centered,
          accent: Colors.cyan,
        ),
        brightness: brightness,
      ));
      final roles =
          KubusColorRoles.of(tester.element(find.byType(KubusStatCard)));
      expect(find.byType(LiquidGlassCard), findsNothing);
      // The metric's symbol appears exactly once: no foreground copy.
      expect(find.byType(KubusContextIcon), findsNothing);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);

      // The ghost glyph is the identity layer: large, in the accent at low
      // opacity, cropped by the card, never announced.
      final ghost = find.descendant(
        of: find.byType(KubusGhostGlyph),
        matching: find.byIcon(Icons.people_outline),
      );
      expect(ghost, findsOneWidget);
      final ghostIcon = tester.widget<Icon>(ghost);
      expect(ghostIcon.size, greaterThanOrEqualTo(56));
      expect(ghostIcon.color!.r, closeTo(Colors.cyan.r, 0.01));
      expect(ghostIcon.color!.a, lessThan(0.25));
      final card = tester.getRect(find.byType(KubusStatCard));
      final ghostRect = tester.getRect(ghost);
      expect(ghostRect.right, greaterThan(card.right),
          reason: 'the glyph bleeds off the trailing edge');

      final material = tester.widget<Material>(find
          .descendant(
            of: find.byType(KubusStatCard),
            matching: find.byType(Material),
          )
          .first);
      expect(material.color, roles.surface);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, roles.rule);
    }
  });

  testWidgets('dense standard rows stay plain unless asked', (tester) async {
    await tester.pumpWidget(_wrap(const KubusStatCard(
      title: 'Views',
      value: '42',
      icon: Icons.visibility_outlined,
    )));
    expect(find.byType(KubusGhostGlyph), findsNothing);
    await tester.pumpWidget(_wrap(const KubusStatCard(
      title: 'Views',
      value: '42',
      icon: Icons.visibility_outlined,
      expressive: true,
    )));
    expect(find.byType(KubusGhostGlyph), findsOneWidget);
  });

  testWidgets('value is announced with its label; tappable tiles are buttons',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_wrap(KubusStatCard(
      title: 'Followers',
      value: '1,284',
      onTap: () => taps++,
    )));
    expect(
      tester.getSemantics(find.byType(KubusStatCard)),
      isSemantics(label: '1,284 Followers', isButton: true),
    );
    expect(tester.getSize(find.byType(KubusStatCard)).height,
        greaterThanOrEqualTo(44));
    await tester.tap(find.byType(KubusStatCard));
    expect(taps, 1);

    await tester.pumpWidget(_wrap(const KubusStatCard(
      title: 'KUB8 earned from achievements',
      value: '25',
      semanticsLabel: '25 KUB8 earned from achievements',
    )));
    expect(
      tester.getSemantics(find.byType(KubusStatCard)),
      isSemantics(label: '25 KUB8 earned from achievements'),
    );
    handle.dispose();
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'hover answers inside the tile; the number never moves '
        '(reduced motion: $reduced)', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: _wrap(const KubusStatCard(
          title: 'Views',
          value: '42',
          icon: Icons.visibility_outlined,
          layout: KubusStatCardLayout.centered,
        )),
      ));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final before = tester.getRect(find.text('42'));
      final ghost = find.descendant(
        of: find.byType(KubusGhostGlyph),
        matching: find.byIcon(Icons.visibility_outlined),
      );
      final ghostBefore = tester.getRect(ghost);
      await gesture.moveTo(tester.getCenter(find.byType(KubusStatCard)));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('42')), before);
      if (reduced) {
        expect(tester.getRect(ghost), ghostBefore,
            reason: 'reduced motion: no decorative movement');
      } else {
        expect(tester.getRect(ghost), isNot(ghostBefore));
      }
    });
  }
}
