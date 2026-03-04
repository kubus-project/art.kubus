import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
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
      routes: <String, WidgetBuilder>{
        '/main': (_) => const Scaffold(body: Text('Main shell')),
      },
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
    final hasLoading =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    if (!hasLoading) {
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

  testWidgets('onboarding starts at welcome wizard phase', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Welcome wizard should show page view with dot indicators
    expect(find.byType(PageView), findsOneWidget);
    // Should show discover title from welcome pages
    expect(find.text('Discover art around you'), findsOneWidget);
    // Branch buttons should be visible
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Discover art'), findsOneWidget);
  });

  testWidgets('welcome wizard shows both branch buttons on page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Both branch buttons should be visible and tappable
    final createAccountButton = find.text('Create an account');
    final discoverArtButton = find.text('Discover art');
    expect(createAccountButton, findsOneWidget);
    expect(discoverArtButton, findsOneWidget);
  });

  testWidgets('guest branch: discover art → permissions → done',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Tap "Discover art" to enter guest branch
    await tester.tap(find.text('Discover art'));
    await tester.pumpAndSettle();

    // Should show permissions step
    expect(find.text('Choose what to enable'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('account branch: create account shows auth panel',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Tap "Create an account" to enter account branch
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    // Should show account step with auth panel
    expect(find.text('Create your account'), findsOneWidget);
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
      'verification auto-check on app resume shows finish sign-in prompt after verify',
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
    await _pumpUntilFound(tester, find.text('Sign in to finish'));

    expect(statusChecks, greaterThanOrEqualTo(2));
    expect(find.text('Sign in to finish'), findsOneWidget);
    expect(find.text('Choose what to enable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role step shows persona picker without DAO fields',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1700));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    _installBackendMock((request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        size: const Size(390, 1700),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.text('Pick your role'), findsOneWidget);
    // DAO application fields should NOT appear in onboarding
    expect(find.text('Apply for DAO review'), findsNothing);
    // No text fields for portfolio URL, medium, statement
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('onboarding header action icons follow theme contrast rules',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
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

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
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
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Enter account branch to get the header with AuthTitleRow
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    final titleSize = tester.getSize(find.byType(AuthTitleRow).first);
    expect(titleSize.height, greaterThanOrEqualTo(48));
    expect(titleSize.width, greaterThan(280));
  });

  testWidgets('onboarding remains stable on small mobile heights',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(),
        locale: const Locale('en'),
        size: const Size(360, 640),
      ),
    );
    await _pumpOnboardingReady(tester);
    expect(tester.takeException(), isNull);

    // Welcome wizard should render without overflow on small heights
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Discover art'), findsOneWidget);
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
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
        locale: const Locale('en'),
        viewInsetsBottom: 280,
        size: const Size(390, 1200),
      ),
    );
    await _pumpOnboardingReady(tester);
    await tester.pump(const Duration(milliseconds: 250));
    final AnimatedPadding openPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(openPadding.padding.resolve(TextDirection.ltr).bottom, equals(280));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'account'),
        locale: const Locale('en'),
        viewInsetsBottom: 0,
        size: const Size(390, 1200),
      ),
    );
    await _pumpOnboardingReady(tester);
    await tester.pump(const Duration(milliseconds: 250));
    final AnimatedPadding closedPadding =
        tester.widget(find.byType(AnimatedPadding).first);
    expect(closedPadding.padding.resolve(TextDirection.ltr).bottom, equals(0));
  });
}
