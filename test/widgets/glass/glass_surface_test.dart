import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GlassSurface blur path keeps platform views out of foreground',
      (tester) async {
    const childKey = Key('sharp-foreground-child');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: const Scaffold(
          body: GlassSurface(
            enableBlur: true,
            child: SizedBox(
              key: childKey,
              width: 120,
              height: 60,
              child: Text('Sharp'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(HtmlElementView), findsNothing);
    expect(find.byKey(childKey), findsOneWidget);

    final blurFinder = find.byType(BackdropFilter);
    final decoratedFinder = find.descendant(
      of: blurFinder,
      matching: find.byType(DecoratedBox),
    );
    expect(decoratedFinder, findsOneWidget);
    expect(
      find.descendant(
        of: decoratedFinder,
        matching: find.byKey(childKey),
      ),
      findsOneWidget,
    );
  });

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
