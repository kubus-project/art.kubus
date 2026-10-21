import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/reset_password_screen.dart';
import 'package:art_kubus/screens/web3/wallet/qr_scanner_screen.dart';
import 'package:art_kubus/widgets/email_registration_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
  await tester.pump();
}

EmailRegistrationForm _registrationForm() {
  return EmailRegistrationForm(
    emailController: TextEditingController(),
    passwordController: TextEditingController(),
    confirmPasswordController: TextEditingController(),
    submitLabel: 'Submit',
    submittingLabel: 'Submitting',
    showUsername: false,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('password visibility toggles', () {
    testWidgets('registration form toggles tooltip with state (EN)',
        (tester) async {
      await _pumpLocalized(tester, Scaffold(body: _registrationForm()));

      // Both fields start obscured, so both toggles offer "Show password".
      expect(find.byTooltip('Show password'), findsNWidgets(2));
      expect(find.byTooltip('Hide password'), findsNothing);

      await tester.tap(find.byTooltip('Show password').first);
      await tester.pump();

      expect(find.byTooltip('Show password'), findsOneWidget);
      expect(find.byTooltip('Hide password'), findsOneWidget);

      // Re-obscure the revealed field through its "Hide password" tooltip.
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();

      expect(find.byTooltip('Show password'), findsNWidgets(2));
      expect(find.byTooltip('Hide password'), findsNothing);
    });

    testWidgets('registration form uses Slovenian tooltips (SL)',
        (tester) async {
      await _pumpLocalized(
        tester,
        Scaffold(body: _registrationForm()),
        locale: const Locale('sl'),
      );

      expect(find.byTooltip('Pokaži geslo'), findsNWidgets(2));
      expect(find.byTooltip('Skrij geslo'), findsNothing);
    });

    testWidgets('reset password screen toggles tooltip with state (EN)',
        (tester) async {
      await _pumpLocalized(
        tester,
        const ResetPasswordScreen(token: 'test-token'),
      );

      expect(find.byTooltip('Show password'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Show password').first);
      await tester.pump();

      expect(find.byTooltip('Hide password'), findsOneWidget);
      expect(find.byTooltip('Show password'), findsOneWidget);
    });
  });

  group('QR scanner app bar controls', () {
    testWidgets('close, torch and switch camera expose tooltips (EN)',
        (tester) async {
      await _pumpLocalized(tester, const QRScannerScreen());

      expect(find.byTooltip('Close'), findsOneWidget);
      // Torch starts off, so the control offers to turn it on.
      expect(find.byTooltip('Turn on flashlight'), findsOneWidget);
      expect(find.byTooltip('Turn off flashlight'), findsNothing);
      expect(find.byTooltip('Switch camera'), findsOneWidget);
    });
  });
}
