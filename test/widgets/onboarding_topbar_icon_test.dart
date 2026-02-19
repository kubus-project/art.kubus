import 'dart:ui';

import 'package:art_kubus/widgets/onboarding_topbar_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildApp(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: const Scaffold(
      body: Center(
        child: OnboardingTopbarIcon(
          icon: Icons.language,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('topbar icon is icon-only with no background fill',
      (tester) async {
    await tester.pumpWidget(_buildApp(ThemeData.light(useMaterial3: true)));
    await tester.pumpAndSettle();

    final animatedContainer =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    final decoration = animatedContainer.decoration as BoxDecoration?;
    expect(decoration, isNotNull);
    expect(decoration!.color, isNull);
  });

  testWidgets('topbar icon contrast follows theme brightness', (tester) async {
    await tester.pumpWidget(_buildApp(ThemeData.light(useMaterial3: true)));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Icon>(find.byIcon(Icons.language)).color, Colors.black);

    await tester.pumpWidget(_buildApp(ThemeData.dark(useMaterial3: true)));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Icon>(find.byIcon(Icons.language)).color, Colors.white);
  });

  testWidgets('topbar icon reacts to press feedback', (tester) async {
    await tester.pumpWidget(_buildApp(ThemeData.light(useMaterial3: true)));
    await tester.pumpAndSettle();

    final iconFinder = find.byType(OnboardingTopbarIcon);
    final iconCenter = tester.getCenter(iconFinder);
    final idleScale =
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    final idleOpacity =
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    final touch = await tester.startGesture(
      iconCenter,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 160));

    final pressedScale =
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    final pressedOpacity =
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    expect(pressedScale, lessThan(idleScale));
    expect(pressedOpacity, lessThan(idleOpacity));

    await touch.up();
  });
}
