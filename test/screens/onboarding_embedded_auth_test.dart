import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

// Minimal fake ProfileProvider for tests
// Use the real ProfileProvider in tests to avoid API contract mismatch.

class _NavObserver extends NavigatorObserver {
  final List<Route> pushed = [];
  @override
  void didPush(Route route, Route? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      // Ensure onboarding incomplete
      'hasCompletedOnboarding': false,
      // Seed a pending verification email
      'onboarding_verification_email_v3': 'tester@example.com',
      'onboarding_pending_email_verification_v1': true,
    });
  });

  testWidgets(
    'embedded sign-in does not navigate away from onboarding',
    (tester) async {
      // TODO: convert to integration test or add full widget harness
      // Requires full app provider environment (ThemeProvider, many app services)
      final observer = _NavObserver();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
            ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
            ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider(deferInit: true)),
            ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => const OnboardingFlowScreen(initialStepId: 'account'),
            ),
            navigatorObservers: [observer],
          ),
        ),
      );

      // Allow bootstrap to run
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Grab the state and invoke the test shim to simulate embedded sign-in success
      final state = tester.state(find.byType(OnboardingFlowScreen));

      final payload = {
        'data': {
          'user': {
            'email': 'tester@example.com',
          }
        }
      };

      // Call the test shim
      await (state as dynamic).testHandleEmbeddedSignInSuccess(payload);

      // Allow any async tasks to settle
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Ensure we did not navigate to sign-in or main (no replacement pushes)
      expect(observer.pushed, isEmpty);

      // Also ensure the OnboardingFlowScreen is still present
      expect(find.byType(OnboardingFlowScreen), findsOneWidget);
    },
    skip: true,
  );
}
