import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/design_tokens.dart';

Widget _host(Brightness b, void Function(BuildContext) probe) {
  return MaterialApp(
    theme: ThemeData(
      brightness: b,
      colorScheme: b == Brightness.dark
          ? const ColorScheme.dark(outline: KubusColors.outlineDark)
          : const ColorScheme.light(outline: KubusColors.outlineLight),
    ),
    home: Builder(builder: (context) {
      probe(context);
      return const SizedBox.shrink();
    }),
  );
}

void main() {
  testWidgets('hairline uses scheme outline at hairline width', (tester) async {
    late BorderSide side;
    await tester.pumpWidget(_host(Brightness.dark, (c) {
      side = KubusBorders.hairlineSide(c);
    }));
    expect(side.width, KubusSizes.hairline);
    expect(side.color, KubusColors.outlineDark);
  });

  testWidgets('glass border matches glass token per brightness',
      (tester) async {
    late BorderSide dark;
    late BorderSide light;
    await tester.pumpWidget(_host(Brightness.dark, (c) {
      dark = KubusBorders.glassSide(c);
    }));
    // Tear down between pumps: MaterialApp animates theme changes, so a
    // rebuilt host would briefly still report the previous brightness.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_host(Brightness.light, (c) {
      light = KubusBorders.glassSide(c);
    }));
    expect(dark.color, KubusColors.glassBorderDark);
    expect(light.color, KubusColors.glassBorderLight);
  });

  testWidgets('focus and active derive from accent', (tester) async {
    late BorderSide focus;
    late BorderSide active;
    const accent = KubusColors.accentBlue;
    await tester.pumpWidget(_host(Brightness.dark, (c) {
      focus = KubusBorders.focusSide(c, accent: accent);
      active = KubusBorders.activeSide(c, accent: accent);
    }));
    expect(focus.width, greaterThan(KubusSizes.hairline));
    expect(
      focus.color.toARGB32() & 0x00FFFFFF,
      accent.toARGB32() & 0x00FFFFFF,
    );
    expect(active.color.a, closeTo(0.85, 0.01));
  });
}
