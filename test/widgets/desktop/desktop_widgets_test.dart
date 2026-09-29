import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/desktop/components/desktop_widgets.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpDesktopStatCard(
    WidgetTester tester, {
    required Widget child,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  testWidgets('DesktopStatCard uses the shared stat type roles',
      (tester) async {
    await pumpDesktopStatCard(
      tester,
      child: const SizedBox(
        width: 240,
        height: 180,
        child: DesktopStatCard(
          label: 'Followers',
          value: '128',
          icon: Icons.group_outlined,
        ),
      ),
    );

    final value = tester.widget<Text>(find.text('128'));
    final label = tester.widget<Text>(find.text('Followers'));
    expect(value.style?.fontSize, KubusTextStyles.statValue.fontSize);
    expect(label.style?.fontSize, KubusTextStyles.detailCaption.fontSize);
  });

  testWidgets(
      'DesktopStatCard is flat: one small context icon, no hover lift or shadow',
      (tester) async {
    await pumpDesktopStatCard(
      tester,
      child: const SizedBox(
        width: 240,
        height: 180,
        child: DesktopStatCard(
          label: 'Followers',
          value: '128',
          icon: Icons.group_outlined,
        ),
      ),
    );

    // The icon is a compact context tile, not a card-sized watermark.
    final icon = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.icon == Icons.group_outlined,
    );
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon).height, lessThanOrEqualTo(16));
    expect(
      find.descendant(
        of: find.byType(DesktopStatCard),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    final decorated = tester
        .widgetList<DecoratedBox>(find.descendant(
          of: find.byType(DesktopStatCard),
          matching: find.byType(DecoratedBox),
        ))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>();
    expect(decorated.any((d) => (d.boxShadow ?? const []).isNotEmpty), isFalse);
  });
}
