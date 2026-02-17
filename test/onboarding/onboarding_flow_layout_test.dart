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
    expect(find.byType(SingleChildScrollView), findsNothing);
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

  testWidgets('onboarding cannot finish when user is not signed in', (tester) async {
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

    for (var i = 0; i < 8; i++) {
      final done = find.text('Get started');
      if (done.evaluate().isNotEmpty) break;
      await tester.tap(find.text('Skip').first);
      await tester.pumpAndSettle();
    }

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('role and follow steps remain visible for unsigned users', (tester) async {
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
    await tester.tap(find.text('Skip').first); // account
    await tester.pumpAndSettle();
    expect(find.text('Pick your role'), findsOneWidget);

    await tester.tap(find.text('Skip').first); // role
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip').first); // permissions
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip').first); // artwork
    await tester.pumpAndSettle();
    expect(find.text('Follow a few artists'), findsOneWidget);
  });

  testWidgets('permissions step keeps action controls available after request tap', (tester) async {
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
    await tester.tap(find.text('Skip').first); // account
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip').first); // role
    await tester.pumpAndSettle();
    expect(find.text('Choose what to enable'), findsOneWidget);

    final enableButtons = find.widgetWithText(TextButton, 'Enable');
    expect(enableButtons, findsWidgets);
    await tester.tap(enableButtons.first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Choose what to enable'), findsOneWidget);
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
