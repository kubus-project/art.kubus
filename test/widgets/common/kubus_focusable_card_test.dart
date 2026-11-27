import 'dart:ui' show Tristate;

import 'package:art_kubus/widgets/common/kubus_focusable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 160, height: 120, child: child),
        ),
      ),
    );

KubusFocusableCard _card({required VoidCallback onTap}) => KubusFocusableCard(
      semanticLabel: 'Sun Garden, 3 likes',
      accent: const Color(0xFF14B8A6),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: const ColoredBox(
        color: Color(0xFF223344),
        child: Center(child: Text('Sun Garden')),
      ),
    );

/// Every semantics node under [node] that can take focus but has no label.
List<SemanticsNode> _namelessFocusStops(SemanticsNode node) {
  final found = <SemanticsNode>[];
  void visit(SemanticsNode current) {
    if (current.flagsCollection.isFocused != Tristate.none &&
        current.label.isEmpty) {
      found.add(current);
    }
    current.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(node);
  return found;
}

void main() {
  testWidgets('the card is one labelled button that is also the focus stop',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_harness(_card(onTap: () {})));

    final node =
        tester.getSemantics(find.bySemanticsLabel('Sun Garden, 3 likes'));
    expect(node.label, 'Sun Garden, 3 likes');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isFocused, isNot(Tristate.none));
    expect(node.flagsCollection.isFocused, Tristate.isFalse);
    expect(_namelessFocusStops(node), isEmpty);
    semantics.dispose();
  });

  testWidgets('Tab focuses the card and Enter and Space activate it',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_harness(_card(onTap: () => taps++)));

    final finder = find.bySemanticsLabel('Sun Garden, 3 likes');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.getSemantics(finder).flagsCollection.isFocused,
      Tristate.isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
    semantics.dispose();
  });

  testWidgets('a keyboard-focused card shows the accent border',
      (tester) async {
    await tester.pumpWidget(_harness(_card(onTap: () {})));

    BoxDecoration decoration() => tester
        .widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(KubusFocusableCard),
                matching: find.byType(DecoratedBox),
              )
              .first,
        )
        .decoration as BoxDecoration;

    expect(decoration().border, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final border = decoration().border! as Border;
    expect(border.top.color, const Color(0xFF14B8A6));
    expect(border.top.width, KubusFocusableCard.focusBorderWidth);
  });
}
