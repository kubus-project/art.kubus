import 'package:art_kubus/widgets/common/kubus_glass_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required bool fullWidth, double cellWidth = 300}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: cellWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: KubusGlassChip(
              label: 'Discovered',
              icon: Icons.check_circle_outline,
              active: false,
              fullWidth: fullWidth,
              minHeight: fullWidth ? 44 : null,
              onPressed: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('fullWidth chip border wraps the whole cell', (tester) async {
    await tester.pumpWidget(_host(fullWidth: true, cellWidth: 300));
    await tester.pump();

    // The bordered AnimatedContainer (the chip cell) fills the parent width and
    // honours the consistent minimum height, so the border wraps the whole
    // button rather than just the icon + label.
    final size = tester.getSize(find.byType(AnimatedContainer).first);
    expect(size.width, 300);
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('non-fullWidth chip shrink-wraps its content', (tester) async {
    await tester.pumpWidget(_host(fullWidth: false, cellWidth: 300));
    await tester.pump();

    final size = tester.getSize(find.byType(AnimatedContainer).first);
    expect(size.width, lessThan(300));
  });

  testWidgets('active state applies to the full cell border + tint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: KubusGlassChip(
                label: 'Favorites',
                icon: Icons.favorite,
                active: true,
                fullWidth: true,
                minHeight: 44,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    final decoration = container.decoration as BoxDecoration;
    // Active chips get a coloured border + glow over the whole cell.
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotNull);

    final size = tester.getSize(find.byType(AnimatedContainer).first);
    expect(size.width, 300);
  });
}
