import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/desktop/onboarding/desktop_web3_onboarding.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/gradient_icon_card.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the six-page "Wallet and archive tools" flow that ships as the
/// desktop Web3 feature onboarding.
List<Web3OnboardingPage> _pages({int count = 6}) {
  return List<Web3OnboardingPage>.generate(
    count,
    (index) => Web3OnboardingPage(
      title: 'Page $index',
      description: 'Description for page $index.',
      icon: Icons.account_balance_wallet,
      gradientColors: const <Color>[Color(0xFF6C5CE7), Color(0xFF4C8DFF)],
      features: <String>[
        'Feature ${index}a',
        'Feature ${index}b',
        'Feature ${index}c',
        'Feature ${index}d',
      ],
    ),
  );
}

Widget _buildApp({required Size size, int pageCount = 6}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: DesktopWeb3OnboardingScreen(
          featureKey: 'Web3 Features',
          featureTitle: 'Wallet and archive tools',
          pages: _pages(count: pageCount),
          onComplete: () {},
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('page content is vertically centred on a tall desktop viewport',
      (tester) async {
    const size = Size(1600, 1200);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(size: size));
    // AnimatedGradientBackground loops forever, so pumpAndSettle never
    // returns; pump past the 800ms page enter animation instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    // The content column runs from its icon card (first child) to the
    // key-features panel (last child); that span's midpoint must sit near the
    // centre of the area below the app bar, not pinned to the top.
    final iconTop = tester.getRect(find.byType(GradientIconCard).first).top;
    final panelBottom =
        tester.getRect(find.byType(LiquidGlassPanel).first).bottom;
    final contentCentre = (iconTop + panelBottom) / 2;

    final bodyCentre = kToolbarHeight + (size.height - kToolbarHeight) / 2;
    expect(
      (contentCentre - bodyCentre).abs(),
      lessThan(48),
      reason: 'content centre $contentCentre should track $bodyCentre',
    );
    // Guards the regression itself: top-anchored content put the icon within a
    // few dozen pixels of y=0.
    expect(iconTop, greaterThan(200));
  });

  testWidgets('sidebar is vertically centred alongside the page content',
      (tester) async {
    const size = Size(1600, 1200);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(size: size));
    // AnimatedGradientBackground loops forever, so pumpAndSettle never
    // returns; pump past the 800ms page enter animation instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    final sidebarRect = tester.getRect(
      find
          .ancestor(
            of: find.widgetWithText(KubusButton, 'Continue'),
            matching: find.byType(SingleChildScrollView),
          )
          .last,
    );
    final sidebarCentre = (sidebarRect.top + sidebarRect.bottom) / 2;
    final bodyCentre = kToolbarHeight + (size.height - kToolbarHeight) / 2;

    expect(
      (sidebarCentre - bodyCentre).abs(),
      lessThan(48),
      reason: 'sidebar centre $sidebarCentre should track $bodyCentre',
    );
  });

  testWidgets('content clears the app bar instead of tucking under Skip',
      (tester) async {
    const size = Size(1600, 1200);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(size: size));
    // AnimatedGradientBackground loops forever, so pumpAndSettle never
    // returns; pump past the 800ms page enter animation instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    final skipBottom = tester.getRect(find.text('Skip').first).bottom;
    final iconTop = tester.getRect(find.byType(GradientIconCard).first).top;
    expect(iconTop, greaterThan(skipBottom));
  });

  testWidgets('short desktop window scrolls instead of overflowing',
      (tester) async {
    const size = Size(1280, 560);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(size: size));
    // AnimatedGradientBackground loops forever, so pumpAndSettle never
    // returns; pump past the 800ms page enter animation instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(KubusButton, 'Continue'), findsOneWidget);
  });
}
