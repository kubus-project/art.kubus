import 'dart:convert';

import 'package:art_kubus/core/app_navigator.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A signed-in account whose access token has expired: the credential sits in
/// the platform store, the preferences only carry the non-secret account hints.
String _expiredJwt() {
  final exp = DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url
      .encode(
          utf8.encode(jsonEncode(<String, Object>{'sub': 'u1', 'exp': exp})))
      .replaceAll('=', '');
  return 'e30.$payload.';
}

void _seedExpiredSession(Map<String, Object> prefs) {
  FlutterSecureStorage.setMockInitialValues(
      <String, String>{'jwt_token': _expiredJwt()});
  BackendApiService().resetCredentialStoreForTesting();
  SharedPreferences.setMockInitialValues(<String, Object>{
    'user_id': 'user-1',
    'auth_onboarding_completed': true,
    ...prefs,
  });
}

/// The gate restores credentials and reads preferences before it decides, so
/// the lock is not open after a single event-loop turn.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Credentials are restored from the platform store, never from preferences;
    // without the mock the restore waits on a missing plugin channel.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    BackendApiService().resetCredentialStoreForTesting();
    BackendApiService().setAuthTokenForTesting(null);
    _seedExpiredSession(<String, Object>{'requirePin': true});
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

    await _until(() => gate.isResolving);
    expect(gate.isResolving, isTrue);
    // Clearing the HTTP session never opens a token-expired lock.
    gate.reset();
    expect(gate.isResolving, isTrue);
    gate.completeForTesting(localAuthentication: true);

    final r1 = await f1;
    final r2 = await f2;
    expect(r1.outcome, AuthReauthOutcome.success);
    expect(r2.outcome, AuthReauthOutcome.success);
    expect(gate.isResolving, isFalse);
    expect(gate.isLocked, isFalse);
  });

  test('SecurityGateProvider does not prompt reauth on cold start wallet-only',
      () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    BackendApiService().resetCredentialStoreForTesting();
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

  test(
      'SecurityGateProvider does not prompt reauth on first onboarding with no session',
      () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    BackendApiService().resetCredentialStoreForTesting();
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

  testWidgets(
      'SecurityGateProvider routes to sign-in when token expires with app lock off',
      (tester) async {
    _seedExpiredSession(<String, Object>{
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

  test('SecurityGateProvider locks on token expiry when app lock enabled',
      () async {
    _seedExpiredSession(<String, Object>{'requirePin': true});

    final gate = SecurityGateProvider(promptCooldown: Duration.zero);
    final future = gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/profiles/me',
      ),
    );

    await _until(() => gate.isLocked);

    expect(gate.isLocked, isTrue);
    expect(gate.lockReason, SecurityLockReason.tokenExpired);

    gate.reset();
    expect(gate.isLocked, isTrue);
    gate.completeForTesting(localAuthentication: true);
    await future;
  });
}
