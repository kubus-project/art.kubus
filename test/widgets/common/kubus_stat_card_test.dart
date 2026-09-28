import 'package:flutter/gestures.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
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

  testWidgets('stat tiles are flat: surface fill, rule, no glass/watermark',
      (tester) async {
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
      expect(find.byIcon(Icons.people_outline), findsNothing,
          reason: 'centered tiles carry no watermark glyph');
      final material = tester.widget<Material>(find.descendant(
        of: find.byType(KubusStatCard),
        matching: find.byType(Material),
      ));
      expect(material.color, roles.surface);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, roles.rule);
    }
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

  testWidgets('no hover motion: nothing animates on pointer enter',
      (tester) async {
    await tester.pumpWidget(_wrap(const KubusStatCard(
      title: 'Views',
      value: '42',
      layout: KubusStatCardLayout.centered,
    )));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    final before = tester.getRect(find.text('42'));
    await gesture.moveTo(tester.getCenter(find.byType(KubusStatCard)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.text('42')), before);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
