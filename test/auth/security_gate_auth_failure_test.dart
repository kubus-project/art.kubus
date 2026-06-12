import 'dart:convert';

import 'package:art_kubus/core/app_navigator.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for the "Google/email signup ejects to /sign-in" bug:
/// SecurityGateProvider.handleAuthFailure used to wipe the navigator stack to
/// /sign-in on ANY 401/403 whenever the user had a local account but no app
/// lock — including seconds after a successful Google registration with a
/// perfectly valid session, and mid-onboarding wallet linking.
String _jwt({DateTime? expiry}) {
  final payload = <String, Object>{
    'sub': 'user-gate-test',
    if (expiry != null) 'exp': expiry.millisecondsSinceEpoch ~/ 1000,
  };
  final encoded = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return 'e30.$encoded.';
}

AuthFailureContext _failure(String path) {
  return AuthFailureContext(
    statusCode: 401,
    method: 'GET',
    path: path,
    body: '{"error":"Unauthorized"}',
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  String homeRouteName = '/main',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: appNavigatorKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
      ),
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute(
          settings: RouteSettings(name: homeRouteName),
          builder: (_) => Scaffold(body: Text('route:$homeRouteName')),
        ),
      ],
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
  });

  testWidgets(
      'valid fresh session + random 401 never redirects to /sign-in '
      '(post-Google-signup ejection regression)', (tester) async {
    final validToken = _jwt(
      expiry: DateTime.now().add(const Duration(hours: 1)),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': validToken,
      'user_id': 'user-gate-test',
    });
    BackendApiService().setAuthTokenForTesting(validToken);

    await _pumpHost(tester);
    final gate = SecurityGateProvider();

    final result = await gate.handleAuthFailure(
      _failure('/api/saved/items'),
    );
    await tester.pumpAndSettle();

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(find.text('route:/sign-in'), findsNothing);
    expect(find.text('route:/main'), findsOneWidget);
    expect(gate.isLocked, isFalse);
  });

  testWidgets(
      'active account-link guard suppresses the sign-in redirect even '
      'without a valid token', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _jwt(
        expiry: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      'user_id': 'user-gate-test',
    });
    await OnboardingStateService.markAccountLinkStarted(
      userId: 'user-gate-test',
    );

    await _pumpHost(tester, homeRouteName: '/onboarding');
    final gate = SecurityGateProvider();

    final result = await gate.handleAuthFailure(
      _failure('/api/auth/bind-wallet'),
    );
    await tester.pumpAndSettle();

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(find.text('route:/sign-in'), findsNothing);
    expect(find.text('route:/onboarding'), findsOneWidget);
  });

  testWidgets('401 from /api/auth/google is left to the auth screen',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _jwt(
        expiry: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    });

    await _pumpHost(tester);
    final gate = SecurityGateProvider();

    final result = await gate.handleAuthFailure(
      _failure('/api/auth/google'),
    );
    await tester.pumpAndSettle();

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(find.text('route:/sign-in'), findsNothing);
  });

  testWidgets(
      'truly expired session without app lock still forces /sign-in from '
      'a normal shell route', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _jwt(
        expiry: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      'user_id': 'user-gate-test',
    });

    await _pumpHost(tester);
    final gate = SecurityGateProvider();

    final result = await gate.handleAuthFailure(
      _failure('/api/saved/items'),
    );
    await tester.pumpAndSettle();

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(find.text('route:/sign-in'), findsOneWidget);
  });

  testWidgets(
      'truly expired session does not hijack the onboarding route',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _jwt(
        expiry: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      'user_id': 'user-gate-test',
    });

    await _pumpHost(tester, homeRouteName: '/onboarding');
    final gate = SecurityGateProvider();

    final result = await gate.handleAuthFailure(
      _failure('/api/saved/items'),
    );
    await tester.pumpAndSettle();

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(find.text('route:/sign-in'), findsNothing);
    expect(find.text('route:/onboarding'), findsOneWidget);
  });
}
