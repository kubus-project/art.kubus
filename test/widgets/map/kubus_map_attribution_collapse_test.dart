import 'package:art_kubus/utils/kubus_map_tokens.dart';
import 'package:art_kubus/widgets/map/kubus_map_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home:
          Scaffold(body: Align(alignment: Alignment.bottomRight, child: child)),
    );

void main() {
  group('collapsing basemap credit', () {
    testWidgets(
        'spells the credit out on arrival, then collapses to the info '
        'button', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_wrap(KubusMapCollapsingAttribution(
        semanticsLabel: 'Attributions',
        onPressed: () => opened++,
      )));
      expect(find.text(kubusMapAttributionCredit), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      expect(find.text(kubusMapAttributionCredit), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      final size = tester.getSize(find.byType(KubusMapAttributionControl));
      // One control-sized square (plus the surface's hairline).
      expect(size.width, size.height);
      expect(size.width, inInclusiveRange(48, 50));
    });

    testWidgets(
        'the credit stays reachable once collapsed: tap, tooltip, '
        'semantics', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_wrap(KubusMapCollapsingAttribution(
        semanticsLabel: 'Attributions',
        onPressed: () => opened++,
        expandedFor: Duration.zero,
      )));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byType(KubusMapAttributionControl));
      expect(opened, 1);
      expect(
        find.bySemanticsLabel('Attributions: $kubusMapAttributionCredit'),
        findsOneWidget,
        reason: 'a screen reader still hears the full credit',
      );
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('OpenStreetMap'));
    });

    testWidgets('the mobile control height is honoured collapsed',
        (tester) async {
      await tester.pumpWidget(_wrap(KubusMapCollapsingAttribution(
        semanticsLabel: 'Attributions',
        minHeight: KubusMapMetrics.mobileControlSize,
        onPressed: () {},
        expandedFor: Duration.zero,
      )));
      await tester.pump(const Duration(milliseconds: 10));
      final size = tester.getSize(find.byType(KubusMapAttributionControl));
      expect(size.width, size.height);
      expect(size.width, inInclusiveRange(48, 50));
    });

    testWidgets('disposing before the timer fires is safe', (tester) async {
      await tester.pumpWidget(_wrap(KubusMapCollapsingAttribution(
        semanticsLabel: 'Attributions',
        onPressed: () {},
      )));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });
  });
}
