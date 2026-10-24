import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _buildApp(Locale locale) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const MediaQuery(
        data: MediaQueryData(size: Size(390, 844)),
        child: Scaffold(body: SignInScreen()),
      ),
    ),
  );
}

/// Semantics of the single node whose label is exactly [label].
SemanticsData _semanticsNamed(WidgetTester tester, String label) {
  final finder = find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}\$'));
  expect(finder, findsOneWidget, reason: 'no semantics node named "$label"');
  return tester.getSemantics(finder).getSemanticsData();
}

void _runEmailFormSemanticsTests(Locale locale) {
  final l10n = lookupAppLocalizations(locale);

  Future<void> openEmailForm(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildApp(locale));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text(l10n.authContinueWithEmail).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('[${locale.languageCode}] email field is a labelled text field',
      (tester) async {
    final handle = tester.ensureSemantics();
    await openEmailForm(tester);

    final field = _semanticsNamed(tester, l10n.commonEmail);
    expect(field.flagsCollection.isTextField, isTrue);
    expect(field.flagsCollection.isObscured, isFalse);
    handle.dispose();
  });

  testWidgets(
      '[${locale.languageCode}] password field is a labelled, obscured text field',
      (tester) async {
    final handle = tester.ensureSemantics();
    await openEmailForm(tester);

    final field = _semanticsNamed(tester, l10n.commonPassword);
    expect(field.flagsCollection.isTextField, isTrue);
    expect(field.flagsCollection.isObscured, isTrue);
    handle.dispose();
  });

  testWidgets(
      '[${locale.languageCode}] password visibility toggle is named and reflects state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await openEmailForm(tester);

    // Hidden by default: the toggle offers to show the password.
    final show = _semanticsNamed(tester, l10n.formShowPassword);
    expect(show.flagsCollection.isButton, isTrue);
    expect(find.bySemanticsLabel(l10n.formHidePassword), findsNothing);

    await tester.tap(find.byTooltip(l10n.formShowPassword));
    await tester.pump();

    // Visible now: the same control offers to hide it, and the field is not
    // obscured any more.
    final hide = _semanticsNamed(tester, l10n.formHidePassword);
    expect(hide.flagsCollection.isButton, isTrue);
    expect(find.bySemanticsLabel(l10n.formShowPassword), findsNothing);
    final password = _semanticsNamed(tester, l10n.commonPassword);
    expect(password.flagsCollection.isObscured, isFalse);
    handle.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sign-in email form semantics (en)', () {
    _runEmailFormSemanticsTests(const Locale('en'));
  });

  group('sign-in email form semantics (sl)', () {
    _runEmailFormSemanticsTests(const Locale('sl'));
  });
}
