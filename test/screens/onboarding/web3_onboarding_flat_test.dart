import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/onboarding/web3/web3_onboarding.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(extensions: const [KubusColorRoles.light]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              Web3OnboardingPageBody(
                icon: Icons.palette,
                title: 'Welcome to artist studio',
                description: 'Your workspace for managing artworks, creating '
                    'AR markers, and tracking your progress.',
                features: <String>[
                  'Manage your artwork collection',
                  'Create interactive AR markers',
                ],
              ),
              Web3OnboardingProgress(count: 5, current: 1, label: '2 of 5'),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('sl')]) {
    testWidgets(
        'structural features label has no trailing colon (${locale.languageCode})',
        (tester) async {
      await _pump(tester, locale: locale);
      final expected =
          locale.languageCode == 'sl' ? 'ORODJA PLATFORME' : 'PLATFORM TOOLS';
      expect(find.text(expected), findsOneWidget);
      expect(find.text('$expected:'), findsNothing);
    });
  }

  testWidgets('onboarding body fits 320 px at 200% text', (tester) async {
    await _pump(tester, locale: const Locale('sl'), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress exposes its position as text, not only dots',
      (tester) async {
    await _pump(tester, locale: const Locale('en'));
    expect(find.text('2 of 5'), findsOneWidget);
  });
}
