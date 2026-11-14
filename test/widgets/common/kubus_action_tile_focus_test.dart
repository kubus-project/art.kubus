import 'dart:ui' show Tristate;

import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 240, child: child),
        ),
      ),
    );

KubusActionTile _tile({
  required VoidCallback onTap,
  bool enabled = true,
  KubusActionTileLayout layout = KubusActionTileLayout.stacked,
}) =>
    KubusActionTile(
      title: 'Ko-fi',
      icon: Icons.coffee_outlined,
      accent: const Color(0xFF14B8A6),
      onTap: onTap,
      enabled: enabled,
      layout: layout,
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
  for (final layout in KubusActionTileLayout.values) {
    testWidgets('${layout.name}: the labelled button is the focus stop',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(_tile(onTap: () {}, layout: layout)));

      final node = tester.getSemantics(find.bySemanticsLabel('Ko-fi'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isFocused, isNot(Tristate.none));
      expect(node.flagsCollection.isFocused, Tristate.isFalse);
      expect(_namelessFocusStops(node), isEmpty);
      semantics.dispose();
    });

    testWidgets('${layout.name}: Tab focuses the tile, Enter and Space open it',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(_tile(onTap: () => taps++, layout: layout)),
      );

      final finder = find.bySemanticsLabel('Ko-fi');
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
  }

  testWidgets('a disabled tile is not a focus stop', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_tile(onTap: () {}, enabled: false)));

    final node = tester.getSemantics(find.bySemanticsLabel('Ko-fi'));
    expect(node.flagsCollection.isFocused, Tristate.none);
    expect(_namelessFocusStops(node), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Ko-fi'))
          .flagsCollection
          .isFocused,
      isNot(Tristate.isTrue),
    );
    semantics.dispose();
  });
}
