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

  test('typed Map with data.user returns success', () async {
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

  test('untyped Map with data.user returns success', () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <Object, Object>{
        'data': <Object, Object>{
          'user': <Object, Object>{'id': 'u1', 'walletAddress': 'abc'},
        },
      },
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'abc');
  });

  test("{'user': {...}} normalizes to data.user", () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'user': <String, dynamic>{'id': 'u1', 'walletAddress': 'abc'},
      },
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect((result.payload!['data'] as Map)['user'], isA<Map>());
    expect(_wallet(result), 'abc');
  });

  test("{'walletAddress': 'abc'} normalizes to data.user.walletAddress",
      () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{'walletAddress': 'abc'},
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'abc');
  });

  test("{'wallet_address': 'abc'} normalizes to data.user.walletAddress",
      () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{'wallet_address': 'abc'},
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'abc');
  });

  test("{'address': 'abc'} normalizes to data.user.walletAddress", () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{'address': 'abc'},
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'abc');
  });

  test("{'success': true, 'data': {'walletAddress': 'abc'}} succeeds",
      () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'walletAddress': 'abc'},
      },
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'abc');
  });

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

  test("{'success': true} returns failure without auth evidence", () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{'success': true},
      api: api,
    );

    expect(result.isFailure, isTrue);
    expect(result.reason, contains('did not include user'));
  });

  test("{'foo': 'bar'} returns failure without auth evidence", () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{'foo': 'bar'},
      api: api,
    );

    expect(result.isFailure, isTrue);
  });

  test("{'data': {}} returns failure without auth evidence", () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{'data': <String, dynamic>{}},
      api: api,
    );

    expect(result.isFailure, isTrue);
  });

  test("{'data': {'user': {}}} returns failure without auth evidence",
      () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'data': <String, dynamic>{'user': <String, dynamic>{}},
      },
      api: api,
    );

    expect(result.isFailure, isTrue);
  });

  test("{'token': 'token-value'} returns success", () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{'token': 'token-value'},
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(result.payload?['token'], 'token-value');
  });

  test("{'authToken': 'token-value'} returns success", () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{'authToken': 'token-value'},
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(result.payload?['authToken'], 'token-value');
  });

  test("{'profile': {'id': 'p1'}} returns success", () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'profile': <String, dynamic>{'id': 'p1'},
      },
      api: api,
    );

    expect(result.isSuccess, isTrue);
    final data = result.payload?['data'] as Map<String, dynamic>?;
    final user = data?['user'] as Map<String, dynamic>?;
    expect(user?['id'], 'p1');
  });

  test('malformed Map failure reason does not include secret values', () async {
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

  test('explicit success true with walletAddress still succeeds', () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'success': true,
        'walletAddress': 'abc',
      },
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'abc');
  });

  test('explicit success true with user id still succeeds', () async {
    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'success': true,
        'user': <String, dynamic>{'id': 'u1'},
      },
      api: api,
    );

    expect(result.isSuccess, isTrue);
    final data = result.payload?['data'] as Map<String, dynamic>?;
    final user = data?['user'] as Map<String, dynamic>?;
    expect(user?['id'], 'u1');
  });

  test('null result with auth token and getMyProfile success returns success',
      () async {
    api.setAuthTokenForTesting(_jwtWithWallet('token-wallet'));
    api.setHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/profiles/me');
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'profile-1',
              'walletAddress': 'profile-wallet',
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await normalizeWalletAuthResult(
      routeResult: null,
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'profile-wallet');
  });

  test(
      'null result with token, profile failure, and current auth wallet succeeds',
      () async {
    api.setAuthTokenForTesting(_jwtWithWallet('token-wallet'));
    api.setHttpClient(
      MockClient((_) async => http.Response('server error', 500)),
    );

    final result = await normalizeWalletAuthResult(
      routeResult: null,
      api: api,
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'token-wallet');
  });

  test('null result with fallbackWalletAddress returns success', () async {
    final result = await normalizeWalletAuthResult(
      routeResult: null,
      api: api,
      fallbackWalletAddress: 'fallback-wallet',
    );

    expect(result.isSuccess, isTrue);
    expect(_wallet(result), 'fallback-wallet');
  });

  test('null result with no token, wallet, or fallback returns cancelled',
      () async {
    final result = await normalizeWalletAuthResult(
      routeResult: null,
      api: api,
    );

    expect(result.isCancelled, isTrue);
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
