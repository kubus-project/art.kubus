import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/auth_methods_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
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

    await tester.pumpWidget(
      _buildTestApp(
        AuthMethodsPanel(
          embedded: true,
          onVerificationRequired: (_) => verificationTriggered = true,
        ),
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
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('An account with this email already exists. Sign in instead.'),
      findsOneWidget,
    );
    expect(verificationTriggered, isFalse);
    expect(find.textContaining('Working'), findsNothing);
  });
}
