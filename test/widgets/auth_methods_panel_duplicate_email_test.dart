import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Future<WalletProvider> _createSignerBackedWalletProvider() async {
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  final solana = SolanaWalletService();
  final derived = await solana.derivePreferredKeyPair(mnemonic);
  solana.setActiveKeyPair(derived.hdKeyPair);
  return WalletProvider(solanaWalletService: solana, deferInit: true)
    ..setCurrentWalletAddressForTesting(derived.address);
}

Widget _buildTestApp(
  Widget child, {
  required WalletProvider walletProvider,
  ProfileProvider? profileProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<ProfileProvider>.value(
        value:
            profileProvider ?? ProfileProvider(apiService: BackendApiService()),
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

void _installBackendMock(
  Future<http.Response> Function(http.Request request) handler,
) {
  BackendApiService().setHttpClient(MockClient(handler));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/register/email') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'error': 'User already exists. Please login instead.',
          }),
          409,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
  });

  tearDown(() {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.setHttpClient(
      MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'success': false}),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
  });

  testWidgets(
      'duplicate email registration shows error, stays on form, and clears loading',
      (tester) async {
    var verificationTriggered = false;
    final walletProvider = await _createSignerBackedWalletProvider();

    await tester.pumpWidget(
      _buildTestApp(
        AuthMethodsPanel(
          embedded: true,
          onVerificationRequired: (_) => verificationTriggered = true,
        ),
        walletProvider: walletProvider,
      ),
    );
    await tester.pumpAndSettle();

    final expandEmail = find.text('Continue with email');
    if (expandEmail.evaluate().isNotEmpty) {
      await tester.tap(expandEmail.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'duplicate@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'Pass1234A',
    );

    final submitLabel = find.text('Continue with email');
    expect(submitLabel, findsWidgets);
    await tester.tap(submitLabel.last);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(
      find.text('An account with this email already exists. Sign in instead.'),
      findsOneWidget,
    );
    expect(verificationTriggered, isFalse);
    expect(find.textContaining('Working'), findsNothing);
  });

  testWidgets(
      'embedded email registration shows username field when required for onboarding',
      (tester) async {
    final walletProvider = await _createSignerBackedWalletProvider();
    await tester.pumpWidget(
      _buildTestApp(
        const AuthMethodsPanel(
          embedded: true,
          requireUsernameForEmailRegistration: true,
        ),
        walletProvider: walletProvider,
      ),
    );
    await tester.pumpAndSettle();

    final expandEmail = find.text('Continue with email');
    if (expandEmail.evaluate().isNotEmpty) {
      await tester.tap(expandEmail.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.widgetWithText(TextField, 'Enter username'), findsOneWidget);
  });

  testWidgets(
      'embedded email registration blocks submit when required username is missing',
      (tester) async {
    var verificationTriggered = false;
    final walletProvider = await _createSignerBackedWalletProvider();

    await tester.pumpWidget(
      _buildTestApp(
        AuthMethodsPanel(
          embedded: true,
          requireUsernameForEmailRegistration: true,
          onVerificationRequired: (_) => verificationTriggered = true,
        ),
        walletProvider: walletProvider,
      ),
    );
    await tester.pumpAndSettle();

    final expandEmail = find.text('Continue with email');
    if (expandEmail.evaluate().isNotEmpty) {
      await tester.tap(expandEmail.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'required-username@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'Pass1234A',
    );

    final submit = find.text('Continue with email');
    await tester.tap(submit.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Username is required'), findsOneWidget);
    expect(verificationTriggered, isFalse);
    expect(find.textContaining('Working'), findsNothing);
  });

  testWidgets(
      'embedded email registration blocks submit when username is too short',
      (tester) async {
    final walletProvider = await _createSignerBackedWalletProvider();
    await tester.pumpWidget(
      _buildTestApp(
        const AuthMethodsPanel(
          embedded: true,
          requireUsernameForEmailRegistration: true,
        ),
        walletProvider: walletProvider,
      ),
    );
    await tester.pumpAndSettle();

    final expandEmail = find.text('Continue with email');
    if (expandEmail.evaluate().isNotEmpty) {
      await tester.tap(expandEmail.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'short-username@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter username'),
      'ab',
    );

    await tester.tap(find.text('Continue with email').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Username must be at least 3 characters'), findsOneWidget);
  });

  testWidgets(
      'embedded email registration blocks submit when username is too long',
      (tester) async {
    final walletProvider = await _createSignerBackedWalletProvider();
    await tester.pumpWidget(
      _buildTestApp(
        const AuthMethodsPanel(
          embedded: true,
          requireUsernameForEmailRegistration: true,
        ),
        walletProvider: walletProvider,
      ),
    );
    await tester.pumpAndSettle();

    final expandEmail = find.text('Continue with email');
    if (expandEmail.evaluate().isNotEmpty) {
      await tester.tap(expandEmail.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'long-username@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter username'),
      List<String>.filled(51, 'a').join(),
    );

    await tester.tap(find.text('Continue with email').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
        find.text('Username must be 50 characters or fewer'), findsOneWidget);
  });

  testWidgets('duplicate username shows explicit username taken message',
      (tester) async {
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/register/email') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'error': 'Username already taken.',
            'errorCode': 'USERNAME_ALREADY_TAKEN',
          }),
          409,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final walletProvider = await _createSignerBackedWalletProvider();
    await tester.pumpWidget(
      _buildTestApp(
        const AuthMethodsPanel(
          embedded: true,
          requireUsernameForEmailRegistration: true,
        ),
        walletProvider: walletProvider,
      ),
    );
    await tester.pumpAndSettle();

    final expandEmail = find.text('Continue with email');
    if (expandEmail.evaluate().isNotEmpty) {
      await tester.tap(expandEmail.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'duplicate-username@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter username'),
      'taken_name',
    );

    final submit = find.text('Continue with email');
    await tester.tap(submit.last);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Username already taken'), findsWidgets);
  });

  testWidgets('register form exposes show-password icons', (tester) async {
    final walletProvider = await _createSignerBackedWalletProvider();
    await tester.pumpWidget(
      _buildTestApp(
        const AuthMethodsPanel(
          embedded: true,
          requireUsernameForEmailRegistration: true,
        ),
        walletProvider: walletProvider,
      ),
    );
    await tester.pumpAndSettle();

    final expandEmail = find.text('Continue with email');
    if (expandEmail.evaluate().isNotEmpty) {
      await tester.tap(expandEmail.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byIcon(Icons.visibility_outlined), findsAtLeast(2));
  });

  testWidgets('standalone register surfaces duplicate username message',
      (tester) async {
    _installBackendMock((request) async {
      if (request.url.path == '/api/auth/register/email') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': false,
            'error': 'Username already taken.',
            'errorCode': 'USERNAME_ALREADY_TAKEN',
          }),
          409,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final walletProvider = await _createSignerBackedWalletProvider();
    await tester.pumpWidget(
      _buildTestApp(
        const AuthMethodsPanel(),
        walletProvider: walletProvider,
      ),
    );
    await tester.pumpAndSettle();

    final expandEmail = find.text('Continue with email');
    if (expandEmail.evaluate().isNotEmpty) {
      await tester.tap(expandEmail.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'standalone-duplicate@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'Pass1234A',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Username (optional)'),
      'taken_name',
    );

    await tester.tap(find.text('Continue with email').last);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Username already taken'), findsWidgets);
  });
}
