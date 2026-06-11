import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/auth_wallet_result_normalizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwtWithWallet(String walletAddress, {String? marker}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'walletAddress': walletAddress,
            'sub': marker ?? 'test-user',
          }),
        ),
      )
      .replaceAll('=', '');
  return 'e30.$payload.';
}

String? _wallet(NormalizedWalletAuthResult result) {
  final data = result.payload?['data'] as Map<String, dynamic>?;
  final user = data?['user'] as Map<String, dynamic>?;
  return user?['walletAddress'] as String?;
}

MockClient _profileMeClient({
  String walletAddress = 'profile-wallet',
  String userId = 'profile-user',
}) {
  return MockClient((request) async {
    if (request.url.path == '/api/profiles/me') {
      return http.Response(
        jsonEncode(<String, Object?>{
          'success': true,
          'data': <String, Object?>{
            'id': 'profile-1',
            'userId': userId,
            'walletAddress': walletAddress,
          },
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }
    return http.Response('Not found', 404);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.setHttpClient(MockClient((_) async => http.Response('Not found', 404)));
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
  });

  group('token-bearing results succeed', () {
    test("{'token': ...} succeeds and persists the token", () async {
      final token = _jwtWithWallet('abc');
      final result = await normalizeWalletAuthResult(
        routeResult: <String, dynamic>{
          'token': token,
          'data': <String, dynamic>{
            'user': <String, dynamic>{'id': 'u1', 'walletAddress': 'abc'},
          },
        },
        api: api,
      );

      expect(result.isSuccess, isTrue);
      expect(_wallet(result), 'abc');
      expect(api.getAuthToken(), token);
    });

    test("{'data': {'token': ...}} succeeds", () async {
      final token = _jwtWithWallet('abc');
      final result = await normalizeWalletAuthResult(
        routeResult: <String, dynamic>{
          'data': <String, dynamic>{
            'token': token,
            'user': <String, dynamic>{'id': 'u1', 'walletAddress': 'abc'},
          },
        },
        api: api,
      );

      expect(result.isSuccess, isTrue);
      expect(_wallet(result), 'abc');
      expect(api.getAuthToken(), token);
    });

    test("{'accessToken': ...} succeeds", () async {
      final result = await normalizeWalletAuthResult(
        routeResult: <String, dynamic>{'accessToken': _jwtWithWallet('abc')},
        api: api,
      );

      expect(result.isSuccess, isTrue);
    });

    test("{'authToken': ...} succeeds", () async {
      final result = await normalizeWalletAuthResult(
        routeResult: <String, dynamic>{'authToken': _jwtWithWallet('abc')},
        api: api,
      );

      expect(result.isSuccess, isTrue);
    });

    test("{'auth': {'token': ...}} succeeds", () async {
      final result = await normalizeWalletAuthResult(
        routeResult: <String, dynamic>{
          'auth': <String, dynamic>{'token': _jwtWithWallet('abc')},
        },
        api: api,
      );

      expect(result.isSuccess, isTrue);
    });

    test("{'session': {'token': ...}} succeeds", () async {
      final result = await normalizeWalletAuthResult(
        routeResult: <String, dynamic>{
          'session': <String, dynamic>{'token': _jwtWithWallet('abc')},
        },
        api: api,
      );

      expect(result.isSuccess, isTrue);
    });
  });

  group('wallet-only results fail without a backend token', () {
    test('data.user with wallet but no token fails', () async {
      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{
          'data': <String, dynamic>{
            'user': <String, dynamic>{'id': 'u1', 'walletAddress': 'abc'},
          },
        },
        api: api,
      );

      expect(result.isFailure, isTrue);
    });

    test("{'walletAddress': 'abc'} fails", () async {
      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{'walletAddress': 'abc'},
        api: api,
      );

      expect(result.isFailure, isTrue);
    });

    test("{'address': 'abc'} fails", () async {
      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{'address': 'abc'},
        api: api,
      );

      expect(result.isFailure, isTrue);
    });

    test('fallbackWalletAddress alone is never success', () async {
      final result = await normalizeWalletAuthResult(
        routeResult: null,
        api: api,
        fallbackWalletAddress: 'fallback-wallet',
      );

      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
    });

    test('profile-only result without token fails', () async {
      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{
          'profile': <String, dynamic>{'id': 'p1'},
        },
        api: api,
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('wallet result without payload token but with persisted api token', () {
    test('succeeds when /api/profiles/me confirms the session', () async {
      api.setAuthTokenForTesting(_jwtWithWallet('token-wallet'));
      api.setHttpClient(_profileMeClient(walletAddress: 'profile-wallet'));

      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{
          'data': <String, dynamic>{
            'user': <String, dynamic>{'id': 'u1', 'walletAddress': 'abc'},
          },
        },
        api: api,
      );

      expect(result.isSuccess, isTrue);
      expect(_wallet(result), 'abc');
    });

    test('fails when /api/profiles/me rejects the session', () async {
      api.setAuthTokenForTesting(_jwtWithWallet('token-wallet'));
      api.setHttpClient(
        MockClient((_) async => http.Response('Unauthorized', 401)),
      );

      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{
          'data': <String, dynamic>{
            'user': <String, dynamic>{'id': 'u1', 'walletAddress': 'abc'},
          },
        },
        api: api,
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('explicit failures', () {
    test("{'success': false, 'error': 'bad'} returns failure", () async {
      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{
          'success': false,
          'error': 'bad',
        },
        api: api,
      );

      expect(result.isFailure, isTrue);
      expect(result.reason, 'bad');
    });

    test("{'success': true} without token returns failure", () async {
      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{'success': true},
        api: api,
      );

      expect(result.isFailure, isTrue);
    });

    test('non-map route result returns failure', () async {
      final result = await normalizeWalletAuthResult(
        routeResult: 'unexpected',
        api: api,
      );

      expect(result.isFailure, isTrue);
    });

    test('failure reason does not include secret values', () async {
      const secretValue = 'secret-token-value';
      final result = await normalizeWalletAuthResult(
        routeResult: const <String, dynamic>{
          'success': true,
          'unexpected': secretValue,
        },
        api: api,
      );

      expect(result.isFailure, isTrue);
      expect(result.reason, isNot(contains(secretValue)));
    });
  });

  group('null route result (flow closed without payload)', () {
    test('with fresh token and /me success returns success', () async {
      api.setAuthTokenForTesting(_jwtWithWallet('token-wallet'));
      api.setHttpClient(_profileMeClient(walletAddress: 'profile-wallet'));

      final result = await normalizeWalletAuthResult(
        routeResult: null,
        api: api,
      );

      expect(result.isSuccess, isTrue);
      expect(_wallet(result), 'profile-wallet');
    });

    test('with fresh token but failing /me returns failure', () async {
      api.setAuthTokenForTesting(_jwtWithWallet('token-wallet'));
      api.setHttpClient(
        MockClient((_) async => http.Response('server error', 500)),
      );

      final result = await normalizeWalletAuthResult(
        routeResult: null,
        api: api,
      );

      expect(result.isFailure, isTrue);
    });

    test('with pre-existing auth token returns cancelled', () async {
      api.setAuthTokenForTesting(_jwtWithWallet('token-wallet'));
      api.setHttpClient(_profileMeClient());

      final result = await normalizeWalletAuthResult(
        routeResult: null,
        api: api,
        hadAuthBeforeOpen: true,
      );

      expect(result.isCancelled, isTrue);
    });

    test('with no token, wallet, or fallback returns cancelled', () async {
      final result = await normalizeWalletAuthResult(
        routeResult: null,
        api: api,
      );

      expect(result.isCancelled, isTrue);
    });
  });

  test('debug output does not include token values', () async {
    const secretToken = 'secret-token-value';
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      messages.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = previousDebugPrint;
    });

    api.setAuthTokenForTesting(secretToken);
    await normalizeWalletAuthResult(
      routeResult: null,
      api: api,
      fallbackWalletAddress: 'fallback-wallet',
    );

    expect(messages.join('\n'), isNot(contains(secretToken)));
  });
}
