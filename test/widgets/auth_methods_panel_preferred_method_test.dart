import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/preferred_auth_method.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:art_kubus/widgets/google_sign_in_web_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WalletProvider>(
        create: (_) => WalletProvider(deferInit: true),
      ),
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider(apiService: BackendApiService()),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'a preferred email method lands directly in the email form, no '
      'method choice shown first', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      const AuthMethodsPanel(
        embedded: true,
        preferredAuthMethod: PreferredAuthMethod.email,
      ),
    ));
    await tester.pump();

    final state = tester.state(find.byType(AuthMethodsPanel)) as dynamic;
    expect(state.debugShowCompactEmailForm, isTrue);
    // The Google/wallet choice buttons are not shown alongside the form.
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
  });

  testWidgets(
      'a preferred wallet method opens the inline wallet surface directly',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(
      const AuthMethodsPanel(
        embedded: true,
        preferredAuthMethod: PreferredAuthMethod.wallet,
      ),
    ));
    await tester.pump();

    final state = tester.state(find.byType(AuthMethodsPanel)) as dynamic;
    expect(state.debugShowInlineWalletFlow, isTrue);
  });

  testWidgets(
      'a preferred method is consumed exactly once so the caller can clear it',
      (tester) async {
    var consumedCount = 0;
    await tester.pumpWidget(_buildTestApp(
      AuthMethodsPanel(
        embedded: true,
        preferredAuthMethod: PreferredAuthMethod.email,
        onPreferredAuthMethodConsumed: () => consumedCount++,
      ),
    ));
    await tester.pump();

    expect(consumedCount, 1);
  });

  testWidgets(
      'preferred Google on web shows the focused Google continuation surface, '
      'not the generic method picker', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      const AuthMethodsPanel(
        embedded: true,
        preferredAuthMethod: PreferredAuthMethod.google,
        debugIsWebOverride: true,
      ),
    ));
    await tester.pump();

    final state = tester.state(find.byType(AuthMethodsPanel)) as dynamic;
    expect(state.debugShowPreferredGoogleContinuation, isTrue);

    // Focused Google surface is present...
    expect(find.byType(GoogleSignInWebButton), findsOneWidget);
    // ...the email and wallet alternatives are not offered alongside it...
    expect(find.text('Continue with email'), findsNothing);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
    // ...and there is an explicit way to reach the other methods.
    expect(find.text('Show other options'), findsOneWidget);
  });

  testWidgets(
      'choosing another method from the Google continuation surface reveals '
      'the normal Google/email/wallet picker', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      const AuthMethodsPanel(
        embedded: true,
        preferredAuthMethod: PreferredAuthMethod.google,
        debugIsWebOverride: true,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Show other options'));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(AuthMethodsPanel)) as dynamic;
    expect(state.debugShowPreferredGoogleContinuation, isFalse);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
  });

  testWidgets(
      'preferred Google off web does not arm the focused continuation surface',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(
      const AuthMethodsPanel(
        embedded: true,
        preferredAuthMethod: PreferredAuthMethod.google,
        debugIsWebOverride: false,
      ),
    ));
    await tester.pump();

    final state = tester.state(find.byType(AuthMethodsPanel)) as dynamic;
    expect(state.debugShowPreferredGoogleContinuation, isFalse);
  });

  testWidgets('no preferred method leaves the Google/email/wallet choice up',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(
      const AuthMethodsPanel(embedded: true),
    ));
    await tester.pump();

    final state = tester.state(find.byType(AuthMethodsPanel)) as dynamic;
    expect(state.debugShowCompactEmailForm, isFalse);
    expect(state.debugShowInlineWalletFlow, isFalse);
    expect(find.text('Continue with email'), findsOneWidget);
  });
}
