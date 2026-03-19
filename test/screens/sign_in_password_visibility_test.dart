import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _buildApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const Scaffold(body: SignInScreen()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login form shows password visibility toggle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp());
    await tester.pump(const Duration(milliseconds: 700));

    final openEmailForm = find.text('Sign in with email');
    if (openEmailForm.evaluate().isNotEmpty) {
      await tester.tap(openEmailForm.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
