import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/auth_wallet_result_normalizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _buildJwtWithWallet(String walletAddress) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode(const <String, Object>{'alg': 'none'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode(<String, Object>{
            'walletAddress': walletAddress,
            'sub': 'test-user',
          }),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.setHttpClient(
      MockClient((request) async {
        return http.Response('Not found', 404);
      }),
    );
  });

  tearDown(() {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
  });

  test('typed Map route result passes through unchanged', () async {
    final api = BackendApiService();

    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'data': {
          'user': {
            'id': 'u1',
            'walletAddress': 'wallet-123',
          },
        },
      },
      api: api,
    );

    expect(result, isNotNull);
    expect(result!['data']['user']['walletAddress'], 'wallet-123');
  });

  test('untyped Map route result normalizes with walletAddress', () async {
    final api = BackendApiService();

    final untyped = <Object?, Object?>{
      'user': <Object?, Object?>{
        'wallet_address': 'wallet-abc',
      },
    };

    final result = await normalizeWalletAuthResult(
      routeResult: untyped,
      api: api,
    );

    expect(result, isNotNull);
    expect((result!['data']['user'] as Map)['walletAddress'], 'wallet-abc');
  });

  test('nested payload shapes are normalized to {data:{user:{...}}}', () async {
    final api = BackendApiService();

    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'success': true,
        'token': 'ignored-in-normalizer-tests',
        'user': {
          'id': 'u2',
          'walletAddress': 'wallet-nested',
        },
      },
      api: api,
    );

    expect(result, isNotNull);
    final data = result!['data'] as Map<String, dynamic>?;
    expect(data, isNotNull);
    final user = data!['user'] as Map<String, dynamic>?;
    expect(user, isNotNull);
    expect(user!['walletAddress'], 'wallet-nested');
    expect(result['token'], 'ignored-in-normalizer-tests');
  });

  test('walletAddress-only result is normalized into user payload', () async {
    final api = BackendApiService();

    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'walletAddress': 'wallet-only',
      },
      api: api,
    );

    expect(result, isNotNull);
    expect(
      ((result!['data'] as Map)['user'] as Map)['walletAddress'],
      'wallet-only',
    );
  });

  test('null route result hydrates via getMyProfile when token exists',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(_buildJwtWithWallet('wallet-from-token'));

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/profiles/me') {
          return http.Response(
            jsonEncode(
              const <String, Object?>{
                'data': <String, Object?>{
                  'id': 'profile-id',
                  'walletAddress': 'wallet-from-profile',
                },
              },
            ),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      }),
    );

    final result = await normalizeWalletAuthResult(
      routeResult: null,
      api: api,
    );

    expect(result, isNotNull);
    expect(result!['data']['walletAddress'], 'wallet-from-profile');
  });

  test('null route result falls back to token wallet when getMyProfile fails',
      () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(_buildJwtWithWallet('wallet-from-token'));

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/profiles/me') {
          return http.Response('server error', 500);
        }
        return http.Response('Not found', 404);
      }),
    );

    final result = await normalizeWalletAuthResult(
      routeResult: null,
      api: api,
    );

    expect(result, isNotNull);
    expect(result!['data']['walletAddress'], 'wallet-from-token');
  });

  test('null route result without session evidence returns null', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);

    final result = await normalizeWalletAuthResult(
      routeResult: null,
      api: api,
    );

    expect(result, isNull);
  });

  test('explicit error payload returns null or error dict', () async {
    final api = BackendApiService();

    final result = await normalizeWalletAuthResult(
      routeResult: const <String, dynamic>{
        'success': false,
        'error': 'wallet connect failed',
      },
      api: api,
    );

    // Error responses may return null or an error dict; normalize handles both
    if (result != null) {
      expect(result['error'] ?? result['reason'], contains('wallet'));
    }
  });

  test('debug logs never include raw auth tokens', () async {
    final api = BackendApiService();
    final token = _buildJwtWithWallet('wallet-from-token');
    api.setAuthTokenForTesting(token);

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/profiles/me') {
          return http.Response(
            jsonEncode(
              const <String, Object?>{
                'data': <String, Object?>{
                  'walletAddress': 'wallet-from-profile',
                },
              },
            ),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      }),
    );

    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };

    try {
      await normalizeWalletAuthResult(
        routeResult: null,
        api: api,
      );
    } finally {
      debugPrint = originalDebugPrint;
    }

    expect(logs.join('\n'), isNot(contains(token)));
  });
}
