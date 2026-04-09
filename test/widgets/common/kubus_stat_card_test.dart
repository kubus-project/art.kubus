import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('centered stat cards render icon watermark in card center',
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

    expect((iconCenter.dx - cardCenter.dx).abs(), lessThan(2.0));
    expect((iconCenter.dy - cardCenter.dy).abs(), lessThan(2.0));
  });
}
