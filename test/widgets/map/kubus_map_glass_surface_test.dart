import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('map blur policy allows compact web-sized chrome when capable',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 720)),
          child: Builder(
            builder: (context) {
              decision = resolveKubusMapBlurDecision(
                context,
                policy: KubusMapBlurPolicy.allowCompactWeb,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(decision.width, 390);
  });

  testWidgets('map blur policy reports explicit disabled fallback',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.disabled,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decision.enabled, isFalse);
    expect(decision.reason, 'policy-disabled');
  });

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
