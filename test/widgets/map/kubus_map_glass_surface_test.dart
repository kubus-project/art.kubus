import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'map glass surface uses the same opaque fallback when blur is forced off',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => buildKubusMapGlassSurface(
              context: context,
              kind: KubusMapGlassSurfaceKind.button,
              useBlur: false,
              tintBase: Colors.teal,
              child: const SizedBox(width: 80, height: 40),
            ),
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
  });
}
