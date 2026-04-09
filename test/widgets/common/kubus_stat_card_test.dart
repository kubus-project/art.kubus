import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('centered stat cards show cropped lower watermark by default',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 120,
              child: KubusStatCard(
                title: 'Followers',
                value: '128',
                icon: Icons.people_outline,
                layout: KubusStatCardLayout.centered,
                centeredWatermarkAlignment: Alignment.center,
              ),
            ),
          ),
        ),
      ),
    );

    final cardFinder = find.byType(KubusStatCard);
    final iconFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Icon && widget.icon == Icons.people_outline,
    );

    expect(iconFinder, findsOneWidget);

    final cardCenter = tester.getCenter(cardFinder);
    final iconCenter = tester.getCenter(iconFinder);
    final iconWidget = tester.widget<Icon>(iconFinder);

    expect((iconCenter.dx - cardCenter.dx).abs(), lessThan(2.0));
    expect(iconCenter.dy, greaterThan(cardCenter.dy + 8.0));
    expect(iconWidget.size, greaterThan(120));
  });

  testWidgets('centered stat cards rise and float when hovered',
      (tester) async {
    Widget buildCard({required bool hovered}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 160,
              child: KubusStatCard(
                title: 'Followers',
                value: '128',
                icon: Icons.people_outline,
                layout: KubusStatCardLayout.centered,
                centeredWatermarkAlignment: Alignment.center,
                centeredWatermarkHovered: hovered,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildCard(hovered: false));

    final iconFinder = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.icon == Icons.people_outline,
    );
    final transformFinder = find.ancestor(
      of: iconFinder,
      matching: find.byType(Transform),
    );

    final restingTransform = tester.widgetList<Transform>(transformFinder).last;
    final restingYOffset = restingTransform.transform.storage[13];

    await tester.pumpWidget(buildCard(hovered: true));
    await tester.pump(const Duration(milliseconds: 320));

    final hoveredTransform = tester.widgetList<Transform>(transformFinder).last;
    final hoveredYOffset = hoveredTransform.transform.storage[13];

    expect(restingYOffset - hoveredYOffset, greaterThan(35.0));

    await tester.pump(const Duration(milliseconds: 700));
    final floatingTransform = tester.widgetList<Transform>(transformFinder).last;
    final floatingYOffset = floatingTransform.transform.storage[13];

    expect((floatingYOffset - hoveredYOffset).abs(), greaterThan(1.0));
  });
}
