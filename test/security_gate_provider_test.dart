import 'package:art_kubus/core/app_navigator.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': 'stored-token',
      'requirePin': true,
    });
  });

  test('SecurityGateProvider coalesces concurrent auth failures', () async {
    final gate = SecurityGateProvider(promptCooldown: Duration.zero);

    final f1 = gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/test',
      ),
    );
    final f2 = gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/test',
      ),
    );

    await Future<void>.delayed(Duration.zero);
    expect(gate.isResolving, isTrue);
    gate.reset();

    final r1 = await f1;
    final r2 = await f2;
    expect(r1.outcome, AuthReauthOutcome.cancelled);
    expect(r2.outcome, AuthReauthOutcome.cancelled);
    expect(gate.isResolving, isFalse);
    expect(gate.isLocked, isFalse);
  });

  test('SecurityGateProvider does not prompt reauth on cold start wallet-only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': 'wallet-only',
      'has_wallet': true,
    });

    final gate = SecurityGateProvider(promptCooldown: Duration.zero);
    final result = await gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/profiles/me',
      ),
    );

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(gate.isResolving, isFalse);
    expect(gate.isLocked, isFalse);
  });

  test('SecurityGateProvider does not prompt reauth on first onboarding with no session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final gate = SecurityGateProvider(promptCooldown: Duration.zero);
    final result = await gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/profiles/me',
      ),
    );

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(gate.isResolving, isFalse);
    expect(gate.isLocked, isFalse);
  });

  testWidgets('SecurityGateProvider routes to sign-in when token expires with app lock off', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': 'stored-token',
      'auth_onboarding_completed': true,
      'requirePin': false,
      'biometricAuth': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        routes: {
          '/sign-in': (_) => const Scaffold(body: Text('SignIn')),
        },
        home: const Scaffold(body: Text('Home')),
      ),
    );

    final gate = SecurityGateProvider(promptCooldown: Duration.zero);
    final result = await gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/profiles/me',
      ),
    );

    await tester.pumpAndSettle();

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(find.text('SignIn'), findsOneWidget);
    expect(gate.isLocked, isFalse);
  });

  test('SecurityGateProvider locks on token expiry when app lock enabled', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': 'stored-token',
      'auth_onboarding_completed': true,
      'requirePin': true,
    });

    final gate = SecurityGateProvider(promptCooldown: Duration.zero);
    final future = gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/profiles/me',
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(gate.isLocked, isTrue);
    expect(gate.lockReason, SecurityLockReason.tokenExpired);

    gate.reset();
    await future;
  });
}
