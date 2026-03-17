import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHarness({
  required Widget child,
  required double width,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'sign-in wallet menu shows the three wallet entry options on mobile',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: const SignInScreen(embedded: true),
        width: 500,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect wallet').first);
    await tester.pumpAndSettle();

    expect(find.text('WalletConnect'), findsOneWidget);
    expect(find.text('Create a new wallet'), findsOneWidget);
    expect(find.text('Link existing wallet'), findsOneWidget);
    expect(find.text('Advanced'), findsNWidgets(2));
  });

  testWidgets(
      'registration wallet menu shows the same wallet entry options on desktop',
      (tester) async {
    await tester.pumpWidget(
      _buildHarness(
        child: const AuthMethodsPanel(embedded: true),
        width: 1100,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect wallet').first);
    await tester.pumpAndSettle();

    expect(find.text('WalletConnect'), findsOneWidget);
    expect(find.text('Create a new wallet'), findsOneWidget);
    expect(find.text('Link existing wallet'), findsOneWidget);
    expect(find.text('Advanced'), findsNWidgets(2));
  });
}
