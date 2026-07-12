import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/common/kubus_meter_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 200, child: child)),
      ),
    );

void main() {
  testWidgets('fill width follows progress', (tester) async {
    await tester.pumpWidget(_wrap(const KubusMeterBar(progress: 0.5)));
    final fill = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fill.widthFactor, 0.5);
  });

  testWidgets('progress is clamped to 0..1', (tester) async {
    await tester.pumpWidget(_wrap(const KubusMeterBar(progress: 1.7)));
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      1.0,
    );
    await tester.pumpWidget(_wrap(const KubusMeterBar(progress: -3)));
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      0.0,
    );
  });

  testWidgets('honors explicit height and colors', (tester) async {
    const accent = Color(0xFF10B981);
    await tester.pumpWidget(_wrap(
      const KubusMeterBar(progress: 0.25, height: 10, color: accent),
    ));
    final box = tester.getSize(find.byType(KubusMeterBar));
    expect(box.height, 10);
    final deco = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((deco.decoration as BoxDecoration).color, accent);
  });
}
