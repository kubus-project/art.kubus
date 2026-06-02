import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/widgets/google_sign_in_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(390, 844),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WalletProvider>(
        create: (_) => WalletProvider(deferInit: true),
      ),
      ChangeNotifierProvider<CacheProvider>(create: (_) => CacheProvider()),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<SavedItemsProvider>(
        create: (_) => SavedItemsProvider(),
      ),
      ChangeNotifierProvider<SecurityGateProvider>(
        create: (_) => SecurityGateProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    ),
  );
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async => tester.binding.setSurfaceSize(null));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Google and email methods are visible immediately',
      (tester) async {
    await _setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      _buildApp(child: const SignInScreen(embedded: true)),
    );
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Use wallet instead'), findsOneWidget);
    expect(find.text('Show other options'), findsNothing);
  });

  testWidgets('Google loading state disables interaction and shows progress',
      (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      _buildApp(
        child: GoogleSignInButton(
          onPressed: () async {
            pressed = true;
          },
          isLoading: true,
          colorScheme: ThemeData.light().colorScheme,
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data ?? '').startsWith('Connecting'),
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();
    expect(pressed, isFalse);
  });

  testWidgets('email method opens compact form and focuses email field',
      (tester) async {
    await _setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      _buildApp(child: const SignInScreen(embedded: true)),
    );
    await tester.tap(find.text('Continue with email'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Email'), findsOneWidget);
    final emailField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Email'),
    );
    expect(emailField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('wallet method opens inline wallet flow', (tester) async {
    await _setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      _buildApp(child: const SignInScreen(embedded: true)),
    );
    await tester.tap(find.text('Use wallet instead'));
    await tester.pump();

    expect(find.byType(ConnectWallet), findsOneWidget);
  });

  testWidgets('narrow mobile layout does not overflow', (tester) async {
    await _setSurfaceSize(tester, const Size(320, 640));

    await tester.pumpWidget(
      _buildApp(
        child: const SignInScreen(embedded: true),
        size: const Size(320, 640),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('auth methods render in dark and light themes', (tester) async {
    for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        _buildApp(
          child: const SignInScreen(embedded: true),
          themeMode: themeMode,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
      expect(find.text('Use wallet instead'), findsOneWidget);
    }
  });
}
