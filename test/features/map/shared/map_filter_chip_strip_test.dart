import 'package:art_kubus/features/map/shared/map_search_filter_assembly.dart';
import 'package:art_kubus/widgets/common/kubus_glass_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<KubusMapFilterOption> _options() => const <KubusMapFilterOption>[
      KubusMapFilterOption(
        key: 'all',
        label: 'All',
        accentColor: Colors.blue,
        icon: Icons.public,
      ),
      KubusMapFilterOption(
        key: 'undiscovered',
        label: 'Undiscovered',
        accentColor: Colors.green,
        icon: Icons.explore_outlined,
      ),
    ];

Widget _host({
  required String selectedKey,
  double width = 1000,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: KubusMapFilterChipStrip(
            options: _options(),
            selectedKey: selectedKey,
            layout: KubusMapFilterChipLayout.rowFixed,
            onSelected: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'rowFixed chips render as fixed-size button cells with a full-cell border',
    (tester) async {
      await tester.pumpWidget(_host(selectedKey: 'all'));
      await tester.pump();

      // Each chip is a fixed cell so the border wraps the whole button.
      final cells = find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.width == kKubusMapFilterRowChipMinWidth &&
            w.height == kKubusMapFilterChipHeight,
      );
      expect(cells, findsNWidgets(2));

      // The bordered AnimatedContainer fills the whole cell (not just icon/text).
      final firstChip = find
          .descendant(of: cells.first, matching: find.byType(AnimatedContainer))
          .first;
      final size = tester.getSize(firstChip);
      expect(size.width, kKubusMapFilterRowChipMinWidth);
      expect(size.height, kKubusMapFilterChipHeight);

      final container = tester.widget<AnimatedContainer>(firstChip);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    },
  );

  testWidgets('rowFixed active state colours the whole selected cell',
      (tester) async {
    await tester.pumpWidget(_host(selectedKey: 'undiscovered'));
    await tester.pump();

    // The active chip is full width inside its fixed cell and carries a border
    // + glow over the whole cell.
    final activeChip = tester.widget<KubusGlassChip>(
      find.byWidgetPredicate(
        (w) => w is KubusGlassChip && w.active && w.fullWidth,
      ),
    );
    expect(activeChip.fullWidth, isTrue);

    // Two cells, only one active.
    expect(
      find.byWidgetPredicate((w) => w is KubusGlassChip && w.active),
      findsOneWidget,
    );
  });

  testWidgets('rowFixed reflows onto a second line on narrow widths',
      (tester) async {
    // Two 140px cells + spacing can't fit in 180px, so the Wrap must reflow.
    await tester.pumpWidget(_host(selectedKey: 'all', width: 180));
    await tester.pump();

    final cells = find.byWidgetPredicate(
      (w) =>
          w is SizedBox &&
          w.width == kKubusMapFilterRowChipMinWidth &&
          w.height == kKubusMapFilterChipHeight,
    );
    final first = tester.getTopLeft(cells.at(0));
    final second = tester.getTopLeft(cells.at(1));
    expect(second.dy, greaterThan(first.dy),
        reason: 'cells should wrap to a second row, not overflow');
  });
}
