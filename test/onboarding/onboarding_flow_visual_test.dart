import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual contract for the redesigned onboarding shell: light contextual
/// header, stage-grouped progress, reduced-motion support, and the calm
/// one-decision wallet step.
Widget _buildTestApp({
  required Widget child,
  Size size = const Size(390, 844),
  bool disableAnimations = false,
  ProfileProvider? profileProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profileProvider ?? ProfileProvider(),
      ),
      ChangeNotifierProvider<WalletProvider>(
        create: (_) => WalletProvider(deferInit: true),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: disableAnimations,
        ),
        child: child,
      ),
    ),
  );
}

Future<void> _pumpOnboardingReady(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    if (find.byType(InlineLoading).evaluate().isEmpty) return;
  }
}

ProfileProvider _signedInAccountWithoutWallet() {
  return ProfileProvider()
    ..setCurrentUser(UserProfile(
      id: 'profile_visual',
      walletAddress: '',
      username: 'visual_user',
      displayName: 'Visual User',
      bio: '',
      avatar: '',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
  });

  testWidgets('header shows contextual stage label instead of a heavy card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        size: const Size(390, 1024),
      ),
    );
    await _pumpOnboardingReady(tester);

    // Light header: stage label + "Step x of y" context, quiet skip.
    expect(find.text('Profile'), findsWidgets);
    expect(find.textContaining('Step '), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion removes the step transition switcher',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1024));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'role'),
        size: const Size(390, 1024),
        disableAnimations: true,
      ),
    );
    await _pumpOnboardingReady(tester);

    final scaffoldSwitchers = find.descendant(
      of: find.byType(OnboardingFlowScreen),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedSwitcher &&
            widget.duration == const Duration(milliseconds: 240),
      ),
    );
    expect(scaffoldSwitchers, findsNothing);
    expect(find.text('Pick your role'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'wallet step leads with one primary decision and progressive disclosure',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'walletConnect'),
        size: const Size(390, 1200),
        profileProvider: _signedInAccountWithoutWallet(),
      ),
    );
    await _pumpOnboardingReady(tester);

    // One primary CTA; alternatives stay folded away.
    expect(find.text('Create wallet'), findsOneWidget);
    expect(find.text('I already have a wallet'), findsOneWidget);
    expect(find.text('Import wallet'), findsNothing);
    expect(find.text('Connect wallet'), findsNothing);

    await tester.tap(find.text('I already have a wallet'));
    // First pump starts the AnimatedSize reveal, second completes it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Import wallet'), findsOneWidget);
    // This native test build has no Reown project ID, so the unavailable
    // external-wallet action must stay hidden after disclosure.
    expect(find.text('Connect wallet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet step does not overflow on small mobile heights',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(initialStepId: 'walletConnect'),
        size: const Size(360, 640),
        profileProvider: _signedInAccountWithoutWallet(),
      ),
    );
    await _pumpOnboardingReady(tester);

    expect(find.text('Create wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop rail lists user-facing stages, not internal steps',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: const OnboardingFlowScreen(
          forceDesktop: true,
          initialStepId: 'walletConnect',
        ),
        size: const Size(1400, 900),
        profileProvider: _signedInAccountWithoutWallet(),
      ),
    );
    await _pumpOnboardingReady(tester);

    final rail = find.byKey(const Key('onboarding_desktop_step_rail'));
    expect(rail, findsOneWidget);
    expect(
      find.descendant(of: rail, matching: find.text('Wallet')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rail, matching: find.text('Account')),
      findsOneWidget,
    );
    // Internal step names must not leak into the rail.
    expect(
      find.descendant(of: rail, matching: find.text('Verify your email')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
