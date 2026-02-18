import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({
  required Widget child,
  required Locale locale,
  double viewInsetsBottom = 0,
  Size size = const Size(390, 844),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('onboarding starts at welcome and stays non-scrollable on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Welcome to art.kubus'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(CustomScrollView), findsNothing);
  });

  testWidgets('onboarding shows desktop step rail on wide layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        size: const Size(1280, 900),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const Key('onboarding_desktop_step_rail')), findsOneWidget);
  });

  testWidgets('contextual permissions appear on map/community/ar steps', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    expect(find.text('Explore artworks'), findsOneWidget);
    expect(find.text('Location access'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Enable'), findsWidgets);

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    expect(find.text('Join the community'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Enable'), findsWidgets);

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    expect(find.text('Experience AR'), findsOneWidget);
    expect(find.text('Camera access'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Enable'), findsWidgets);
  });

  testWidgets('onboarding remains stable on small mobile heights', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        size: const Size(360, 640),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in mobile layout has no page scroll and clears keyboard inset gap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const SignInScreen(),
        locale: const Locale('en'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(CustomScrollView), findsNothing);

    await tester.pumpWidget(
      _buildTestApp(
        child: const SignInScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 320,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final AnimatedPadding openPadding = tester.widget(find.byType(AnimatedPadding).first);
    expect(openPadding.padding.resolve(TextDirection.ltr).bottom, greaterThan(0));

    await tester.pumpWidget(
      _buildTestApp(
        child: const SignInScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final AnimatedPadding closedPadding = tester.widget(find.byType(AnimatedPadding).first);
    expect(closedPadding.padding.resolve(TextDirection.ltr).bottom, equals(0));
  });

  testWidgets('onboarding keyboard inset animation resets to zero after close', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 280,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final AnimatedPadding openPadding = tester.widget(find.byType(AnimatedPadding).first);
    expect(openPadding.padding.resolve(TextDirection.ltr).bottom, equals(280));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final AnimatedPadding closedPadding = tester.widget(find.byType(AnimatedPadding).first);
    expect(closedPadding.padding.resolve(TextDirection.ltr).bottom, equals(0));
  });
}
