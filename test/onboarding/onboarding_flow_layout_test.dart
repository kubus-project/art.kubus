import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
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

ProfileProvider _signedInProfileProvider({
  String walletAddress = 'wallet_test_123',
}) {
  final profileProvider = ProfileProvider();
  profileProvider.setCurrentUser(
    UserProfile(
      id: 'user-1',
      walletAddress: walletAddress,
      username: 'tester',
      displayName: 'QA Tester',
      bio: '',
      avatar: '',
      isArtist: true,
      createdAt: DateTime.utc(2025, 1, 1),
      updatedAt: DateTime.utc(2025, 1, 1),
    ),
  );
  return profileProvider;
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
      'deprecated permissions step id falls back to contextual permissions flow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'permissions'),
        locale: const Locale('en'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.text('Before we start...'), findsNothing);
    expect(find.text('Continue'), findsWidgets);

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    expect(find.text('Explore artworks'), findsOneWidget);
    expect(find.text('Location access'), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
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

  testWidgets(
      'role step stores DAO draft locally and does not submit before onboarding completion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1700));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    var daoSubmitCount = 0;
    _installBackendMock((request) async {
      if (request.method == 'POST' && request.url.path == '/api/dao/reviews') {
        daoSubmitCount += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true}),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.path.startsWith('/api/dao/reviews/')) {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'data': null}),
          404,
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
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        size: const Size(390, 1700),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.text('Pick your role'), findsOneWidget);
    await tester.tap(find.text('Artist / collective'));
    await tester.pumpAndSettle();
    expect(find.text('Apply for DAO review'), findsNothing);

    await tester.enterText(
        find.byType(TextField).at(0), 'https://portfolio.test');
    await tester.enterText(find.byType(TextField).at(1), 'Murals');
    await tester.enterText(
        find.byType(TextField).at(2), 'Community-led practice');
    await tester.pump();

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('onboarding_dao_application_draft_v1'), isNotNull);
    expect(daoSubmitCount, 0);
  });

  testWidgets('DAO draft submits once on completion and clears local draft',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    BackendApiService().setAuthTokenForTesting('qa-auth-token');

    var daoSubmitCount = 0;
    final seenRequests = <String>[];
    _installBackendMock((request) async {
      seenRequests.add('${request.method} ${request.url.path}');
      if (request.url.path.contains('/api/dao/reviews') &&
          request.method.toUpperCase() == 'POST') {
        daoSubmitCount += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'id': 'review-1',
              'status': 'pending',
            },
          }),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.path.startsWith('/api/dao/reviews/')) {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'data': null}),
          404,
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
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        profileProvider: _signedInProfileProvider(),
      ),
    );
    await _pumpOnboardingReady(tester);

    await tester.tap(find.text('Artist / collective'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).at(0), 'https://portfolio.test');
    await tester.enterText(find.byType(TextField).at(1), 'Street art');
    await tester.enterText(
        find.byType(TextField).at(2), 'I create community murals.');
    await tester.pump();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final prefsBefore = await SharedPreferences.getInstance();
    expect(
      prefsBefore.getString('onboarding_dao_application_draft_v1'),
      isNotNull,
    );
    expect(daoSubmitCount, 0);

    for (var i = 0;
        i < 6 && find.text('Get started').evaluate().isEmpty;
        i += 1) {
      final continueButtons = find.text('Continue');
      if (continueButtons.evaluate().isNotEmpty) {
        await tester.tap(continueButtons.last);
      }
      await tester.pumpAndSettle();
    }

    await _pumpUntilFound(tester, find.text('Get started'));
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started').first);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      seenRequests.any((request) => request.contains('/api/dao/reviews')),
      isTrue,
    );
    expect(daoSubmitCount, 1);
    expect(prefs.getString('onboarding_dao_application_draft_v1'), isNull);
  });

  testWidgets(
      'DAO draft submission failure keeps local draft and surfaces retry feedback',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    BackendApiService().setAuthTokenForTesting('qa-auth-token');

    var daoSubmitCount = 0;
    final seenRequests = <String>[];
    _installBackendMock((request) async {
      seenRequests.add('${request.method} ${request.url.path}');
      if (request.url.path.contains('/api/dao/reviews') &&
          request.method.toUpperCase() == 'POST') {
        daoSubmitCount += 1;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'error': 'DAO temporarily unavailable',
          }),
          500,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.path.startsWith('/api/dao/reviews/')) {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'data': null}),
          404,
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
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        locale: const Locale('en'),
        profileProvider: _signedInProfileProvider(),
      ),
    );
    await _pumpOnboardingReady(tester);

    await tester.tap(find.text('Artist / collective'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).at(0), 'https://portfolio.test');
    await tester.enterText(find.byType(TextField).at(1), 'Street art');
    await tester.enterText(
        find.byType(TextField).at(2), 'I create community murals.');
    await tester.pump();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final prefsBefore = await SharedPreferences.getInstance();
    expect(
      prefsBefore.getString('onboarding_dao_application_draft_v1'),
      isNotNull,
    );
    expect(daoSubmitCount, 0);

    for (var i = 0;
        i < 6 && find.text('Get started').evaluate().isEmpty;
        i += 1) {
      final continueButtons = find.text('Continue');
      if (continueButtons.evaluate().isNotEmpty) {
        await tester.tap(continueButtons.last);
      }
      await tester.pumpAndSettle();
    }

    await _pumpUntilFound(tester, find.text('Get started'));
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started').first);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      seenRequests.any((request) => request.contains('/api/dao/reviews')),
      isTrue,
    );
    expect(daoSubmitCount, 1);
    expect(prefs.getString('onboarding_dao_application_draft_v1'), isNotNull);
    expect(
      find.textContaining('Draft kept locally so you can retry later.'),
      findsOneWidget,
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
