import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthCoordinator implements AuthSessionCoordinator {
  int failures = 0;

  @override
  bool get isResolving => false;

  @override
  Future<AuthReauthResult> handleAuthFailure(AuthFailureContext context) async {
    failures += 1;
    return const AuthReauthResult(AuthReauthOutcome.success);
  }

  @override
  Future<AuthReauthResult?> waitForResolution() async => null;

  @override
  void reset() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('getProfileByWallet does not auto-issue auth for viewed wallet',
      () async {
    const testWallet = '4Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTU';
    final requests = <http.Request>[];

    final api = BackendApiService();
    api.setHttpClient(MockClient((request) async {
      requests.add(request);

      // Return a minimal successful profile payload.
      return http.Response(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'walletAddress': testWallet,
            'username': 'someone',
            'displayName': 'Someone Else',
          },
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await api.getProfileByWallet(testWallet);

    // The critical behavior: viewing a profile must not trigger auth issuance
    // (no POSTs to register/issue-token, no extra calls beyond the profile fetch).
    expect(requests, isNotEmpty);
    expect(requests.every((r) => r.method.toUpperCase() == 'GET'), isTrue);
    expect(
      requests.every((r) => r.url.path.contains('/api/profiles/')),
      isTrue,
      reason: 'Expected only profile fetch requests when viewing a profile.',
    );
  });

  test('403 Forbidden does not trigger re-auth prompt (authz != auth failure)',
      () async {
    const otherWallet = '6Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTV';

    final coordinator = _TestAuthCoordinator();
    final api = BackendApiService();
    api.bindAuthCoordinator(coordinator);
    api.setHttpClient(MockClient((request) async {
      expect(request.url.path, contains('/api/achievements/user/'));
      return http.Response(
        jsonEncode(<String, Object?>{
          'success': false,
          'error': 'Forbidden',
        }),
        403,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    // This endpoint is self-only on the backend; when called with another wallet it returns 403.
    // The critical behavior: a 403 should NOT be treated as token-expiry and must not trigger reauth.
    await api.getUserAchievements(otherWallet);
    expect(coordinator.failures, 0);
  });

  test('401 Unauthorized triggers re-auth flow exactly once and retries',
      () async {
    const wallet = '4Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTU';

    final coordinator = _TestAuthCoordinator();
    final api = BackendApiService();
    api.bindAuthCoordinator(coordinator);

    var callCount = 0;
    api.setHttpClient(MockClient((request) async {
      callCount += 1;
      if (callCount == 1) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'Authentication required',
          }),
          401,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, Object?>{
          'success': true,
          'unlocked': <Object?>[],
          'progress': <Object?>[],
          'totalTokens': 0,
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await api.getUserAchievements(wallet);
    expect(coordinator.failures, 1);
    expect(callCount, 2,
        reason: 'Expected a single retry after auth failure coordination.');
  });
}
