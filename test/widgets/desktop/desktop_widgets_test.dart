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

  testWidgets('DesktopStatCard uses standardized stat sizing', (tester) async {
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

    expect(
      value.style?.fontSize,
      closeTo(KubusChromeMetrics.statValue * 0.95, 0.001),
    );
    expect(
      label.style?.fontSize,
      closeTo(KubusTextStyles.actionTileTitle.fontSize! * 0.93, 0.001),
    );
  });

  testWidgets('DesktopStatCard composes through shared watermark icon',
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
          centeredWatermarkAlignment: Alignment.center,
        ),
      ),
    );

    final iconFinder = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.icon == Icons.group_outlined,
    );

    expect(iconFinder, findsOneWidget);
  });
}
