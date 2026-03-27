import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'GlassSurface uses opaque theme-surface fallback when blur is disabled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: GlassSurface(
            enableBlur: false,
            tintColor: Colors.red,
            borderRadius: BorderRadius.circular(KubusRadius.md),
            child: const SizedBox(width: 120, height: 60),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);

    final clipFinder = find.byType(ClipRRect).first;
    final decoratedFinder = find
        .descendant(
          of: clipFinder,
          matching: find.byType(DecoratedBox),
        )
        .first;
    final decoratedBox = tester.widget<DecoratedBox>(decoratedFinder);
    final decoration = decoratedBox.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;

    expect(
      gradient.colors.first.a,
      closeTo(KubusGlassEffects.fallbackOpaqueOpacity, 0.001),
    );
    expect(gradient.colors.first.r, lessThan(1.0));
  });
}
