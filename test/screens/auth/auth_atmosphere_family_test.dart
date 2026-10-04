import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/auth/auth_atmosphere.dart';
import 'package:art_kubus/widgets/auth_entry_shell.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:art_kubus/widgets/common/kubus_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Account entry carries one restrained atmospheric field, and the form stays
/// readable on top of it.
///
/// The shell had drifted to a flat page colour while the rest of the family
/// still used an older animated gradient, so the five screens did not look
/// like the same place. They now share [AuthAtmosphere].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget shell({Brightness brightness = Brightness.dark}) {
    final theme = ThemeProvider();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme:
            brightness == Brightness.dark ? theme.darkTheme : theme.lightTheme,
        home: AuthEntryShell(
          title: 'Sign in',
          subtitle: 'Continue to art.kubus',
          heroIcon: Icons.lock_outline,
          form: const KubusTextField(label: 'Email'),
        ),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('the shell carries the shared field in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(shell(brightness: brightness));
      await tester.pump();

      // The field is present...
      expect(find.byType(AuthAtmosphere), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AuthAtmosphere),
          matching: find.byKey(const ValueKey<String>('kubus_atmosphere')),
        ),
        findsOneWidget,
      );

      // ...and it is the restrained kind: full bleed, so no card edge or rule
      // frames the page, and no cropped glyph sits behind the credentials.
      final atmosphere = tester.widget<KubusAtmosphere>(
        find.byType(KubusAtmosphere),
      );
      expect(atmosphere.framed, isFalse);
      expect(atmosphere.glyph, isNull);
      expect(atmosphere.padding, EdgeInsets.zero);

      // The form is still there and readable on the plain ground beneath.
      expect(find.byType(KubusTextField), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });
  }

  testWidgets('the field never swallows the title or subtitle', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(shell());
    await tester.pump();

    // The shell's own title and subtitle still read on top of the field; the
    // atmosphere adds no second headline or symbol of its own.
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Continue to art.kubus'), findsOneWidget);
  });
}
