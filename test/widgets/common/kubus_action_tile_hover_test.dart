import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _accent = Color(0xFF14B8A6);
const _longTitle =
    'Institucionalno središče za razstave, dogodke in sodelovanje';

const _glyphKey = ValueKey<String>('kubus_action_tile_ghost_glyph');
const _indicatorKey = ValueKey<String>('kubus_action_tile_indicator');

Widget _host(
  KubusActionTileLayout layout, {
  bool reduceMotion = false,
  String? subtitle,
  double textScale = 1,
  String title = 'Analytics',
  double width = 260,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: SizedBox(
              width: width,
              height: layout == KubusActionTileLayout.stacked ? 140 : null,
              child: KubusActionTile(
                title: title,
                subtitle: subtitle,
                icon: Icons.analytics_outlined,
                accent: _accent,
                onTap: () {},
                layout: layout,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(1, 1));
  addTearDown(gesture.removePointer);
  return gesture;
}

Offset _surfaceTopLeft(WidgetTester tester) => tester.getTopLeft(
      find
          .descendant(
            of: find.byType(KubusActionTile),
            matching: find.byType(Material),
          )
          .first,
    );

/// The alpha actually being painted, read off the render object.
///
/// [_shadowAlpha] reads the *target* decoration handed to [AnimatedContainer],
/// which is the right thing for a rest/settled assertion but can never observe
/// the interpolation: the in-between decoration lives in the animation's own
/// state and reaches the tree as the render object's decoration.
double _paintedShadowAlpha(WidgetTester tester) {
  final box = tester.renderObject<RenderDecoratedBox>(
    find
        .descendant(
          of: find.byType(AnimatedContainer).first,
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  final shadows = (box.decoration as BoxDecoration).boxShadow;
  return shadows == null || shadows.isEmpty ? 0 : shadows.first.color.a;
}

double _shadowAlpha(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(
    find
        .descendant(
          of: find.byType(KubusActionTile),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  final shadows = (box.decoration! as BoxDecoration).boxShadow;
  return shadows == null || shadows.isEmpty ? 0 : shadows.first.color.a;
}

Offset _arrow(WidgetTester tester) =>
    tester.getTopLeft(find.byIcon(Icons.arrow_forward));

Future<void> _hover(WidgetTester tester, TestGesture gesture) async {
  await gesture.moveTo(tester.getCenter(find.byType(KubusActionTile)));
  await tester.pumpAndSettle();
}

void main() {
  group('KubusActionTile hover contract', () {
    for (final layout in const [
      KubusActionTileLayout.stacked,
      KubusActionTileLayout.inline,
    ]) {
      testWidgets(
          '${layout.name}: lifts 2 px with a soft accent shadow, without '
          'moving layout', (tester) async {
        await tester.pumpWidget(_host(layout));
        final gesture = await _mouse(tester);
        final restSize = tester.getSize(find.byType(KubusActionTile));
        final rest = _surfaceTopLeft(tester);
        expect(_shadowAlpha(tester), 0);

        await _hover(tester, gesture);

        final lifted = _surfaceTopLeft(tester);
        expect(rest.dy - lifted.dy, moreOrLessEquals(2, epsilon: 0.01));
        expect(lifted.dx, rest.dx);
        // Paint only: the laid-out size is untouched.
        expect(tester.getSize(find.byType(KubusActionTile)), restSize);
        // A tinted drop shadow, not a glow: visible but restrained.
        expect(_shadowAlpha(tester), inInclusiveRange(0.2, 0.4));

        await gesture.moveTo(const Offset(790, 590));
        await tester.pumpAndSettle();
        expect(_surfaceTopLeft(tester), rest);
        expect(_shadowAlpha(tester), 0);
      });
    }

    testWidgets(
        'stacked: the clipped ghost glyph drifts a few px and scales at most '
        '4 %', (tester) async {
      await tester.pumpWidget(_host(KubusActionTileLayout.stacked));
      final gesture = await _mouse(tester);
      final glyphFinder = find.byKey(_glyphKey);
      expect(tester.widget<KubusGhostGlyph>(glyphFinder).scale, 1);
      expect(tester.widget<KubusGhostGlyph>(glyphFinder).shift, Offset.zero);

      await _hover(tester, gesture);

      final glyph = tester.widget<KubusGhostGlyph>(glyphFinder);
      expect(glyph.scale, inInclusiveRange(1.02, 1.04));
      expect(glyph.shift.distance, inInclusiveRange(2, 5));
    });

    testWidgets('inline: the arrow travels 2 px', (tester) async {
      await tester.pumpWidget(_host(KubusActionTileLayout.inline));
      final gesture = await _mouse(tester);
      final rest = _arrow(tester);

      await _hover(tester, gesture);

      expect(_arrow(tester).dx - rest.dx, moreOrLessEquals(2, epsilon: 0.01));
    });

    testWidgets(
        'compact: quiet, no lift, no shadow, no arrow travel; an indicator '
        'answers instead', (tester) async {
      await tester.pumpWidget(
        _host(KubusActionTileLayout.compact, subtitle: 'Where this goes'),
      );
      final gesture = await _mouse(tester);
      final rest = _surfaceTopLeft(tester);
      final arrow = _arrow(tester);
      Color indicator() => (tester
              .widget<AnimatedContainer>(find.byKey(_indicatorKey))
              .decoration! as BoxDecoration)
          .color!;
      expect(indicator().a, 0);
      final glyphBefore = tester.getRect(find.byIcon(Icons.analytics_outlined));

      await _hover(tester, gesture);

      expect(_surfaceTopLeft(tester), rest);
      expect(_arrow(tester), arrow);
      expect(_shadowAlpha(tester), 0);
      expect(tester.getRect(find.byIcon(Icons.analytics_outlined)), glyphBefore,
          reason: 'a dense row never drifts its glyph');
      expect(indicator().a, greaterThan(0.5));
    });

    for (final layout in KubusActionTileLayout.values) {
      testWidgets(
          '${layout.name}: reduced motion has no movement but still answers',
          (tester) async {
        await tester.pumpWidget(_host(layout, reduceMotion: true));
        final gesture = await _mouse(tester);
        final rest = _surfaceTopLeft(tester);
        final stacked = layout == KubusActionTileLayout.stacked;
        final arrow = stacked ? null : _arrow(tester);

        await _hover(tester, gesture);

        expect(_surfaceTopLeft(tester), rest, reason: 'no lift');
        if (!stacked) {
          expect(_arrow(tester), arrow, reason: 'no arrow travel');
        }
        if (layout == KubusActionTileLayout.stacked) {
          final glyph = tester.widget<KubusGhostGlyph>(find.byKey(_glyphKey));
          expect(glyph.scale, 1, reason: 'no glyph drift');
          expect(glyph.shift, Offset.zero);
        }
        if (layout != KubusActionTileLayout.compact) {
          expect(_shadowAlpha(tester), greaterThan(0),
              reason: 'the static shadow state still changes');
        }
      });
    }

    testWidgets('touch never leaves the tile in a hover state', (tester) async {
      await tester.pumpWidget(_host(KubusActionTileLayout.stacked));
      final rest = _surfaceTopLeft(tester);
      await tester.tap(find.byType(KubusActionTile));
      await tester.pumpAndSettle();
      expect(_surfaceTopLeft(tester), rest);
      expect(_shadowAlpha(tester), 0);
    });
  });

  // The remount fix is about `lift: lifts && interactive` rather than
  // `lift: lifts`, so it can only be observed where `lifts` is true: the
  // compact layout never lifts, which makes both spellings identical there.
  // Every lifting layout is covered.
  for (final layout in const <KubusActionTileLayout>[
    KubusActionTileLayout.stacked,
    KubusActionTileLayout.inline,
    KubusActionTileLayout.compact,
  ]) {
    testWidgets(
        'toggling loading keeps the same ${layout.name} tile subtree '
        '(no remount)', (tester) async {
      Widget tile({required bool loading}) => MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 260,
                  height: layout == KubusActionTileLayout.stacked ? 140 : null,
                  child: KubusActionTile(
                    title: 'Send',
                    icon: Icons.arrow_upward,
                    accent: _accent,
                    layout: layout,
                    loading: loading,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );
      await tester.pumpWidget(tile(loading: false));
      final before = tester.element(find.byType(InkWell));
      // InlineLoading animates forever, so pump frames instead of settling.
      await tester.pumpWidget(tile(loading: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.element(find.byType(InkWell)), same(before));
    });
  }

  testWidgets('an empty subtitle is no subtitle', (tester) async {
    await tester.pumpWidget(_host(KubusActionTileLayout.compact, subtitle: ''));
    final emptyHeight = tester.getSize(find.byType(KubusActionTile)).height;
    final data =
        tester.getSemantics(find.byType(KubusActionTile)).getSemanticsData();
    expect(data.hint, isEmpty);
    // The real effects, not just the hint: no subtitle Text is built at all,
    // and the tile takes the no-subtitle minimum height.
    expect(
      find.descendant(
        of: find.byType(KubusActionTile),
        matching: find.text(''),
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      _host(KubusActionTileLayout.compact, subtitle: 'Backup and sign-in'),
    );
    expect(
      tester.getSize(find.byType(KubusActionTile)).height,
      greaterThan(emptyHeight),
    );
  });

  testWidgets('the hover shadow fades in rather than popping to full strength',
      (tester) async {
    // Both ends of the implicit lerp must carry the same geometry, or
    // BoxShadow.lerpList falls back to scaling blur while holding the colour
    // at its final alpha — the shadow then appears at full strength on the
    // first frame.
    await tester.pumpWidget(_host(KubusActionTileLayout.stacked));
    expect(_paintedShadowAlpha(tester), 0);

    final gesture = await _mouse(tester);
    await gesture.moveTo(tester.getCenter(find.byType(KubusActionTile)));
    await tester.pump();

    final samples = <double>[];
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 45));
      samples.add(_paintedShadowAlpha(tester));
    }
    await tester.pumpAndSettle();
    final peak = _paintedShadowAlpha(tester);

    expect(peak, greaterThan(0));
    // Strictly increasing, and the first sampled frame is well below peak.
    expect(samples.first, lessThan(peak * 0.75));
    for (var i = 1; i < samples.length; i++) {
      expect(samples[i], greaterThan(samples[i - 1]));
    }
  });

  group('KubusActionTile.compact', () {
    testWidgets(
        'fills the slot with title, subtitle and one arrow; the title owns '
        'the button semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
        KubusActionTileLayout.compact,
        title: 'Security',
        subtitle: 'PIN, backup and sign-in methods',
        width: 320,
      ));
      expect(tester.getSize(find.byType(KubusActionTile)).width, 320);
      expect(tester.getSize(find.byType(KubusActionTile)).height,
          greaterThanOrEqualTo(44));
      expect(find.text('PIN, backup and sign-in methods'), findsOneWidget);
      // One identity layer: the destination glyph appears once, cropped and
      // decorative, never as a foreground icon.
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KubusGhostGlyph),
          matching: find.byIcon(Icons.analytics_outlined),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      final data =
          tester.getSemantics(find.byType(KubusActionTile)).getSemanticsData();
      expect(data.label, 'Security');
      expect(data.hint, 'PIN, backup and sign-in methods');
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    for (final scale in const [1.3, 2.0]) {
      testWidgets(
          'long title and subtitle wrap at ${scale}x text without overflow',
          (tester) async {
        await tester.pumpWidget(_host(
          KubusActionTileLayout.compact,
          title: _longTitle,
          subtitle: _longTitle,
          textScale: scale,
          width: 280,
        ));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(KubusActionTile)).width, 280);
      });
    }
  });
}
