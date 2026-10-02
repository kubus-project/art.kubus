import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/desktop/components/desktop_widgets.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:art_kubus/widgets/common/kubus_context_icon.dart';
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
      'DesktopStatCard: one identity layer (cropped ghost glyph, no '
      'foreground tile), no lift or shadow on the tile itself', (tester) async {
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

    // The symbol appears once, as the decorative ghost layer clipped by the
    // tile; there is no small foreground copy beside the number.
    expect(find.byType(KubusContextIcon), findsNothing);
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(KubusGhostGlyph),
        matching: find.byIcon(Icons.group_outlined),
      ),
      findsOneWidget,
    );
    // A metric is data: the tile never lifts and casts no shadow.
    expect(find.byType(DesktopStatCard), findsOneWidget);
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
