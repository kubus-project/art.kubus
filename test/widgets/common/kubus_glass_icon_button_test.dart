import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_badge.dart';
import 'package:art_kubus/widgets/common/kubus_glass_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('count badge stays inside a 44px canonical touch target',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      _wrap(
        KubusGlassIconButton(
          icon: Icons.filter_alt,
          tooltip: 'Active filters: 3',
          semanticsLabel: 'Active filters: 3',
          active: true,
          badgeCount: 3,
          size: KubusHeaderMetrics.actionHitArea,
          borderRadius: KubusRadius.sm,
          enableBlur: false,
          onPressed: () => taps += 1,
        ),
      ),
    );

    expect(find.byType(KubusBadge), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      tester.getSize(find.byType(KubusGlassIconButton)),
      const Size(
        KubusHeaderMetrics.actionHitArea,
        KubusHeaderMetrics.actionHitArea,
      ),
    );

    await tester.tap(find.byType(KubusGlassIconButton));
    expect(taps, 1);
  });

  testWidgets('active state and localized label are exposed as semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        KubusGlassIconButton(
          icon: Icons.filter_alt,
          tooltip: 'Filters',
          semanticsLabel: 'Active filters: 12',
          active: true,
          badgeCount: 12,
          enableBlur: false,
          onPressed: () {},
        ),
      ),
    );

    final control = find.bySemanticsLabel('Active filters: 12');
    expect(control, findsOneWidget);
    expect(
      tester.getSemantics(control),
      matchesSemantics(
        label: 'Active filters: 12',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('zero count does not render an empty badge', (tester) async {
    await tester.pumpWidget(
      _wrap(
        KubusGlassIconButton(
          icon: Icons.filter_alt,
          tooltip: 'Filters',
          badgeCount: 0,
          enableBlur: false,
          onPressed: () {},
        ),
      ),
    );

    expect(find.byType(KubusBadge), findsNothing);
  });
}
