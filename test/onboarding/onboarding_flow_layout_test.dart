import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/screens/onboarding/onboarding_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/auth_title_row.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({
  required Widget child,
  required Locale locale,
  double viewInsetsBottom = 0,
  Size size = const Size(390, 844),
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.system,
  ProfileProvider? profileProvider,
}) {
  final resolvedProfileProvider = profileProvider ?? ProfileProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<ProfileProvider>.value(
          value: resolvedProfileProvider),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      darkTheme: darkTheme ?? ThemeData.dark(useMaterial3: true),
      themeMode: themeMode,
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

Future<void> _pumpOnboardingReady(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 120));
    final hasTitleRow = find.byType(AuthTitleRow).evaluate().isNotEmpty;
    final hasLoading =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    if (hasTitleRow && !hasLoading) {
      return;
    }
  }
  await tester.pump(const Duration(milliseconds: 120));
}

void _installBackendMock(
  Future<http.Response> Function(http.Request request) handler,
) {
  BackendApiService().setHttpClient(MockClient(handler));
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 120));
    if (finder.evaluate().isNotEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    _installBackendMock((_) async => http.Response(
          jsonEncode(<String, dynamic>{'success': false}),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        ));
  });

  tearDown(() {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
  });

  testWidgets('onboarding starts at welcome and stays non-scrollable on mobile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.text('Your quick setup'), findsOneWidget);
    expect(find.text('Continue'), findsWidgets);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(CustomScrollView), findsNothing);
  });

  testWidgets('onboarding shows desktop step rail on wide layouts',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        size: const Size(1280, 900),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(
        find.byKey(const Key('onboarding_desktop_step_rail')), findsOneWidget);
  });

  testWidgets('contextual permissions appear on map/community/ar steps',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

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

    expect(find.text('Experience AR'), findsWidgets);
    expect(find.text('Camera access'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Enable'), findsWidgets);
  });

  testWidgets(
      'verification manual check keeps onboarding on verify step while pending',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': 'pending@example.com',
    });

    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'verified': false}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);
    expect(find.text('I verified / Continue'), findsWidgets);

    await tester.tap(find.text('I verified / Continue').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(
        find.text('After verifying, return here to sign in.'), findsOneWidget);
    expect(find.text('Choose what to enable'), findsNothing);
    expect(
      find.ancestor(
        of: find.text('After verifying, return here to sign in.'),
        matching: find.byType(LiquidGlassPanel),
      ),
      findsWidgets,
    );
  });

  testWidgets(
      'verification auto-check on app resume advances when backend confirms',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_verification_email_v3': 'resume-check@example.com',
    });

    var statusChecks = 0;
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/email-status') {
        statusChecks += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'verified': statusChecks >= 2,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'verifyEmail'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);
    expect(find.text('I verified / Continue'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpUntilFound(tester, find.text('Choose what to enable'));

    expect(statusChecks, greaterThanOrEqualTo(2));
    expect(find.text('I verified / Continue'), findsNothing);
  });

  testWidgets(
      'dao application with missing fields shows warning and stays on role step',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1700));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        size: const Size(390, 1700),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.text('Pick your role'), findsOneWidget);
    await tester.tap(find.text('Artist / collective'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Apply for DAO review'),
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await tester.tap(find.text('Apply for DAO review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Please fill in all required fields'), findsOneWidget);
    expect(find.text('Pick your role'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Please fill in all required fields'),
        matching: find.byType(LiquidGlassPanel),
      ),
      findsWidgets,
    );
  });

  testWidgets('onboarding header action icons follow theme contrast rules',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        themeMode: ThemeMode.light,
      ),
    );
    await _pumpOnboardingReady(tester);

    final lightLanguageIcon =
        tester.widget<Icon>(find.byIcon(Icons.language).first);
    final lightThemeIcon =
        tester.widget<Icon>(find.byIcon(Icons.brightness_6_outlined).first);
    expect(lightLanguageIcon.color, equals(Colors.black));
    expect(lightThemeIcon.color, equals(Colors.black));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        themeMode: ThemeMode.dark,
      ),
    );
    await _pumpOnboardingReady(tester);

    final darkLanguageIcon =
        tester.widget<Icon>(find.byIcon(Icons.language).first);
    final darkThemeIcon =
        tester.widget<Icon>(find.byIcon(Icons.brightness_6_outlined).first);
    expect(darkLanguageIcon.color, equals(Colors.white));
    expect(darkThemeIcon.color, equals(Colors.white));
  });

  testWidgets('onboarding header keeps enlarged auth title footprint',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    final titleSize = tester.getSize(find.byType(AuthTitleRow).first);
    expect(titleSize.height, greaterThanOrEqualTo(68));
    expect(titleSize.width, greaterThan(280));
  });

  testWidgets('onboarding remains stable on small mobile heights',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        size: const Size(360, 640),
      ),
    );
    await _pumpOnboardingReady(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'sign-in mobile layout has no page scroll and clears keyboard inset gap',
      (tester) async {
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

    final AnimatedPadding openPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(
        openPadding.padding.resolve(TextDirection.ltr).bottom, greaterThan(0));

    await tester.pumpWidget(
      _buildTestApp(
        child: const SignInScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final AnimatedPadding closedPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(closedPadding.padding.resolve(TextDirection.ltr).bottom, equals(0));
  });

  testWidgets('onboarding keyboard inset animation resets to zero after close',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 280,
      ),
    );
    await _pumpOnboardingReady(tester);
    await tester.pump(const Duration(milliseconds: 250));
    final AnimatedPadding openPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(openPadding.padding.resolve(TextDirection.ltr).bottom, equals(280));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingScreen(),
        locale: const Locale('en'),
        viewInsetsBottom: 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final AnimatedPadding closedPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(closedPadding.padding.resolve(TextDirection.ltr).bottom, equals(0));
  });
}
