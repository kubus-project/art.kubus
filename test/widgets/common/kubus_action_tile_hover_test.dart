import 'dart:math' as math;

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

/// The painted rect of the ghost glyph (paint transforms included).
Rect _glyph(WidgetTester tester) => tester.getRect(find.descendant(
      of: find.byKey(_glyphKey),
      matching: find.byIcon(Icons.analytics_outlined),
    ));

/// Moves the pointer onto the tile and lets the 180 ms lift complete. The
/// float keeps running afterwards (it only stops once the pointer leaves), so
/// tests never `pumpAndSettle` while hovered.
Future<void> _hover(WidgetTester tester, TestGesture gesture) async {
  await gesture.moveTo(tester.getCenter(find.byType(KubusActionTile)));
  await tester.pump();
  await tester.pump(KubusHoverResponse.duration * 1.2);
}

/// The surface's vertical offset from [rest], sampled every [step] for
/// [span] while the pointer stays. Negative is up.
Future<List<double>> _floatTrace(
  WidgetTester tester,
  Offset rest, {
  Duration step = const Duration(milliseconds: 100),
  Duration span = const Duration(milliseconds: 2400),
}) async {
  final trace = <double>[];
  for (var t = Duration.zero; t < span; t += step) {
    await tester.pump(step);
    trace.add(_surfaceTopLeft(tester).dy - rest.dy);
  }
  return trace;
}

void _expectOffset(Offset actual, Offset expected, {String? reason}) {
  expect(actual.dx, moreOrLessEquals(expected.dx, epsilon: 0.01),
      reason: reason);
  expect(actual.dy, moreOrLessEquals(expected.dy, epsilon: 0.01),
      reason: reason);
}

void _expectRect(Rect actual, Rect expected, {String? reason}) {
  _expectOffset(actual.topLeft, expected.topLeft, reason: reason);
  _expectOffset(actual.bottomRight, expected.bottomRight, reason: reason);
}

Future<void> _leave(WidgetTester tester, TestGesture gesture) async {
  await gesture.moveTo(const Offset(790, 590));
  await tester.pump();
  await tester.pump(KubusHoverResponse.duration * 1.2);
}

void main() {
  group('KubusGhostGlyphPlacement contract', () {
    test('tile, row and stat glyphs stay mostly inside their surface', () {
      // 0.8.1: 0.30-0.36 pushed most of the symbol off the card. Material
      // symbols carry ~8 % padding, so 0.2 already crops ~14 % per edge.
      for (final placement in const [
        KubusGhostGlyphPlacement.tile,
        KubusGhostGlyphPlacement.row,
        KubusGhostGlyphPlacement.stat,
      ]) {
        expect(placement.bleed, inInclusiveRange(0.08, 0.18),
            reason: placement.name);
        expect(placement.hoverShift, inInclusiveRange(2, 3),
            reason: placement.name);
        expect(placement.hoverScale, inInclusiveRange(1.02, 1.035),
            reason: placement.name);
      }
      // Only atmospheres and heroes crop hard, and they do not answer hover.
      // The atmosphere keeps its pre-0.8.1 geometry exactly.
      const atmosphere = KubusGhostGlyphPlacement.atmosphere;
      expect(atmosphere.bleed, 0.28);
      expect(atmosphere.extentFor(const Size(400, 200)), 220);
      expect(atmosphere.extentFor(const Size(400, 100)), 125);
      expect(atmosphere.hoverScale, 1);
      expect(KubusGhostGlyphPlacement.hero.bleed, greaterThan(0.3));
      expect(KubusGhostGlyphPlacement.hero.hoverScale, 1);
    });

    test('the hover drift points at the surface centre', () {
      const p = KubusGhostGlyphPlacement.tile;
      expect(p.shiftAt(Alignment.topRight, 0), Offset.zero);
      final s = p.shiftAt(Alignment.topRight, 1);
      expect(s.distance, moreOrLessEquals(p.hoverShift));
      expect(s.dx, lessThan(0));
      expect(s.dy, greaterThan(0));
      final b = p.shiftAt(Alignment.bottomRight, 1);
      expect(b.dx, lessThan(0));
      expect(b.dy, lessThan(0));
    });
  });

  group('KubusActionTile hover contract', () {
    const lift = KubusHoverResponse.liftDistance;
    const amp = KubusHoverResponse.floatAmplitude;

    for (final layout in KubusActionTileLayout.values) {
      testWidgets(
          '${layout.name}: rises, keeps floating while hovered, shadows, '
          'never moves layout and settles on exit', (tester) async {
        await tester.pumpWidget(_host(layout));
        final gesture = await _mouse(tester);
        final restSize = tester.getSize(find.byType(KubusActionTile));
        final rest = _surfaceTopLeft(tester);
        expect(_shadowAlpha(tester), 0);

        await _hover(tester, gesture);

        // The lift has completed: the surface sits inside the float band
        // around its lifted position, and never below its resting line.
        final first = _surfaceTopLeft(tester);
        expect(first.dx, rest.dx);
        expect(
          first.dy - rest.dy,
          inInclusiveRange(-(lift + amp), -(lift - amp)),
        );
        // Paint only: the laid-out size is untouched.
        expect(tester.getSize(find.byType(KubusActionTile)), restSize);
        // A tinted drop shadow, not a glow: visible but restrained.
        expect(_shadowAlpha(tester), inInclusiveRange(0.2, 0.4));

        // The float is continuous: over a bit more than one period the
        // surface visits both ends of its band.
        final trace = await _floatTrace(tester, rest);
        expect(trace.reduce(math.min), lessThanOrEqualTo(-(lift + amp) + 0.3));
        expect(
            trace.reduce(math.max), greaterThanOrEqualTo(-(lift - amp) - 0.3));
        for (final dy in trace) {
          expect(dy, lessThan(0), reason: 'never below the resting line');
          expect(dy, greaterThanOrEqualTo(-(lift + amp) - 0.01));
        }

        // Exit: back on the resting line, shadow gone, and the float stops
        // (pumpAndSettle only returns when nothing keeps animating).
        await _leave(tester, gesture);
        await tester.pumpAndSettle();
        expect(_surfaceTopLeft(tester), rest);
        expect(_shadowAlpha(tester), 0);
      });
    }

    testWidgets('the rise is an eased entry, not a jump', (tester) async {
      await tester.pumpWidget(_host(KubusActionTileLayout.stacked));
      final gesture = await _mouse(tester);
      final rest = _surfaceTopLeft(tester);
      await gesture.moveTo(tester.getCenter(find.byType(KubusActionTile)));
      await tester.pump();

      final frames = <double>[];
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 45));
        frames.add(rest.dy - _surfaceTopLeft(tester).dy);
      }
      // Rising on every frame, and still short of the lifted position after
      // the first 45 ms.
      expect(frames.first, inExclusiveRange(0.3, lift));
      expect(frames[1], greaterThan(frames.first));
      expect(frames[2], greaterThan(frames[1]));
    });

    for (final layout in const [
      KubusActionTileLayout.stacked,
      KubusActionTileLayout.compact,
    ]) {
      testWidgets(
          '${layout.name}: the ghost glyph drifts inward, grows at most 4 % '
          'and counter-floats', (tester) async {
        await tester.pumpWidget(_host(layout));
        final gesture = await _mouse(tester);
        final rest = _glyph(tester);
        final restSurface = _surfaceTopLeft(tester);

        await _hover(tester, gesture);

        final hovered = _glyph(tester);
        final scale = hovered.width / rest.width;
        expect(scale, inInclusiveRange(1.02, 1.04));
        // Measured on the glyph's own motion: take the tile's travel out of
        // the delta. The drift is 2-3 px, plus the glyph's own float
        // (2.2 % of its size).
        final surfaceTravel = _surfaceTopLeft(tester) - restSurface;
        final drift = hovered.center - rest.center - surfaceTravel;
        expect(drift.distance, inInclusiveRange(1, 6));
        // Inward from the top-right corner: to the left.
        expect(drift.dx, lessThan(0));

        // It floats on its own, against the surface: its offset inside the
        // tile changes over a period.
        final inside = <double>[];
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          inside.add(_glyph(tester).center.dy - _surfaceTopLeft(tester).dy);
        }
        expect(
            inside.reduce(math.max) - inside.reduce(math.min), greaterThan(1));
      });
    }

    testWidgets('inline: the arrow travels 2 px', (tester) async {
      await tester.pumpWidget(_host(KubusActionTileLayout.inline));
      final gesture = await _mouse(tester);
      final rest = _arrow(tester);

      await _hover(tester, gesture);

      expect(_arrow(tester).dx - rest.dx, moreOrLessEquals(2, epsilon: 0.01));
    });

    testWidgets(
        'compact: floats with an accent shadow, the arrow and text stay '
        'fixed relative to the tile, and the indicator and glyph answer',
        (tester) async {
      await tester.pumpWidget(
        _host(KubusActionTileLayout.compact, subtitle: 'Where this goes'),
      );
      final gesture = await _mouse(tester);
      final rest = _surfaceTopLeft(tester);
      final arrow = _arrow(tester) - rest;
      Color indicator() => (tester
              .widget<AnimatedContainer>(find.byKey(_indicatorKey))
              .decoration! as BoxDecoration)
          .color!;
      expect(indicator().a, 0);
      final glyphBefore = _glyph(tester);
      final title = tester.getRect(find.text('Analytics'));
      final size = tester.getSize(find.byType(KubusActionTile));

      await _hover(tester, gesture);

      // The whole surface moves as one painted unit: the arrow and title
      // keep their place on it at every point of the float.
      for (var i = 0; i < 12; i++) {
        final now = _surfaceTopLeft(tester);
        expect(now.dy, lessThan(rest.dy));
        _expectOffset(_arrow(tester) - now, arrow);
        _expectRect(
          tester.getRect(find.text('Analytics')),
          title.shift(Offset(0, now.dy - rest.dy)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.getSize(find.byType(KubusActionTile)), size);
      expect(_shadowAlpha(tester), inInclusiveRange(0.2, 0.4));
      expect(_glyph(tester), isNot(glyphBefore));
      expect(indicator().a, greaterThan(0.5));
    });

    for (final layout in KubusActionTileLayout.values) {
      testWidgets(
          '${layout.name}: reduced motion keeps a still lifted state, no '
          'animation', (tester) async {
        await tester.pumpWidget(_host(layout, reduceMotion: true));
        final gesture = await _mouse(tester);
        final rest = _surfaceTopLeft(tester);
        final stacked = layout == KubusActionTileLayout.stacked;
        final arrow = stacked ? null : _arrow(tester) - rest;
        final glyph = layout == KubusActionTileLayout.inline
            ? null
            : _glyph(tester).shift(const Offset(0, -lift));

        // One frame after the pointer arrives: already in the lifted state,
        // with no transition to wait for.
        await gesture.moveTo(tester.getCenter(find.byType(KubusActionTile)));
        await tester.pump();
        expect(
          rest.dy - _surfaceTopLeft(tester).dy,
          moreOrLessEquals(lift, epsilon: 0.01),
          reason: 'a still lift',
        );
        // ...and it stays exactly there: no float.
        final trace = await _floatTrace(tester, rest);
        expect(trace.toSet().length, 1, reason: 'no float');
        await tester.pumpAndSettle();

        expect(_surfaceTopLeft(tester).dx, rest.dx);
        if (!stacked) {
          _expectOffset(
            _arrow(tester) - _surfaceTopLeft(tester),
            arrow!,
            reason: 'no arrow travel',
          );
        }
        if (glyph != null) {
          _expectRect(_glyph(tester), glyph,
              reason: 'no glyph drift, scale or float');
        }
        expect(_shadowAlpha(tester), greaterThan(0),
            reason: 'the static shadow state still changes');

        await gesture.moveTo(const Offset(790, 590));
        await tester.pump();
        expect(_surfaceTopLeft(tester), rest, reason: 'returns at once');
      });
    }

    testWidgets('a disabled tile never lifts or floats', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 260,
                child: KubusActionTile(
                  title: 'Locked',
                  icon: Icons.lock_outline,
                  accent: _accent,
                  onTap: () {},
                  enabled: false,
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await _mouse(tester);
      final rest = _surfaceTopLeft(tester);
      await gesture.moveTo(tester.getCenter(find.byType(KubusActionTile)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_surfaceTopLeft(tester), rest);
      expect(_shadowAlpha(tester), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('removing a hovered tile disposes its float cleanly',
        (tester) async {
      await tester.pumpWidget(_host(KubusActionTileLayout.stacked));
      final gesture = await _mouse(tester);
      await _hover(tester, gesture);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('touch never leaves the tile in a hover state', (tester) async {
      await tester.pumpWidget(_host(KubusActionTileLayout.stacked));
      final rest = _surfaceTopLeft(tester);
      await tester.tap(find.byType(KubusActionTile));
      await tester.pumpAndSettle();
      expect(_surfaceTopLeft(tester), rest);
      expect(_shadowAlpha(tester), 0);
    });
  });

  // The remount fix is about `lift: interactive` toggling without rebuilding
  // the subtree; every layout lifts now, so every layout is covered.
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
    await tester.pump(const Duration(milliseconds: 300));
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
