import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:art_kubus/widgets/common/kubus_context_icon.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  // Every stat card floats on hover; the layout only decides the identity
  // device (ghost glyph and field, or the compact context tile).
  final variants = <String, KubusStatCard Function(VoidCallback? onTap)>{
    'centered (expressive by default)': (onTap) => KubusStatCard(
          title: 'Views',
          value: '42',
          icon: Icons.visibility_outlined,
          layout: KubusStatCardLayout.centered,
          onTap: onTap,
        ),
    'standard (dense by default)': (onTap) => KubusStatCard(
          title: 'Views',
          value: '42',
          icon: Icons.visibility_outlined,
          onTap: onTap,
        ),
    'standard with expressive: true': (onTap) => KubusStatCard(
          title: 'Views',
          value: '42',
          icon: Icons.visibility_outlined,
          expressive: true,
          onTap: onTap,
        ),
    'standard without an icon': (onTap) => KubusStatCard(
          title: 'Views',
          value: '42',
          onTap: onTap,
        ),
  };

  for (final reduced in [false, true]) {
    for (final entry in variants.entries) {
      for (final tappable in [false, true]) {
        testWidgets(
            'hover floats the whole surface as one unit: ${entry.key}, '
            '${tappable ? 'tappable' : 'informational'} '
            '(reduced motion: $reduced)', (tester) async {
          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: _wrap(entry.value(tappable ? () {} : null)),
          ));
          final gesture =
              await tester.createGesture(kind: PointerDeviceKind.mouse);
          await gesture.addPointer(location: Offset.zero);
          addTearDown(gesture.removePointer);
          final card = find.byType(KubusStatCard);
          // The lift is a paint transform inside the card, so the surface
          // (its Material) is what moves.
          final surface =
              find.descendant(of: card, matching: find.byType(Material)).first;
          final ghost = find.descendant(
            of: find.byType(KubusGhostGlyph),
            matching: find.byType(Icon),
          );
          final hasGhost = ghost.evaluate().isNotEmpty;
          double shadowAlpha() {
            final box = tester.widget<AnimatedContainer>(find
                .descendant(of: card, matching: find.byType(AnimatedContainer))
                .first);
            final shadows = (box.decoration! as BoxDecoration).boxShadow;
            return shadows == null || shadows.isEmpty
                ? 0
                : shadows.first.color.a;
          }

          final cardBefore = tester.getTopLeft(surface);
          final sizeBefore = tester.getSize(card);
          final numberRel = tester.getTopLeft(find.text('42')) - cardBefore;
          final labelRel = tester.getTopLeft(find.text('Views')) - cardBefore;
          final ghostBefore = hasGhost ? tester.getRect(ghost) : null;
          expect(shadowAlpha(), 0);

          await gesture.moveTo(tester.getCenter(card));
          await tester.pump();
          await tester.pump(KubusHoverResponse.duration * 1.2);

          // Number and label never move relative to the card, at any point of
          // the float.
          const lift = KubusHoverResponse.liftDistance;
          const amp = KubusHoverResponse.floatAmplitude;
          final dys = <double>[];
          for (var i = 0; i < 24; i++) {
            final now = tester.getTopLeft(surface);
            dys.add(now.dy - cardBefore.dy);
            expect(tester.getTopLeft(find.text('42')).dx - now.dx,
                moreOrLessEquals(numberRel.dx, epsilon: 0.01));
            expect(tester.getTopLeft(find.text('42')).dy - now.dy,
                moreOrLessEquals(numberRel.dy, epsilon: 0.01));
            expect(tester.getTopLeft(find.text('Views')).dy - now.dy,
                moreOrLessEquals(labelRel.dy, epsilon: 0.01));
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.getSize(card), sizeBefore, reason: 'paint only');
          expect(shadowAlpha(), greaterThan(0.2),
              reason: 'the accent shadow state changes even without motion');

          if (reduced) {
            for (final dy in dys) {
              expect(dy, moreOrLessEquals(-lift, epsilon: 0.01),
                  reason: 'a still lift, no float');
            }
            if (ghostBefore != null) {
              expect(
                tester.getRect(ghost).shift(const Offset(0, lift)).topLeft.dx,
                moreOrLessEquals(ghostBefore.topLeft.dx, epsilon: 0.01),
              );
              expect(tester.getRect(ghost).width, ghostBefore.width,
                  reason: 'reduced motion: no decorative movement');
            }
            await tester.pumpAndSettle();
          } else {
            for (final dy in dys) {
              expect(dy, inInclusiveRange(-(lift + amp) - 0.01, -(lift - amp)));
            }
            expect(dys.reduce(math.max) - dys.reduce(math.min),
                greaterThan(2 * amp - 0.5),
                reason: 'it keeps floating while the pointer stays');
            if (ghostBefore != null) {
              expect(
                  tester.getRect(ghost).width, greaterThan(ghostBefore.width));
            }
          }

          await gesture.moveTo(const Offset(790, 590));
          await tester.pump();
          await tester.pump(KubusHoverResponse.duration * 1.2);
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(surface), cardBefore);
          expect(shadowAlpha(), 0);
        });
      }
    }
  }

  testWidgets(
      'informational stat cards keep the default cursor and no '
      'button semantics while still answering hover', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const KubusStatCard(
      title: 'Views',
      value: '42',
      icon: Icons.visibility_outlined,
    )));
    expect(
      tester.getSemantics(find.byType(KubusStatCard)),
      isSemantics(label: '42 Views'),
    );
    final regions = tester
        .widgetList<MouseRegion>(find.descendant(
            of: find.byType(KubusStatCard), matching: find.byType(MouseRegion)))
        .where((r) => r.cursor == SystemMouseCursors.click);
    expect(regions, isEmpty);
    handle.dispose();
  });

  testWidgets('reduced motion paints the whole hover answer on the first frame',
      (tester) async {
    for (final expressive in [false, true]) {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(KubusStatCard(
          title: 'Views',
          value: '42',
          icon: Icons.visibility_outlined,
          expressive: expressive,
        )),
      ));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(KubusStatCard)));
      await tester.pump();

      final shadowBox = find
          .descendant(
            of: find.byType(KubusStatCard),
            matching: find.byType(AnimatedContainer),
          )
          .first;
      final box = tester.renderObject<RenderDecoratedBox>(
        find
            .descendant(of: shadowBox, matching: find.byType(DecoratedBox))
            .first,
      );
      final shadows = (box.decoration as BoxDecoration).boxShadow!;
      expect(shadows.first.color.a, greaterThan(0.2),
          reason: 'expressive: $expressive');
      await gesture.removePointer();
    }
  });

  testWidgets('a hovered stat card disposes its float cleanly', (tester) async {
    await tester.pumpWidget(_wrap(const KubusStatCard(
      title: 'Views',
      value: '42',
      icon: Icons.visibility_outlined,
    )));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(KubusStatCard)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
