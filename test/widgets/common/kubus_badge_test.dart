import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/common/kubus_badge.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('renders text', (tester) async {
    await tester.pumpWidget(_wrap(const KubusBadge(text: 'Draft')));
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('status variant tints with provided accent', (tester) async {
    const accent = Color(0xFF10B981);
    await tester.pumpWidget(_wrap(const KubusBadge(
      text: 'Live',
      variant: KubusBadgeVariant.status,
      accent: accent,
    )));
    final deco = tester
        .widget<Container>(
          find
              .ancestor(of: find.text('Live'), matching: find.byType(Container))
              .first,
        )
        .decoration! as BoxDecoration;
    expect(
      deco.color!.toARGB32() & 0x00FFFFFF,
      accent.toARGB32() & 0x00FFFFFF,
    );
  });

  testWidgets('optional icon renders', (tester) async {
    await tester.pumpWidget(_wrap(const KubusBadge(
      text: '3',
      variant: KubusBadgeVariant.count,
      icon: Icons.notifications,
    )));
    expect(find.byIcon(Icons.notifications), findsOneWidget);
  });
}
