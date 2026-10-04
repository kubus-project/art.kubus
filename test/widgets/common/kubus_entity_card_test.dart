import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/kubus_entity_semantics.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:art_kubus/widgets/common/kubus_entity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHarness(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('a tappable entity card exposes button semantics and taps',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;

    await tester.pumpWidget(
      _buildHarness(
        KubusEntityCard(
          variant: KubusEntityCardVariant.media,
          kind: KubusEntityKind.artwork,
          title: 'Sun Garden',
          subtitle: 'AR mural',
          meta: '12 likes',
          width: 220,
          height: 240,
          onTap: () => taps += 1,
        ),
      ),
    );

    final cardFinder = find.bySemanticsLabel('Sun Garden, AR mural, 12 likes');
    expect(cardFinder, findsOneWidget);
    expect(tester.getSemantics(cardFinder).flagsCollection.isButton, isTrue);

    await tester.tap(cardFinder);
    await tester.pump();

    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('a tappable entity card activates from keyboard focus',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      _buildHarness(
        KubusEntityCard(
          variant: KubusEntityCardVariant.media,
          kind: KubusEntityKind.artwork,
          title: 'Sun Garden',
          subtitle: 'AR mural',
          semanticLabel: 'Open Sun Garden',
          width: 220,
          height: 240,
          onTap: () => taps += 1,
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    // Keyboard focus is explicit and always available, hover or not.
    final container =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    final border = (container.decoration as BoxDecoration).border as Border;
    expect(border.top.width, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(taps, 2);
  });

  testWidgets('an entity card paints no shadow at rest', (tester) async {
    // debugDisableShadows is true under flutter_test, which makes a painted
    // shadow render hard-edged rather than absent — so assert on the
    // decoration instead, and restore the flag *inside* the body: the painting
    // debug invariant is verified before tearDown runs.
    final previous = debugDisableShadows;
    debugDisableShadows = false;

    await tester.pumpWidget(
      _buildHarness(
        KubusEntityCard(
          variant: KubusEntityCardVariant.media,
          kind: KubusEntityKind.artwork,
          title: 'Sun Garden',
          width: 220,
          height: 240,
          onTap: () {},
        ),
      ),
    );

    final container =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    final decoration = container.decoration as BoxDecoration;
    debugDisableShadows = previous;
    // Nothing *visible* at rest. The hover shadow keeps a fully transparent
    // entry at rest so its alpha can fade in rather than pop (an empty list
    // would interpolate from full strength), so assert on alpha, not length.
    expect(
      (decoration.boxShadow ?? const <BoxShadow>[]).every(
        (shadow) => shadow.color.a == 0,
      ),
      isTrue,
    );
  });

  testWidgets('a card without usable media shows the authored role field',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        KubusEntityCard(
          variant: KubusEntityCardVariant.media,
          kind: KubusEntityKind.collection,
          title: 'Night Walks',
          width: 220,
          height: 240,
        ),
      ),
    );

    // Not an anonymous grey rectangle with a small centred icon: the entity's
    // own colour field with its category glyph cropped into the corner.
    expect(
      find.byKey(const ValueKey<String>('kubus_entity_card_field')),
      findsOneWidget,
    );
    expect(find.byType(KubusAtmosphere), findsOneWidget);
  });

  testWidgets('reduced motion removes the media scale and the lift',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        KubusEntityCard(
          variant: KubusEntityCardVariant.media,
          kind: KubusEntityKind.artwork,
          title: 'Sun Garden',
          width: 220,
          height: 240,
          onTap: () {},
        ),
        disableAnimations: true,
      ),
    );

    // Under reduced motion the paint-only media scale is not built at all.
    expect(find.byKey(KubusEntityCard.mediaScaleKey), findsNothing);

    // The lift wrapper stays in the tree so toggling the setting never
    // remounts the card, but it never moves: its transform is the identity.
    final lift = tester.widget<Transform>(
      find.byKey(KubusEntityCard.liftKey),
    );
    expect(lift.transform, Matrix4.identity());
  });

  test('every entity kind resolves an accent and a glyph', () {
    for (final kind in KubusEntityKind.values) {
      expect(
        KubusEntitySemantics.accentFor(kind, KubusColorRoles.dark),
        isNotNull,
      );
      expect(KubusEntitySemantics.glyphFor(kind).codePoint, isNonZero);
    }
  });
}
