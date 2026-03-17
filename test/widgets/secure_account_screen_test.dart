import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/auth/secure_account_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHarness({
  required WalletProvider walletProvider,
  required ProfileProvider profileProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SecureAccountScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  testWidgets(
      'secure account resend shows backend info message in success state',
      (tester) async {
    final walletProvider = WalletProvider(deferInit: true)
      ..setCurrentWalletAddressForTesting('wallet1');
    final profileProvider = ProfileProvider();
    final api = BackendApiService();
    api.setAuthTokenForTesting('cached-token');

    var registerRequests = 0;
    var resendRequests = 0;
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/auth/account-security-status') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'hasEmail': false,
                'hasPassword': false,
                'emailVerified': false,
                'emailAuthEnabled': true,
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/register/email') {
          registerRequests += 1;
          expect(request.headers['Authorization'], 'Bearer cached-token');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'emailVerificationSent': true,
                'user': <String, dynamic>{
                  'email': 'wallet@example.com',
                  'emailVerified': false,
                },
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/auth/resend-verification') {
          resendRequests += 1;
          expect(request.headers['Authorization'], 'Bearer cached-token');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'Email is already verified.',
              'data': <String, dynamic>{
                'emailVerificationSent': false,
                'requiresEmailVerification': false,
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      }),
    );

    await tester.pumpWidget(
      _buildHarness(
        walletProvider: walletProvider,
        profileProvider: profileProvider,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'wallet@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Password123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'Password123',
    );

    await tester.tap(find.text('Secure account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(registerRequests, 1);
    expect(find.text('Verification email sent'), findsOneWidget);

    await tester.tap(find.text('Resend verification email'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(resendRequests, 1);
    expect(
      find.text('Could not resend verification email. Please try again.'),
      findsNothing,
    );
  });

  testWidgets(
      'secure account uses password-only mode when email already exists',
      (tester) async {
    final walletProvider = WalletProvider(deferInit: true)
      ..setCurrentWalletAddressForTesting('wallet1');
    final profileProvider = ProfileProvider();
    final api = BackendApiService();
    api.setAuthTokenForTesting('cached-token');

    var addPasswordRequests = 0;
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/auth/account-security-status') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'hasEmail': true,
                'hasPassword': false,
                'email': 'google@example.com',
                'emailVerified': true,
                'emailAuthEnabled': true,
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/account-security/password') {
          addPasswordRequests += 1;
          expect(request.headers['Authorization'], 'Bearer cached-token');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'user': <String, dynamic>{
                  'email': 'google@example.com',
                  'emailVerified': true,
                },
                'securityStatus': <String, dynamic>{
                  'hasEmail': true,
                  'hasPassword': true,
                  'email': 'google@example.com',
                  'emailVerified': true,
                  'emailAuthEnabled': true,
                },
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }),
    );

    await tester.pumpWidget(
      _buildHarness(
        walletProvider: walletProvider,
        profileProvider: profileProvider,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add a password'), findsOneWidget);
    expect(find.text('google@example.com'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'Password123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'Password123',
    );

    await tester.tap(find.text('Add password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(addPasswordRequests, 1);
    expect(find.text('Account secured'), findsOneWidget);
  });
}
