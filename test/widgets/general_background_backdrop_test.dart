import 'package:art_kubus/widgets/general_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GeneralBackground paints a non-white fallback first',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: GeneralBackground(
            animate: false,
            showMapLayer: false,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final fallback = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('general-background-fallback')),
    );

    expect(fallback.color, isNot(Colors.white));
    expect(fallback.color.toARGB32() >> 24, 0xFF);
  });
}
